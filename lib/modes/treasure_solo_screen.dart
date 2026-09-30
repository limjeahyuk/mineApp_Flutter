import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/item_dock.dart';
import '../progression/daily.dart';
import 'treasure_board.dart';
import 'treasure_model.dart';

/// 보물찾기 혼자 연습 — Swift TreasureView 이식(51×51, 깃발 모드 기본 ON).
class TreasureSoloScreen extends StatefulWidget {
  const TreasureSoloScreen({super.key});

  @override
  State<TreasureSoloScreen> createState() => _TreasureSoloScreenState();
}

class _TreasureSoloScreenState extends State<TreasureSoloScreen> {
  final game = TreasureModel(size: 51);
  bool flagMode = true;
  bool probing = false;
  bool reviewing = false;
  GameState _last = GameState.ready;

  static const gold = Color.fromRGBO(242, 199, 77, 1);

  @override
  void initState() {
    super.initState();
    final inv = LocalStore.shared;
    game.autoFlagSupplier = () => inv.ownedFlags;
    game.onConsumeAutoFlag = inv.consumeFlag;
    game.onGoldenMineFound = () {
      inv.awardGoldenMine();
      Daily.bump(DailyKind.golden);
      Haptics.success();
    };
    game.loadAutoFlagSupply();
    _last = game.state;
    game.addListener(() {
      if (game.state == _last) return;
      _last = game.state;
      setState(() {
        if (game.state != GameState.playing) probing = false;
        if (game.state == GameState.playing) reviewing = false;
      });
    });
  }

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  String _time(int s) => s < 60 ? '$s초' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: ListenableBuilder(
        listenable: game,
        builder: (context, _) => Stack(children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(children: [
                _topBar(t),
                const SizedBox(height: 10),
                Text(
                    flagMode
                        ? '🚩 깃발 모드 · 탭=깃발 · 길게=열기 · 숫자 탭=주변 열기'
                        : '탭=열기 · 길게=깃발 · 숫자 탭=주변 열기 · 가운데 💎까지',
                    textAlign: TextAlign.center,
                    style: sf(11, weight: W.medium, color: t.textTertiary)),
                const SizedBox(height: 10),
                Expanded(
                  child: TreasureBoard(
                    game: game,
                    flagMode: flagMode,
                    probing: probing,
                    reviewing: reviewing,
                    onProbe: (r, c) {
                      game.useAutoFlag(r, c);
                      setState(() => probing = false);
                    },
                  ),
                ),
                if (!reviewing) ...[const SizedBox(height: 10), _bottomBar(t)],
              ]),
            ),
          ),
          if (game.state == GameState.playing)
            Positioned(
              right: 0,
              bottom: mq.padding.bottom + 110,
              child: ItemDock(
                autoFlagTickets: game.autoFlagTickets,
                isPlaying: game.state == GameState.playing,
                probing: probing,
                usesEdgeDrawer: true,
                onProbingChanged: (v) => setState(() => probing = v),
              ),
            ),
          if (game.won && !reviewing) _winOverlay(t),
          if (game.won && reviewing) _reviewBar(),
        ]),
      ),
    );
  }

  Widget _topBar(AppTheme t) => Row(children: [
        Tap(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
            child: Icon(SF.xmark, size: 15, color: t.textSecondary),
          ),
        ),
        const Spacer(),
        Column(children: [
          Text('💎 보물찾기', style: sf(17, weight: W.heavy, color: t.text)),
          const SizedBox(height: 1),
          Text('혼자 연습', style: sf(10, weight: W.semibold, color: t.textTertiary)),
        ]),
        const Spacer(),
        SizedBox(
          width: 56,
          child: Text(_time(game.elapsed),
              textAlign: TextAlign.right,
              style: sf(15, weight: W.bold, color: t.textSecondary, mono: true)),
        ),
      ]);

  Widget _bottomBar(AppTheme t) {
    Widget stat(String icon, String label, String value) => Row(children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: sf(15, weight: W.bold, color: t.text, height: 1.1)),
            Text(label, style: sf(9, weight: W.semibold, color: t.textTertiary)),
          ]),
        ]);
    Widget sq(IconData icon, bool on, VoidCallback onTap) => Tap(
          onTap: () {
            Haptics.tap();
            onTap();
          },
          child: Container(
            width: 46,
            height: 40,
            decoration: rr(11, on ? const Color.fromRGBO(230, 77, 61, 1) : t.fill),
            child: Icon(icon, size: 16, color: on ? Colors.white : t.textSecondary),
          ),
        );
    return Row(children: [
      stat('💥', '지뢰 밟음', '${game.minesHit}'),
      const SizedBox(width: 10),
      stat('🚩', '깃발', '${game.flagCount}'),
      const Spacer(),
      sq(SF.flagFill, flagMode, () => setState(() => flagMode = !flagMode)),
      const SizedBox(width: 10),
      sq(SF.arrowClockwise, false, game.newGame),
    ]);
  }

  Widget _winOverlay(AppTheme t) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: rr(22, t.surface),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🏆', style: TextStyle(fontSize: 54, height: 1.1)),
                const SizedBox(height: 14),
                Text('보물 발견!', style: sf(22, weight: W.heavy, color: Colors.white)),
                const SizedBox(height: 14),
                Text('${_time(game.elapsed)} · 지뢰 ${game.minesHit}번 밟음',
                    style: sf(14, weight: W.medium, color: const Color(0xFFB3B3B3))),
                const SizedBox(height: 16),
                SizedBox(
                  width: 230,
                  child: Tap(
                    onTap: () {
                      Haptics.tap();
                      setState(() => reviewing = true);
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gold.withValues(alpha: 0.6), width: 1.5),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(CupertinoIcons.map_fill, size: 15, color: gold),
                        const SizedBox(width: 6),
                        Text('보드 보기', style: sf(15, weight: W.bold, color: gold)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Tap(
                    onTap: () {
                      Haptics.tap();
                      game.newGame();
                    },
                    child: Container(
                      width: 110,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: rr(12, gold),
                      child: Text('다시', style: sf(16, weight: W.bold, color: Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tap(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 110,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: rr(12, const Color(0xFF383838)),
                      child: Text('닫기', style: sf(16, weight: W.bold, color: Colors.white)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      );

  Widget _reviewBar() => Positioned(
        left: 0,
        right: 0,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
        child: Center(
          child: Tap(
            onTap: () => setState(() => reviewing = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: gold,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 3))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(SF.rosette, size: 15, color: Colors.black),
                const SizedBox(width: 6),
                Text('결과 보기', style: sf(15, weight: W.semibold, color: Colors.black)),
              ]),
            ),
          ),
        ),
      );
}
