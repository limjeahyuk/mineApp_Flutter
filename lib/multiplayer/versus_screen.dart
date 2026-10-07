import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Title;

<<<<<<< HEAD
import '../app/deep_link.dart';
=======
import '../core/board.dart';
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/board_widget.dart';
import '../game/item_dock.dart';
<<<<<<< HEAD
import '../progression/title.dart';
=======
import '../progression/title.dart' show TitleBadge;
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
import 'bot_match_service.dart';
import 'firebase_match_service.dart';
import 'match_widgets.dart';
import 'multiplayer.dart';
import 'race_controller.dart';

<<<<<<< HEAD
/// 대전(레이스) 화면 — Swift MultiplayerView 이식. 상대 검색 → 카운트다운 → 레이스 → 결과.
=======
/// 멀티플레이(레이스) 전체 화면 — Swift MultiplayerView 이식: 상대 검색 → 카운트다운 → 레이스 → 결과.
/// 스피드·지뢰 대결·합동(공유 보드 협동) 공용. 자리비움 경고/항복, 아이템 도크 포함.
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
class VersusScreen extends StatefulWidget {
  const VersusScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

<<<<<<< HEAD
class _VersusScreenState extends State<VersusScreen> {
=======
class _VersusScreenState extends State<VersusScreen>
    with WidgetsBindingObserver {
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  late final RaceController vm = RaceController(
      widget.mode.kind == RaceModeKind.bot
          ? BotMatchService(rule: widget.mode.rule)
          : FirebaseMatchService(kind: 'mine'));
<<<<<<< HEAD
  late final AppLifecycleListener _life;
  bool flagMode = true; // 대전은 첫 칸이 열린 채 시작하므로 깃발 모드 기본
  bool boardZoomed = false;
  bool probing = false;
  RaceFlow _lastFlow = RaceFlow.searching;
  Difficulty? _matchDiff;

  static const meColor = AppTheme.raceMe;
  static const oppColor = AppTheme.raceOpp;
  static const coopColor = AppTheme.coop;

  bool get isCoopLaunch => widget.mode.kind != RaceModeKind.join && widget.mode.rule == RaceRule.coop;
  bool get isCoop => vm.match?.rule == RaceRule.coop;
  bool get isScoreMode => vm.match?.rule == RaceRule.score;
=======
  // 대전은 시작 시 첫 칸이 이미 열려 있으므로 깃발 모드를 기본값으로 둔다.
  bool flagMode = true;
  bool boardZoomed = false;
  bool probing = false;
  RaceFlow _lastFlow = RaceFlow.searching;
  Difficulty? _lastDiff;
  bool _closed = false;
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    vm.addListener(_onChange);
    _life = AppLifecycleListener(
        onStateChange: (s) => vm.setSceneActive(s == AppLifecycleState.resumed));
    vm.start(widget.mode);
  }

  void _onChange() {
    if (vm.flow != _lastFlow) {
      _lastFlow = vm.flow;
      if (vm.flow != RaceFlow.racing) probing = false;
    }
    // 코드로 참가는 매칭 전 난이도를 모르므로, 매칭되면 방향을 맞춘다.
    final d = vm.match?.difficulty;
    if (d != null && d != _matchDiff) {
      _matchDiff = d;
      setBigBoardOrientation(d.prefersLandscape);
    }
    if (vm.shouldExit) {
      vm.shouldExit = false;
      _close();
    }
    if (mounted) setState(() {});
=======
    WidgetsBinding.instance.addObserver(this);
    vm.addListener(_onVm);
    final d = widget.mode.difficulty;
    setAppOrientation(allowLandscape: d?.prefersLandscape ?? false);
    vm.start(widget.mode);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  }

  @override
  void dispose() {
<<<<<<< HEAD
    _life.dispose();
    vm.removeListener(_onChange);
    vm.leave();
    vm.dispose();
    setBigBoardOrientation(false);
    super.dispose();
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
=======
    WidgetsBinding.instance.removeObserver(this);
    vm.removeListener(_onVm);
    vm.leave();
    vm.dispose();
    setAppOrientation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드(전화·알림)에 있던 시간은 자리비움으로 세지 않는다.
    vm.setSceneActive(state == AppLifecycleState.resumed);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  }

