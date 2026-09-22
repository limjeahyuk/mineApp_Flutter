import 'dart:async';
import 'dart:math';

import '../core/game_model.dart';
import '../core/types.dart';
import 'multiplayer.dart';

/// 봇전 전용 서비스 — 오프라인에서 봇과 대결한다. Swift BotMatchService 이식.
/// - 스피드: 시간 기반으로 상대 진행을 시뮬레이션하다 난이도별 목표 시각에 완료.
/// - 지뢰 대결: 봇이 같은 보드의 '미러'(botModel)를 직접 플레이. 봇이 연 칸/꽂은 깃발은
///   onRemoteBoard로 사람 화면 공유 보드에 반영되고, 사람의 동작은 pushReveal/pushFlag로
///   봇 미러에 반영된다.
///
/// ponytail: 합동(coop) 봇은 미이식(대전 메뉴 봇 카드는 지뢰찾기 스피드/지뢰대결 전용).
class BotMatchService extends MatchService {
  BotMatchService({required this.rule});

  final RaceRule rule;
  final Random _rng = Random();

  MatchInfo? _info;

  // 스피드: 시간 기반 상대 시뮬레이션
  Timer? _speedTimer;
  int _elapsed = 0;
  int _finishAt = 60;

  // 지뢰 대결: 봇이 직접 플레이하는 공유 보드 미러
  GameModel? _botModel;
  Timer? _moveTimer;
  bool _stopped = false;
  final Set<int> _humanFlags = {};
  double _flagBias = 0.45;

  static const _neighbors = [
    [-1, -1], [-1, 0], [-1, 1],
    [0, -1], [0, 1],
    [1, -1], [1, 0], [1, 1],
  ];
  static const _names = ['스윕봇', '마인봇', '지뢰봇', '디텍터봇', '클리어봇', '비프봇'];

