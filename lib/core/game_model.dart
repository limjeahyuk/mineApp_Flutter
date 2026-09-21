import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'board.dart';
import 'seeded_random.dart';
import 'types.dart';

export 'board.dart' show Difficulty;

/// 솔로(기본)·대전(스피드/지뢰 대결)·협동(공유 보드)의 지뢰찾기 코어.
/// Swift `GameModel`(ObservableObject)을 Flutter `ChangeNotifier`로 이식.
///
/// 솔로(기본) 모드 자동깃발 한 판 상한 — 난이도별. 다른 모드는 GachaItem.flag.perGameCap(3).
int soloAutoFlagCap(Difficulty d) {
  switch (d) {
    case Difficulty.beginner:
    case Difficulty.intermediate:
      return 3;
    case Difficulty.expert:
      return 5;
    case Difficulty.ultimate:
      return 7;
  }
}

/// 한 칸의 상태
class Cell {
  Cell(this.id);
  final int id;
  bool isMine = false;
  bool isRevealed = false;
  bool isFlagged = false;
  bool exploded = false; // 밟아서 터진 지뢰
  int adjacent = 0; // 주변 지뢰 수
  FlagOwner? flagOwner; // 공유 보드에서 이 깃발을 꽂은 사람
  bool isGolden = false; // 황금지뢰
}

class SoloWinResult {
  SoloWinResult(this.difficulty, this.timeSec, this.isBest);
  final Difficulty difficulty;
  final int timeSec;
  final bool isBest; // 이번 클리어가 개인 신기록인지

  @override
  bool operator ==(Object other) =>
      other is SoloWinResult &&
      other.difficulty == difficulty &&
      other.timeSec == timeSec &&
      other.isBest == isBest;
  @override
  int get hashCode => Object.hash(difficulty, timeSec, isBest);
}

const List<List<int>> _offsets = [
  [-1, -1], [-1, 0], [-1, 1],
  [0, -1], [0, 1],
  [1, -1], [1, 0], [1, 1],
];

/// 최고 기록 저장소. Swift는 UserDefaults를 썼다.
/// ponytail: UI 단계에서 shared_preferences로 교체. 지금은 인메모리라 앱 재시작 시 사라짐.
final Map<String, int> _bestTimes = {};

class GameModel extends ChangeNotifier {
  List<List<Cell>> grid = [];
  GameState state = GameState.ready;
  int elapsed = 0;

  Difficulty _difficulty = Difficulty.beginner;
  Difficulty get difficulty => _difficulty;
  set difficulty(Difficulty v) {
    if (_isReconfiguring || v == _difficulty) {
      _difficulty = v;
      return;
    }
    _difficulty = v;
    newGame(); // 난이도를 바꾸면 그 난이도의 새 판.
  }

  int? seed; // 현재 판 시드
  bool _isReconfiguring = false;
  bool _minesPlaced = false;
  bool _isSolo = true;
  Timer? _timer;

  int get rows => difficulty.rows;
  int get cols => difficulty.cols;

  RaceRule rule = RaceRule.speed;
  bool shared = false;

  // 훅 (RaceViewModel이 연결)
  void Function(List<int> safe, List<int> exploded)? onPushReveal;
  void Function(int index, bool set)? onPushFlag;
  void Function()? onLocalAction;
  void Function(Difficulty, int timeSec, bool noItem)? onSoloWin;
  void Function()? onGoldenMineFound;
  int Function() autoFlagSupplier = () => 0;
  void Function()? onConsumeAutoFlag;
  int Function() radarSupplier = () => 0;
  void Function()? onConsumeRadar;

  final Set<int> _goldenAwarded = {};
  SoloWinResult? soloWinResult;

  int autoFlagTickets = 0;
  int radarTickets = 0;
  bool usedAutoFlagThisGame = false;

  final List<int> _pendingSafe = [];
  final List<int> _pendingExploded = [];

  final List<int> _gameOverRevealed = [];
  final List<int> _reviveExploded = [];
  bool _didContinue = false;

  bool get canContinue => state == GameState.lost && _reviveExploded.isNotEmpty;

  int _count(bool Function(Cell) test) {
    var n = 0;
    for (final row in grid) {
      for (final c in row) {
        if (test(c)) n++;
      }
    }
    return n;
  }

  int get minesRemaining =>
      difficulty.mineCount - _count((c) => c.isFlagged);
  int get correctFlags => _count((c) => c.isFlagged && c.isMine);
  int get wrongFlags => _count((c) => c.isFlagged && !c.isMine);
  int get explodedMines => _count((c) => c.exploded);
  int get score => correctFlags - wrongFlags - explodedMines;

