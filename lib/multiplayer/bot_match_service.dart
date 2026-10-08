import 'dart:async';
import 'dart:math';

import '../core/game_model.dart';
import '../core/types.dart';
import 'bot_solver.dart';
import 'multiplayer.dart';

/// 봇전 전용 서비스 — 오프라인에서 봇과 대결한다. Swift BotMatchService 이식.
/// 봇은 정답을 보지 않고 [BotSolver]로 화면에 보이는 숫자만 보고 푼다(막히면 찍어서 질 수도 있음).
/// - 스피드: 봇이 같은 시드의 자기 보드를 직접 푼다. 찍어야 할 땐 항상 안전한 칸을 골라 탈락하지 않는다.
/// - 지뢰 대결: 봇이 같은 보드의 '미러'(botModel)를 직접 플레이. 봇이 연 칸/꽂은 깃발은
///   onRemoteBoard로 사람 화면 공유 보드에 반영되고, 사람의 동작은 pushReveal/pushFlag로
///   봇 미러에 반영된다. 막히면 찍는다(터지면 감점).
/// - 합동: 봇 파트너가 같은 보드를 함께 푼다(확정 안전 칸만 열고, 확정 지뢰엔 깃발로 표시. 찍지 않음).
class BotMatchService extends MatchService {
  BotMatchService({required this.rule});

  final RaceRule rule;
  final Random _rng = Random();
  late final BotSolver _solver = BotSolver(_rng);

  MatchInfo? _info;

