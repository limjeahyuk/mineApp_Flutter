import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/haptics.dart';
import '../core/seeded_random.dart';
import '../core/types.dart';

/// "너에게 닿기를" — 협동 멀티. 한 보드에서 멀리 떨어진 두 사람이 각자 파 들어가다
/// 서로의 안전칸이 4방향으로 맞닿으면 둘 다 성공. Swift `TouchModel` 이식.
class TCell {
  bool isMine = false;
  bool isRevealed = false;
  bool isFlagged = false; // 내 깃발
  bool isGolden = false;
  bool oppFlagged = false; // 상대 깃발(안개 안에서만 보임)
  bool exploded = false;
  int adjacent = 0;
  bool onPath = false; // 두 시작점을 잇는 보장 안전통로
  bool isMegaphone = false;
  FlagOwner? owner; // 이 칸을 연 사람
}

class Blast {
  Blast(this.id, this.r, this.c);
  final int id;
  final int r;
  final int c;
}

class TouchModel extends ChangeNotifier {
  final int size;
  final int fogRadius = 3;
  final int minSeparation = 30;
  static const int megaphoneCount = 5;
  static const int goldenMin = 5, goldenMax = 10; // 협동 황금지뢰 수 범위
  int seed = 0;

  (int, int) myStart = (0, 0);
  (int, int) oppStart = (0, 0);
  List<(int, int)> megaphones = [];

  bool stunned = false;

  // 동기화 훅
  void Function(List<int> safe, List<int> exploded)? onPushReveal;
  void Function(int index, bool set)? onPushFlag;
  void Function()? onMineHitPenalty;
  void Function(int index)? onMegaphone;

  int Function() autoFlagSupplier = () => 0;
  void Function()? onConsumeAutoFlag;
  int Function() megaphoneSupplier = () => 0;
  void Function()? onConsumeMegaphone;
  void Function()? onGoldenMineFound;

  final List<int> _pendingSafe = [];
  final List<int> _pendingExploded = [];
  final List<int> _pendingMegaphones = [];

  List<List<TCell>> grid = [];
  List<List<bool>> visible = [];
  GameState state = GameState.ready;
  int elapsed = 0;
  int minesHit = 0;
  int revealedCount = 0;
  int autoFlagTickets = 0;
  int megaphoneTickets = 0;
  final Set<int> _goldenAwarded = {};
  List<Blast> blasts = [];

  (int, int) lastOpened = (0, 0);
  (int, int)? meetPoint;

  Timer? _timer;
  int _blastId = 0;
  final Random _localRng = Random();

  static const _neighbors = [
    [-1, -1], [-1, 0], [-1, 1],
    [0, -1], [0, 1],
    [1, -1], [1, 0], [1, 1],
  ];
  static const _neighbors4 = [
    [-1, 0], [1, 0], [0, -1], [0, 1],
  ];

