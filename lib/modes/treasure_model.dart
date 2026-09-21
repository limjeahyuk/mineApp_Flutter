import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/haptics.dart';
import '../core/seeded_random.dart';
import '../core/types.dart';
import 'touch_model.dart' show Blast;

/// 보물찾기 — 꼭짓점→중앙 보물까지 길을 뚫는다. 솔로/공유(대결) 겸용. Swift `TreasureModel` 이식.
class TrCell {
  bool isMine = false;
  bool isRevealed = false;
  bool isFlagged = false;
  bool isGolden = false;
  bool exploded = false;
  int adjacent = 0;
  bool isTreasure = false;
  bool onPath = false; // 보장된 안전 통로(지뢰 배치/재배치에서 제외)
  FlagOwner? owner;
}

class TreasureModel extends ChangeNotifier {
  final int size; // 홀수(정중앙 1칸 보장)
  final int startR = 0;
  final int startC = 0;
  int get center => size ~/ 2;
  int seed = 0;

  bool shared = false;
  (int, int) myStart = (0, 0);
  bool stunned = false;

  void Function(List<int> safe, List<int> exploded)? onPushReveal;
  final List<int> _pendingSafe = [];
  final List<int> _pendingExploded = [];

  int Function() autoFlagSupplier = () => 0;
  void Function()? onConsumeAutoFlag;
  void Function()? onGoldenMineFound;

  List<List<TrCell>> grid = [];
  GameState state = GameState.ready;
  int elapsed = 0;
  int minesHit = 0;
  bool failedByMines = false;
  static const int maxMineHits = 5; // 공유 보드에서 이만큼 밟으면 즉시 패배
  int revealedCount = 0;
  int autoFlagTickets = 0;
  final Set<int> _goldenAwarded = {};
  List<Blast> blasts = [];

  Timer? _timer;
  int _blastId = 0;
  final Random _localRng = Random();

  static const _neighbors = [
    [-1, -1], [-1, 0], [-1, 1],
    [0, -1], [0, 1],
    [1, -1], [1, 0], [1, 1],
  ];

