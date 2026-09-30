import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/types.dart';
import '../multiplayer/multiplayer.dart';
import '../progression/daily.dart';
import '../ranking/ranking_service.dart';
import 'touch_model.dart';
import '../progression/title.dart';

enum CoopFlow { searching, racing, finished }

/// 확성기 핑 — mine=true면 내가 울림(확인 배너), false면 파트너가 울림(방향 화살표).
class TouchPing {
  TouchPing(this.id, this.r, this.c, {this.mine = false});
  final int id;
  final int r;
  final int c;
  final bool mine;
}

/// '너에게 닿기를' 협동 진행 — Swift TouchRaceViewModel 이식.
/// 매칭 → 80×80 안개 공유 보드 → 만나면 둘 다 성공(걸린 시간 = 협동 기록).
/// 확성기 핑, 지뢰를 밟으면 파트너 깃발 1개가 떨어지는 페널티도 여기서 중계한다.
class CoopController extends ChangeNotifier {
  CoopController(this.service, {int size = 80}) : model = TouchModel(size: size) {
    model.addListener(_onChange);
    service.onRoomCode = (c) {
      roomCode = c;
      notifyListeners();
    };
    service.onOpponent = _handleOpponent;
    service.onOpponentLeft = _onOpponentLeft;
    service.onRemoteBoard = (b) => model.applyRemote(b);
    service.onFlagPenalty = model.dropRandomFlag;
    service.onPing = (idx) => _showPing(idx);
    model.onPushReveal = (safe, exp) => service.pushReveal(safe, exp);
    model.onPushFlag = (i, set) => service.pushFlag(i, set: set);
    model.onMineHitPenalty = service.pushFlagPenalty;
    model.onMegaphone = (idx) {
      service.pushPing(idx);
      _showPing(idx, mine: true);
    };
    final inv = LocalStore.shared;
    model.autoFlagSupplier = () => inv.ownedFlags;
    model.onConsumeAutoFlag = inv.consumeFlag;
    model.megaphoneSupplier = () => inv.ownedMegaphones;
    model.onConsumeMegaphone = inv.consumeMegaphone;
    model.onGoldenMineFound = () {
      inv.awardGoldenMine();
      Daily.bump(DailyKind.golden);
      announceAchievements();
      Haptics.success();
    };
  }

  final TouchModel model;
  final MatchService service;

  CoopFlow flow = CoopFlow.searching;
  OpponentStatus opponent = OpponentStatus();
  RaceResult? result;
  bool opponentLeft = false;
  bool rematching = false;
  MatchInfo? match;
  String? roomCode;
  MatchError? failure;
  String opponentName = '상대';
  String opponentTitle = '';
  final List<TouchPing> pings = [];
  int _pingId = 0;

  RaceMode _mode = RaceMode.quick(Difficulty.beginner, RaceRule.coop);
  GameState _lastState = GameState.ready;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  double get progress => model.progress;

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
    _find(mode).then(_begin).catchError((Object e) {
      if (e != MatchError.cancelled) {
        failure = e is MatchError ? e : MatchError.roomNotFound;
        notifyListeners();
      }
    });
  }

  // 보드 고정(80) — difficulty는 placeholder, rule=coop으로 같은 모드끼리만 매칭.
  Future<MatchInfo> _find(RaceMode mode) {
    switch (mode.kind) {
      case RaceModeKind.quick:
      case RaceModeKind.bot:
        return service.find(Difficulty.beginner, RaceRule.coop);
      case RaceModeKind.host:
        return service.createRoom(Difficulty.beginner, RaceRule.coop);
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
    flow = CoopFlow.racing;
    service.beginRace();
    notifyListeners();
  }

  /// "다시 하기" — 코드로 만난 파트너는 같은 파트너와, 랜덤은 새 파트너.
  void rematch() {
    if (_mode.kind == RaceModeKind.quick) {
      service.leave();
      start(_mode);
      return;
    }
    flow = CoopFlow.searching;
    rematching = true;
    result = null;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    opponentLeft = false;
    pings.clear();
    notifyListeners();
    service.rematch().then((info) {
      rematching = false;
      _begin(info);
    }).catchError((Object e) {
      rematching = false;
      if (e != MatchError.cancelled) failure = e is MatchError ? e : MatchError.opponentLeft;
      notifyListeners();
    });
  }

  void _onChange() {
    notifyListeners();
    _report();
    if (model.state == _lastState) return;
    _lastState = model.state;
    if (flow != CoopFlow.racing || result != null) return;
    if (model.state == GameState.won) {
      service.report(progress: 1, phase: RacerPhase.won, elapsed: model.elapsed, score: 0);
      _finish(RaceResult.win);
    }
  }

  void _report() {
    if (flow != CoopFlow.racing || result != null) return;
    final now = DateTime.now();
    if (now.difference(_lastReport) < const Duration(milliseconds: 500)) return;
    _lastReport = now;
    service.report(
        progress: model.progress, phase: RacerPhase.playing, elapsed: model.elapsed, score: 0);
  }

  void _handleOpponent(OpponentStatus s) {
    opponent = s;
    notifyListeners();
    if (flow != CoopFlow.racing || result != null) return;
    if (s.phase == RacerPhase.won) _finish(RaceResult.win); // 파트너가 먼저 만남 감지 → 함께 성공
  }

  void _onOpponentLeft() {
    if (flow != CoopFlow.racing || result != null) return;
    opponentLeft = true;
    _finish(RaceResult.lose);
  }

  void _showPing(int index, {bool mine = false}) {
    final p = TouchPing(_pingId++, index ~/ model.size, index % model.size, mine: mine);
    pings.add(p);
    if (mine) {
      Haptics.success();
    } else {
      Haptics.tap();
    }
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
        // 만남 = 공동 성공 → 걸린 시간을 협동 랭킹에(1회).
        final inv = LocalStore.shared;
        Daily.bump(DailyKind.touch);
      announceAchievements();
        if (inv.recordTouch(model.elapsed)) {
          RankingService().submitTouchBest(
              name: inv.nickname,
              timeSec: model.elapsed,
              deviceId: inv.deviceId,
              title: inv.equippedTitleName);
        }
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
    _disposed = true;
    model.removeListener(_onChange);
    model.dispose();
    super.dispose();
  }
}
