import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/game_model.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/types.dart';
import 'multiplayer.dart';

enum RaceFlow { searching, starting, racing, finished }

/// 레이스 한 판 진행 — Swift RaceViewModel 이식. 로컬 GameModel + MatchService를 묶어
/// 매칭 → 카운트다운 → 레이스 → 결과, 승패 판정, 자리비움(AFK) 항복을 담당한다.
class RaceController extends ChangeNotifier {
  RaceController(this.service) {
    service.onRoomCode = (code) {
      roomCode = code;
      notifyListeners();
    };
    game.addListener(_onGameChanged);
    service.onOpponent = _handleOpponent;
    service.onOpponentLeft = _handleOpponentLeft;
    game.onLocalAction = _registerActivity;
    // 아이템: 내 보드는 보유 인벤토리에서 채우고 쓸 때마다 영구 차감(봇 미러는 미연결=0).
    final store = LocalStore.maybe;
    if (store != null) {
      game.autoFlagSupplier = () => store.ownedFlags;
      game.onConsumeAutoFlag = store.consumeFlag;
      game.radarSupplier = () => store.ownedRadars;
      game.onConsumeRadar = store.consumeRadar;
      game.onGoldenMineFound = () {
        store.awardGoldenMine();
        Haptics.success();
      };
    }
    // 공유 보드(지뢰 대결·합동): 내 동작을 상대에게, 상대 동작을 내 보드에.
    game.onPushReveal = (safe, exploded) => service.pushReveal(safe, exploded);
    game.onPushFlag = (index, set) => service.pushFlag(index, set: set);
    service.onRemoteBoard = (board) => game.applySharedState(board);
  }

  final GameModel game = GameModel();
  final MatchService service;

  RaceFlow flow = RaceFlow.searching;
  int startCountdown = 3;
  OpponentStatus opponent = OpponentStatus();
  RaceResult? result;
  bool opponentLeft = false;
  bool afkWarning = false;
  int afkRemaining = 0;
  bool shouldExit = false;
  MatchInfo? match;
  String? roomCode;
  MatchError? failure;
  bool rematching = false;

  RaceMode _mode = RaceMode.quick(Difficulty.beginner, RaceRule.speed);
  RaceMode get mode => _mode;
  GameState _lastState = GameState.ready;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _countdown;
  bool _disposed = false;

  // ── 진행률/점수 ──
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── 시작 ──
  void start(RaceMode mode) {
    _mode = mode;
    flow = RaceFlow.searching;
    result = null;
    opponentLeft = false;
    afkWarning = false;
    shouldExit = false;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    _notify();
    _matchInfo(mode).then((info) {
      if (_disposed) return;
      match = info;
      game.difficulty = info.difficulty;
      _beginStartCountdown(info);
    }).catchError((Object e) {
      if (_disposed || e == MatchError.cancelled) return;
      failure = e is MatchError ? e : MatchError.roomNotFound;
      _notify();
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

  /// 매칭 직후 — 3→2→1 카운트다운 후 실제 레이스(보드는 그 뒤에 만들어 타이머가 0부터).
  void _beginStartCountdown(MatchInfo info) {
    _countdown?.cancel();
    flow = RaceFlow.starting;
    startCountdown = 3;
    Haptics.tap();
    _notify();
    var n = 3;
    Haptics.tap();
    _countdown = Timer.periodic(const Duration(milliseconds: 800), (t) {
      n -= 1;
      if (n <= 0) {
        t.cancel();
        _beginRace(info);
        return;
      }
      startCountdown = n;
      Haptics.tap();
      _notify();
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
    _notify();
  }

  // ── 재대결 ──
  /// 코드로 만난 상대(host/join)는 같은 상대와 자동 재대결, 랜덤/봇은 새로 매칭.
  void rematch() {
    if (_mode.kind == RaceModeKind.host || _mode.kind == RaceModeKind.join) {
      _startRematch();
    } else {
      service.leave();
      start(_mode);
    }
  }

  void _startRematch() {
    flow = RaceFlow.searching;
    rematching = true;
    result = null;
    opponentLeft = false;
    afkWarning = false;
    shouldExit = false;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    _notify();
    service.rematch().then((info) {
      if (_disposed) return;
      match = info;
      rematching = false;
      game.difficulty = info.difficulty;
      _beginStartCountdown(info);
    }).catchError((Object e) {
      if (_disposed) return;
      rematching = false;
      if (e != MatchError.cancelled) {
        failure = e is MatchError ? e : MatchError.opponentLeft;
      }
      _notify();
    });
  }

  void leave() {
    _countdown?.cancel();
    _stopAfkTimer();
    service.leave();
  }

  @override
  void dispose() {
    _disposed = true;
    _countdown?.cancel();
    _afkTimer?.cancel();
    game.removeListener(_onGameChanged);
    game.dispose();
    super.dispose();
  }

  // ── 로컬 게임 변화 ──
  void _onGameChanged() {
    _notify();
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
      _finish(game.rule == RaceRule.score
          ? _scoreResult(myScore, opponentScore)
          : RaceResult.win);
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

  /// 진행률 보고는 최소 0.5초 간격(쓰기 절약). 승/패는 _handleLocal에서 즉시.
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
    _notify();
    if (flow != RaceFlow.racing || result != null) return;
    if (game.rule == RaceRule.coop) return; // 합동은 공유 보드로 직접 판정
    if (status.phase == RacerPhase.won) {
      _finish(game.rule == RaceRule.score
          ? _scoreResult(myScore, opponentScore)
          : RaceResult.lose);
    }
  }

  void _handleOpponentLeft() {
    if (flow != RaceFlow.racing || result != null) return;
    opponentLeft = true;
    _finish(game.rule == RaceRule.coop ? RaceResult.lose : RaceResult.win);
  }

  // ── 자리비움(AFK) 항복: 30초 무조작 → 경고, 120초 → 항복 ──
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
      _notify();
    }
  }

  /// 경고 배너 "계속하기".
  void stayActive() => _registerActivity();

  /// 백그라운드에 있던 시간은 자리비움으로 세지 않는다.
  void setSceneActive(bool active) {
    if (flow != RaceFlow.racing || result != null) return;
    active ? _startAfkTimer() : _stopAfkTimer();
  }

  void _checkAfk() {
    if (flow != RaceFlow.racing || result != null) {
      _stopAfkTimer();
      return;
    }
    final idle = DateTime.now().difference(_lastActivity);
    if (idle >= _afkForfeit) {
      _forfeitByAfk();
    } else if (idle >= _afkWarn) {
      afkRemaining = ((_afkForfeit - idle).inMilliseconds / 1000).ceil();
      afkWarning = true;
      _notify();
    }
  }

  void _forfeitByAfk() {
    if (flow != RaceFlow.racing || result != null) return;
    _stopAfkTimer();
    LocalStore.maybe?.recordRace(RaceResult.lose); // 항복 = 패배
    service.leave(); // 상대 부전승
    shouldExit = true;
    _notify();
  }

  void _finish(RaceResult r) {
    _stopAfkTimer();
    result = r;
    flow = RaceFlow.finished;
    LocalStore.maybe?.recordRace(r); // 대전 전적(승/패/무)
    switch (r) {
      case RaceResult.win:
        Haptics.success();
      case RaceResult.lose:
        Haptics.error();
      case RaceResult.draw:
        Haptics.warning();
    }
    _notify();
  }
}
