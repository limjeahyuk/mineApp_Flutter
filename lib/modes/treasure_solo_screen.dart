import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/item_dock.dart';
import 'treasure_board.dart';
import 'treasure_model.dart';

/// 보물찾기(혼자 연습) — Swift TreasureView 이식. 좌상단 꼭짓점에서 가운데 💎까지 길을 뚫는다.
class TreasureSoloScreen extends StatefulWidget {
  const TreasureSoloScreen({super.key});

  @override
  State<TreasureSoloScreen> createState() => _TreasureSoloScreenState();
}

class _TreasureSoloScreenState extends State<TreasureSoloScreen> {
  final TreasureModel game = TreasureModel(size: 51);
  bool flagMode = true; // 보물찾기는 깃발 위주 플레이라 기본 ON
  bool probing = false;
  bool reviewing = false;
  GameState _lastState = GameState.playing;

  static const _gold = AppTheme.gold;

  @override
  void initState() {
    super.initState();
    final s = LocalStore.shared;
    game.autoFlagSupplier = () => s.ownedFlags;
    game.onConsumeAutoFlag = () => s.consumeFlag();
    game.onGoldenMineFound = () {
      s.awardGoldenMine();
      Haptics.success();
    };
    game.loadAutoFlagSupply(); // 생성 시점엔 supplier가 없었으므로 다시 채운다
    _lastState = game.state;
    game.addListener(_onGame);
  }

  @override
  void dispose() {
    game.removeListener(_onGame);
    game.dispose();
    super.dispose();
  }

  void _onGame() {
    if (game.state != _lastState) {
      _lastState = game.state;
      setState(() {
        if (game.state != GameState.playing) probing = false;
        if (game.state == GameState.playing) reviewing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: ListenableBuilder(
        listenable: game,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  children: [
                    _topBar(t),
                    const SizedBox(height: 10),
                    Text(
                        flagMode
                            ? '🚩 깃발 모드 · 탭=깃발 · 길게=열기 · 숫자 탭=주변 열기'
                            : '탭=열기 · 길게=깃발 · 숫자 탭=주변 열기 · 가운데 💎까지',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: t.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TreasureBoard(
                        game: game,
                        flagMode: flagMode,
                        probing: probing,
                        onProbe: (r, c) {
                          game.useAutoFlag(r, c);
                          setState(() => probing = false);
                        },
                        reviewing: reviewing,
                      ),
                    ),
                    if (!reviewing) ...[
                      const SizedBox(height: 10),
                      _bottomBar(t),
                    ],
                  ],
                ),
              ),
            ),
            if (game.state == GameState.playing)
              SafeArea(
                child: Stack(children: [
                  ItemDock(
                    tickets: game.autoFlagTickets,
                    isPlaying: game.state == GameState.playing,
                    probing: probing,
                    onProbingChanged: (v) => setState(() => probing = v),
                    drawerBottomPadding: 110,
                  ),
                ]),
              ),
            if (game.won && !reviewing) _winOverlay(t),
            if (game.won && reviewing) _reviewBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar(AppTheme t) {
    return Row(
      children: [
        PlainButton(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
            child: Icon(Icons.close, size: 17, color: t.textSecondary),
          ),
        ),
        const Spacer(),
        Column(children: [
          Text('💎 보물찾기',
              style: TextStyle(
                  color: t.text, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 1),
          Text('혼자 연습',
              style: TextStyle(
                  color: t.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ]),
        const Spacer(),
        SizedBox(
          width: 56,
          child: ValueListenableBuilder<int>(
            valueListenable: game.tick,
            builder: (_, _, _) => Text(timeLabel(game.elapsed),
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Menlo',
                    fontFamilyFallback: const ['Courier', 'monospace'])),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar(AppTheme t) {
    Widget stat(String icon, String label, String value) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Text(label,
                    style: TextStyle(
                        color: t.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        );
    Widget square(Widget icon, Color fill, VoidCallback onTap) => PlainButton(
          onTap: () {
            Haptics.tap();
            onTap();
          },
          child: Container(
            width: 46,
            height: 40,
            decoration: BoxDecoration(
                color: fill, borderRadius: BorderRadius.circular(11)),
            child: icon,
          ),
        );
    return Row(
      children: [
        stat('💥', '지뢰 밟음', '${game.minesHit}'),
        const SizedBox(width: 10),
        stat('🚩', '깃발', '${game.flagCount}'),
        const Spacer(),
        square(
            Icon(Icons.flag,
                size: 18, color: flagMode ? Colors.white : t.textSecondary),
            flagMode ? AppTheme.dangerRed : t.fill,
            () => setState(() => flagMode = !flagMode)),
        const SizedBox(width: 10),
        square(Icon(Icons.refresh, size: 18, color: t.textSecondary), t.fill,
            game.newGame),
      ],
    );
  }

  Widget _winOverlay(AppTheme t) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: t.surface, borderRadius: BorderRadius.circular(22)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 14),
            Text('보물 발견!',
                style: TextStyle(
                    color: t.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Text('${timeLabel(game.elapsed)} · 지뢰 ${game.minesHit}번 밟음',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            SizedBox(
              width: 230,
              child: PlainButton(
                onTap: () {
                  Haptics.tap();
                  setState(() => reviewing = true);
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _gold.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 17, color: _gold),
                      SizedBox(width: 6),
                      Text('보드 보기',
                          style: TextStyle(
                              color: _gold,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlainButton(
                  onTap: () {
                    Haptics.tap();
                    game.newGame();
                  },
                  child: Container(
                    width: 110,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: _gold, borderRadius: BorderRadius.circular(12)),
                    child: const Text('다시',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                PlainButton(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 110,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: const Color.fromRGBO(56, 56, 56, 1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('닫기',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewBar() => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: PlainButton(
            onTap: () => setState(() => reviewing = false),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.workspace_premium, size: 17, color: Colors.black),
                SizedBox(width: 6),
                Text('결과 보기',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}