  TouchModel({int size = 80}) : size = max(40, size) {
    startShared(seed: Random().nextInt(1 << 32), asHost: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;
  bool isVisible(int r, int c) => inBounds(r, c) && visible[r][c];
  bool get won => state == GameState.won;
  double get progress =>
      min(1, revealedCount / (size * size * 0.25));

  // MARK: - 시작 / 생성

  void startShared({required int seed, required bool asHost}) {
    this.seed = seed;
    final rng = SeededGenerator(seed);
    final (a, b) = _pickStarts(rng); // 같은 시퀀스 → 양쪽 동일
    myStart = asHost ? a : b;
    oppStart = asHost ? b : a;
    _generate(a, b, rng);
    elapsed = 0;
    minesHit = 0;
    revealedCount = 0;
    autoFlagTickets = min(autoFlagSupplier(), GachaItem.flag.perGameCap);
    megaphoneTickets =
        min(megaphoneSupplier(), GachaItem.megaphone.perGameCap);
    _goldenAwarded.clear();
    lastOpened = myStart;
    meetPoint = null;
    blasts = [];
    stunned = false;
    _pendingSafe.clear();
    _pendingExploded.clear();
    _pendingMegaphones.clear();
    state = GameState.playing;
    _revealFlood(myStart.$1, myStart.$2, FlagOwner.me);
    _flushPush();
    _startTimer();
    notifyListeners();
  }

  ((int, int), (int, int)) _pickStarts(SeededGenerator rng) {
    const m = 4;
    var a = (m, m), b = (size - 1 - m, size - 1 - m);
    for (var i = 0; i < 200; i++) {
      a = (rng.intInRange(m, size - m), rng.intInRange(m, size - m));
      b = (rng.intInRange(m, size - m), rng.intInRange(m, size - m));
      if (max((a.$1 - b.$1).abs(), (a.$2 - b.$2).abs()) >= minSeparation) {
        return (a, b);
      }
    }
    return (a, b); // 폴백
  }

  void _generate((int, int) a, (int, int) b, SeededGenerator rng) {
    final g = [
      for (var r = 0; r < size; r++) [for (var c = 0; c < size; c++) TCell()],
    ];

    // 1) 두 시작점을 잇는 보장 안전통로
    for (final p in _carvePath(a, b, rng)) {
      g[p.$1][p.$2].onPath = true;
    }

    // 2) 지뢰 배치(통로·시작 안전영역 제외, 밀도 0.18)
    final minePositions = <int>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (g[r][c].onPath) continue;
        if (_inSafeZone(r, c, a) || _inSafeZone(r, c, b)) continue;
        if (rng.doubleInRange(0, 1) < 0.18) {
          g[r][c].isMine = true;
          minePositions.add(r * size + c);
        }
      }
    }

    // 2-b) 황금지뢰 5~10개
    final roll = rng.intInClosed(goldenMin, goldenMax);
    final goldenCount = min(minePositions.length, roll);
    for (final idx in rng.shuffled(minePositions).take(goldenCount)) {
      g[idx ~/ size][idx % size].isGolden = true;
    }

    grid = g;
    _recomputeAllAdjacency();

    // 3) 확성기 5개 — 안전칸 중 무작위
    megaphones = [];
    final safeSpots = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (!grid[r][c].isMine &&
            !_inSafeZone(r, c, a) &&
            !_inSafeZone(r, c, b)) {
          safeSpots.add((r, c));
        }
      }
    }
    rng.shuffle(safeSpots);
    for (final p in safeSpots.take(megaphoneCount)) {
      grid[p.$1][p.$2].isMegaphone = true;
      megaphones.add(p);
    }

    visible = [
      for (var r = 0; r < size; r++) [for (var c = 0; c < size; c++) false],
    ];
  }

  bool _inSafeZone(int r, int c, (int, int) p) =>
      (r - p.$1).abs() <= 1 && (c - p.$2).abs() <= 1;

  List<(int, int)> _carvePath((int, int) from, (int, int) to, SeededGenerator rng) {
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
      if (n.isRevealed && n.owner == FlagOwner.me) return true;
    }
    return false;
  }

  void primaryTap(int r, int c) {
    if (!inBounds(r, c)) return;
    if (grid[r][c].isRevealed) {
      chord(r, c);
    } else {
      tap(r, c);
    }
  }

  void tap(int r, int c) {
    if (state != GameState.playing || stunned || !inBounds(r, c)) return;
    final cell = grid[r][c];
    if (cell.isRevealed || cell.isFlagged || !isFrontier(r, c)) return;

    if (cell.isMine) {
      minesHit++;
      _emitBlast(r, c);
      _hitMine(r, c);
      return;
    }
    lastOpened = (r, c);
    _pendingSafe.clear();
    _pendingExploded.clear();
    _pendingMegaphones.clear();
    final met = _revealFlood(r, c, FlagOwner.me);
    _flushPush();
    _flushMegaphones();
    Haptics.tap();
    if (met) _meetWin();
    notifyListeners();
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
    lastOpened = (r, c);
    _pendingSafe.clear();
    _pendingExploded.clear();
    _pendingMegaphones.clear();
    var hitMineFlag = false;
    var met = false;
    for (final p in covered) {
      if (grid[p.$1][p.$2].isMine) {
        minesHit++;
        hitMineFlag = true;
        _emitBlast(p.$1, p.$2);
        _markExploded(p.$1, p.$2);
      } else if (_revealFlood(p.$1, p.$2, FlagOwner.me)) {
        met = true;
      }
    }
    _flushPush();
    _flushMegaphones();
    if (hitMineFlag) {
      onMineHitPenalty?.call();
      _applyStun();
    } else {
      Haptics.tap();
    }
    if (met) _meetWin();
    notifyListeners();
  }

  void toggleFlag(int r, int c) {
    if (state != GameState.playing || !inBounds(r, c)) return;
    if (grid[r][c].isRevealed) return;
    grid[r][c].isFlagged = !grid[r][c].isFlagged;
    onPushFlag?.call(r * size + c, grid[r][c].isFlagged);
    if (grid[r][c].isFlagged) _claimGoldenIfNeeded(r, c);
    Haptics.flagTap();
    notifyListeners();
  }

  /// 파트너가 지뢰를 밟아 내 깃발 1개가 무작위로 떨어진다.
  void dropRandomFlag() {
    final flagged = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (grid[r][c].isFlagged) flagged.add((r, c));
      }
    }
    if (flagged.isEmpty) return;
    final pick = flagged[_localRng.nextInt(flagged.length)];
    grid[pick.$1][pick.$2].isFlagged = false;
    onPushFlag?.call(pick.$1 * size + pick.$2, false);
    Haptics.warning();
    notifyListeners();
  }

  // MARK: - 자동깃발(아이템)

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
      if (n.isMine && !n.isFlagged && !n.isRevealed) toFlag.add((nr, nc));
    }
    if (toFlag.isEmpty) return false;

    autoFlagTickets--;
    onConsumeAutoFlag?.call();
    for (final p in toFlag) {
      grid[p.$1][p.$2].isFlagged = true;
      _claimGoldenIfNeeded(p.$1, p.$2);
      onPushFlag?.call(p.$1 * size + p.$2, true);
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

  // MARK: - 확성기(아이템)

  bool useMegaphone() {
    if (state != GameState.playing || stunned || megaphoneTickets <= 0) {
      return false;
    }
    megaphoneTickets--;
    onConsumeMegaphone?.call();
    onMegaphone?.call(lastOpened.$1 * size + lastOpened.$2);
    Haptics.tap();
    notifyListeners();
    return true;
  }

  // MARK: - 열기(플러드) / 만남

  bool _revealFlood(int r, int c, FlagOwner owner) {
    final stack = [
      [r, c]
    ];
    final newly = <(int, int)>[];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final cr = p[0], cc = p[1];
      if (!inBounds(cr, cc)) continue;
      final cell = grid[cr][cc];
      if (cell.isRevealed || cell.isMine || cell.isFlagged) continue;
      cell.isRevealed = true;
      cell.owner = owner;
      cell.isFlagged = false;
      revealedCount++;
      newly.add((cr, cc));
      if (owner == FlagOwner.me) {
        _pendingSafe.add(cr * size + cc);
        _markVisible(cr, cc);
        if (cell.isMegaphone) {
          _pendingMegaphones.add(cr * size + cc);
        }
      }
      if (cell.adjacent == 0) {
        for (final o in _neighbors) {
          stack.add([cr + o[0], cc + o[1]]);
        }
      }
    }
    for (final p in newly) {
      if (_checkMeet(p.$1, p.$2)) {
        meetPoint = (p.$1, p.$2);
        return true;
      }
    }
    return false;
  }

  bool _checkMeet(int r, int c) {
    final cell = grid[r][c];
    if (!cell.isRevealed || cell.exploded || cell.owner == null) return false;
    final other =
        (cell.owner == FlagOwner.me) ? FlagOwner.opponent : FlagOwner.me;
    for (final o in _neighbors4) {
      final nr = r + o[0], nc = c + o[1];
      if (!inBounds(nr, nc)) continue;
      final n = grid[nr][nc];
      if (n.isRevealed && !n.exploded && n.owner == other) return true;
    }
    return false;
  }

  void _markExploded(int r, int c) {
    grid[r][c].isRevealed = true;
    grid[r][c].exploded = true;
    grid[r][c].owner = FlagOwner.me;
    grid[r][c].isFlagged = false;
    _pendingExploded.add(r * size + c);
    _markVisible(r, c);
  }

  void _hitMine(int r, int c) {
    _pendingSafe.clear();
    _pendingExploded.clear();
    _markExploded(r, c);
    _flushPush();
    onMineHitPenalty?.call();
    _applyStun();
    notifyListeners();
  }

  void _markVisible(int r, int c) {
    for (var dr = -fogRadius; dr <= fogRadius; dr++) {
      for (var dc = -fogRadius; dc <= fogRadius; dc++) {
        final nr = r + dr, nc = c + dc;
        if (inBounds(nr, nc)) visible[nr][nc] = true;
      }
    }
  }

  // MARK: - 동기화(상대 → 나)

  void applyRemote(SharedBoardState s) {
    final newlyOpp = <(int, int)>[];
    for (final idx in s.revealed) {
      final r = idx ~/ size, c = idx % size;
      if (!inBounds(r, c) || grid[r][c].isRevealed) continue;
      grid[r][c].isRevealed = true;
      grid[r][c].owner = FlagOwner.opponent;
      grid[r][c].isFlagged = false;
      revealedCount++;
      newlyOpp.add((r, c));
    }
    for (final idx in s.exploded) {
      final r = idx ~/ size, c = idx % size;
      if (!inBounds(r, c) || grid[r][c].isRevealed) continue;
      grid[r][c].isRevealed = true;
      grid[r][c].exploded = true;
      grid[r][c].owner = FlagOwner.opponent;
    }
    _reconcileOppFlags(s.oppFlags);
    for (final p in newlyOpp) {
      if (_checkMeet(p.$1, p.$2)) {
        meetPoint = (p.$1, p.$2);
        _meetWin();
        break;
      }
    }
    notifyListeners();
  }

  void _reconcileOppFlags(List<int> flags) {
    final set = flags.toSet();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final want = set.contains(r * size + c);
        if (grid[r][c].oppFlagged != want) grid[r][c].oppFlagged = want;
      }
    }
  }

  // MARK: - 푸시(나 → 상대)

  void _flushPush() {
    if (_pendingSafe.isEmpty && _pendingExploded.isEmpty) return;
    onPushReveal?.call(List.of(_pendingSafe), List.of(_pendingExploded));
    _pendingSafe.clear();
    _pendingExploded.clear();
  }

  void _flushMegaphones() {
    if (_pendingMegaphones.isEmpty) return;
    for (final idx in _pendingMegaphones) {
      onMegaphone?.call(idx);
    }
    _pendingMegaphones.clear();
  }

  // MARK: - 효과 / 승리 / 타이머

  void _applyStun() {
    Haptics.error();
    stunned = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1500), () {
      stunned = false;
      notifyListeners();
    });
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

  void _meetWin() {
    if (state != GameState.playing) return;
    state = GameState.won;
    _stopTimer();
    Haptics.success();
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state == GameState.playing && elapsed < 9999) {
        elapsed++;
        // ponytail: 80×80 보드(6400칸)를 매초 통째로 rebuild하지 않도록 elapsed는
        // 알림 없이 증가만 시킨다. 협동 화면은 경과시간을 표시하지 않고, 결과 보고용
        // elapsed는 실제 조작(reveal/원격 반영)마다 오는 notify로 함께 갱신된다.
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
