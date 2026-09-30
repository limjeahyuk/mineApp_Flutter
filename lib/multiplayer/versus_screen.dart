import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/board_widget.dart';
import '../game/game_screen.dart' show ledRed, setAppOrientationFor;
import '../game/item_dock.dart';
import '../progression/daily.dart';
import 'bot_match_service.dart';
import 'firebase_match_service.dart';
import 'mp_ui.dart';
import 'multiplayer.dart';
import 'race_controller.dart';
import '../progression/title.dart';

/// 대전(레이스) 화면 — Swift MultiplayerView 이식. 검색 → 카운트다운 → 레이스 → 결과.
/// 스피드/지뢰 대결/합동(봇 포함), 자동깃발·레이더 도크, 자리비움 경고/항복.
class VersusScreen extends StatefulWidget {
  const VersusScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

class _VersusScreenState extends State<VersusScreen> with WidgetsBindingObserver {
  late final RaceController ctrl = RaceController(widget.mode.kind == RaceModeKind.bot
      ? BotMatchService(rule: widget.mode.rule)
      : FirebaseMatchService(kind: 'mine'));
  final TransformationController _zoom = TransformationController();
  bool flagMode = true; // 대전은 첫 칸이 열린 채 시작 → 깃발 모드 기본
  bool probing = false;
  bool _recorded = false;
  Difficulty? _orientedFor;

  bool get _isCoopLaunch => widget.mode.kind != RaceModeKind.join && widget.mode.rule == RaceRule.coop;
  bool get _isCoop => ctrl.match?.rule == RaceRule.coop;
  bool get _isScore => ctrl.match?.rule == RaceRule.score;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final inv = LocalStore.shared;
    final g = ctrl.game;
    g.autoFlagSupplier = () => inv.ownedFlags;
    g.onConsumeAutoFlag = inv.consumeFlag;
    g.radarSupplier = () => inv.ownedRadars;
    g.onConsumeRadar = inv.consumeRadar;
    g.onGoldenMineFound = () {
      inv.awardGoldenMine();
      Daily.bump(DailyKind.golden);
      announceAchievements();
      Haptics.success();
    };
    ctrl.addListener(_onCtrl);
    ctrl.start(widget.mode);
    if (widget.mode.difficulty != null) setAppOrientationFor(widget.mode.difficulty);
  }

  void _onCtrl() {
    if (ctrl.flow != RaceFlow.racing && probing) probing = false;
    final d = ctrl.match?.difficulty;
    if (d != null && d != _orientedFor) {
      _orientedFor = d;
      setAppOrientationFor(d);
    }
    if (ctrl.shouldExit) {
      if (!_recorded) {
        _recorded = true;
        LocalStore.shared.recordRaceLoss(); // 자리비움 항복 = 패배
      }
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (_recorded || ctrl.flow != RaceFlow.finished || ctrl.result == null) return;
    _recorded = true;
    final inv = LocalStore.shared;
    switch (ctrl.result!) {
      case RaceResult.win:
        inv.recordRaceWin();
        Daily.bump(DailyKind.raceWins);
      announceAchievements();
      case RaceResult.lose:
        inv.recordRaceLoss();
      case RaceResult.draw:
        inv.recordRaceDraw();
    }
    announceAchievements();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ctrl.setSceneActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    setAppOrientationFor(null);
    ctrl.removeListener(_onCtrl);
    ctrl.leave();
    ctrl.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _exit() {
    if (mounted) Navigator.of(context).pop();
  }

  void _rematch() {
    _recorded = false;
    ctrl.rematch();
  }

  void _handleProbe(int r, int c) {
    final used = ctrl.game.useAutoFlag(r, c);
    setState(() => probing = false);
    if (used) {
      Haptics.success();
    } else {
      Haptics.tap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final g = ctrl.game;
          final big = g.difficulty == Difficulty.expert || g.difficulty == Difficulty.ultimate;
          final mq = MediaQuery.of(context);
          return Stack(children: [
            SafeArea(child: _content(t)),
            if (ctrl.flow == RaceFlow.racing)
              Positioned(
                right: 0,
                bottom: big
                    ? mq.padding.bottom + (g.difficulty.prefersLandscape ? 40 : 96)
                    : mq.padding.bottom,
                child: ItemDock(
                  autoFlagTickets: g.autoFlagTickets,
                  radarTickets: g.radarTickets,
                  isPlaying: g.state == GameState.playing,
                  probing: probing,
                  usesEdgeDrawer: big,
                  onProbingChanged: (v) => setState(() => probing = v),
                  onRadar: () => g.useRadar(),
                ),
              ),
            if (ctrl.flow == RaceFlow.finished && ctrl.result != null) _result(t, ctrl.result!),
            if (ctrl.flow == RaceFlow.racing && ctrl.afkWarning)
              mpAfkBanner(ctrl.afkRemaining, ctrl.stayActive),
          ]);
        },
      ),
    );
  }

  Widget _content(AppTheme t) {
    switch (ctrl.flow) {
      case RaceFlow.searching:
        if (ctrl.failure != null) return mpFailure(t, ctrl.failure!.message, _exit);
        return _searching(t);
      case RaceFlow.starting:
        return mpStarting(t,
            title: _isCoop ? '파트너를 만났어요!' : '상대를 만났어요!',
            icon: _isCoop ? SF.person2Fill : SF.personFill,
            iconColor: _isCoop ? mpCoopColor : mpOppColor,
            name: ctrl.match?.opponentName ?? (_isCoop ? '파트너' : '상대'),
            titleBadge: ctrl.match?.opponentTitle ?? '',
            countdown: ctrl.startCountdown,
            countColor: _isCoop ? mpCoopColor : mpMeColor,
            caption: _isCoop ? '잠시 후 함께 시작합니다' : '잠시 후 시작합니다');
      case RaceFlow.racing:
      case RaceFlow.finished:
        return _race(t);
    }
  }

