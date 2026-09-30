import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' hide Title;

import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/item_dock.dart';
import '../multiplayer/firebase_match_service.dart';
import '../multiplayer/mp_ui.dart';
import '../multiplayer/multiplayer.dart';
import '../progression/title.dart';
import 'coop_controller.dart';
import 'touch_board.dart';

/// '너에게 닿기를' 협동 화면 — Swift TouchMultiplayerView 이식.
/// 검색 → 함께 길 뚫기(안개 보드) → 닿으면 둘 다 성공 → 결과/복기.
class CoopScreen extends StatefulWidget {
  const CoopScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<CoopScreen> createState() => _CoopScreenState();
}

class _CoopScreenState extends State<CoopScreen> {
  late final CoopController ctrl = CoopController(FirebaseMatchService(kind: 'touch'));
  bool flagMode = true;
  bool probing = false;
  bool reviewing = false;
  CoopFlow _lastFlow = CoopFlow.searching;

  static const accent = Color.fromRGBO(102, 179, 140, 1); // (0.40,0.70,0.55)

  @override
  void initState() {
    super.initState();
    ctrl.addListener(_onCtrl);
    ctrl.start(widget.mode);
  }

  void _onCtrl() {
    if (ctrl.flow != _lastFlow) {
      _lastFlow = ctrl.flow;
      if (ctrl.flow != CoopFlow.racing) probing = false;
      if (ctrl.flow == CoopFlow.racing) reviewing = false;
    }
    if (ctrl.model.stunned) probing = false;
  }

  @override
  void dispose() {
    ctrl.removeListener(_onCtrl);
    ctrl.leave();
    ctrl.dispose();
    super.dispose();
  }

  void _exit() {
    if (mounted) Navigator.of(context).pop();
  }

