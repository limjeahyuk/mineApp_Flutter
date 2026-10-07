import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/item_dock.dart';
import '../multiplayer/match_widgets.dart';
import 'treasure_board.dart';
import 'treasure_model.dart';

/// 보물찾기 혼자 연습 — Swift TreasureView 이식.
class TreasureSoloScreen extends StatefulWidget {
  const TreasureSoloScreen({super.key});

  @override
  State<TreasureSoloScreen> createState() => _TreasureSoloScreenState();
}

class _TreasureSoloScreenState extends State<TreasureSoloScreen> {
  final game = TreasureModel(size: 51);
  bool flagMode = true; // 깃발 위주 플레이라 기본 ON
  bool probing = false;
  bool reviewing = false;
  GameState _last = GameState.playing;

  static const gold = AppTheme.gold;

  @override
  void initState() {
    super.initState();
    final store = LocalStore.shared;
    game.autoFlagSupplier = () => store.ownedFlags;
    game.onConsumeAutoFlag = store.consumeFlag;
    game.onGoldenMineFound = () {
      store.awardGoldenMine();
      Haptics.success();
    };
    game.loadAutoFlagSupply(); // init이 supplier 주입 전에 새 판을 만들었으므로 다시 채운다
    game.addListener(_onChange);
  }

  void _onChange() {
    if (game.state != _last) {
      _last = game.state;
      if (game.state != GameState.playing) probing = false;
      if (game.state == GameState.playing) reviewing = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    game.removeListener(_onChange);
    game.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
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
                  style: TextStyle(
                      color: t.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
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
              if (!reviewing) ...[const SizedBox(height: 10), _bottomBar(t)],
            ]),
          ),
        ),
        if (game.state == GameState.playing)
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: ItemDock(
                  tickets: game.autoFlagTickets,
                  isPlaying: game.state == GameState.playing,
                  usesEdgeDrawer: true,
                  probing: probing,
                  onProbingChanged: (v) => setState(() => probing = v),
                  drawerBottomPadding: 110,
                ),
              ),
            ),
          ),
        if (game.won && !reviewing) _winOverlay(t),
        if (game.won && reviewing)
          ReviewBar(
              color: gold,
              textColor: Colors.black,
              bottom: 24,
              onTap: () => setState(() => reviewing = false)),
      ]),
    );
  }

  Widget _topBar(AppTheme t) => Row(children: [
        Pressable(
          onTap: _close,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
            child: Icon(CupertinoIcons.xmark, size: 15, color: t.textSecondary),
          ),
        ),
        Expanded(
          child: Column(children: [
            Text('💎 보물찾기',
                style: TextStyle(color: t.text, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 1),
            Text('혼자 연습',
                style: TextStyle(
                    color: t.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
        SizedBox(
          width: 56,
          child: Text(timeLabel(game.elapsed),
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier')),
        ),
      ]);

  Widget _bottomBar(AppTheme t) {
    Widget stat(String icon, String label, String value) => Row(children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    color: t.textTertiary, fontSize: 9, fontWeight: FontWeight.w600)),
          ]),
        ]);
    Widget btn(IconData icon, bool on, VoidCallback onTap) => Pressable(
          onTap: () {
            Haptics.tap();
            onTap();
          },
          child: Container(
            width: 46,
            height: 40,
            decoration: BoxDecoration(
                color: on ? AppTheme.flagRed : t.fill,
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 17, color: on ? Colors.white : t.textSecondary),
          ),
        );
    return Row(children: [
      stat('💥', '지뢰 밟음', '${game.minesHit}'),
      const SizedBox(width: 10),
      stat('🚩', '깃발', '${game.flagCount}'),
      const Spacer(),
      btn(CupertinoIcons.flag_fill, flagMode, () => setState(() => flagMode = !flagMode)),
      const SizedBox(width: 10),
      btn(CupertinoIcons.arrow_clockwise, false, game.newGame),
    ]);
  }

  Widget _winOverlay(AppTheme t) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration:
              BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🏆', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 14),
            const Text('보물 발견!',
                style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Text('${timeLabel(game.elapsed)} · 지뢰 ${game.minesHit}번 밟음',
                style: const TextStyle(
                    color: Color.fromRGBO(179, 179, 179, 1),
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            SizedBox(
              width: 230,
              child: OutlineButton(
                  label: '보드 보기',
                  icon: CupertinoIcons.map_fill,
                  color: gold,
                  height: 44,
                  onTap: () {
                    Haptics.tap();
                    setState(() => reviewing = true);
                  }),
            ),
            const SizedBox(height: 18),
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 110,
                child: BigButton(
                    label: '다시',
                    color: gold,
                    textColor: Colors.black,
                    height: 48,
                    fontSize: 16,
                    onTap: () {
                      Haptics.tap();
                      game.newGame();
                    }),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: BigButton(
                    label: '닫기',
                    color: const Color.fromRGBO(56, 56, 56, 1),
                    height: 48,
                    fontSize: 16,
                    onTap: _close),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