  int get myMineFlags =>
      _count((c) => c.isMine && c.flagOwner == FlagOwner.me);
  int get oppMineFlags =>
      _count((c) => c.isMine && c.flagOwner == FlagOwner.opponent);
  int get myWrongFlags => _count(
      (c) => c.isFlagged && !c.isMine && c.flagOwner == FlagOwner.me);
  int get oppWrongFlags => _count(
      (c) => c.isFlagged && !c.isMine && c.flagOwner == FlagOwner.opponent);
  int get myDuelScore => myMineFlags - myWrongFlags;
  int get oppDuelScore => oppMineFlags - oppWrongFlags;
  int get _resolvedMines =>
      _count((c) => c.isMine && (c.isFlagged || c.exploded));

  String? get boardCode =>
      seed == null ? null : makeCode(difficulty, seed!);

  GameModel() {
    newGame();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  static int _randomSeed() => Random().nextInt(1 << 32);

  // MARK: - 게임 시작 / 리셋

  void newGame() => startSeeded(_randomSeed());

  void startSolo(Difficulty newDifficulty) {
    _isReconfiguring = true;
    difficulty = newDifficulty;
    _isReconfiguring = false;
    newGame();
  }

  /// 솔로 판: 빈 보드로 시작하고 지뢰는 첫 클릭 때 배치(첫 클릭 안전).
  void startSeeded(int seed) {
    _stopTimer();
    _isSolo = true;
    elapsed = 0;
    this.seed = seed;
    _buildEmptyGrid();
    _minesPlaced = false;
    _resetReviveState();
    autoFlagTickets = min(autoFlagSupplier(), soloAutoFlagCap(difficulty));
    radarTickets = min(radarSupplier(), difficulty.radarCap);
    soloWinResult = null;
    state = GameState.ready;
    notifyListeners();
  }

  void _resetReviveState() {
    _gameOverRevealed.clear();
    _reviveExploded.clear();
    _goldenAwarded.clear();
    _didContinue = false;
    usedAutoFlagThisGame = false;
  }

  /// 이어하기: 밟은 지뢰는 깃발로, 게임오버로 드러난 지뢰는 다시 가리고 이어서 진행.
  void continueGame() {
    if (state != GameState.lost || _reviveExploded.isEmpty) return;
    for (final idx in _gameOverRevealed) {
      final r = idx ~/ cols, c = idx % cols;
      if (_inBounds(r, c)) grid[r][c].isRevealed = false;
    }
    for (final idx in _reviveExploded) {
      final r = idx ~/ cols, c = idx % cols;
      if (!_inBounds(r, c)) continue;
      grid[r][c].isRevealed = false;
      grid[r][c].exploded = false;
      grid[r][c].isFlagged = true;
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (grid[r][c].isFlagged && !grid[r][c].isMine) {
          grid[r][c].isFlagged = false;
        }
      }
    }
    _gameOverRevealed.clear();
    _reviveExploded.clear();
    _didContinue = true;
    state = GameState.playing;
    _startTimer();
    notifyListeners();
  }

  /// 멀티 레이스 시작: 공유 시드 + 지정 안전 칸으로 양쪽 동일 보드. 즉시 시작.
  void startSeededGame(
    int seed, {
    required int safeR,
    required int safeC,
    RaceRule rule = RaceRule.speed,
    bool shared = false,
  }) {
    _stopTimer();
    _isSolo = false;
    elapsed = 0;
    this.rule = rule;
    this.shared = shared;
    this.seed = seed;
    _buildSeededBoard(seed, safeR, safeC);
    _resetReviveState();
    _minesPlaced = true;
    autoFlagTickets = min(autoFlagSupplier(), GachaItem.flag.perGameCap);
    radarTickets = min(radarSupplier(), difficulty.radarCap);
    state = GameState.playing;
    _startTimer();
    notifyListeners();
  }

  bool loadCode(String code) {
    final parsed = parse(code);
    if (parsed == null) return false;
    _isReconfiguring = true;
    difficulty = parsed.$1;
    _isReconfiguring = false;
    startSeeded(parsed.$2);
    return true;
  }

  void resetCurrentGame() {
    if (seed != null) {
      startSeeded(seed!);
    } else {
      newGame();
    }
  }

  // MARK: - 사용자 동작