  // ── 매칭(봇은 즉시 성사) ──
  @override
  Future<MatchInfo> find(Difficulty difficulty, RaceRule _) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200)); // 매칭 연출
    final info = MatchInfo(
      seed: _rng.nextInt(0x7FFFFFFF),
      difficulty: difficulty,
      safeR: difficulty.rows ~/ 2,
      safeC: difficulty.cols ~/ 2,
      opponentName: _names[_rng.nextInt(_names.length)],
      rule: rule, // 봇 규칙은 생성 시 고정
    );
    _info = info;
    _finishAt = _speedFinishSeconds(difficulty);
    return info;
  }

  @override
  Future<MatchInfo> createRoom(Difficulty difficulty, RaceRule r) =>
      find(difficulty, r);
  @override
  Future<MatchInfo> joinRoom(String code) => find(Difficulty.intermediate, rule);
  @override
  Future<MatchInfo> rematch() =>
      find(_info?.difficulty ?? Difficulty.intermediate, rule);

  @override
  void beginRace() {
    final info = _info;
    if (info == null) return;
    _stopped = false;
    if (rule == RaceRule.score) {
      _startBoardBot(info);
    } else {
      _startSpeedSim();
    }
  }

  @override
  void report(
      {required double progress,
      required RacerPhase phase,
      required int elapsed,
      required int score}) {
    // 봇은 사람 진행을 공유 보드로 직접 보므로 별도 처리 없음.
  }

  // 사람의 공유 보드 동작을 봇 미러에 반영.
  @override
  void pushReveal(List<int> safe, List<int> exploded) {
    final m = _botModel;
    if (!rule.sharesBoard || m == null) return;
    m.applySharedState(SharedBoardState(
        revealed: safe, exploded: exploded, oppFlags: _humanFlags.toList()));
  }

  @override
  void pushFlag(int index, {required bool set}) {
    final m = _botModel;
    if (!rule.sharesBoard || m == null) return;
    if (set) {
      _humanFlags.add(index);
    } else {
      _humanFlags.remove(index);
    }
    m.applySharedState(SharedBoardState(oppFlags: _humanFlags.toList()));
  }

  @override
  void leave() {
    _stopped = true;
    _speedTimer?.cancel();
    _speedTimer = null;
    _moveTimer?.cancel();
    _moveTimer = null;
    _botModel?.dispose();
    _botModel = null;
    _humanFlags.clear();
  }

  // ── 스피드 — 시간 기반 상대 ──
  void _startSpeedSim() {
    _elapsed = 0;
    _speedTimer?.cancel();
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += 1;
      if (_elapsed >= _finishAt) {
        onOpponent?.call(OpponentStatus(
            progress: 1, phase: RacerPhase.won, elapsed: _elapsed));
        _speedTimer?.cancel();
        _speedTimer = null;
      } else {
        onOpponent?.call(OpponentStatus(
            progress: (_elapsed / _finishAt).clamp(0, 1),
            phase: RacerPhase.playing,
            elapsed: _elapsed));
      }
    });
  }

  // ── 지뢰 대결 — 봇이 같은 보드를 직접 플레이 ──
  void _startBoardBot(MatchInfo info) {
    _moveTimer?.cancel(); // 재대결 시 이전 판 봇을 정리
    _botModel?.dispose();
    final m = GameModel()..difficulty = info.difficulty;
    m.startSeededGame(info.seed,
        safeR: info.safeR, safeC: info.safeC, rule: RaceRule.score, shared: true);
    m.onPushReveal = (_, _) => _emitBoard();
    m.onPushFlag = (_, _) => _emitBoard();
    _botModel = m;
    _humanFlags.clear();
    _flagBias = _flagBiasFor(info.difficulty);
    _scheduleFirstMove(_turnInterval(info.difficulty));
  }

  void _scheduleFirstMove(double base) {
    // 사람이 먼저 보드를 살펴볼 여유(시작하자마자 점수가 벌어지는 느낌 방지).
    _moveTimer?.cancel();
    _moveTimer = Timer(const Duration(milliseconds: 2200), () => _step(base));
  }

  void _step(double base) {
    final m = _botModel;
    if (_stopped || m == null || m.state != GameState.playing) return;
    _botActOnce(m);
    // 후반으로 갈수록 봇이 느려지도록 진행도 기반 배율.
    final pace = _paceMultiplier(_botProgress(m));
    final jitter = 0.75 + _rng.nextDouble() * (1.6 - 0.75);
    final delayMs = (base * pace * jitter * 1000).round();
    _moveTimer = Timer(Duration(milliseconds: delayMs), () => _step(base));
  }

  /// 봇 한 수 — 사람처럼 둔다. 확정 지뢰는 flagBias 확률로 차지, 아니면 안전 칸을 연다.
  void _botActOnce(GameModel m) {
    final (safe, mines) = _deductions(m);
    if (mines.isNotEmpty && _rng.nextDouble() < _flagBias) {
      _claim(mines[_rng.nextInt(mines.length)], m);
    } else if (safe.isNotEmpty) {
      final s = safe[_rng.nextInt(safe.length)];
      m.reveal(s[0], s[1]);
    } else if (mines.isNotEmpty) {
      _claim(mines[_rng.nextInt(mines.length)], m);
    } else {
      final s = _frontierSafeCell(m);
      if (s != null) {
        m.reveal(s[0], s[1]);
      } else {
        final mine = _unclaimedMine(m);
        if (mine != null) _claim(mine, m);
      }
    }
  }

  void _claim(List<int> cell, GameModel m) {
    final c = m.grid[cell[0]][cell[1]];
    if (c.isRevealed || c.isFlagged) return;
    m.toggleFlag(cell[0], cell[1]); // 깃발 = 지뢰 차지(점수)
  }

  /// 열린 숫자만으로 확정할 수 있는 안전 칸/지뢰 칸(사람의 기본 추론과 동일).
  (List<List<int>> safe, List<List<int>> mines) _deductions(GameModel m) {
    final cols = m.cols;
    final safe = <int>{};
    final mines = <int>{};
    for (var r = 0; r < m.rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = m.grid[r][c];
        if (!cell.isRevealed || cell.isMine || cell.adjacent == 0) continue;
        final hidden = <int>[];
        var known = 0;
        for (final o in _neighbors) {
          final nr = r + o[0], nc = c + o[1];
          if (nr < 0 || nr >= m.rows || nc < 0 || nc >= cols) continue;
          final n = m.grid[nr][nc];
          if (n.isFlagged || n.exploded) {
            known += 1;
          } else if (!n.isRevealed) {
            hidden.add(nr * cols + nc);
          }
        }
        if (hidden.isEmpty) continue;
        if (cell.adjacent == known) {
          safe.addAll(hidden);
        } else if (cell.adjacent - known == hidden.length) {
          mines.addAll(hidden);
        }
      }
    }
    List<int> toRC(int i) => [i ~/ cols, i % cols];
    return (
      safe.map(toRC).toList(),
      mines.difference(safe).map(toRC).toList(),
    );
  }

  /// 봇 미러의 현재 상태를 사람 화면으로 보낸다(봇 깃발은 상대 색으로 보인다).
  void _emitBoard() {
    final m = _botModel;
    if (m == null) return;
    final revealed = <int>[];
    final exploded = <int>[];
    final oppFlags = <int>[];
    var openedSafe = 0;
    for (var r = 0; r < m.rows; r++) {
      for (var c = 0; c < m.cols; c++) {
        final cell = m.grid[r][c];
        final idx = r * m.cols + c;
        if (cell.isRevealed) {
          if (cell.exploded) {
            exploded.add(idx);
          } else {
            revealed.add(idx);
            openedSafe += 1;
          }
        } else if (cell.isFlagged && cell.flagOwner == FlagOwner.me) {
          oppFlags.add(idx); // 봇 깃발 = 사람 화면에선 상대 색
        }
      }
    }
    onRemoteBoard?.call(SharedBoardState(
        revealed: revealed, exploded: exploded, oppFlags: oppFlags));
    final total = m.rows * m.cols - m.difficulty.mineCount;
    final progress = total > 0 ? (openedSafe / total).clamp(0.0, 1.0) : 0.0;
    onOpponent?.call(OpponentStatus(
        progress: progress,
        phase: RacerPhase.playing,
        elapsed: m.elapsed,
        score: m.myDuelScore));
  }

  // ── 후보 칸 찾기 ──
  List<int>? _unclaimedMine(GameModel m) {
    final frontier = <List<int>>[];
    final any = <List<int>>[];
    for (var r = 0; r < m.rows; r++) {
      for (var c = 0; c < m.cols; c++) {
        final cell = m.grid[r][c];
        if (!cell.isMine || cell.isRevealed || cell.isFlagged ||
            cell.flagOwner != null) {
          continue;
        }
        any.add([r, c]);
        if (_hasRevealedNeighbor(m, r, c)) frontier.add([r, c]);
      }
    }
    if (frontier.isNotEmpty) return frontier[_rng.nextInt(frontier.length)];
    if (any.isNotEmpty) return any[_rng.nextInt(any.length)];
    return null;
  }

  List<int>? _frontierSafeCell(GameModel m) {
    final cands = <List<int>>[];
    for (var r = 0; r < m.rows; r++) {
      for (var c = 0; c < m.cols; c++) {
        final cell = m.grid[r][c];
        if (cell.isRevealed || cell.isMine || cell.isFlagged) continue;
        if (_hasRevealedNeighbor(m, r, c)) cands.add([r, c]);
      }
    }
    return cands.isEmpty ? null : cands[_rng.nextInt(cands.length)];
  }

  bool _hasRevealedNeighbor(GameModel m, int r, int c) {
    for (final o in _neighbors) {
      final nr = r + o[0], nc = c + o[1];
      if (nr >= 0 && nr < m.rows && nc >= 0 && nc < m.cols &&
          m.grid[nr][nc].isRevealed) {
        return true;
      }
    }
    return false;
  }

  double _botProgress(GameModel m) {
    final total = m.rows * m.cols - m.difficulty.mineCount;
    if (total <= 0) return 0;
    var opened = 0;
    for (final row in m.grid) {
      for (final cell in row) {
        if (cell.isRevealed && !cell.isMine) opened += 1;
      }
    }
    return (opened / total).clamp(0, 1);
  }

  // ── 난이도 파라미터(Swift와 동일) ──
  int _speedFinishSeconds(Difficulty d) => switch (d) {
        Difficulty.beginner => 27 + _rng.nextInt(17), // ≈35초
        Difficulty.intermediate => 80 + _rng.nextInt(41), // ≈1분40초
        Difficulty.expert => 360 + _rng.nextInt(121), // ≈7분
        Difficulty.ultimate => 720 + _rng.nextInt(281), // ≈14분
      };

  double _turnInterval(Difficulty d) => switch (d) {
        Difficulty.beginner => 2.6,
        Difficulty.intermediate => 1.9,
        Difficulty.expert => 1.5,
        Difficulty.ultimate => 1.3,
      };

  double _paceMultiplier(double progress) {
    final p = progress.clamp(0.0, 1.0);
    return 1.0 + 1.3 * pow(p, 1.6);
  }

  double _flagBiasFor(Difficulty d) => switch (d) {
        Difficulty.beginner => 0.35,
        Difficulty.intermediate => 0.45,
        Difficulty.expert => 0.50,
        Difficulty.ultimate => 0.55,
      };
}
