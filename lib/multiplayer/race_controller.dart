import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/game_model.dart';
import '../core/haptics.dart';
import '../core/types.dart';
import 'multiplayer.dart';

enum RaceFlow { searching, starting, racing, finished }

/// 레이스 한 판 진행 — 로컬 GameModel + MatchService를 묶어 매칭→카운트다운→레이스→결과를
/// 담당한다. Swift RaceViewModel 이식. (AFK 자동항복은 후속 단계로 미이식)
class RaceController extends ChangeNotifier {
  RaceController(this.service) {
    service.onRoomCode = (code) {
      roomCode = code;
      notifyListeners();
    };
    game.addListener(_onGameChanged);
    service.onOpponent = _handleOpponent;
    service.onOpponentLeft = _handleOpponentLeft;
    // 지뢰 대결/합동(공유 보드) 동기화
    game.onPushReveal = (safe, exploded) => service.pushReveal(safe, exploded);
    game.onPushFlag = (index, set) => service.pushFlag(index, set: set);
    service.onRemoteBoard = (board) => game.applySharedState(board);
    game.onGoldenMineFound = () => Haptics.success();
    game.onLocalAction = _registerActivity;
  }

  // ── 자리비움(AFK) 항복 — 30초 무조작이면 경고, 총 120초면 항복(패배) 후 나가기 ──
  bool afkWarning = false;
  int afkRemaining = 0;
  bool shouldExit = false; // 자리비움 항복 → 화면이 닫아야 함
  bool forfeitedByAfk = false;
  Timer? _afkTimer;
  DateTime _lastActivity = DateTime.now();
  static const _afkWarn = Duration(seconds: 30);
  static const _afkForfeit = Duration(seconds: 120);

