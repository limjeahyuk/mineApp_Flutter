import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/types.dart';
import '../multiplayer/multiplayer.dart';
import 'treasure_model.dart';

enum TreasureFlow { searching, starting, racing, finished }

/// 보물찾기 한 판 진행 — TreasureModel(중앙 보물 경쟁) + MatchService.
/// 매칭→카운트다운→먼저 중앙 보물을 열면 승리. Swift TreasureRaceViewModel 핵심 이식.
class TreasureController extends ChangeNotifier {
  TreasureController(this.service, {int size = 15})
      : model = TreasureModel(size: size) {
    model.addListener(_onChange);
    service.onRoomCode = (c) {
      roomCode = c;
      notifyListeners();
    };
    service.onOpponent = (s) {
      opponent = s;
      notifyListeners();
      _checkOpponent();
    };
    service.onOpponentLeft = _onOpponentLeft;
    service.onRemoteBoard = (b) => model.applyRemote(b);
    model.onPushReveal = (safe, exp) => service.pushReveal(safe, exp);
    model.onGoldenMineFound = Haptics.success;
  }

  final TreasureModel model;
  final MatchService service;

  TreasureFlow flow = TreasureFlow.searching;
  int startCountdown = 3;
  OpponentStatus opponent = OpponentStatus();
  RaceResult? result;
  bool opponentLeft = false;
  MatchInfo? match;
  String? roomCode;
  MatchError? failure;

  RaceMode _mode = RaceMode.quick(Difficulty.intermediate, RaceRule.speed);
  GameState _lastState = GameState.ready;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _countdown;

  double get myProgress => model.progress;
  double get opponentProgress => opponent.progress;

  void start(RaceMode mode) {
    _mode = mode;
    flow = TreasureFlow.searching;
    result = null;
    failure = null;
    opponentLeft = false;
    notifyListeners();
    _findMatch(mode).then((info) {
      match = info;
      _beginCountdown(info);
    }).catchError((Object e) {
      if (e != MatchError.cancelled) {
        failure = e is MatchError ? e : MatchError.opponentLeft;
        notifyListeners();
      }
    });
  }

  Future<MatchInfo> _findMatch(RaceMode mode) {
    switch (mode.kind) {
      case RaceModeKind.quick:
        return service.find(mode.difficulty!, mode.rule);
      case RaceModeKind.host:
        return service.createRoom(mode.difficulty!, mode.rule);
      case RaceModeKind.join:
        return service.joinRoom(mode.code!);
    }
  }

  void _beginCountdown(MatchInfo info) {
    _countdown?.cancel();
    flow = TreasureFlow.starting;
    startCountdown = 3;
    Haptics.tap();
    notifyListeners();
    _countdown = Timer.periodic(const Duration(milliseconds: 800), (t) {
      startCountdown -= 1;
      if (startCountdown <= 0) {
        t.cancel();
        _begin(info);
      } else {
        Haptics.tap();
      }
      notifyListeners();
    });
  }

  void _begin(MatchInfo info) {
    if (flow != TreasureFlow.starting) return;
    model.startShared(seed: info.seed, asHost: info.isHost);
    _lastState = model.state;
    flow = TreasureFlow.racing;
    service.beginRace();
    notifyListeners();
  }

  void _onChange() {
    notifyListeners();
    _report();
    if (model.state != _lastState) {
      _lastState = model.state;
      if (flow == TreasureFlow.racing && result == null) {
        if (model.state == GameState.won) {
          service.report(
              progress: 1, phase: RacerPhase.won, elapsed: model.elapsed, score: 0);
          _finish(RaceResult.win);
        } else if (model.state == GameState.lost) {
          service.report(
              progress: model.progress,
              phase: RacerPhase.lost,
              elapsed: model.elapsed,
              score: 0);
          _finish(RaceResult.lose);
        }
      }
    }
  }

  void _report() {
    if (flow != TreasureFlow.racing || result != null) return;
    final now = DateTime.now();
    if (now.difference(_lastReport) < const Duration(milliseconds: 500)) return;
    _lastReport = now;
    service.report(
        progress: model.progress,
        phase: RacerPhase.playing,
        elapsed: model.elapsed,
        score: 0);
  }

  void _checkOpponent() {
    if (flow != TreasureFlow.racing || result != null) return;
    if (opponent.phase == RacerPhase.won) _finish(RaceResult.lose);
  }

  void _onOpponentLeft() {
    if (flow != TreasureFlow.racing || result != null) return;
    opponentLeft = true;
    _finish(RaceResult.win); // 상대가 나가면 부전승
  }

  void _finish(RaceResult r) {
    result = r;
    flow = TreasureFlow.finished;
    r == RaceResult.win ? Haptics.success() : Haptics.error();
    notifyListeners();
  }

  void rematch() {
    service.leave();
    start(_mode);
  }

  void leave() {
    _countdown?.cancel();
    service.leave();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    model.removeListener(_onChange);
    model.dispose();
    super.dispose();
  }
}
