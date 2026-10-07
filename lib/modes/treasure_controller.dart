import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/types.dart';
import '../multiplayer/multiplayer.dart';
import 'treasure_model.dart';

enum TreasureFlow { searching, racing, finished }

/// 보물찾기 "같은 보드 레이스" — Swift TreasureRaceViewModel 이식.
/// 매칭되면 곧바로(카운트다운 없이) 같은 시드 + 반대 꼭짓점으로 공유 보드를 시작한다.
class TreasureController extends ChangeNotifier {
  TreasureController(this.service) {
    game.addListener(_onChange);
    service.onRoomCode = (c) {
      roomCode = c;
      _notify();
    };
    service.onOpponent = _handleOpponent;
    service.onOpponentLeft = _handleOpponentLeft;
    game.onPushReveal = (safe, exp) => service.pushReveal(safe, exp);
    service.onRemoteBoard = game.applyRemote;
    final store = LocalStore.maybe;
    if (store != null) {
      game.autoFlagSupplier = () => store.ownedFlags;
      game.onConsumeAutoFlag = store.consumeFlag;
      game.onGoldenMineFound = () {
        store.awardGoldenMine();
        Haptics.success();
      };
    }
  }

  final TreasureModel game = TreasureModel(size: 51);
  final MatchService service;

  TreasureFlow flow = TreasureFlow.searching;
  OpponentStatus opponent = OpponentStatus();
  RaceResult? result;
  String? roomCode;
  MatchError? failure;
  bool rematching = false;
  String opponentName = '상대';
  String opponentTitle = '';
  bool opponentLeft = false;
  bool opponentFailedByMines = false;

  RaceMode _mode = RaceMode.quick(Difficulty.beginner, RaceRule.speed);
  GameState _lastState = GameState.ready;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void start(RaceMode mode) {
    _mode = mode;
    flow = TreasureFlow.searching;
    result = null;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    opponentLeft = false;
    opponentFailedByMines = false;
    _notify();
    _matchInfo(mode).then(_begin).catchError((Object e) {
      if (_disposed || e == MatchError.cancelled) return;
      failure = e is MatchError ? e : MatchError.roomNotFound;
      _notify();
    });
  }

  // 보드가 고정(51)이라 난이도/규칙은 자리표시 — 시드만 쓴다(원본: 초급·스피드).
  Future<MatchInfo> _matchInfo(RaceMode mode) => switch (mode.kind) {
        RaceModeKind.host =>
          service.createRoom(Difficulty.beginner, RaceRule.speed),
        RaceModeKind.join => service.joinRoom(mode.code!),
        _ => service.find(Difficulty.beginner, RaceRule.speed),
      };

  void _begin(MatchInfo info) {
    if (_disposed) return;
    opponentName = info.opponentName;
    opponentTitle = info.opponentTitle;
    rematching = false;
    game.startShared(seed: info.seed, asHost: info.isHost);
    _lastState = game.state;
    flow = TreasureFlow.racing;
    service.beginRace();
    _notify();
  }

  /// 코드로 만난 상대(host/join)는 같은 상대와 재대결, 랜덤은 새 상대.
  void rematch() {
    if (_mode.kind == RaceModeKind.host || _mode.kind == RaceModeKind.join) {
      flow = TreasureFlow.searching;
      rematching = true;
      result = null;
      roomCode = null;
      failure = null;
      opponent = OpponentStatus();
      opponentLeft = false;
      opponentFailedByMines = false;
      _notify();
      service.rematch().then(_begin).catchError((Object e) {
        if (_disposed) return;
        rematching = false;
        if (e != MatchError.cancelled) {
          failure = e is MatchError ? e : MatchError.opponentLeft;
        }
        _notify();
      });
    } else {
      service.leave();
      start(_mode);
    }
  }

  void leave() => service.leave();

  void _onChange() {
    _notify();
    _report();
    if (game.state != _lastState) {
      _lastState = game.state;
      _handleLocal(game.state);
    }
  }

  void _handleLocal(GameState s) {
    if (flow != TreasureFlow.racing || result != null) return;
    if (s == GameState.won) {
      service.report(progress: 1, phase: RacerPhase.won, elapsed: game.elapsed, score: 0);
      _finish(RaceResult.win);
    } else if (s == GameState.lost && game.failedByMines) {
      service.report(
          progress: game.progress, phase: RacerPhase.lost, elapsed: game.elapsed, score: 0);
      _finish(RaceResult.lose);
    }
  }

  void _report() {
    if (flow != TreasureFlow.racing || result != null) return;
    final now = DateTime.now();
    if (now.difference(_lastReport) < const Duration(milliseconds: 500)) return;
    _lastReport = now;
    service.report(
        progress: game.progress, phase: RacerPhase.playing, elapsed: game.elapsed, score: 0);
  }

  void _handleOpponent(OpponentStatus s) {
    opponent = s;
    _notify();
    if (flow != TreasureFlow.racing || result != null) return;
    if (s.phase == RacerPhase.won) {
      _finish(RaceResult.lose); // 상대가 먼저 보물 발견
    } else if (s.phase == RacerPhase.lost) {
      opponentFailedByMines = true; // 상대가 지뢰 5번 밟고 자멸
      _finish(RaceResult.win);
    }
  }

  void _handleOpponentLeft() {
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
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    game.removeListener(_onChange);
    game.dispose();
    super.dispose();
  }
}