  void _onVm() {
    if (vm.flow != _lastFlow) {
      _lastFlow = vm.flow;
      if (vm.flow != RaceFlow.racing) probing = false;
    }
    final d = vm.match?.difficulty;
    if (d != null && d != _lastDiff) {
      _lastDiff = d;
      setAppOrientation(allowLandscape: d.prefersLandscape);
    }
    if (vm.shouldExit) _close();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  RaceRule? get _modeRule =>
      widget.mode.kind == RaceModeKind.join ? null : widget.mode.rule;
  bool get _isCoopLaunch => _modeRule == RaceRule.coop;
  bool get _isCoop => vm.match?.rule == RaceRule.coop;
  bool get _isScoreMode => vm.match?.rule == RaceRule.score;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
<<<<<<< HEAD
    final g = vm.game;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        SafeArea(
          child: switch (vm.flow) {
            RaceFlow.searching => vm.failure != null
                ? MatchFailedView(error: vm.failure!, onClose: _close)
                : _searching(),
            RaceFlow.starting => _starting(t),
            _ => _race(t),
          },
        ),
        if (vm.flow == RaceFlow.racing)
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: ItemDock(
                  tickets: g.autoFlagTickets,
                  isPlaying: g.state == GameState.playing,
                  usesEdgeDrawer: g.difficulty == Difficulty.expert ||
                      g.difficulty == Difficulty.ultimate,
                  probing: probing,
                  onProbingChanged: (v) => setState(() => probing = v),
                  drawerBottomPadding: g.difficulty.prefersLandscape ? 40 : 96,
                  radarTickets: g.radarTickets,
                  onRadar: () => g.useRadar(),
                ),
              ),
            ),
          ),
        if (vm.flow == RaceFlow.finished && vm.result != null) _resultOverlay(vm.result!),
        if (vm.flow == RaceFlow.racing && vm.afkWarning) _afkBanner(),
      ]),
    );
  }

  // MARK: 검색

  String get _searchingTitle {
    if (vm.rematching) return isCoop ? '파트너를 기다리는 중…' : '상대를 기다리는 중…';
    return switch (widget.mode.kind) {
      RaceModeKind.bot => isCoopLaunch ? '봇 파트너와 준비 중…' : '봇과 매칭 중…',
      RaceModeKind.host => isCoopLaunch ? '파트너 입장을 기다리는 중…' : '상대 입장을 기다리는 중…',
      RaceModeKind.join => '방에 입장 중…',
      RaceModeKind.quick => isCoopLaunch ? '함께할 파트너를 찾는 중…' : '상대를 찾는 중…',
    };
  }

  Widget _searching() => SearchingView(
        title: _searchingTitle,
        onCancel: _close,
        rematchText: vm.rematching
            ? (isCoop ? '같은 파트너와 다시 시작할게요' : '같은 상대와 다시 시작할게요')
            : null,
        isHost: widget.mode.kind == RaceModeKind.host,
        roomCode: vm.roomCode,
        description: isCoopLaunch ? '같은 보드를 둘이서 함께 푸는 협동' : '같은 보드로 동시에 겨루는 레이스',
        shareText: (c) =>
            '지뢰찾기 대전에 들어와요! 방 코드: $c\n${InviteLink.webURL(InviteGame.mine, c)}',
      );

  // MARK: 시작 카운트다운

  Widget _starting(AppTheme t) {
    return Column(children: [
      const Spacer(),
      Text(isCoop ? '파트너를 만났어요!' : '상대를 만났어요!',
          style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 22),
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
        child: Icon(isCoop ? CupertinoIcons.person_2_fill : CupertinoIcons.person_fill,
            size: 30, color: isCoop ? coopColor : oppColor),
      ),
      const SizedBox(height: 8),
      Text(vm.match?.opponentName ?? (isCoop ? '파트너' : '상대'),
          style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TitleBadge(name: vm.match?.opponentTitle ?? '', size: 9),
      const SizedBox(height: 22),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (c, a) =>
            ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
        child: Text('${vm.startCountdown}',
            key: ValueKey(vm.startCountdown),
            style: TextStyle(
                color: isCoop ? coopColor : meColor,
                fontSize: 64,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ),
      const SizedBox(height: 22),
      Text(isCoop ? '잠시 후 함께 시작합니다' : '잠시 후 시작합니다',
          style: TextStyle(color: t.textSecondary, fontSize: 14)),
      const Spacer(),
    ]);
  }

  // MARK: 레이스

  Widget _race(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(children: [
        _raceTopBar(t),
        const SizedBox(height: 10),
        Expanded(
          child: BoardWidget(
            game: vm.game,
            flagMode: flagMode,
            zoomed: boardZoomed,
            onZoomChanged: (z) => setState(() => boardZoomed = z),
            probing: probing,
            onProbe: (r, c) {
              final used = vm.game.useAutoFlag(r, c);
              setState(() => probing = false);
              used ? Haptics.success() : Haptics.tap();
            },
          ),
=======
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            final g = vm.game;
            return Stack(
              fit: StackFit.expand,
              children: [
                SafeArea(
                  child: switch (vm.flow) {
                    RaceFlow.searching => _searchingView(t),
                    RaceFlow.starting => _startingView(),
                    _ => _raceView(t),
                  },
                ),
                if (vm.flow == RaceFlow.racing)
                  SafeArea(
                    child: Stack(children: [
                      ItemDock(
                        tickets: g.autoFlagTickets,
                        isPlaying: g.state == GameState.playing,
                        usesEdgeDrawer: g.difficulty == Difficulty.expert ||
                            g.difficulty == Difficulty.ultimate,
                        probing: probing,
                        onProbingChanged: (v) => setState(() => probing = v),
                        drawerBottomPadding:
                            g.difficulty.prefersLandscape ? 40 : 96,
                        radarTickets: g.radarTickets,
                        onRadar: g.useRadar,
                      ),
                    ]),
                  ),
                if (vm.flow == RaceFlow.finished && vm.result != null)
                  _resultOverlay(vm.result!),
                if (vm.flow == RaceFlow.racing && vm.afkWarning)
                  SafeArea(
                    child: AfkWarningBanner(
                        remaining: vm.afkRemaining, onStay: vm.stayActive),
                  ),
              ],
            );
          },
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
        ),
      ]),
    );
  }

