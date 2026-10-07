import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/types.dart';
import '../multiplayer/multiplayer.dart';
<<<<<<< HEAD
import 'touch_board.dart';
=======
import '../ranking/ranking_service.dart';
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
import 'touch_model.dart';

enum CoopFlow { searching, racing, finished }

<<<<<<< HEAD
/// "너에게 닿기를" 진행 — Swift TouchRaceViewModel 이식.
/// 매칭 → 함께 길 뚫기 → 두 사람 칸이 맞닿으면 둘 다 성공(걸린 시간 = 협동 기록).
/// 확성기 핑·지뢰 페널티(파트너 깃발 1개 떨어뜨리기)도 여기서 중계한다.
class CoopController extends ChangeNotifier {
  CoopController(this.service) {
=======
/// 확성기 핑 — mine=true면 내가 울린 것(확인 배너), false면 파트너가 울린 것(방향 화살표).
class TouchPing {
  TouchPing(this.id, this.r, this.c, {this.mine = false});
  final int id;
  final int r;
  final int c;
  final bool mine;
}

/// "너에게 닿기를"(협동) 진행 — Swift TouchRaceViewModel 이식.
/// 로컬 TouchModel(80×80 안개 공유보드) + MatchService: 매칭 → 플레이 → 만남(둘 다 성공).
/// 확성기 핑·지뢰 페널티(파트너 깃발 1개 떨어뜨림) 같은 협동 신호도 여기서 중계한다.
class CoopController extends ChangeNotifier {
  CoopController(this.service) : game = TouchModel(size: 80) {
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    game.addListener(_onChange);
    service.onRoomCode = (c) {
      roomCode = c;
      _notify();
    };
    service.onOpponent = _handleOpponent;
    service.onOpponentLeft = _handleOpponentLeft;
<<<<<<< HEAD
=======
    // 공유 보드(협동): 내 동작을 파트너에게 보내고, 파트너 동작을 내 보드에 반영한다.
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    game.onPushReveal = (safe, exp) => service.pushReveal(safe, exp);
    game.onPushFlag = (i, set) => service.pushFlag(i, set: set);
    game.onMineHitPenalty = service.pushFlagPenalty;
    game.onMegaphone = (idx) {
<<<<<<< HEAD
      service.pushPing(idx); // 파트너 화면에 방향 화살표
      _showPing(idx, mine: true); // 울린 나에게도 확인 표시
    };
    final store = LocalStore.maybe;
    if (store != null) {
      game.autoFlagSupplier = () => store.ownedFlags;
      game.onConsumeAutoFlag = store.consumeFlag;
      game.megaphoneSupplier = () => store.ownedMegaphones;
      game.onConsumeMegaphone = store.consumeMegaphone;
=======
      service.pushPing(idx); // 파트너 화면에 방향 화살표로 알림
      _showPing(idx, mine: true); // 울린 나에게도 확인 표시
    };
    service.onRemoteBoard = (b) => game.applyRemote(b);
    service.onFlagPenalty = game.dropRandomFlag;
    service.onPing = (idx) => _showPing(idx);
    final store = LocalStore.maybeShared;
    if (store != null) {
      game.autoFlagSupplier = () => store.ownedFlags;
      game.onConsumeAutoFlag = () => store.consumeFlag();
      game.megaphoneSupplier = () => store.ownedMegaphones;
      game.onConsumeMegaphone = () => store.consumeMegaphone();
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      game.onGoldenMineFound = () {
        store.awardGoldenMine();
        Haptics.success();
      };
    }
<<<<<<< HEAD
    service.onRemoteBoard = game.applyRemote;
    service.onFlagPenalty = game.dropRandomFlag;
    service.onPing = (idx) => _showPing(idx);
  }

  final TouchModel game = TouchModel(size: 80);
=======
  }

  final TouchModel game;
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  final MatchService service;

  CoopFlow flow = CoopFlow.searching;
  OpponentStatus opponent = OpponentStatus();
  RaceResult? result;
  String? roomCode;
  MatchError? failure;
  bool rematching = false;
  String opponentName = '상대';
  String opponentTitle = '';
  bool opponentLeft = false;
  final List<TouchPing> pings = [];

  RaceMode _mode = RaceMode.quick(Difficulty.beginner, RaceRule.coop);
  GameState _lastState = GameState.ready;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);
<<<<<<< HEAD
  bool _disposed = false;
  int _pingId = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }
=======
  int _pingId = 0;
  bool _disposed = false;
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  void start(RaceMode mode) {
    _mode = mode;
    flow = CoopFlow.searching;
    result = null;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    opponentLeft = false;
    pings.clear();
<<<<<<< HEAD
    _notify();
    _matchInfo(mode).then(_begin).catchError((Object e) {
      if (_disposed || e == MatchError.cancelled) return;
      failure = e is MatchError ? e : MatchError.roomNotFound;
      _notify();
    });
  }

  // 보드 고정(80×80) — 난이도는 자리표시. 협동이라 rule=.coop으로 같은 모드끼리만 매칭.
  Future<MatchInfo> _matchInfo(RaceMode mode) => switch (mode.kind) {
        RaceModeKind.host => service.createRoom(Difficulty.beginner, RaceRule.coop),
        RaceModeKind.join => service.joinRoom(mode.code!),
        _ => service.find(Difficulty.beginner, RaceRule.coop),
      };
