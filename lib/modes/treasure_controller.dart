import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/types.dart';
import '../multiplayer/multiplayer.dart';
import '../progression/daily.dart';
import 'treasure_model.dart';
import '../progression/title.dart';

enum TreasureFlow { searching, racing, finished }

/// 보물찾기 온라인 레이스 — Swift TreasureRaceViewModel 이식.
/// 검색 → (같은 시드 + 반대 꼭짓점) 공유 보드 레이스 → 결과. 보드는 51×51 고정(원본과 동일, 크로스플레이 정합).
class TreasureController extends ChangeNotifier {
  TreasureController(this.service, {int size = 51}) : model = TreasureModel(size: size) {
    model.addListener(_onChange);
    service.onRoomCode = (c) {
      roomCode = c;
      notifyListeners();
    };
    service.onOpponent = _handleOpponent;
    service.onOpponentLeft = _onOpponentLeft;
    service.onRemoteBoard = (b) => model.applyRemote(b);
    model.onPushReveal = (safe, exp) => service.pushReveal(safe, exp);
    final inv = LocalStore.shared;
    model.autoFlagSupplier = () => inv.ownedFlags;
    model.onConsumeAutoFlag = inv.consumeFlag;
    model.onGoldenMineFound = () {
      inv.awardGoldenMine();
      Daily.bump(DailyKind.golden);
      announceAchievements();
      Haptics.success();
    };
  }

  final TreasureModel model;
  final MatchService service;

  TreasureFlow flow = TreasureFlow.searching;
  OpponentStatus opponent = OpponentStatus();
  RaceResult? result;
  bool opponentLeft = false;
  bool opponentFailedByMines = false;
  bool rematching = false;
  MatchInfo? match;
  String? roomCode;
  MatchError? failure;
  String opponentName = '상대';
  String opponentTitle = '';

  RaceMode _mode = RaceMode.quick(Difficulty.beginner, RaceRule.speed);
  GameState _lastState = GameState.ready;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);

  double get myProgress => model.progress;
  double get opponentProgress => model.opponentProgress;

  void start(RaceMode mode) {
    _mode = mode;
    flow = TreasureFlow.searching;
    result = null;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    opponentLeft = false;
    opponentFailedByMines = false;
    notifyListeners();
    _findMatch(mode).then(_begin).catchError((Object e) {
      if (e != MatchError.cancelled) {
        failure = e is MatchError ? e : MatchError.roomNotFound;
        notifyListeners();
      }
    });
  }

  // 보드 고정(51)이라 difficulty/rule은 placeholder — 시드만 쓴다.
  Future<MatchInfo> _findMatch(RaceMode mode) {
    switch (mode.kind) {
      case RaceModeKind.quick:
      case RaceModeKind.bot:
        return service.find(Difficulty.beginner, RaceRule.speed);
      case RaceModeKind.host:
        return service.createRoom(Difficulty.beginner, RaceRule.speed);
      case RaceModeKind.join:
        return service.joinRoom(mode.code!);
    }
  }

  void _begin(MatchInfo info) {
    match = info;
    opponentName = info.opponentName;
    opponentTitle = info.opponentTitle;
    model.startShared(seed: info.seed, asHost: info.isHost);
    _lastState = model.state;
    flow = TreasureFlow.racing;
    service.beginRace();
    notifyListeners();
  }

  /// "다시 매칭" — 코드로 만난 상대는 같은 상대와 재대결, 랜덤은 새 상대.
  void rematch() {
    if (_mode.kind == RaceModeKind.quick) {
      service.leave();
      start(_mode);
      return;
    }
    flow = TreasureFlow.searching;
    rematching = true;
    result = null;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    opponentLeft = false;
    opponentFailedByMines = false;
    notifyListeners();
    service.rematch().then((info) {
      rematching = false;
      _begin(info);
    }).catchError((Object e) {
      rematching = false;
      if (e != MatchError.cancelled) {
        failure = e is MatchError ? e : MatchError.opponentLeft;
      }
      notifyListeners();
    });
  }

  void _onChange() {
    notifyListeners();
    _report();
    if (model.state == _lastState) return;
    _lastState = model.state;
    if (flow != TreasureFlow.racing || result != null) return;
    if (model.state == GameState.won) {
      service.report(progress: 1, phase: RacerPhase.won, elapsed: model.elapsed, score: 0);
      _finish(RaceResult.win);
    } else if (model.state == GameState.lost && model.failedByMines) {
      service.report(
          progress: model.progress, phase: RacerPhase.lost, elapsed: model.elapsed, score: 0);
      _finish(RaceResult.lose);
    }
  }

  void _report() {
    if (flow != TreasureFlow.racing || result != null) return;
    final now = DateTime.now();
    if (now.difference(_lastReport) < const Duration(milliseconds: 500)) return;
    _lastReport = now;
    service.report(
        progress: model.progress, phase: RacerPhase.playing, elapsed: model.elapsed, score: 0);
  }

  void _handleOpponent(OpponentStatus s) {
    opponent = s;
    notifyListeners();
    if (flow != TreasureFlow.racing || result != null) return;
    if (s.phase == RacerPhase.won) {
      _finish(RaceResult.lose);
    } else if (s.phase == RacerPhase.lost) {
      opponentFailedByMines = true;
      _finish(RaceResult.win);
    }
  }

  void _onOpponentLeft() {
    if (flow != TreasureFlow.racing || result != null) return;
    opponentLeft = true;
    _finish(RaceResult.win);
  }

  void _finish(RaceResult r) {
    result = r;
    flow = TreasureFlow.finished;
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

  void leave() => service.leave();

  @override
  void dispose() {
    model.removeListener(_onChange);
    model.dispose();
    super.dispose();
  }
}