  void _startAfkTimer() {
    _lastActivity = DateTime.now();
    afkWarning = false;
    _afkTimer?.cancel();
    _afkTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkAfk());
  }

  void _stopAfkTimer() {
    _afkTimer?.cancel();
    _afkTimer = null;
    afkWarning = false;
  }

  void _registerActivity() {
    _lastActivity = DateTime.now();
    if (afkWarning) {
      afkWarning = false;
      notifyListeners();
    }
  }

  /// 경고 배너 탭 = 계속하기.
  void stayActive() => _registerActivity();

  /// 앱 백그라운드 동안은 자리비움으로 세지 않는다.
  void setSceneActive(bool active) {
    if (flow != RaceFlow.racing || result != null) return;
    if (active) {
      _startAfkTimer();
    } else {
      _stopAfkTimer();
    }
  }

  void _checkAfk() {
    if (flow != RaceFlow.racing || result != null) {
      _stopAfkTimer();
      return;
    }
    final idle = DateTime.now().difference(_lastActivity);
    if (idle >= _afkForfeit) {
      _stopAfkTimer();
      forfeitedByAfk = true;
      service.leave(); // 상대 부전승
      shouldExit = true;
      notifyListeners();
    } else if (idle >= _afkWarn) {
      afkRemaining = ((_afkForfeit - idle).inMilliseconds / 1000).ceil();
      afkWarning = true;
      notifyListeners();
    }
  }

  final GameModel game = GameModel();
  final MatchService service;

  RaceFlow flow = RaceFlow.searching;
  int startCountdown = 3;
  OpponentStatus opponent = OpponentStatus();
  RaceResult? result;
  bool opponentLeft = false;
  MatchInfo? match;
  String? roomCode;
  MatchError? failure;
  bool rematching = false;

  RaceMode _mode = RaceMode.quick(Difficulty.beginner, RaceRule.speed);
  GameState _lastState = GameState.ready;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _countdown;

  // ── 진행률/점수 (Swift RaceViewModel 이식) ──
  double get myProgress {
    final total = game.rows * game.cols - game.difficulty.mineCount;
    if (total <= 0) return 0;
    var opened = 0;
    for (final row in game.grid) {
      for (final c in row) {
        if (c.isRevealed && !c.isMine) opened++;
      }
    }
    return (opened / total).clamp(0, 1);
  }

  int get myScore => game.rule == RaceRule.score ? game.myDuelScore : game.score;
  int get opponentScore =>
      game.rule == RaceRule.score ? game.oppDuelScore : opponent.score;

  double _mineRatio(int mines) {
    final total = game.difficulty.mineCount;
    if (total <= 0) return 0;
    return (mines / total).clamp(0, 1);
  }

  double get myBarProgress =>
      game.rule == RaceRule.score ? _mineRatio(myScore) : myProgress;
  double get opponentBarProgress => game.rule == RaceRule.score
      ? _mineRatio(opponentScore)
      : opponent.progress;

  // ── 시작 ──
  void start(RaceMode mode) {
    _mode = mode;
    flow = RaceFlow.searching;
    result = null;
    opponentLeft = false;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    notifyListeners();
    _matchInfo(mode).then((info) {
      match = info;
      game.difficulty = info.difficulty;
      _beginStartCountdown(info);
    }).catchError((Object e) {
      failure = e is MatchError ? e : MatchError.roomNotFound;
      notifyListeners();
    });
  }

  Future<MatchInfo> _matchInfo(RaceMode mode) {
    switch (mode.kind) {
      case RaceModeKind.quick:
      case RaceModeKind.bot:
        return service.find(mode.difficulty!, mode.rule);
      case RaceModeKind.host:
        return service.createRoom(mode.difficulty!, mode.rule);
      case RaceModeKind.join:
        return service.joinRoom(mode.code!);
    }
  }

  void _beginStartCountdown(MatchInfo info) {
    _countdown?.cancel();
    flow = RaceFlow.starting;
    startCountdown = 3;
    Haptics.tap();
    notifyListeners();
    _countdown = Timer.periodic(const Duration(milliseconds: 800), (t) {
      startCountdown -= 1;
      if (startCountdown <= 0) {
        t.cancel();
        _beginRace(info);
      } else {
        Haptics.tap();
      }
      notifyListeners();
    });
  }

  void _beginRace(MatchInfo info) {
    if (flow != RaceFlow.starting) return;
    game.startSeededGame(
      info.seed,
      safeR: info.safeR,
      safeC: info.safeC,
      rule: info.rule,
      shared: info.rule.sharesBoard,
    );
    _lastState = game.state;
    flow = RaceFlow.racing;
    service.beginRace();
    _startAfkTimer();
    notifyListeners();
  }

  // ── 재대결 ──
  void rematch() {
    // 방/코드/봇은 같은 상대로 새 판(service.rematch), 랜덤은 새로 매칭.
    if (_mode.kind == RaceModeKind.quick) {
      service.leave();
      start(_mode);
    } else {
      _startRematch();
    }
  }

  void _startRematch() {
    flow = RaceFlow.searching;
    rematching = true;
    result = null;
    opponentLeft = false;
    failure = null;
    opponent = OpponentStatus();
    notifyListeners();
    service.rematch().then((info) {
      match = info;
      rematching = false;
      game.difficulty = info.difficulty;
      _beginStartCountdown(info);
    }).catchError((Object e) {
      rematching = false;
      if (e != MatchError.cancelled) {
        failure = e is MatchError ? e : MatchError.opponentLeft;
      }
      notifyListeners();
    });
  }

  void leave() {
    _countdown?.cancel();
    _stopAfkTimer();
    service.leave();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    game.removeListener(_onGameChanged);
    game.dispose();
    super.dispose();
  }

  // ── 로컬 게임 변화 ──
  void _onGameChanged() {
    notifyListeners();
    _reportProgress();
    if (game.state != _lastState) {
      _lastState = game.state;
      _handleLocal(game.state);
    }
  }

  void _handleLocal(GameState state) {
    if (flow != RaceFlow.racing || result != null) return;
    if (state == GameState.won) {
      service.report(
          progress: 1, phase: RacerPhase.won, elapsed: game.elapsed, score: myScore);
      if (game.rule == RaceRule.score) {
        _finish(_scoreResult(myScore, opponentScore));
      } else {
        _finish(RaceResult.win);
      }
    } else if (state == GameState.lost) {
      service.report(
          progress: myProgress,
          phase: RacerPhase.lost,
          elapsed: game.elapsed,
          score: myScore);
      _finish(RaceResult.lose);
    }
  }

  RaceResult _scoreResult(int mine, int opp) {
    if (mine > opp) return RaceResult.win;
    if (mine < opp) return RaceResult.lose;
    return RaceResult.draw;
  }

  void _reportProgress() {
    if (flow != RaceFlow.racing || result != null) return;
    final now = DateTime.now();
    if (now.difference(_lastReport) < const Duration(milliseconds: 500)) return;
    _lastReport = now;
    service.report(
        progress: myProgress,
        phase: RacerPhase.playing,
        elapsed: game.elapsed,
        score: myScore);
  }

  void _handleOpponent(OpponentStatus status) {
    opponent = status;
    notifyListeners();
    if (flow != RaceFlow.racing || result != null) return;
    if (game.rule == RaceRule.coop) return; // 합동은 공유 보드로 판정
    if (status.phase == RacerPhase.won) {
      if (game.rule == RaceRule.score) {
        _finish(_scoreResult(myScore, opponentScore));
      } else {
        _finish(RaceResult.lose);
      }
    }
  }

  void _handleOpponentLeft() {
    if (flow != RaceFlow.racing || result != null) return;
    opponentLeft = true;
    _finish(game.rule == RaceRule.coop ? RaceResult.lose : RaceResult.win);
  }

  void _finish(RaceResult r) {
    _stopAfkTimer();
    result = r;
    flow = RaceFlow.finished;
    switch (r) {
      case RaceResult.win:
        Haptics.success();
      case RaceResult.lose:
        Haptics.error();
      case RaceResult.draw:
        Haptics.warning();
    }
    notifyListeners();
  }
}