  // 봇이 직접 플레이하는 보드(스피드=자기 보드, 지뢰 대결·합동=공유 보드 미러)
  GameModel? _botModel;
  final Set<int> _knownMines = {}; // 스피드: 봇이 머릿속으로 확정한 지뢰(깃발은 안 꽂음)
  Timer? _moveTimer;
  bool _stopped = false;
  final Set<int> _humanFlags = {};
  double _flagBias = 0.45;

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
      opponentTitle: randomBotTitle(_rng),
    );
    _info = info;
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
    switch (rule) {
      case RaceRule.speed:
        _startSpeedBot(info);
      case RaceRule.score:
        _startBoardBot(info);
      case RaceRule.coop:
        _startCoopBot(info);
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
      // 합동: 사람이 파트너(봇)가 꽂은 깃발을 치웠다면 봇 미러에서도 내린다(되살아나지 않게).
      if (rule == RaceRule.coop) {
        final r = index ~/ m.cols, c = index % m.cols;
        final cell = m.grid[r][c];
        if (cell.isFlagged && cell.flagOwner == FlagOwner.me) {
          m.toggleFlag(r, c);
        }
      }
    }
    m.applySharedState(SharedBoardState(oppFlags: _humanFlags.toList()));
  }

  @override
  void leave() {
    _stopped = true;
    _moveTimer?.cancel();
    _moveTimer = null;
    _botModel?.dispose();
    _botModel = null;
    _humanFlags.clear();
  }

  // ── 스피드 — 봇이 같은 시드의 자기 보드를 직접 푼다 ──
  void _startSpeedBot(MatchInfo info) {
    _moveTimer?.cancel();
    _botModel?.dispose();
    final m = GameModel()
      ..difficulty = info.difficulty
      ..recordsWins = false;
    m.startSeededGame(info.seed, safeR: info.safeR, safeC: info.safeC);
    _botModel = m;
    _knownMines.clear();
    _moveTimer = Timer(
      const Duration(milliseconds: 1500),
      () => _speedStep(info),
    );
  }

  /// 다음 수를 고르고, 생각하는 시간만큼 기다렸다가 둔다(찍을 땐 더 오래 고민).
  void _speedStep(MatchInfo info) {
    final m = _botModel;
    if (_stopped || m == null || m.state != GameState.playing) return;
    BotMove? mv;
    while (true) {
      mv = _solver.next(m, _knownMines, startR: info.safeR, startC: info.safeC);
      if (mv == null || !mv.flag) break;
      _knownMines.add(mv.r * m.cols + mv.c); // 스피드엔 깃발이 필요 없다
    }
    if (mv == null) return;
    // 스피드 봇은 찍을 때 지뢰를 밟지 않는다 — 찍은 칸이 지뢰면 경계의 안전한 칸으로 바꾼다.
    final move = mv.guess && m.grid[mv.r][mv.c].isMine
        ? _safeGuess(m) ?? mv
        : mv;
    final jitter = 0.75 + _rng.nextDouble() * (1.6 - 0.75);
    // 찍어야 하는 수는 사람처럼 7~10초 더 망설인다 → 그 사이 사람이 따라잡을 기회.
    final think =
        _speedThink(info.difficulty) * jitter +
        (move.guess ? 7 + _rng.nextDouble() * 3 : 0);
    _moveTimer = Timer(Duration(milliseconds: (think * 1000).round()), () {
      if (_stopped || _botModel != m || m.state != GameState.playing) return;
      m.reveal(move.r, move.c);
      final phase = switch (m.state) {
        GameState.won => RacerPhase.won,
        GameState.lost => RacerPhase.lost,
        _ => RacerPhase.playing,
      };
      onOpponent?.call(
        OpponentStatus(
          progress: _botProgress(m),
          phase: phase,
          elapsed: m.elapsed,
        ),
      );
      if (phase == RacerPhase.playing) _speedStep(info);
    });
  }

  /// 아직 안 열린 안전 칸 하나(열린 칸 옆 우선) — 스피드 봇의 '운 좋은 찍기'.
  BotMove? _safeGuess(GameModel m) {
    final frontier = <BotMove>[], any = <BotMove>[];
    for (var r = 0; r < m.rows; r++) {
      for (var c = 0; c < m.cols; c++) {
        final cell = m.grid[r][c];
        if (cell.isRevealed || cell.isMine) continue;
        final mv = BotMove(r, c, guess: true);
        any.add(mv);
        var nearOpen = false;
        for (var dr = -1; dr <= 1 && !nearOpen; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            final nr = r + dr, nc = c + dc;
            if (nr >= 0 &&
                nr < m.rows &&
                nc >= 0 &&
                nc < m.cols &&
                m.grid[nr][nc].isRevealed) {
              nearOpen = true;
              break;
            }
          }
        }
        if (nearOpen) frontier.add(mv);
      }
    }
    final pool = frontier.isNotEmpty ? frontier : any;
    return pool.isEmpty ? null : pool[_rng.nextInt(pool.length)];
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

  // ── 합동(협동) — 봇이 같은 보드를 함께 푼다 ──
  void _startCoopBot(MatchInfo info) {
    _moveTimer?.cancel();
    _botModel?.dispose();
    final m = GameModel()..difficulty = info.difficulty;
    m.startSeededGame(info.seed,
        safeR: info.safeR, safeC: info.safeC, rule: RaceRule.coop, shared: true);
    m.onPushReveal = (_, _) => _emitBoard();
    m.onPushFlag = (_, _) => _emitBoard();
    _botModel = m;
    _humanFlags.clear();
    final base = _turnInterval(info.difficulty);
    _moveTimer?.cancel();
    _moveTimer =
        Timer(const Duration(milliseconds: 2200), () => _coopStep(base));
  }

  void _coopStep(double base) {
    final m = _botModel;
    if (_stopped || m == null || m.state != GameState.playing) return;
    _botActOnceCoop(m);
    final jitter = 0.75 + _rng.nextDouble() * (1.6 - 0.75);
    _moveTimer = Timer(Duration(milliseconds: (base * jitter * 1000).round()),
        () => _coopStep(base));
  }

  /// 합동 봇 한 수 — '확정된' 안전 칸만 연다. 확정 지뢰엔 깃발을 꽂아 사람이 피하도록 표시.
  /// 추측은 하지 않는다(빗나가면 둘 다 패배). 막히면 사람이 결정할 때까지 기다린다.
  void _botActOnceCoop(GameModel m) {
    final info = _info;
    if (info == null) return;
    final mv = _solver.next(
      m,
      const {},
      startR: info.safeR,
      startC: info.safeC,
      allowGuess: false,
    );
    if (mv == null) return;
    if (mv.flag) {
      if (m.grid[mv.r][mv.c].flagOwner == null) _claim([mv.r, mv.c], m);
    } else {
      m.reveal(mv.r, mv.c);
    }
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
  /// 확정 수가 없으면 가장 덜 위험해 보이는 칸을 찍는다(지뢰면 터져서 감점).
  void _botActOnce(GameModel m) {
    final info = _info;
    if (info == null) return;
    final (safe, mines) = _solver.deduce(m, const {});
    List<int> rc(int i) => [i ~/ m.cols, i % m.cols];
    if (mines.isNotEmpty && _rng.nextDouble() < _flagBias) {
      _claim(rc(mines.elementAt(_rng.nextInt(mines.length))), m);
    } else if (safe.isNotEmpty) {
      final s = rc(safe.elementAt(_rng.nextInt(safe.length)));
      m.reveal(s[0], s[1]);
    } else if (mines.isNotEmpty) {
      _claim(rc(mines.elementAt(_rng.nextInt(mines.length))), m);
    } else {
      final mv = _solver.next(
        m,
        const {},
        startR: info.safeR,
        startC: info.safeC,
      );
      if (mv == null) return;
      if (mv.flag) {
        _claim([mv.r, mv.c], m);
      } else {
        m.reveal(mv.r, mv.c);
      }
    }
  }

  void _claim(List<int> cell, GameModel m) {
    final c = m.grid[cell[0]][cell[1]];
    if (c.isRevealed || c.isFlagged) return;
    m.toggleFlag(cell[0], cell[1]); // 깃발 = 지뢰 차지(점수)
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

  // ── 난이도 파라미터 ──
  /// 스피드 봇이 한 칸 여는 데 드는 기본 생각 시간(초, 실제는 ×0.75~1.6 흔들림).
  /// 예상 완주 시간은 test/bot_solver_test.dart의 스피드 봇 테스트가 출력한다.
  double _speedThink(Difficulty d) => switch (d) {
    Difficulty.beginner => 4,
    Difficulty.intermediate => 3.5,
    Difficulty.expert => 3,
    Difficulty.ultimate => 2.5,
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