  TreasureModel({int size = 51}) : size = size | 1 {
    newGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // MARK: - 파생 값

  int get mineCount => _count((c) => c.isMine);
  int get flagCount => _count((c) => c.isFlagged);
  bool get won => state == GameState.won;
  bool inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

  int _count(bool Function(TrCell) test) {
    var n = 0;
    for (final row in grid) {
      for (final c in row) {
        if (test(c)) n++;
      }
    }
    return n;
  }

  double get progress => _progressFor(FlagOwner.me);
  double get opponentProgress => _progressFor(FlagOwner.opponent);

  double _progressFor(FlagOwner owner) {
    final cd = center.toDouble();
    final maxDist = sqrt(cd * cd * 2);
    if (maxDist <= 0) return 0;
    var minDist = maxDist;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (grid[r][c].isRevealed && grid[r][c].owner == owner) {
          final d = sqrt(pow(r - center, 2) + pow(c - center, 2));
          if (d < minDist) minDist = d.toDouble();
        }
      }
    }
    return max(0, min(1, 1 - minDist / maxDist));
  }

  // MARK: - 시작 / 생성

  void newGame() => start(Random().nextInt(1 << 32));

  void start(int seed) {
    shared = false;
    myStart = (startR, startC);
    _begin(seed);
  }

  void startShared({required int seed, required bool asHost}) {
    shared = true;
    myStart = asHost ? (startR, startC) : (size - 1, size - 1);
    _begin(seed);
  }

  void _begin(int seed) {
    this.seed = seed;
    final rng = SeededGenerator(seed);
    _generate(rng, twoStarts: shared);
    elapsed = 0;
    minesHit = 0;
    failedByMines = false;
    revealedCount = 0;
    autoFlagTickets = min(autoFlagSupplier(), GachaItem.flag.perGameCap);
    _goldenAwarded.clear();
    blasts = [];
    stunned = false;
    _pendingSafe.clear();
    _pendingExploded.clear();
    state = GameState.playing;
    _revealFlood(myStart.$1, myStart.$2, FlagOwner.me);
    _flushPush();
    _startTimer();
    notifyListeners();
  }

  void _generate(SeededGenerator rng, {required bool twoStarts}) {
    final g = [
      for (var r = 0; r < size; r++) [for (var c = 0; c < size; c++) TrCell()],
    ];
    final c = center;
    // 보물: 가운데 3×3(모두 안전)
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (inBounds(c + dr, c + dc)) g[c + dr][c + dc].isTreasure = true;
      }
    }

    // 1) 안전 통로: 꼭짓점 → 중앙. 멀티는 반대 꼭짓점에서도.
    for (final p in _carvePath((startR, startC), (c, c), rng)) {
      g[p.$1][p.$2].onPath = true;
    }
    if (twoStarts) {
      for (final p in _carvePath((size - 1, size - 1), (c, c), rng)) {
        g[p.$1][p.$2].onPath = true;
      }
    }

    // 2) 지뢰 배치(통로·보물·시작 안전영역 제외, 중앙에 가까울수록 확률↑)
    final minePositions = <int>[];
    for (var r = 0; r < size; r++) {
      for (var cc = 0; cc < size; cc++) {
        if (g[r][cc].onPath || g[r][cc].isTreasure) continue;
        if ((r - startR).abs() <= 1 && (cc - startC).abs() <= 1) continue;
        if (twoStarts &&
            (r - (size - 1)).abs() <= 1 &&
            (cc - (size - 1)).abs() <= 1) {
          continue;
        }
        if (rng.doubleInRange(0, 1) < _mineProbability(r, cc)) {
          g[r][cc].isMine = true;
          minePositions.add(r * size + cc);
        }
      }
    }

    // 2-b) 황금지뢰 3~6개
    final roll = rng.intInClosed(3, 6);
    final goldenCount = min(minePositions.length, roll);
    for (final idx in rng.shuffled(minePositions).take(goldenCount)) {
      g[idx ~/ size][idx % size].isGolden = true;
    }

    grid = g;
    _recomputeAllAdjacency();
  }

  double _mineProbability(int r, int c) {
    final cd = center.toDouble();
    final maxDist = cd * 1.41421356;
    final d = sqrt(pow(r - center, 2) + pow(c - center, 2));
    final t = max(0, 1 - d / maxDist);
    return 0.10 + 0.32 * t;
  }

  List<(int, int)> _carvePath(
      (int, int) from, (int, int) to, SeededGenerator rng) {
    final path = <(int, int)>[from];
    var (r, c) = from;
    final (tr, tc) = to;
    var guard = 0;
    while ((r != tr || c != tc) && guard < size * 6) {
      guard++;
      var dr = (tr > r) ? 1 : (tr < r ? -1 : 0);
      var dc = (tc > c) ? 1 : (tc < c ? -1 : 0);
      if (rng.doubleInRange(0, 1) < 0.30) {
        if (rng.nextBool()) {
          dr = rng.randomElement(const [-1, 0, 1]);
        } else {
          dc = rng.randomElement(const [-1, 0, 1]);
        }
      }
      r = min(size - 1, max(0, r + dr));
      c = min(size - 1, max(0, c + dc));
      path.add((r, c));
    }
    while (r != tr || c != tc) {
      r += (tr > r) ? 1 : (tr < r ? -1 : 0);
      c += (tc > c) ? 1 : (tc < c ? -1 : 0);
      path.add((r, c));
    }
    return path;
  }

  void _recomputeAllAdjacency() {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (grid[r][c].isMine) continue;
        var n = 0;
        for (final o in _neighbors) {
          final nr = r + o[0], nc = c + o[1];
          if (inBounds(nr, nc) && grid[nr][nc].isMine) n++;
        }
        grid[r][c].adjacent = n;
      }
    }
  }

  // MARK: - 입력

  bool isFrontier(int r, int c) {
    for (final o in _neighbors) {
      final nr = r + o[0], nc = c + o[1];
      if (!inBounds(nr, nc)) continue;
      final n = grid[nr][nc];
      if (shared) {
        if (n.isRevealed && n.owner == FlagOwner.me) return true;
      } else if (n.isRevealed) {
        return true;
      }
    }
    return false;
  }

  void tap(int r, int c) {
    if (state != GameState.playing || stunned || !inBounds(r, c)) return;
    final cell = grid[r][c];
    if (cell.isRevealed || cell.isFlagged || !isFrontier(r, c)) return;

    if (cell.isMine) {
      minesHit++;
      _emitBlast(r, c);
      if (shared) {
        _hitMineShared(r, c);
        _checkMineLimit();
      } else {
        Haptics.error();
        _penaltyReset(r, c);
      }
      notifyListeners();
      return;
    }
    if (shared) {
      _pendingSafe.clear();
      _pendingExploded.clear();
    }
    _revealFlood(r, c, FlagOwner.me);
    if (shared) _flushPush();
    Haptics.tap();
    if (_treasureRevealedByMe) _winGame();
    notifyListeners();
  }

  void toggleFlag(int r, int c) {
    if (state != GameState.playing || stunned || !inBounds(r, c)) return;
    if (grid[r][c].isRevealed) return;
    if (!grid[r][c].isFlagged) {
      if (!isFrontier(r, c)) return;
    }
    grid[r][c].isFlagged = !grid[r][c].isFlagged;
    if (grid[r][c].isFlagged) _claimGoldenIfNeeded(r, c);
    Haptics.flagTap();
    notifyListeners();
  }

  void _clearFlagsAround(int r, int c) {
    for (final o in _neighbors) {
      final nr = r + o[0], nc = c + o[1];
      if (inBounds(nr, nc)) grid[nr][nc].isFlagged = false;
    }
  }

  bool useAutoFlag(int r, int c) {
    if (state != GameState.playing ||
        stunned ||
        autoFlagTickets <= 0 ||
        !inBounds(r, c)) {
      return false;
    }
    final cell = grid[r][c];
    if (!cell.isRevealed || cell.isMine || cell.adjacent <= 0) return false;

    final toFlag = <(int, int)>[];
    for (final o in _neighbors) {
      final nr = r + o[0], nc = c + o[1];
      if (!inBounds(nr, nc)) continue;
      final n = grid[nr][nc];
      if (n.isMine && !n.isFlagged && !n.isRevealed) {
        toFlag.add((nr, nc));
      }
    }
    if (toFlag.isEmpty) return false;

    autoFlagTickets--;
    onConsumeAutoFlag?.call();
    for (final p in toFlag) {
      grid[p.$1][p.$2].isFlagged = true;
      _claimGoldenIfNeeded(p.$1, p.$2);
    }
    Haptics.tap();
    notifyListeners();
    return true;
  }

  void _claimGoldenIfNeeded(int r, int c) {
    if (!inBounds(r, c)) return;
    final cell = grid[r][c];
    if (!cell.isGolden || !cell.isMine || !cell.isFlagged) return;
    if (!_goldenAwarded.add(r * size + c)) return;
    onGoldenMineFound?.call();
  }

  void loadAutoFlagSupply() {
    autoFlagTickets = min(autoFlagSupplier(), GachaItem.flag.perGameCap);
    notifyListeners();
  }

  void primaryTap(int r, int c) {
    if (!inBounds(r, c)) return;
    if (grid[r][c].isRevealed) {
      chord(r, c);
    } else {
      tap(r, c);
    }
  }

  void chord(int r, int c) {
    if (state != GameState.playing || stunned || !inBounds(r, c)) return;
    final cell = grid[r][c];
    if (!cell.isRevealed || cell.adjacent <= 0) return;
    var satisfied = 0;
    final covered = <(int, int)>[];
    for (final o in _neighbors) {
      final nr = r + o[0], nc = c + o[1];
      if (!inBounds(nr, nc)) continue;
      final n = grid[nr][nc];
      if (n.isFlagged || n.exploded) {
        satisfied++;
      } else if (!n.isRevealed) {
        covered.add((nr, nc));
      }
    }
    if (satisfied != cell.adjacent || covered.isEmpty) return;
    if (shared) {
      _pendingSafe.clear();
      _pendingExploded.clear();
    }
    var hitMine = false;
    for (final p in covered) {
      if (grid[p.$1][p.$2].isMine) {
        minesHit++;
        hitMine = true;
        _emitBlast(p.$1, p.$2);
        if (shared) {
          _markExplodedShared(p.$1, p.$2);
        } else {
          _penaltyReset(p.$1, p.$2);
        }
      } else {
        _revealFlood(p.$1, p.$2, FlagOwner.me);
      }
    }
    if (hitMine) _clearFlagsAround(r, c);
    if (shared) {
      _flushPush();
      if (hitMine) {
        _applyStun();
      } else {
        Haptics.tap();
      }
    } else {
      if (hitMine) {
        Haptics.error();
      } else {
        Haptics.tap();
      }
    }
    if (state == GameState.playing && _treasureRevealedByMe) {
      _winGame();
    } else if (shared && hitMine) {
      _checkMineLimit();
    }
    notifyListeners();
  }

  bool get _treasureRevealedByMe {
    for (var r = center - 1; r <= center + 1; r++) {
      for (var c = center - 1; c <= center + 1; c++) {
        if (!inBounds(r, c)) continue;
        if (grid[r][c].isTreasure &&
            grid[r][c].isRevealed &&
            grid[r][c].owner == FlagOwner.me) {
          return true;
        }
      }
    }
    return false;
  }

  // MARK: - 열기(플러드)

  void _revealFlood(int r, int c, FlagOwner owner) {
    final stack = [
      [r, c]
    ];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final cr = p[0], cc = p[1];
      if (!inBounds(cr, cc)) continue;
      final cell = grid[cr][cc];
      if (cell.isRevealed || cell.isMine || cell.isFlagged) continue;
      cell.isRevealed = true;
      cell.owner = owner;
      revealedCount++;
      if (shared && owner == FlagOwner.me) _pendingSafe.add(cr * size + cc);
      if (cell.adjacent == 0 && !cell.isTreasure) {
        for (final o in _neighbors) {
          stack.add([cr + o[0], cc + o[1]]);
        }
      }
    }
  }

  // MARK: - 공유 보드(온라인 멀티)

  void _hitMineShared(int r, int c) {
    _pendingSafe.clear();
    _pendingExploded.clear();
    _markExplodedShared(r, c);
    _flushPush();
    _applyStun();
  }

  void _markExplodedShared(int r, int c) {
    grid[r][c].isRevealed = true;
    grid[r][c].exploded = true;
    grid[r][c].owner = FlagOwner.me;
    _pendingExploded.add(r * size + c);
  }

  void _checkMineLimit() {
    if (!shared || state != GameState.playing || minesHit < maxMineHits) return;
    failedByMines = true;
    state = GameState.lost;
    _stopTimer();
    Haptics.error();
  }

  void _applyStun() {
    Haptics.error();
    stunned = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1500), () {
      stunned = false;
      notifyListeners();
    });
  }

  void _flushPush() {
    if (!shared || (_pendingSafe.isEmpty && _pendingExploded.isEmpty)) return;
    onPushReveal?.call(List.of(_pendingSafe), List.of(_pendingExploded));
    _pendingSafe.clear();
    _pendingExploded.clear();
  }

  void applyRemote(SharedBoardState s) {
    if (!shared) return;
    var oppHitTreasure = false;
    for (final idx in s.revealed) {
      final r = idx ~/ size, c = idx % size;
      if (!inBounds(r, c) || grid[r][c].isRevealed) continue;
      grid[r][c].isRevealed = true;
      grid[r][c].owner = FlagOwner.opponent;
      grid[r][c].isFlagged = false;
      revealedCount++;
      if (grid[r][c].isTreasure) {
        oppHitTreasure = true;
      }
    }
    for (final idx in s.exploded) {
      final r = idx ~/ size, c = idx % size;
      if (!inBounds(r, c) || grid[r][c].isRevealed) continue;
      grid[r][c].isRevealed = true;
      grid[r][c].exploded = true;
      grid[r][c].owner = FlagOwner.opponent;
    }
    if (oppHitTreasure && state == GameState.playing) {
      state = GameState.lost;
      _stopTimer();
    }
    notifyListeners();
  }

  void _emitBlast(int r, int c) {
    final b = Blast(_blastId++, r, c);
    blasts.add(b);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 600), () {
      blasts.removeWhere((x) => x.id == b.id);
      notifyListeners();
    });
  }

  // MARK: - 지뢰 패널티(5×5 리셋 + 재배치)

  void _penaltyReset(int r, int c) {
    const radius = 2;
    final region = <(int, int)>[];
    var mines = 0;
    for (var dr = -radius; dr <= radius; dr++) {
      for (var dc = -radius; dc <= radius; dc++) {
        final nr = r + dr, nc = c + dc;
        if (!inBounds(nr, nc)) continue;
        if (grid[nr][nc].isTreasure || grid[nr][nc].onPath) continue;
        if (grid[nr][nc].isMine) mines++;
        region.add((nr, nc));
      }
    }
    for (final p in region) {
      if (grid[p.$1][p.$2].isRevealed) revealedCount--;
      grid[p.$1][p.$2].isMine = false;
      grid[p.$1][p.$2].isRevealed = false;
      grid[p.$1][p.$2].isFlagged = false;
    }
    final spots = region.where((p) => !(p.$1 == r && p.$2 == c)).toList();
    spots.shuffle(_localRng);
    for (var i = 0; i < min(mines, spots.length); i++) {
      grid[spots[i].$1][spots[i].$2].isMine = true;
    }
    _recomputeAllAdjacency();
    _closeDisconnectedReveals();
  }

  void _closeDisconnectedReveals() {
    if (!grid[startR][startC].isRevealed) return;
    final reachable = [
      for (var r = 0; r < size; r++) [for (var c = 0; c < size; c++) false],
    ];
    final stack = [
      [startR, startC]
    ];
    reachable[startR][startC] = true;
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      for (final o in _neighbors) {
        final nr = p[0] + o[0], nc = p[1] + o[1];
        if (!inBounds(nr, nc) || reachable[nr][nc] || !grid[nr][nc].isRevealed) {
          continue;
        }
        reachable[nr][nc] = true;
        stack.add([nr, nc]);
      }
    }
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (grid[r][c].isRevealed && !reachable[r][c]) {
          grid[r][c].isRevealed = false;
          revealedCount--;
        }
      }
    }
  }

  // MARK: - 승리 / 타이머

  void _winGame() {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (grid[r][c].isTreasure) {
          grid[r][c].isRevealed = true;
          grid[r][c].owner = FlagOwner.me;
        }
      }
    }
    state = GameState.won;
    _stopTimer();
    Haptics.success();
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state == GameState.playing && elapsed < 9999) {
        elapsed++;
        notifyListeners();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
