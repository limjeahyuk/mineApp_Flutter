import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Title;

import '../app/deep_link.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/item_dock.dart';
import '../multiplayer/firebase_match_service.dart';
import '../multiplayer/match_widgets.dart';
import '../multiplayer/multiplayer.dart';
import '../progression/title.dart';
import 'coop_controller.dart';
import 'touch_board.dart';

/// "너에게 닿기를" 협동 화면 — Swift TouchMultiplayerView 이식.
class CoopScreen extends StatefulWidget {
  const CoopScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<CoopScreen> createState() => _CoopScreenState();
}

class _CoopScreenState extends State<CoopScreen> {
  late final CoopController vm = CoopController(FirebaseMatchService(kind: 'touch'));
  bool flagMode = true; // 기본 깃발 모드
  bool probing = false;
  bool reviewing = false;
  CoopFlow _lastFlow = CoopFlow.searching;
  bool _lastStunned = false;

  static const accent = Color.fromRGBO(102, 179, 140, 1); // (0.40,0.70,0.55)

  @override
  void initState() {
    super.initState();
    vm.addListener(_onChange);
    vm.start(widget.mode);
  }

  void _onChange() {
    if (vm.flow != _lastFlow) {
      _lastFlow = vm.flow;
      if (vm.flow != CoopFlow.racing) probing = false;
      if (vm.flow == CoopFlow.racing) reviewing = false;
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

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final g = vm.game;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        SafeArea(
          child: vm.flow == CoopFlow.searching
              ? (vm.failure != null
                  ? MatchFailedView(error: vm.failure!, onClose: _close)
                  : _searching())
              : _race(t),
        ),
        if (vm.flow == CoopFlow.racing)
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
                  megaphoneTickets: g.megaphoneTickets,
                  onMegaphone: () => g.useMegaphone(),
                ),
              ),
            ),
          ),
        if (vm.flow == CoopFlow.finished && vm.result != null && !reviewing)
          _resultOverlay(t, vm.result!),
        if (vm.flow == CoopFlow.finished && reviewing)
          ReviewBar(color: accent, onTap: () => setState(() => reviewing = false)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: vm.flow == CoopFlow.racing && g.stunned
              ? const StunBanner(
                  key: ValueKey('stun'), text: '지뢰! 잠깐 멈춤… (파트너 깃발 1개 떨어짐)', fontSize: 13)
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  String get _searchingTitle {
    if (vm.rematching) return '파트너를 기다리는 중…';
    return switch (widget.mode.kind) {
      RaceModeKind.host => '파트너 입장을 기다리는 중…',
      RaceModeKind.join => '방에 입장 중…',
      _ => '함께할 사람을 찾는 중…',
    };
  }

  Widget _searching() => SearchingView(
        title: _searchingTitle,
        onCancel: _close,
        rematchText: vm.rematching ? '같은 파트너와 다시 시작할게요' : null,
        isHost: widget.mode.kind == RaceModeKind.host,
        roomCode: vm.roomCode,
        description: '서로 길을 뚫어 만나면 둘 다 성공이에요',
        codeHint: '친구가 이 코드를 입력하면 함께 시작돼요',
        shareText: (c) =>
            '‘너에게 닿기를’ 같이 해요! 방 코드: $c\n${InviteLink.webURL(InviteGame.touch, c)}',
      );

  Widget _race(AppTheme t) {
    final g = vm.game;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(children: [
        Row(children: [
          CircleIconButton(icon: CupertinoIcons.xmark, onTap: _close),
          const Spacer(),
          Text(timeLabel(g.elapsed),
              style: TextStyle(
                  color: t.text, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
          const Spacer(),
          FlagToggle(on: flagMode, onChanged: (v) => setState(() => flagMode = v)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text('🤝', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Flexible(
            child: Text('${vm.opponentName}와 길을 뚫어 만나기',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          TitleBadge(name: vm.opponentTitle, size: 8),
          const Spacer(),
          if (g.minesHit > 0)
            Text('💣 ${g.minesHit}',
                style: const TextStyle(
                    color: AppTheme.raceOpp, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: TouchBoard(
            game: g,
            flagMode: flagMode,
            pings: vm.pings,
            probing: probing,
            onProbe: (r, c) {
              g.useAutoFlag(r, c);
              setState(() => probing = false);
            },
            reveal: reviewing,
          ),
        ),
      ]),
    );
  }

  Widget _resultOverlay(AppTheme t, RaceResult r) {
    final win = r == RaceResult.win;
    final best = LocalStore.shared.touchBest;
    return ResultOverlay(
      emoji: win ? '🤝' : '🌫️',
      title: win ? '서로에게 닿았어요!' : '아쉽게 끝났어요',
      titleSize: 23,
      subtitle: vm.opponentLeft
          ? '상대가 나가서 함께 도달하지 못했어요'
          : (win ? '둘이 길을 이어 만났어요 🎉' : '다시 도전해 보세요'),
      children: [
        if (win)
          Column(children: [
            Text('걸린 시간 ${timeLabel(vm.game.elapsed)}',
                style: const TextStyle(
                    color: accent, fontSize: 16, fontWeight: FontWeight.bold)),
            if (best != null) ...[
              const SizedBox(height: 3),
              Text('최고 기록 ${timeLabel(best)}',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
            ],
          ]),
        if (win)
          OutlineButton(
              label: '보드 보기',
              icon: CupertinoIcons.map_fill,
              color: accent,
              onTap: () => setState(() => reviewing = true)),
        BigButton(label: '다시 하기', color: accent, onTap: vm.rematch),
        TextLink('나가기', onTap: _close),
      ],
    );
  }
}