  void reveal(int r, int c) {
    if (state != GameState.ready && state != GameState.playing) return;
    onLocalAction?.call();
    if (!_inBounds(r, c)) return;
    if (grid[r][c].isFlagged) return;

    if (shared) {
      _pendingSafe.clear();
      _pendingExploded.clear();
    }

    if (!_minesPlaced) {
      _placeSeededMines(r, c);
      _minesPlaced = true;
    }
    if (state == GameState.ready) {
      state = GameState.playing;
      _startTimer();
    }

    if (grid[r][c].isRevealed) {
      _chord(r, c);
      if (shared) _flushPendingReveals();
      notifyListeners();
      return;
    }

    if (grid[r][c].isMine) {
      grid[r][c].isRevealed = true;
      grid[r][c].exploded = true;
      if (shared) {
        _pendingExploded.add(r * cols + c);
        if (rule == RaceRule.coop) {
          _coopGameOver();
        } else {
          _checkClaimEnd();
        }
      } else if (rule == RaceRule.speed) {
        _reviveExploded.add(r * cols + c);
        _gameOver();
      } else {
        _checkWin();
      }
      if (shared) _flushPendingReveals();
      notifyListeners();
      return;
    }

    _floodReveal(r, c);
    if (!(shared && rule == RaceRule.score)) _checkWin();
    if (shared) _flushPendingReveals();
    notifyListeners();
  }

  void toggleFlag(int r, int c) {
    if (state != GameState.ready && state != GameState.playing) return;
    onLocalAction?.call();
    if (!_inBounds(r, c) || grid[r][c].isRevealed) return;

    if (shared) {
      final idx = r * cols + c;
      switch (grid[r][c].flagOwner) {
        case FlagOwner.opponent:
          if (rule == RaceRule.coop) {
            grid[r][c].isFlagged = false;
            grid[r][c].flagOwner = null;
            onPushFlag?.call(idx, false);
          }
          notifyListeners();
          return;
        case FlagOwner.me:
          grid[r][c].isFlagged = false;
          grid[r][c].flagOwner = null;
          onPushFlag?.call(idx, false);
        case null:
          grid[r][c].isFlagged = true;
          grid[r][c].flagOwner = FlagOwner.me;
          onPushFlag?.call(idx, true);
          if (rule == RaceRule.score) _checkClaimEnd();
      }
      notifyListeners();
      return;
    }

    if (state == GameState.ready) {
      state = GameState.playing;
      _startTimer();
    }
    grid[r][c].isFlagged = !grid[r][c].isFlagged;
    if (grid[r][c].isFlagged) _claimGoldenIfNeeded(r, c);
    notifyListeners();
  }

  void _claimGoldenIfNeeded(int r, int c) {
    if (!_inBounds(r, c)) return;
    final cell = grid[r][c];
    if (!cell.isMine || !cell.isFlagged || !cell.isGolden) return;
    if (!_goldenAwarded.add(r * cols + c)) return; // 이미 보상한 칸
    onGoldenMineFound?.call();
  }

  // MARK: - 자동깃발(아이템)

  bool useAutoFlag(int r, int c) {
    if (state != GameState.playing) return false;
    if (autoFlagTickets <= 0) return false;
    if (!_inBounds(r, c)) return false;
    final cell = grid[r][c];
    if (!cell.isRevealed || cell.isMine || cell.adjacent <= 0) return false;

    final toFlag = <List<int>>[];
    for (final o in _offsets) {
      final nr = r + o[0], nc = c + o[1];
      if (!_inBounds(nr, nc)) continue;
      final n = grid[nr][nc];
      if (n.isMine && !n.isFlagged && !n.isRevealed) toFlag.add([nr, nc]);
    }
    if (toFlag.isEmpty) return false;

    onLocalAction?.call();
    autoFlagTickets -= 1;
    usedAutoFlagThisGame = true;
    onConsumeAutoFlag?.call();

    for (final p in toFlag) {
      grid[p[0]][p[1]].isFlagged = true;
      _claimGoldenIfNeeded(p[0], p[1]);
      if (shared) {
        grid[p[0]][p[1]].flagOwner = FlagOwner.me;
        onPushFlag?.call(p[0] * cols + p[1], true);
      }
    }
    if (shared && rule == RaceRule.score) _checkClaimEnd();
    notifyListeners();
    return true;
  }

  // MARK: - 레이더(아이템)

