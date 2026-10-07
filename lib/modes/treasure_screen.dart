import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/item_dock.dart';
import '../multiplayer/firebase_match_service.dart';
import '../multiplayer/match_widgets.dart';
import '../multiplayer/multiplayer.dart';
import 'treasure_board.dart';
import 'treasure_controller.dart';
import 'treasure_model.dart';

/// 보물찾기 온라인 레이스 — Swift TreasureMultiplayerView 이식: 상대 검색 → 같은 보드 레이스 → 결과.
class TreasureScreen extends StatefulWidget {
  const TreasureScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<TreasureScreen> createState() => _TreasureScreenState();
}

class _TreasureScreenState extends State<TreasureScreen> {
  late final TreasureController vm =
      TreasureController(FirebaseMatchService(kind: 'treasure'));
  bool flagMode = true;
  bool probing = false; // 자동깃발 아이템 발동 대기
  bool reviewing = false; // 결과창 대신 보드로 복기 중
  TreasureFlow _lastFlow = TreasureFlow.searching;
  bool _lastStunned = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    vm.addListener(_onVm);
    vm.start(widget.mode);
  }

  @override
  void dispose() {
    vm.removeListener(_onVm);
    vm.leave();
    vm.dispose();
    super.dispose();
  }

  void _onVm() {
    if (vm.flow != _lastFlow) {
      _lastFlow = vm.flow;
      if (vm.flow != TreasureFlow.racing) probing = false;
      if (vm.flow == TreasureFlow.racing) reviewing = false;
    }
    if (vm.game.stunned != _lastStunned) {
      _lastStunned = vm.game.stunned;
      if (_lastStunned) probing = false;
    }
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop();
  }

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
                  child: vm.flow == TreasureFlow.searching
                      ? _searchingView(t)
                      : _raceView(t),
                ),
                if (vm.flow == TreasureFlow.racing)
                  SafeArea(
                    child: Stack(children: [
                      ItemDock(
                        tickets: g.autoFlagTickets,
                        isPlaying:
                            g.state == GameState.playing && !g.stunned,
                        usesEdgeDrawer: true,
                        probing: probing,
                        onProbingChanged: (v) => setState(() => probing = v),
                        drawerBottomPadding: 40,
                      ),
                    ]),
                  ),
                if (vm.flow == TreasureFlow.finished &&
                    vm.result != null &&
                    !reviewing)
                  _resultOverlay(vm.result!),
                if (vm.flow == TreasureFlow.finished && reviewing)
                  _reviewBar(),
                if (vm.flow == TreasureFlow.racing && g.stunned)
                  SafeArea(child: _stunBanner()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stunBanner() => Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('💥', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
                '지뢰! 잠깐 멈춤… (${vm.game.minesHit}/${TreasureModel.maxMineHits})',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  // MARK: 검색 중

  Widget _searchingView(AppTheme t) {
    final failure = vm.failure;
    if (failure != null) return MatchFailedView(error: failure, onClose: _close);
    final Widget detail;
    if (vm.rematching) {
      detail = const MatchDetailText('같은 상대와 다시 시작할게요');
    } else if (widget.mode.kind == RaceModeKind.host) {
      detail = RoomCodeBlock(
        code: vm.roomCode,
        shareText: (code) =>
            '보물찾기 대결에 들어와요! 방 코드: $code\n${InviteLink.webURL('treasure', code)}',
      );
    } else {
      detail = const MatchDetailText('같은 보드에서 먼저 가운데 💎를 여는 사람이 승');
    }
    final title = vm.rematching
        ? '상대를 기다리는 중…'
        : switch (widget.mode.kind) {
            RaceModeKind.host => '상대 입장을 기다리는 중…',
            RaceModeKind.join => '방에 입장 중…',
            _ => '상대를 찾는 중…',
          };
    return MatchSearchingView(title: title, detail: detail, onCancel: _close);
  }

  // MARK: 레이스

  Widget _raceView(AppTheme t) {
    final g = vm.game;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              CircleIconButton(icon: Icons.close, onTap: _close),
              const Spacer(),
              ValueListenableBuilder<int>(
                valueListenable: g.tick,
                builder: (_, _, _) => Text(timeLabel(g.elapsed),
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Menlo',
                        fontFamilyFallback: const ['Courier', 'monospace'])),
              ),
              const Spacer(),
              CircleFlagToggle(
                  on: flagMode,
                  onTap: () => setState(() => flagMode = !flagMode)),
            ],
          ),
          const SizedBox(height: 8),
          RaceProgressRow(
              label: '나',
              title: LocalStore.shared.equippedTitleName,
              value: g.progress,
              color: kRaceMe,
              labelWidth: 74),
          const SizedBox(height: 8),
          RaceProgressRow(
              label: vm.opponentName,
              title: vm.opponentTitle,
              value: g.opponentProgress,
              color: kRaceOpp,
              labelWidth: 74),
          const SizedBox(height: 10),
          Expanded(
            child: TreasureBoard(
              game: g,
              flagMode: flagMode,
              // 게스트(우하단 출발)는 뒤집어 그려 '내 출발점=좌상단'으로 통일한다.
              flipped: g.myStart != (0, 0),
              probing: probing,
              onProbe: (r, c) {
                g.useAutoFlag(r, c);
                setState(() => probing = false);
              },
              reviewing: reviewing,
            ),
          ),
        ],
      ),
    );
  }

  // MARK: 결과

  String _resultSubtitle(RaceResult r) {
    if (vm.opponentLeft) return '상대가 나가서 승리했어요';
    if (r == RaceResult.win) {
      return vm.opponentFailedByMines ? '상대가 지뢰를 너무 많이 밟았어요' : '보물을 먼저 찾았어요!';
    }
    return vm.game.failedByMines
        ? '지뢰를 ${TreasureModel.maxMineHits}번 밟아 패배했어요'
        : '상대가 먼저 보물을 찾았어요';
  }

  Widget _resultOverlay(RaceResult r) {
    return ResultOverlay(
      emoji: r == RaceResult.win ? '🏆' : '💎',
      title: r == RaceResult.win ? '승리!' : '패배',
      subtitle: _resultSubtitle(r),
      children: [
        PlainButton(
          onTap: () => setState(() => reviewing = true),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: kRaceMe.withValues(alpha: 0.6), width: 1.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 17, color: kRaceMe),
                SizedBox(width: 6),
                Text('보드 보기',
                    style: TextStyle(
                        color: kRaceMe,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledWideButton(
            label: '다시 매칭',
            onTap: () {
              setState(() => flagMode = true);
              vm.rematch();
            }),
        TextLinkButton(label: '나가기', onTap: _close),
      ],
    );
  }

  Widget _reviewBar() => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 34),
          child: PlainButton(
            onTap: () => setState(() => reviewing = false),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: kRaceMe,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.workspace_premium, size: 17, color: Colors.white),
                SizedBox(width: 6),
                Text('결과 보기',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}