<<<<<<< HEAD
  Widget _raceTopBar(AppTheme t) {
    return Column(children: [
      Row(children: [
        CircleIconButton(icon: CupertinoIcons.xmark, onTap: _close),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.black, borderRadius: BorderRadius.circular(6)),
          child: Text(vm.game.elapsed.toString().padLeft(3, '0'),
              style: const TextStyle(
                  color: AppTheme.ledRed,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier')),
        ),
        const Spacer(),
        FlagToggle(on: flagMode, onChanged: (v) => setState(() => flagMode = v)),
      ]),
      const SizedBox(height: 8),
      if (isCoop) ...[
        ProgressRow(label: '함께', value: vm.myBarProgress, color: coopColor),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(CupertinoIcons.person_2_fill, size: 12, color: coopColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text('${vm.match?.opponentName ?? '파트너'}와 함께 푸는 중',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 6),
          TitleBadge(name: vm.match?.opponentTitle ?? '', size: 8),
        ]),
      ] else ...[
        ProgressRow(
            label: '나',
            title: LocalStore.shared.equippedTitleName,
            value: vm.myBarProgress,
            color: meColor,
            score: isScoreMode ? vm.myScore : null),
        const SizedBox(height: 8),
        ProgressRow(
            label: vm.match?.opponentName ?? '상대',
            title: vm.match?.opponentTitle ?? '',
            value: vm.opponentBarProgress,
            color: oppColor,
            score: isScoreMode ? vm.opponentScore : null),
=======
  // MARK: 상대 검색 중

  Widget _searchingView(AppTheme t) {
    final failure = vm.failure;
    if (failure != null) return MatchFailedView(error: failure, onClose: _close);
    final Widget detail;
    if (vm.rematching) {
      detail = MatchDetailText(
          _isCoop ? '같은 파트너와 다시 시작할게요' : '같은 상대와 다시 시작할게요');
    } else if (widget.mode.kind == RaceModeKind.host) {
      detail = RoomCodeBlock(
        code: vm.roomCode,
        shareText: (code) =>
            '지뢰찾기 대전에 들어와요! 방 코드: $code\n${InviteLink.webURL('mine', code)}',
      );
    } else {
      detail = MatchDetailText(
          _isCoopLaunch ? '같은 보드를 둘이서 함께 푸는 협동' : '같은 보드로 동시에 겨루는 레이스');
    }
    return MatchSearchingView(
        title: _searchingTitle, detail: detail, onCancel: _close);
  }

  String get _searchingTitle {
    if (vm.rematching) return _isCoop ? '파트너를 기다리는 중…' : '상대를 기다리는 중…';
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

  // MARK: 시작 카운트다운

  Widget _startingView() => MatchStartingView(
        headline: _isCoop ? '파트너를 만났어요!' : '상대를 만났어요!',
        opponentName: vm.match?.opponentName ?? (_isCoop ? '파트너' : '상대'),
        opponentTitle: vm.match?.opponentTitle ?? '',
        countdown: vm.startCountdown,
        footer: _isCoop ? '잠시 후 함께 시작합니다' : '잠시 후 시작합니다',
        icon: _isCoop ? Icons.people : Icons.person,
        iconColor: _isCoop ? kRaceCoop : kRaceOpp,
        numberColor: _isCoop ? kRaceCoop : kRaceMe,
      );

  // MARK: 레이스

  Widget _raceView(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        children: [
          _raceTopBar(t),
          const SizedBox(height: 10),
          Expanded(
            child: BoardWidget(
              game: vm.game,
              flagMode: flagMode,
              zoomedIn: boardZoomed,
              onZoomChanged: (z) => setState(() => boardZoomed = z),
              probing: probing,
              onProbe: _handleProbe,
            ),
          ),
        ],
      ),
    );
  }

  void _handleProbe(int r, int c) {
    final used = vm.game.useAutoFlag(r, c);
    setState(() => probing = false);
    if (used) {
      Haptics.success();
    } else {
      Haptics.tap();
    }
  }

  Widget _raceTopBar(AppTheme t) {
    final e = vm.game.elapsed.clamp(0, 999);
    return Column(
      children: [
        Row(
          children: [
            CircleIconButton(icon: Icons.close, onTap: _close),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black, borderRadius: BorderRadius.circular(6)),
              child: Text(e.toString().padLeft(3, '0'),
                  style: const TextStyle(
                      color: AppTheme.ledRed,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Menlo',
                      fontFamilyFallback: ['Courier', 'monospace'],
                      fontFeatures: [FontFeature.tabularFigures()])),
            ),
            const Spacer(),
            CircleFlagToggle(
                on: flagMode, onTap: () => setState(() => flagMode = !flagMode)),
          ],
        ),
        const SizedBox(height: 8),
        if (_isCoop) ...[
          // 합동: 한 보드를 공유하므로 진행바는 하나(공동 진행도) + 파트너 표시.
          RaceProgressRow(
              label: '함께', value: vm.myBarProgress, color: kRaceCoop),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.people, size: 13, color: kRaceCoop),
            const SizedBox(width: 6),
            Flexible(
              child: Text('${vm.match?.opponentName ?? '파트너'}와 함께 푸는 중',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 6),
            TitleBadge(name: vm.match?.opponentTitle ?? '', size: 8),
          ]),
        ] else ...[
          RaceProgressRow(
            label: '나',
            title: LocalStore.shared.equippedTitleName,
            value: vm.myBarProgress,
            color: kRaceMe,
            score: _isScoreMode ? vm.myScore : null,
          ),
          const SizedBox(height: 8),
          RaceProgressRow(
            label: vm.match?.opponentName ?? '상대',
            title: vm.match?.opponentTitle ?? '',
            value: vm.opponentBarProgress,
            color: kRaceOpp,
            score: _isScoreMode ? vm.opponentScore : null,
          ),
        ],
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      ],
    ]);
  }

  // MARK: 결과