  bool useRadar() {
    if (state != GameState.playing || radarTickets <= 0) return false;

    final candidates = <List<int>>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = grid[r][c];
        if (!cell.isRevealed &&
            !cell.isMine &&
            !cell.isFlagged &&
            cell.adjacent > 0) {
          candidates.add([r, c]);
        }
      }
    }
    if (candidates.isEmpty) return false;

    onLocalAction?.call();
    radarTickets -= 1;
    usedAutoFlagThisGame = true;
    onConsumeRadar?.call();

    if (shared) {
      _pendingSafe.clear();
      _pendingExploded.clear();
    }
    candidates.shuffle(); // 비시드(로컬) — 공유 보드는 pendingSafe로 상대에 동기화
    for (final p in candidates.take(3)) {
      grid[p[0]][p[1]].isRevealed = true;
      if (shared) _pendingSafe.add(p[0] * cols + p[1]);
    }
    if (shared) _flushPendingReveals();

    if (shared && rule == RaceRule.score) {
      _checkClaimEnd();
    } else {
      _checkWin();
    }
    notifyListeners();
    return true;
  }

  // MARK: - 내부 로직

  void _placeSeededMines(int safeR, int safeC) {
    final rng = SeededGenerator(seed ?? _randomSeed());
    _placeMines(safeR, safeC, rng);
  }

  void _placeMines(int safeR, int safeC, SeededGenerator rng) {
    final forbidden = <int>{safeR * cols + safeC};
    for (final o in _offsets) {
      final nr = safeR + o[0], nc = safeC + o[1];
      if (_inBounds(nr, nc)) forbidden.add(nr * cols + nc);
    }
    final candidates = [
      for (var i = 0; i < rows * cols; i++)
        if (!forbidden.contains(i)) i,
    ];
    rng.shuffle(candidates);
    final minePositions = candidates.take(difficulty.mineCount).toList();
    for (final p in minePositions) {
      grid[p ~/ cols][p % cols].isMine = true;
    }

    // 황금지뢰 1~2개 (min이라도 random은 항상 소비 — Swift와 동일)
    final roll = rng.intInClosed(1, 2);
    final goldenCount = min(minePositions.length, roll);
    for (final p in rng.shuffled(minePositions).take(goldenCount)) {
      grid[p ~/ cols][p % cols].isGolden = true;
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (grid[r][c].isMine) continue;
        var count = 0;
        for (final o in _offsets) {
          final nr = r + o[0], nc = c + o[1];
          if (_inBounds(nr, nc) && grid[nr][nc].isMine) count++;
        }
        grid[r][c].adjacent = count;
      }
    }
  }

  void _buildEmptyGrid() {
    var id = 0;
    grid = [
      for (var r = 0; r < rows; r++)
        [for (var c = 0; c < cols; c++) Cell(id++)],
    ];
  }

  void _buildSeededBoard(int seed, int safeR, int safeC) {
    _buildEmptyGrid();
    final rng = SeededGenerator(seed);
    _placeMines(safeR, safeC, rng);
    _floodReveal(safeR, safeC);
  }

  void _floodReveal(int sr, int sc) {
    final stack = [
      [sr, sc]
    ];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final r = p[0], c = p[1];
      if (!_inBounds(r, c)) continue;
      final cell = grid[r][c];
      if (cell.isRevealed || cell.isFlagged || cell.isMine) continue;
      cell.isRevealed = true;
      if (shared) _pendingSafe.add(r * cols + c);
      if (cell.adjacent == 0) {
        for (final o in _offsets) {
          stack.add([r + o[0], c + o[1]]);
        }
      }
    }
  }

  void _chord(int r, int c) {
    final cell = grid[r][c];
    if (!cell.isRevealed || cell.adjacent <= 0) return;

    var accounted = 0;
    for (final o in _offsets) {
      final nr = r + o[0], nc = c + o[1];
      if (!_inBounds(nr, nc)) continue;
      if (grid[nr][nc].isFlagged || grid[nr][nc].exploded) accounted++;
    }
    if (accounted != cell.adjacent) return;

    var detonated = false;
    for (final o in _offsets) {
      final nr = r + o[0], nc = c + o[1];
      if (!_inBounds(nr, nc)) continue;
      final n = grid[nr][nc];
      if (n.isFlagged || n.isRevealed) continue;
      if (n.isMine) {
        n.isRevealed = true;
        n.exploded = true;
        if (shared) {
          _pendingExploded.add(nr * cols + nc);
          if (rule == RaceRule.coop) {
            _coopGameOver();
            return;
          }
          detonated = true;
          continue;
        }
        if (rule == RaceRule.speed) {
          _reviveExploded.add(nr * cols + nc);
          _gameOver();
          return;
        }
        detonated = true;
        continue;
      }
      _floodReveal(nr, nc);
    }
    if (rule == RaceRule.score && detonated) _clearMyFlagsAround(r, c);
    if (shared && rule == RaceRule.score) {
      _checkClaimEnd();
    } else {
      _checkWin();
    }
  }

  void _clearMyFlagsAround(int r, int c) {
    for (final o in _offsets) {
      final nr = r + o[0], nc = c + o[1];
      if (!_inBounds(nr, nc)) continue;
      final n = grid[nr][nc];
      if (!n.isFlagged || n.flagOwner == FlagOwner.opponent) continue;
      n.isFlagged = false;
      n.flagOwner = null;
      onPushFlag?.call(nr * cols + nc, false);
    }
  }

  void _gameOver() {
    state = GameState.lost;
    _stopTimer();
    _gameOverRevealed.clear();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (grid[r][c].isMine && !grid[r][c].isRevealed) {
          grid[r][c].isRevealed = true;
          _gameOverRevealed.add(r * cols + c);
        }
      }
    }
  }

  void _coopGameOver() {
    if (state != GameState.playing) return;
    state = GameState.lost;
    _stopTimer();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (grid[r][c].isMine && !grid[r][c].isRevealed) {
          grid[r][c].isRevealed = true;
        }
      }
    }
  }

  void _checkWin() {
    for (final row in grid) {
      for (final cell in row) {
        if (!cell.isMine && !cell.isRevealed) return;
      }
    }
    state = GameState.won;
    _stopTimer();
    if (rule != RaceRule.speed) return;
    if (!_didContinue) {
      _recordWin();
      if (_isSolo) {
        onSoloWin?.call(difficulty, elapsed, !usedAutoFlagThisGame);
      }
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (grid[r][c].isMine) grid[r][c].isFlagged = true;
      }
    }
  }

  void _checkClaimEnd() {
    if (!shared || state != GameState.playing) return;
    if (_resolvedMines >= difficulty.mineCount) {
      state = GameState.won;
      _stopTimer();
    }
  }

  void _flushPendingReveals() {
    if (_pendingSafe.isEmpty && _pendingExploded.isEmpty) return;
    onPushReveal?.call(List.of(_pendingSafe), List.of(_pendingExploded));
    _pendingSafe.clear();
    _pendingExploded.clear();
  }

  /// 서버(공유 보드)의 최신 상태를 로컬 보드에 반영.
  void applySharedState(SharedBoardState s) {
    if (!shared) return;
    for (final idx in s.revealed) {
      _revealIndex(idx, asMine: false);
    }
    for (final idx in s.exploded) {
      _revealIndex(idx, asMine: true);
    }
    final opp = s.oppFlags.toSet();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (grid[r][c].isRevealed) continue;
        final idx = r * cols + c;
        if (opp.contains(idx)) {
          grid[r][c].isFlagged = true;
          grid[r][c].flagOwner = FlagOwner.opponent;
        } else if (grid[r][c].flagOwner == FlagOwner.opponent) {
          grid[r][c].isFlagged = false;
          grid[r][c].flagOwner = null;
        }
      }
    }
    if (rule == RaceRule.coop) {
      if (explodedMines > 0) {
        _coopGameOver();
      } else {
        _checkWin();
      }
    } else {
      _checkClaimEnd();
    }
    notifyListeners();
  }

  void _revealIndex(int idx, {required bool asMine}) {
    final r = idx ~/ cols, c = idx % cols;
    if (!_inBounds(r, c)) return;
    grid[r][c].isRevealed = true;
    if (asMine) grid[r][c].exploded = true;
    grid[r][c].isFlagged = false;
    grid[r][c].flagOwner = null;
  }

  // MARK: - 판 코드 / 최고 기록

  static String makeCode(Difficulty difficulty, int seed) {
    final s = (seed & 0xFFFFFFFF).toRadixString(36).toUpperCase();
    return '${difficulty.code}-$s';
  }

  static (Difficulty, int)? parse(String code) {
    final cleaned = code
        .toUpperCase()
        .split('')
        .where((ch) => RegExp(r'[A-Z0-9]').hasMatch(ch))
        .join();
    if (cleaned.isEmpty) return null;
    final diff = Difficulty.fromCode(cleaned[0]);
    if (diff == null) return null;
    final seedPart = cleaned.substring(1);
    if (seedPart.isEmpty) return null;
    final seed = int.tryParse(seedPart, radix: 36);
    if (seed == null) return null;
    return (diff, seed);
  }

  int? bestTime(String code) {
    final v = _bestTimes[_bestKey(code)];
    return (v != null && v > 0) ? v : null;
  }

  static String _bestKey(String code) => 'best_$code';

  void _recordWin() {
    final code = boardCode;
    if (code == null) return;
    final key = _bestKey(code);
    final prev = _bestTimes[key] ?? 0;
    if (prev == 0 || elapsed < prev) _bestTimes[key] = elapsed;
  }

  // MARK: - 타이머

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state == GameState.playing && elapsed < 999) {
        elapsed += 1;
        notifyListeners();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  bool _inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;
}
