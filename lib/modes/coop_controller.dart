import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/types.dart';
import '../multiplayer/multiplayer.dart';
import 'touch_board.dart';
import 'touch_model.dart';

enum CoopFlow { searching, racing, finished }

/// "너에게 닿기를" 진행 — Swift TouchRaceViewModel 이식.
/// 매칭 → 함께 길 뚫기 → 두 사람 칸이 맞닿으면 둘 다 성공(걸린 시간 = 협동 기록).
/// 확성기 핑·지뢰 페널티(파트너 깃발 1개 떨어뜨리기)도 여기서 중계한다.
class CoopController extends ChangeNotifier {
  CoopController(this.service) {
    game.addListener(_onChange);
    service.onRoomCode = (c) {
      roomCode = c;
      _notify();
    };
    service.onOpponent = _handleOpponent;
    service.onOpponentLeft = _handleOpponentLeft;
    game.onPushReveal = (safe, exp) => service.pushReveal(safe, exp);
    game.onPushFlag = (i, set) => service.pushFlag(i, set: set);
    game.onMineHitPenalty = service.pushFlagPenalty;
    game.onMegaphone = (idx) {
      service.pushPing(idx); // 파트너 화면에 방향 화살표
      _showPing(idx, mine: true); // 울린 나에게도 확인 표시
    };
    final store = LocalStore.maybe;
    if (store != null) {
      game.autoFlagSupplier = () => store.ownedFlags;
      game.onConsumeAutoFlag = store.consumeFlag;
      game.megaphoneSupplier = () => store.ownedMegaphones;
      game.onConsumeMegaphone = store.consumeMegaphone;
      game.onGoldenMineFound = () {
        store.awardGoldenMine();
        Haptics.success();
      };
    }
    service.onRemoteBoard = game.applyRemote;
    service.onFlagPenalty = game.dropRandomFlag;
    service.onPing = (idx) => _showPing(idx);
  }

  final TouchModel game = TouchModel(size: 80);
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
  bool _disposed = false;
  int _pingId = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void start(RaceMode mode) {
    _mode = mode;
    flow = CoopFlow.searching;
    result = null;
    roomCode = null;
    failure = null;
    opponent = OpponentStatus();
    opponentLeft = false;
    pings.clear();
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

  void _begin(MatchInfo info) {
    if (_disposed) return;
    opponentName = info.opponentName;
    opponentTitle = info.opponentTitle;
    rematching = false;
    game.startShared(seed: info.seed, asHost: info.isHost);
    _lastState = game.state;
    flow = CoopFlow.racing;
    service.beginRace();
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
        _finish(RaceResult.win); // 만남 = 둘 다 성공
      }
    }
  }

  void _report() {
    if (flow != CoopFlow.racing || result != null) return;
    final now = DateTime.now();
    if (now.difference(_lastReport) < const Duration(milliseconds: 500)) return;
    _lastReport = now;
    service.report(
        progress: game.progress, phase: RacerPhase.playing, elapsed: game.elapsed, score: 0);
  }

  void _handleOpponent(OpponentStatus s) {
    opponent = s;
    _notify();
    if (flow != CoopFlow.racing || result != null) return;
    if (s.phase == RacerPhase.won) _finish(RaceResult.win); // 파트너가 먼저 만남 감지
  }

  void _handleOpponentLeft() {
    if (flow != CoopFlow.racing || result != null) return;
    opponentLeft = true;
    _finish(RaceResult.lose);
  }

  /// 확성기 핑을 5초간 띄운다.
  void _showPing(int index, {bool mine = false}) {
    final p = TouchPing(_pingId++, index ~/ game.size, index % game.size, mine: mine);
    pings.add(p);
    mine ? Haptics.success() : Haptics.tap();
    _notify();
    Timer(const Duration(seconds: 5), () {
      pings.removeWhere((x) => x.id == p.id);
      _notify();
    });
  }

  void _finish(RaceResult r) {
    result = r;
    flow = CoopFlow.finished;
    switch (r) {
      case RaceResult.win:
        // 만남 = 공동 성공 → 걸린 시간을 협동 랭킹에(여기서 1회).
        LocalStore.maybe?.recordTouch(game.elapsed);
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
