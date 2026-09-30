import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/item_dock.dart';
import '../multiplayer/firebase_match_service.dart';
import '../multiplayer/mp_ui.dart';
import '../multiplayer/multiplayer.dart';
import 'treasure_board.dart';
import 'treasure_controller.dart';
import 'treasure_model.dart';

/// 보물찾기 온라인 레이스 — Swift TreasureMultiplayerView 이식.
/// 검색 → 같은 51×51 보드(호스트=좌상단, 게스트=우하단 출발 · 게스트는 뒤집어 그림) → 결과/복기.
class TreasureScreen extends StatefulWidget {
  const TreasureScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<TreasureScreen> createState() => _TreasureScreenState();
}

class _TreasureScreenState extends State<TreasureScreen> {
  late final TreasureController ctrl =
      TreasureController(FirebaseMatchService(kind: 'treasure'));
  bool flagMode = true;
  bool probing = false;
  bool reviewing = false;
  TreasureFlow _lastFlow = TreasureFlow.searching;

  @override
  void initState() {
    super.initState();
    ctrl.addListener(_onCtrl);
    ctrl.start(widget.mode);
  }

  void _onCtrl() {
    if (ctrl.flow != _lastFlow) {
      _lastFlow = ctrl.flow;
      if (ctrl.flow != TreasureFlow.racing) probing = false;
      if (ctrl.flow == TreasureFlow.racing) {
        reviewing = false;
      }
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
            if (ctrl.flow == TreasureFlow.racing)
              Positioned(
                right: 0,
                bottom: mq.padding.bottom + 40,
                child: ItemDock(
                  autoFlagTickets: g.autoFlagTickets,
                  isPlaying: g.state == GameState.playing && !g.stunned,
                  probing: probing,
                  usesEdgeDrawer: true,
                  onProbingChanged: (v) => setState(() => probing = v),
                ),
              ),
            if (ctrl.flow == TreasureFlow.finished && ctrl.result != null && !reviewing)
              _result(t, ctrl.result!),
            if (ctrl.flow == TreasureFlow.finished && reviewing) _reviewBar(),
            if (ctrl.flow == TreasureFlow.racing && g.stunned) _stunBanner(g),
          ]);
        },
      ),
    );
  }

  Widget _content(AppTheme t) {
    if (ctrl.flow == TreasureFlow.searching) {
      if (ctrl.failure != null) return mpFailure(t, ctrl.failure!.message, _exit);
      Widget detail;
      if (ctrl.rematching) {
        detail = Text('같은 상대와 다시 시작할게요',
            textAlign: TextAlign.center, style: sf(13, color: t.textSecondary));
      } else if (widget.mode.kind == RaceModeKind.host) {
        final code = ctrl.roomCode;
        detail = RoomCodeBlock(
          code: code,
          shareText: code == null
              ? ''
              : '보물찾기 대결에 들어와요! 방 코드: $code\n${inviteWebUrl('treasure', code)}',
        );
      } else {
        detail = Text('같은 보드에서 먼저 가운데 💎를 여는 사람이 승',
            textAlign: TextAlign.center, style: sf(13, color: t.textSecondary));
      }
      final title = ctrl.rematching
          ? '상대를 기다리는 중…'
          : switch (widget.mode.kind) {
              RaceModeKind.host => '상대 입장을 기다리는 중…',
              RaceModeKind.join => '방에 입장 중…',
              _ => '상대를 찾는 중…',
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
          Text(_time(g.elapsed), style: sf(18, weight: W.bold, color: t.textSecondary, mono: true)),
          const Spacer(),
          mpFlagToggle(t, flagMode, () => setState(() => flagMode = !flagMode)),
        ]),
        const SizedBox(height: 8),
        mpProgressRow(t,
            label: '나',
            title: LocalStore.shared.equippedTitleName,
            value: g.progress,
            color: mpMeColor),
        const SizedBox(height: 8),
        mpProgressRow(t,
            label: ctrl.opponentName,
            title: ctrl.opponentTitle,
            value: g.opponentProgress,
            color: mpOppColor),
        const SizedBox(height: 10),
        Expanded(
          child: TreasureBoard(
            game: g,
            flagMode: flagMode,
            flipped: g.myStart != (0, 0),
            probing: probing,
            reviewing: reviewing,
            onProbe: (r, c) {
              g.useAutoFlag(r, c);
              setState(() => probing = false);
            },
          ),
        ),
      ]),
    );
  }

  Widget _stunBanner(TreasureModel g) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: rr(14, Colors.red.withValues(alpha: 0.85)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('💥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('지뢰! 잠깐 멈춤… (${g.minesHit}/${TreasureModel.maxMineHits})',
                  style: sf(14, weight: W.bold, color: Colors.white)),
            ]),
          ),
        ),
      );

  Widget _result(AppTheme t, RaceResult r) {
    String sub;
    if (ctrl.opponentLeft) {
      sub = '상대가 나가서 승리했어요';
    } else if (r == RaceResult.win) {
      sub = ctrl.opponentFailedByMines ? '상대가 지뢰를 너무 많이 밟았어요' : '보물을 먼저 찾았어요!';
    } else {
      sub = ctrl.model.failedByMines
          ? '지뢰를 ${TreasureModel.maxMineHits}번 밟아 패배했어요'
          : '상대가 먼저 보물을 찾았어요';
    }
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
              Text(r == RaceResult.win ? '🏆' : '💎', style: const TextStyle(fontSize: 54, height: 1.1)),
              const SizedBox(height: 12),
              Text(r == RaceResult.win ? '승리!' : '패배', style: sf(24, weight: W.bold, color: t.text)),
              const SizedBox(height: 12),
              Text(sub, textAlign: TextAlign.center, style: sf(14, color: t.textSecondary)),
              const SizedBox(height: 18),
              Tap(
                onTap: () => setState(() => reviewing = true),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: mpMeColor.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(CupertinoIcons.map_fill, size: 16, color: mpMeColor),
                    const SizedBox(width: 6),
                    Text('보드 보기', style: sf(16, weight: W.semibold, color: mpMeColor)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Tap(
                onTap: ctrl.rematch,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: rr(12, mpMeColor),
                  child: Text('다시 매칭', style: sf(17, weight: W.semibold, color: Colors.white)),
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
                color: mpMeColor,
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