  String _time(int s) => s < 60 ? '$s초' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final g = ctrl.model;
          return Stack(children: [
            SafeArea(child: _content(t)),
            if (ctrl.flow == CoopFlow.racing)
              Positioned(
                right: 0,
                bottom: mq.padding.bottom + 40,
                child: ItemDock(
                  autoFlagTickets: g.autoFlagTickets,
                  isPlaying: g.state == GameState.playing && !g.stunned,
                  probing: probing,
                  usesEdgeDrawer: true,
                  megaphoneTickets: g.megaphoneTickets,
                  onMegaphone: g.useMegaphone,
                  onProbingChanged: (v) => setState(() => probing = v),
                ),
              ),
            if (ctrl.flow == CoopFlow.finished && ctrl.result != null && !reviewing)
              _result(t, ctrl.result!),
            if (ctrl.flow == CoopFlow.finished && reviewing) _reviewBar(),
            if (ctrl.flow == CoopFlow.racing && g.stunned)
              Positioned(
                top: mq.padding.top + 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: rr(14, Colors.red.withValues(alpha: 0.85)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('💥', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('지뢰! 잠깐 멈춤… (파트너 깃발 1개 떨어짐)',
                          style: sf(13, weight: W.bold, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Widget _content(AppTheme t) {
    if (ctrl.flow == CoopFlow.searching) {
      if (ctrl.failure != null) return mpFailure(t, ctrl.failure!.message, _exit);
      Widget detail;
      if (ctrl.rematching) {
        detail = Text('같은 파트너와 다시 시작할게요',
            textAlign: TextAlign.center, style: sf(13, color: t.textSecondary));
      } else if (widget.mode.kind == RaceModeKind.host) {
        final code = ctrl.roomCode;
        detail = RoomCodeBlock(
          code: code,
          caption: '친구가 이 코드를 입력하면 함께 시작돼요',
          shareText: code == null
              ? ''
              : '‘너에게 닿기를’ 같이 해요! 방 코드: $code\n${inviteWebUrl('touch', code)}',
        );
      } else {
        detail = Text('서로 길을 뚫어 만나면 둘 다 성공이에요',
            textAlign: TextAlign.center, style: sf(13, color: t.textSecondary));
      }
      final title = ctrl.rematching
          ? '파트너를 기다리는 중…'
          : switch (widget.mode.kind) {
              RaceModeKind.host => '파트너 입장을 기다리는 중…',
              RaceModeKind.join => '방에 입장 중…',
              _ => '함께할 사람을 찾는 중…',
            };
      return mpSearching(t, title: title, detail: detail, onCancel: _exit);
    }
    final g = ctrl.model;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(children: [
        Row(children: [
          mpCircleButton(t, SF.xmark, _exit),
          const Spacer(),
          Text(_time(g.elapsed), style: sf(20, weight: W.bold, color: t.text, mono: true)),
          const Spacer(),
          mpFlagToggle(t, flagMode, () => setState(() => flagMode = !flagMode)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text('🤝', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Flexible(
            child: Text('${ctrl.opponentName}와 길을 뚫어 만나기',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sf(12, weight: W.semibold, color: t.textSecondary)),
          ),
          if (ctrl.opponentTitle.isNotEmpty) ...[
            const SizedBox(width: 6),
            TitleBadge(name: ctrl.opponentTitle, size: 8),
          ],
          const Spacer(),
          if (g.minesHit > 0)
            Text('💣 ${g.minesHit}', style: sf(12, weight: W.bold, color: mpOppColor)),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: TouchBoard(
            game: g,
            flagMode: flagMode,
            pings: ctrl.pings,
            probing: probing,
            reveal: reviewing,
            onProbe: (r, c) {
              g.useAutoFlag(r, c);
              setState(() => probing = false);
            },
          ),
        ),
      ]),
    );
  }

  Widget _result(AppTheme t, RaceResult r) {
    final win = r == RaceResult.win;
    final best = LocalStore.shared.touchBest;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            margin: const EdgeInsets.all(36),
            padding: const EdgeInsets.all(26),
            decoration: rr(20, t.fill, stroke: t.fillElevated),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(win ? '🤝' : '🌫️', style: const TextStyle(fontSize: 54, height: 1.1)),
              const SizedBox(height: 12),
              Text(win ? '서로에게 닿았어요!' : '아쉽게 끝났어요',
                  style: sf(23, weight: W.bold, color: t.text)),
              const SizedBox(height: 12),
              Text(
                  ctrl.opponentLeft
                      ? '상대가 나가서 함께 도달하지 못했어요'
                      : (win ? '둘이 길을 이어 만났어요 🎉' : '다시 도전해 보세요'),
                  textAlign: TextAlign.center,
                  style: sf(14, color: t.textSecondary)),
              if (win) ...[
                const SizedBox(height: 12),
                Text('걸린 시간 ${_time(ctrl.model.elapsed)}',
                    style: sf(16, weight: W.bold, color: accent)),
                if (best != null) ...[
                  const SizedBox(height: 3),
                  Text('최고 기록 ${_time(best)}', style: sf(12, color: t.textSecondary)),
                ],
                const SizedBox(height: 16),
                Tap(
                  onTap: () => setState(() => reviewing = true),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(CupertinoIcons.map_fill, size: 16, color: accent),
                      const SizedBox(width: 6),
                      Text('보드 보기', style: sf(16, weight: W.semibold, color: accent)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 12 + 6),
              Tap(
                onTap: ctrl.rematch,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: rr(12, accent),
                  child: Text('다시 하기', style: sf(17, weight: W.semibold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              Tap(onTap: _exit, child: Text('나가기', style: sf(14, weight: W.medium, color: t.textSecondary))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _reviewBar() => Positioned(
        left: 0,
        right: 0,
        bottom: 34 + MediaQuery.of(context).padding.bottom,
        child: Center(
          child: Tap(
            onTap: () => setState(() => reviewing = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 3))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(SF.rosette, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text('결과 보기', style: sf(15, weight: W.semibold, color: Colors.white)),
              ]),
            ),
          ),
        ),
      );
}