  String get _searchingTitle {
    if (ctrl.rematching) return _isCoop ? '파트너를 기다리는 중…' : '상대를 기다리는 중…';
    switch (widget.mode.kind) {
      case RaceModeKind.bot:
        return _isCoopLaunch ? '봇 파트너와 준비 중…' : '봇과 매칭 중…';
      case RaceModeKind.host:
        return _isCoopLaunch ? '파트너 입장을 기다리는 중…' : '상대 입장을 기다리는 중…';
      case RaceModeKind.join:
        return '방에 입장 중…';
      case RaceModeKind.quick:
        return _isCoopLaunch ? '함께할 파트너를 찾는 중…' : '상대를 찾는 중…';
    }
  }

  Widget _searching(AppTheme t) {
    Widget detail;
    if (ctrl.rematching) {
      detail = Text(_isCoop ? '같은 파트너와 다시 시작할게요' : '같은 상대와 다시 시작할게요',
          textAlign: TextAlign.center, style: sf(13, color: t.textSecondary));
    } else if (widget.mode.kind == RaceModeKind.host) {
      final code = ctrl.roomCode;
      detail = RoomCodeBlock(
        code: code,
        shareText: code == null
            ? ''
            : '지뢰찾기 대전에 들어와요! 방 코드: $code\n${inviteWebUrl('mine', code)}',
      );
    } else {
      detail = Text(_isCoopLaunch ? '같은 보드를 둘이서 함께 푸는 협동' : '같은 보드로 동시에 겨루는 레이스',
          style: sf(13, color: t.textSecondary));
    }
    return mpSearching(t, title: _searchingTitle, detail: detail, onCancel: _exit);
  }

  Widget _race(AppTheme t) {
    final g = ctrl.game;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(children: [
        Row(children: [
          mpCircleButton(t, SF.xmark, _exit),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: rr(6, Colors.black),
            child: Text(g.elapsed.clamp(0, 999).toString().padLeft(3, '0'),
                style: sf(22, weight: W.bold, color: ledRed, mono: true)),
          ),
          const Spacer(),
          mpFlagToggle(t, flagMode, () => setState(() => flagMode = !flagMode)),
        ]),
        const SizedBox(height: 8),
        if (_isCoop) ...[
          mpProgressRow(t, label: '함께', value: ctrl.myBarProgress, color: mpCoopColor),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(SF.person2Fill, size: 11, color: mpCoopColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text('${ctrl.match?.opponentName ?? '파트너'}와 함께 푸는 중',
                  overflow: TextOverflow.ellipsis,
                  style: sf(12, weight: W.medium, color: t.textSecondary)),
            ),
          ]),
        ] else ...[
          mpProgressRow(t,
              label: '나',
              title: LocalStore.shared.equippedTitleName,
              value: ctrl.myBarProgress,
              color: mpMeColor,
              score: _isScore ? ctrl.myScore : null),
          const SizedBox(height: 8),
          mpProgressRow(t,
              label: ctrl.match?.opponentName ?? '상대',
              title: ctrl.match?.opponentTitle ?? '',
              value: ctrl.opponentBarProgress,
              color: mpOppColor,
              score: _isScore ? ctrl.opponentScore : null),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: BoardWidget(
            game: g,
            flagMode: flagMode,
            controller: _zoom,
            probing: probing,
            onProbe: _handleProbe,
          ),
        ),
      ]),
    );
  }

  Widget _result(AppTheme t, RaceResult r) {
    String emoji, title, sub;
    if (_isCoop) {
      if (ctrl.opponentLeft) {
        emoji = '👋';
        title = '게임 종료';
        sub = '파트너가 나가서 게임이 끝났어요';
      } else {
        emoji = r == RaceResult.win ? '🎉' : '💥';
        title = r == RaceResult.win ? '함께 클리어!' : '함께 실패';
        sub = r == RaceResult.win ? '둘이서 보드를 모두 풀었어요!' : '지뢰를 밟아 함께 실패했어요';
      }
    } else {
      emoji = switch (r) { RaceResult.win => '🏆', RaceResult.lose => '💥', RaceResult.draw => '🤝' };
      title = switch (r) { RaceResult.win => '승리!', RaceResult.lose => '패배', RaceResult.draw => '무승부' };
      if (ctrl.opponentLeft) {
        sub = '상대가 나가서 승리했어요';
      } else if (_isScore) {
        final me = ctrl.myScore, opp = ctrl.opponentScore;
        sub = switch (r) {
          RaceResult.win => '지뢰를 더 많이 찾았어요 ($me : $opp)',
          RaceResult.lose => '상대가 더 많이 찾았어요 ($me : $opp)',
          RaceResult.draw => '같은 수를 찾았어요 ($me : $opp)',
        };
      } else {
        sub = r == RaceResult.win ? '상대보다 먼저 클리어했어요' : '상대가 먼저 끝냈어요';
      }
    }
    return mpResultOverlay(t,
        emoji: emoji,
        title: title,
        subtitle: sub,
        primary: _isCoop ? '다시 하기' : '다시 매칭',
        onPrimary: _rematch,
        onExit: _exit);
  }
}
