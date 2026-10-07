import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/deep_link.dart';
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

/// 보물찾기 온라인 레이스 — Swift TreasureMultiplayerView 이식.
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
  bool probing = false;
  bool reviewing = false;
  TreasureFlow _lastFlow = TreasureFlow.searching;
  bool _lastStunned = false;

  static const meColor = AppTheme.raceMe;
  static const oppColor = AppTheme.raceOpp;

  @override
  void initState() {
    super.initState();
    vm.addListener(_onChange);
    vm.start(widget.mode);
  }

  void _onChange() {
    if (vm.flow != _lastFlow) {
      _lastFlow = vm.flow;
      if (vm.flow != TreasureFlow.racing) probing = false;
      if (vm.flow == TreasureFlow.racing) reviewing = false;
    }
    if (vm.game.stunned != _lastStunned) {
      _lastStunned = vm.game.stunned;
      if (_lastStunned) probing = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    vm.removeListener(_onChange);
    vm.leave();
    vm.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  TreasureModel get g => vm.game;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        SafeArea(
          child: vm.flow == TreasureFlow.searching
              ? (vm.failure != null
                  ? MatchFailedView(error: vm.failure!, onClose: _close)
                  : _searching())
              : _race(t),
        ),
        if (vm.flow == TreasureFlow.racing)
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: ItemDock(
                  tickets: g.autoFlagTickets,
                  isPlaying: g.state == GameState.playing && !g.stunned,
                  usesEdgeDrawer: true,
                  probing: probing,
                  onProbingChanged: (v) => setState(() => probing = v),
                  drawerBottomPadding: 40,
                ),
              ),
            ),
          ),
        if (vm.flow == TreasureFlow.finished && vm.result != null && !reviewing)
          _resultOverlay(vm.result!),
        if (vm.flow == TreasureFlow.finished && reviewing)
          ReviewBar(color: meColor, onTap: () => setState(() => reviewing = false)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: vm.flow == TreasureFlow.racing && g.stunned
              ? StunBanner(
                  key: const ValueKey('stun'),
                  text: '지뢰! 잠깐 멈춤… (${g.minesHit}/${TreasureModel.maxMineHits})')
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  String get _searchingTitle {
    if (vm.rematching) return '상대를 기다리는 중…';
    return switch (widget.mode.kind) {
      RaceModeKind.host => '상대 입장을 기다리는 중…',
      RaceModeKind.join => '방에 입장 중…',
      _ => '상대를 찾는 중…',
    };
  }

  Widget _searching() => SearchingView(
        title: _searchingTitle,
        onCancel: _close,
        rematchText: vm.rematching ? '같은 상대와 다시 시작할게요' : null,
        isHost: widget.mode.kind == RaceModeKind.host,
        roomCode: vm.roomCode,
        description: '같은 보드에서 먼저 가운데 💎를 여는 사람이 승',
        shareText: (c) =>
            '보물찾기 대결에 들어와요! 방 코드: $c\n${InviteLink.webURL(InviteGame.treasure, c)}',
      );

  Widget _race(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(children: [
        Row(children: [
          CircleIconButton(icon: CupertinoIcons.xmark, onTap: _close),
          const Spacer(),
          Text(timeLabel(g.elapsed),
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier')),
          const Spacer(),
          FlagToggle(on: flagMode, onChanged: (v) => setState(() => flagMode = v)),
        ]),
        const SizedBox(height: 8),
        ProgressRow(
            label: '나',
            title: LocalStore.shared.equippedTitleName,
            value: g.progress,
            color: meColor,
            labelWidth: 74),
        const SizedBox(height: 8),
        ProgressRow(
            label: vm.opponentName,
            title: vm.opponentTitle,
            value: g.opponentProgress,
            color: oppColor,
            labelWidth: 74),
        const SizedBox(height: 10),
        Expanded(
          child: TreasureBoard(
            game: g,
            flagMode: flagMode,
            // 게스트(우하단 출발)는 보드를 뒤집어 '내 출발점=좌상단'으로 통일.
            flipped: g.myStart != (0, 0),
            probing: probing,
            onProbe: (r, c) {
              g.useAutoFlag(r, c);
              setState(() => probing = false);
            },
            reviewing: reviewing,
          ),
        ),
      ]),
    );
  }

  String _subtitle(RaceResult r) {
    if (vm.opponentLeft) return '상대가 나가서 승리했어요';
    if (r == RaceResult.win) {
      return vm.opponentFailedByMines ? '상대가 지뢰를 너무 많이 밟았어요' : '보물을 먼저 찾았어요!';
    }
    return g.failedByMines
        ? '지뢰를 ${TreasureModel.maxMineHits}번 밟아 패배했어요'
        : '상대가 먼저 보물을 찾았어요';
  }

  Widget _resultOverlay(RaceResult r) => ResultOverlay(
        emoji: r == RaceResult.win ? '🏆' : '💎',
        title: r == RaceResult.win ? '승리!' : '패배',
        subtitle: _subtitle(r),
        children: [
          OutlineButton(
              label: '보드 보기',
              icon: CupertinoIcons.map_fill,
              color: meColor,
              onTap: () => setState(() => reviewing = true)),
          BigButton(label: '다시 매칭', color: meColor, onTap: vm.rematch),
          TextLink('나가기', onTap: _close),
        ],
      );
}