<<<<<<< HEAD
  String _subtitle(RaceResult r) {
    if (isCoop) {
=======
  String _resultSubtitle(RaceResult r) {
    if (_isCoop) {
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      if (vm.opponentLeft) return '파트너가 나가서 게임이 끝났어요';
      return r == RaceResult.win ? '둘이서 보드를 모두 풀었어요!' : '지뢰를 밟아 함께 실패했어요';
    }
    if (vm.opponentLeft) return '상대가 나가서 승리했어요';
<<<<<<< HEAD
    if (isScoreMode) {
=======
    if (_isScoreMode) {
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      final me = vm.myScore, opp = vm.opponentScore;
      return switch (r) {
        RaceResult.win => '지뢰를 더 많이 찾았어요 ($me : $opp)',
        RaceResult.lose => '상대가 더 많이 찾았어요 ($me : $opp)',
        RaceResult.draw => '같은 수를 찾았어요 ($me : $opp)',
      };
    }
    return r == RaceResult.win ? '상대보다 먼저 클리어했어요' : '상대가 먼저 끝냈어요';
  }

<<<<<<< HEAD
  String _emoji(RaceResult r) {
    if (isCoop) {
=======
  String _resultEmoji(RaceResult r) {
    if (_isCoop) {
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      if (vm.opponentLeft) return '👋';
      return r == RaceResult.win ? '🎉' : '💥';
    }
    return switch (r) {
      RaceResult.win => '🏆',
      RaceResult.lose => '💥',
      RaceResult.draw => '🤝',
    };
  }

<<<<<<< HEAD
  String _title(RaceResult r) {
    if (isCoop) {
=======
  String _resultTitle(RaceResult r) {
    if (_isCoop) {
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      if (vm.opponentLeft) return '게임 종료';
      return r == RaceResult.win ? '함께 클리어!' : '함께 실패';
    }
    return switch (r) {
      RaceResult.win => '승리!',
      RaceResult.lose => '패배',
      RaceResult.draw => '무승부',
    };
  }

  Widget _resultOverlay(RaceResult r) => ResultOverlay(
<<<<<<< HEAD
        emoji: _emoji(r),
        title: _title(r),
        subtitle: _subtitle(r),
        children: [
          BigButton(
              label: isCoop ? '다시 하기' : '다시 매칭',
              color: meColor,
              onTap: () {
                setState(() => flagMode = true);
                vm.rematch();
              }),
          TextLink('나가기', onTap: _close),
        ],
      );

  // MARK: 자리비움 경고

  String _afkText(int s) {
    if (s >= 60) {
      final m = s ~/ 60, r = s % 60;
      return r > 0 ? '$m분 $r초' : '$m분';
    }
    return '$s초';
  }

  Widget _afkBanner() => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8 + MediaQuery.paddingOf(context).top, 16, 0),
          child: Pressable(
            onTap: () {
              Haptics.tap();
              vm.stayActive();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(140, 64, 26, 1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.yellow.withValues(alpha: 0.6)),
              ),
              child: Row(children: [
                const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                    size: 18, color: Colors.yellow),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('자리를 비우셨나요?',
                        style: TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('${_afkText(vm.afkRemaining)} 후 항복 · 탭하면 계속하기',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
=======
        emoji: _resultEmoji(r),
        title: _resultTitle(r),
        subtitle: _resultSubtitle(r),
        children: [
          FilledWideButton(
            label: _isCoop ? '다시 하기' : '다시 매칭',
            onTap: () {
              setState(() {
                flagMode = true;
                boardZoomed = false;
              });
              vm.rematch();
            },
          ),
          TextLinkButton(label: '나가기', onTap: _close),
        ],
      );
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
}
