import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/types.dart';
import '../multiplayer/multiplayer.dart';
import '../ranking/ranking_service.dart';
import 'touch_model.dart';

enum CoopFlow { searching, racing, finished }

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
    game.addListener(_onChange);
    service.onRoomCode = (c) {
      roomCode = c;
      notifyListeners();
    };
    service.onOpponent = _handleOpponent;
    service.onOpponentLeft = _handleOpponentLeft;
    // 공유 보드(협동): 내 동작을 파트너에게 보내고, 파트너 동작을 내 보드에 반영한다.
    game.onPushReveal = (safe, exp) => service.pushReveal(safe, exp);
    game.onPushFlag = (i, set) => service.pushFlag(i, set: set);
    game.onMineHitPenalty = service.pushFlagPenalty;
    game.onMegaphone = (idx) {
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
      game.onGoldenMineFound = () {
        store.awardGoldenMine();
        Haptics.success();
      };
    }
  }

  final TouchModel game;
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
  int _pingId = 0;
  bool _disposed = false;

  void start(RaceMode mode) {
    _mode = mode;
    flow = CoopFlow.searching;
    result = null;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    opponentLeft = false;
    pings.clear();
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

  void _begin(MatchInfo info) {
    if (_disposed) return;
    opponentName = info.opponentName;
    opponentTitle = info.opponentTitle;
    rematching = false;
    // 같은 시드 → 양쪽 동일 보드. 시드에서 정한 두 시작점 중 호스트=A, 게스트=B.
    game.startShared(seed: info.seed, asHost: info.isHost);
    _lastState = game.state;
    flow = CoopFlow.racing;
    service.beginRace();
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
  }

  void _handleOpponentLeft() {
    if (flow != CoopFlow.racing || result != null) return;
    opponentLeft = true;
    _finish(RaceResult.lose); // 파트너 이탈 → 함께 도달할 수 없어 종료
  }

  /// 확성기 핑을 5초간 띄운다.
  void _showPing(int index, {bool mine = false}) {
    final p = TouchPing(_pingId++, index ~/ game.size, index % game.size,
        mine: mine);
    pings.add(p);
    mine ? Haptics.success() : Haptics.tap();
    notifyListeners();
    Timer(const Duration(seconds: 5), () {
      if (_disposed) return;
      pings.removeWhere((x) => x.id == p.id);
      notifyListeners();
    });
  }

  void _finish(RaceResult r) {
    result = r;
    flow = CoopFlow.finished;
    switch (r) {
      case RaceResult.win:
        // 만남 = 공동 성공. "만나기까지 걸린 시간"을 협동 랭킹에 올린다(1회).
        final store = LocalStore.maybeShared;
        if (store != null && store.recordTouch(game.elapsed)) {
          RankingService().submitTouchBest(
              name: store.nickname,
              timeSec: game.elapsed,
              deviceId: store.deviceId,
              title: store.equippedTitleName);
        }
        Haptics.success();
      case RaceResult.lose:
        Haptics.error();
      case RaceResult.draw:
        Haptics.warning();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    game.removeListener(_onChange);
    game.dispose();
    super.dispose();
  }
}