=======
    notifyListeners();
    _matchInfo(mode).then(_begin).catchError((Object e) {
      if (_disposed || e == MatchError.cancelled) return;
      failure = e is MatchError ? e : MatchError.roomNotFound;
      notifyListeners();
    });
  }

  // 보드가 고정(80×80)이라 difficulty는 placeholder. 협동이므로 rule=coop으로 같은 모드끼리만 매칭.
  Future<MatchInfo> _matchInfo(RaceMode mode) {
    switch (mode.kind) {
      case RaceModeKind.host:
        return service.createRoom(Difficulty.beginner, RaceRule.coop);
      case RaceModeKind.join:
        return service.joinRoom(mode.code!);
      case RaceModeKind.quick:
      case RaceModeKind.bot:
        return service.find(Difficulty.beginner, RaceRule.coop);
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
    // 같은 시드 → 양쪽 동일 보드. 시드에서 정한 두 시작점 중 호스트=A, 게스트=B.
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    game.startShared(seed: info.seed, asHost: info.isHost);
    _lastState = game.state;
    flow = CoopFlow.racing;
    service.beginRace();
<<<<<<< HEAD
    _notify();
  }

  void rematch() {
    if (_mode.kind == RaceModeKind.host || _mode.kind == RaceModeKind.join) {
      flow = CoopFlow.searching;
      rematching = true;
      result = null;
      roomCode = null;
      failure = null;
      opponent = OpponentStatus();
      opponentLeft = false;
      pings.clear();
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
      if (flow == CoopFlow.racing && result == null && game.state == GameState.won) {
        service.report(progress: 1, phase: RacerPhase.won, elapsed: game.elapsed, score: 0);
=======
    notifyListeners();
  }

  /// "다시하기". 코드로 만난 파트너(host/join)는 같은 파트너와 재대결, 랜덤은 새 파트너.
  void rematch() {
    if (_mode.kind == RaceModeKind.host || _mode.kind == RaceModeKind.join) {
      flow = CoopFlow.searching;
      rematching = true;
      result = null;
      roomCode = null;
      failure = null;
      opponent = OpponentStatus();
      opponentLeft = false;
      pings.clear();
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
    }
  }

  void leave() => service.leave();

  void _onChange() {
    if (_disposed) return;
    notifyListeners();
    _reportProgress();
    if (game.state != _lastState) {
      _lastState = game.state;
      if (flow == CoopFlow.racing &&
          result == null &&
          game.state == GameState.won) {
        service.report(
            progress: 1, phase: RacerPhase.won, elapsed: game.elapsed, score: 0);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
        _finish(RaceResult.win); // 만남 = 둘 다 성공
      }
    }
  }

  void _reportProgress() {
    if (flow != CoopFlow.racing || result != null) return;
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
    if (flow != CoopFlow.racing || result != null) return;
    if (s.phase == RacerPhase.won) _finish(RaceResult.win); // 파트너가 먼저 만남 감지
=======
        progress: game.progress,
        phase: RacerPhase.playing,
        elapsed: game.elapsed,
        score: 0);
  }

  void _handleOpponent(OpponentStatus status) {
    opponent = status;
    notifyListeners();
    if (flow != CoopFlow.racing || result != null) return;
    // 협동: 파트너가 먼저 만남을 감지(won)했으면 나도 함께 성공 처리.
    if (status.phase == RacerPhase.won) _finish(RaceResult.win);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  }

  void _handleOpponentLeft() {
    if (flow != CoopFlow.racing || result != null) return;
    opponentLeft = true;
<<<<<<< HEAD
    _finish(RaceResult.lose);
=======
    _finish(RaceResult.lose); // 파트너 이탈 → 함께 도달할 수 없어 종료
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  }

  /// 확성기 핑을 5초간 띄운다.
  void _showPing(int index, {bool mine = false}) {
<<<<<<< HEAD
    final p = TouchPing(_pingId++, index ~/ game.size, index % game.size, mine: mine);
    pings.add(p);
    mine ? Haptics.success() : Haptics.tap();
    _notify();
    Timer(const Duration(seconds: 5), () {
      pings.removeWhere((x) => x.id == p.id);
      _notify();
=======
    final p = TouchPing(_pingId++, index ~/ game.size, index % game.size,
        mine: mine);
    pings.add(p);
    mine ? Haptics.success() : Haptics.tap();
    notifyListeners();
    Timer(const Duration(seconds: 5), () {
      if (_disposed) return;
      pings.removeWhere((x) => x.id == p.id);
      notifyListeners();
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    });
  }

  void _finish(RaceResult r) {
    result = r;
    flow = CoopFlow.finished;
    switch (r) {
      case RaceResult.win:
<<<<<<< HEAD
        // 만남 = 공동 성공 → 걸린 시간을 협동 랭킹에(여기서 1회).
        LocalStore.maybe?.recordTouch(game.elapsed);
=======
        // 만남 = 공동 성공. "만나기까지 걸린 시간"을 협동 랭킹에 올린다(1회).
        final store = LocalStore.maybeShared;
        if (store != null && store.recordTouch(game.elapsed)) {
          RankingService().submitTouchBest(
              name: store.nickname,
              timeSec: game.elapsed,
              deviceId: store.deviceId,
              title: store.equippedTitleName);
        }
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
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
