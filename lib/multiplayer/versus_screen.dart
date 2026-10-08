import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/board_widget.dart';
import '../game/item_dock.dart';
import '../progression/title.dart' show TitleBadge;
import 'bot_match_service.dart';
import 'firebase_match_service.dart';
import 'match_widgets.dart';
import 'multiplayer.dart';
import 'race_controller.dart';

/// 멀티플레이(레이스) 전체 화면 — Swift MultiplayerView 이식: 상대 검색 → 카운트다운 → 레이스 → 결과.
/// 스피드·지뢰 대결·합동(공유 보드 협동) 공용. 자리비움 경고/항복, 아이템 도크 포함.
class VersusScreen extends StatefulWidget {
  const VersusScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

class _VersusScreenState extends State<VersusScreen>
    with WidgetsBindingObserver {
  late final RaceController vm = RaceController(
      widget.mode.kind == RaceModeKind.bot
          ? BotMatchService(rule: widget.mode.rule)
          : FirebaseMatchService(kind: 'mine'));
  // 대전은 시작 시 첫 칸이 이미 열려 있으므로 깃발 모드를 기본값으로 둔다.
  bool flagMode = true;
  bool probing = false;
  RaceFlow _lastFlow = RaceFlow.searching;
  Difficulty? _lastDiff;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vm.addListener(_onVm);
    final d = widget.mode.difficulty;
    setAppOrientation(allowLandscape: d?.prefersLandscape ?? false);
    vm.start(widget.mode);
  }

  @override
  void dispose() {
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
        ),
      ),
    );
  }

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
              child: Text(vm.game.difficulty.formatTimer(vm.game.elapsed),
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
          // 스피드: 상대가 지뢰를 밟아도 판은 안 끝난다 — 끝까지 풀면 이긴다는 걸 알려 준다.
          if (!_isScoreMode && vm.opponent.phase == RacerPhase.lost) ...[
            const SizedBox(height: 6),
            Text('💥 상대가 지뢰를 밟았어요 · 끝까지 풀면 승리!',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ],
    );
  }

  // MARK: 결과

  String _resultSubtitle(RaceResult r) {
    if (_isCoop) {
      if (vm.opponentLeft) return '파트너가 나가서 게임이 끝났어요';
      return r == RaceResult.win ? '둘이서 보드를 모두 풀었어요!' : '지뢰를 밟아 함께 실패했어요';
    }
    if (vm.opponentLeft) return '상대가 나가서 승리했어요';
    if (_isScoreMode) {
      final me = vm.myScore, opp = vm.opponentScore;
      return switch (r) {
        RaceResult.win => '지뢰를 더 많이 찾았어요 ($me : $opp)',
        RaceResult.lose => '상대가 더 많이 찾았어요 ($me : $opp)',
        RaceResult.draw => '같은 수를 찾았어요 ($me : $opp)',
      };
    }
    if (r == RaceResult.win) return '상대보다 먼저 클리어했어요';
    return vm.game.state == GameState.lost ? '지뢰를 밟았어요' : '상대가 먼저 끝냈어요';
  }

  String _resultEmoji(RaceResult r) {
    if (_isCoop) {
      if (vm.opponentLeft) return '👋';
      return r == RaceResult.win ? '🎉' : '💥';
    }
    return switch (r) {
      RaceResult.win => '🏆',
      RaceResult.lose => '💥',
      RaceResult.draw => '🤝',
    };
  }

  String _resultTitle(RaceResult r) {
    if (_isCoop) {
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
        emoji: _resultEmoji(r),
        title: _resultTitle(r),
        subtitle: _resultSubtitle(r),
        children: [
          FilledWideButton(
            label: _isCoop ? '다시 하기' : '다시 매칭',
            onTap: () {
              setState(() => flagMode = true);
              vm.rematch();
            },
          ),
          TextLinkButton(label: '나가기', onTap: _close),
        ],
      );
}
