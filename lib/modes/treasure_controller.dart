import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/types.dart';
import '../multiplayer/multiplayer.dart';
import 'treasure_model.dart';

enum TreasureFlow { searching, racing, finished }

<<<<<<< HEAD
/// 보물찾기 "같은 보드 레이스" — Swift TreasureRaceViewModel 이식.
/// 매칭되면 곧바로(카운트다운 없이) 같은 시드 + 반대 꼭짓점으로 공유 보드를 시작한다.
class TreasureController extends ChangeNotifier {
  TreasureController(this.service) {
=======
/// 보물찾기 "같은 보드 레이스" 진행 — Swift TreasureRaceViewModel 이식.
/// 로컬 TreasureModel(51×51) + MatchService: 매칭→레이스→결과.
/// 양쪽이 같은 시드·반대 꼭짓점(호스트=좌상단, 게스트=우하단)에서 출발해 중앙 💎를 먼저 열면 승.
class TreasureController extends ChangeNotifier {
  TreasureController(this.service) : game = TreasureModel(size: 51) {
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    game.addListener(_onChange);
    service.onRoomCode = (c) {
      roomCode = c;
      _notify();
    };
    service.onOpponent = _handleOpponent;
    service.onOpponentLeft = _handleOpponentLeft;
<<<<<<< HEAD
    game.onPushReveal = (safe, exp) => service.pushReveal(safe, exp);
    service.onRemoteBoard = game.applyRemote;
    final store = LocalStore.maybe;
    if (store != null) {
      game.autoFlagSupplier = () => store.ownedFlags;
      game.onConsumeAutoFlag = store.consumeFlag;
=======
    // 공유 보드: 내가 연 칸/터뜨린 지뢰를 상대에게, 상대 동작을 내 보드에.
    game.onPushReveal = (safe, exp) => service.pushReveal(safe, exp);
    service.onRemoteBoard = (b) => game.applyRemote(b);
    final store = LocalStore.maybeShared;
    if (store != null) {
      game.autoFlagSupplier = () => store.ownedFlags;
      game.onConsumeAutoFlag = () => store.consumeFlag();
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      game.onGoldenMineFound = () {
        store.awardGoldenMine();
        Haptics.success();
      };
    }
  }

<<<<<<< HEAD
  final TreasureModel game = TreasureModel(size: 51);
=======
  final TreasureModel game;
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
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
<<<<<<< HEAD
  bool opponentFailedByMines = false;
=======
  bool opponentFailedByMines = false; // 상대가 지뢰를 너무 많이 밟아 자멸(나의 승)
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  RaceMode _mode = RaceMode.quick(Difficulty.beginner, RaceRule.speed);
  GameState _lastState = GameState.ready;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;
<<<<<<< HEAD

  void _notify() {
    if (!_disposed) notifyListeners();
  }
=======
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  void start(RaceMode mode) {
    _mode = mode;
    flow = TreasureFlow.searching;
    result = null;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    opponentLeft = false;
    opponentFailedByMines = false;
<<<<<<< HEAD
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
=======
    notifyListeners();
    _matchInfo(mode).then(_begin).catchError((Object e) {
      if (_disposed || e == MatchError.cancelled) return;
      failure = e is MatchError ? e : MatchError.roomNotFound;
      notifyListeners();
    });
  }

  // 보물찾기는 보드가 고정(size 51)이라 difficulty/rule은 placeholder — 시드만 사용한다.
  Future<MatchInfo> _matchInfo(RaceMode mode) {
    switch (mode.kind) {
      case RaceModeKind.host:
        return service.createRoom(Difficulty.beginner, RaceRule.speed);
      case RaceModeKind.join:
        return service.joinRoom(mode.code!);
      case RaceModeKind.quick:
      case RaceModeKind.bot:
        return service.find(Difficulty.beginner, RaceRule.speed);
    }
  }
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  void _begin(MatchInfo info) {
    if (_disposed) return;
    opponentName = info.opponentName;
    opponentTitle = info.opponentTitle;
    rematching = false;
<<<<<<< HEAD
=======
    // 같은 시드 + 반대 꼭짓점으로 공유 보드 시작
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    game.startShared(seed: info.seed, asHost: info.isHost);
    _lastState = game.state;
    flow = TreasureFlow.racing;
    service.beginRace();
<<<<<<< HEAD
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
=======
    notifyListeners();
  }

  /// "다시하기". 코드로 만난 상대(host/join)는 같은 상대와 재대결, 랜덤은 새 상대를 찾는다.
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
      notifyListeners();
      service.rematch().then(_begin).catchError((Object e) {
        if (_disposed) return;
        rematching = false;
        if (e != MatchError.cancelled) {
          failure = e is MatchError ? e : MatchError.opponentLeft;
        }
        notifyListeners();
      });
    } else {
      service.leave();
      start(_mode);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    }
  }

  void leave() => service.leave();

  void _onChange() {
    if (_disposed) return;
    notifyListeners();
    _reportProgress();
    if (game.state != _lastState) {
      _lastState = game.state;
      _handleLocal(game.state);
    }
  }

  void _handleLocal(GameState state) {
    if (flow != TreasureFlow.racing || result != null) return;
    if (state == GameState.won) {
      service.report(
          progress: 1, phase: RacerPhase.won, elapsed: game.elapsed, score: 0);
      _finish(RaceResult.win); // 보물을 먼저 열면 승
    } else if (state == GameState.lost && game.failedByMines) {
      // 지뢰를 너무 많이 밟아 자멸 → 상대에게 알리고 패배.
      service.report(
          progress: game.progress,
          phase: RacerPhase.lost,
          elapsed: game.elapsed,
          score: 0);
      _finish(RaceResult.lose);
    }
  }

  void _reportProgress() {
    if (flow != TreasureFlow.racing || result != null) return;
    final now = DateTime.now();
    if (now.difference(_lastReport) < const Duration(milliseconds: 500)) return;
    _lastReport = now;
    service.report(
<<<<<<< HEAD
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
=======
        progress: game.progress,
        phase: RacerPhase.playing,
        elapsed: game.elapsed,
        score: 0);
  }

  void _handleOpponent(OpponentStatus status) {
    opponent = status;
    notifyListeners();
    if (flow != TreasureFlow.racing || result != null) return;
    if (status.phase == RacerPhase.won) {
      _finish(RaceResult.lose); // 상대가 먼저 보물 발견 → 패
    } else if (status.phase == RacerPhase.lost) {
      opponentFailedByMines = true; // 상대가 지뢰 5번 밟고 자멸 → 승
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      _finish(RaceResult.win);
    }
  }

  void _handleOpponentLeft() {
    if (flow != TreasureFlow.racing || result != null) return;
    opponentLeft = true;
<<<<<<< HEAD
    _finish(RaceResult.win);
=======
    _finish(RaceResult.win); // 상대 이탈 → 부전승
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
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
<<<<<<< HEAD
    _notify();
=======
    notifyListeners();
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  }

  @override
  void dispose() {
    _disposed = true;
    game.removeListener(_onChange);
    game.dispose();
    super.dispose();
  }
}
