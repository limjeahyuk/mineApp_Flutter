import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../ranking/ranking_service.dart';
import 'board_widget.dart';
import 'item_dock.dart';

/// 솔로 게임 화면 — Swift ContentView(솔로) 이식. 원본 팔레트/레이아웃.
/// 상단바(홈·난이도·메뉴) + LED 카운터/스마일/줌/깃발 + 보드 + 하단 힌트.
///
/// ponytail: 레이더·자동깃발 아이템은 인벤토리 미이식이라 이번 화면에선 생략.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.initialDifficulty = Difficulty.beginner});

  final Difficulty initialDifficulty;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameModel game = GameModel();
  final TransformationController _zoom = TransformationController();
  bool flagMode = false;
  bool probing = false; // 자동깃발 발동 대기

  @override
  void initState() {
    super.initState();
    // 인벤토리 배선 — startSolo가 티켓(min(보유, 상한))을 계산하므로 그 전에 연결.
    final inv = LocalStore.shared;
    game.autoFlagSupplier = () => inv.ownedFlags;
    game.onConsumeAutoFlag = inv.consumeFlag;
    game.radarSupplier = () => inv.ownedRadars;
    game.onConsumeRadar = inv.consumeRadar;
    game.onGoldenMineFound = () => inv.addGoldenMines(1);
    // 솔로 클리어 → 로컬 기록 + (신기록이면) 온라인 랭킹 제출 + 무아이템 하드 클리어 집계.
    game.onSoloWin = (d, timeSec, noItem) {
      final isBest = inv.recordSolo(d, timeSec);
      if (noItem) inv.recordNoItemHardClear(d);
      if (isBest) {
        RankingService().submitBest(ScoreEntry(
          name: inv.nickname,
          difficulty: d.label,
          timeSec: timeSec,
          deviceId: inv.deviceId,
          title: inv.equippedTitleName,
        ));
      }
    };
    game.startSolo(widget.initialDifficulty);
  }

  @override
  void dispose() {
    _zoom.dispose();
    game.dispose();
    super.dispose();
  }

  void _newGame() {
    setState(() {
      flagMode = false;
      probing = false;
      _zoom.value = Matrix4.identity();
    });
    game.startSolo(game.difficulty);
  }

  void _onProbe(int r, int c) {
    game.useAutoFlag(r, c);
    setState(() => probing = false);
  }

  void _toggleZoom() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    setState(() => _zoom.value =
        zoomed ? Matrix4.identity() : Matrix4.diagonal3Values(2.0, 2.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (_, _) => Column(
            children: [
              _topBar(t),
              _counterRow(t),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: BoardWidget(
                        game: game,
                        flagMode: flagMode,
                        controller: _zoom,
                        probing: probing,
                        onProbe: _onProbe,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: ItemDock(
                        radarTickets: game.radarTickets,
                        autoFlagTickets: game.autoFlagTickets,
                        isPlaying: game.state == GameState.playing,
                        probing: probing,
                        onRadar: () => setState(() {
                          game.useRadar();
                        }),
                        onToggleProbe: () =>
                            setState(() => probing = !probing),
                      ),
                    ),
                  ],
                ),
              ),
              _hint(t),
            ],
          ),
        ),
      ),
    );
  }

  // ── 상단바: 홈 · 난이도 타이틀 · 메뉴 ──
  Widget _topBar(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _chip(
            t,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chevron_left, color: t.text, size: 20),
              Text('홈',
                  style: TextStyle(
                      color: t.text, fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
            onTap: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(game.difficulty.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.text, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          _menuButton(t),
        ],
      ),
    );
  }

  Widget _menuButton(AppTheme t) {
    return _chip(
      t,
      child: Icon(Icons.more_horiz, color: t.text, size: 22),
      onTap: () async {
        final d = await showModalBottomSheet<Difficulty>(
          context: context,
          backgroundColor: t.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                for (final d in Difficulty.values)
                  ListTile(
                    title: Text(d.label,
                        style: TextStyle(
                            color: t.text, fontWeight: FontWeight.w600)),
                    trailing: Text('${d.rows}×${d.cols} · 지뢰 ${d.mineCount}',
                        style: TextStyle(color: t.textSecondary, fontSize: 14)),
                    onTap: () => Navigator.pop(ctx, d),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (d != null) {
          setState(() {
            flagMode = false;
            probing = false;
            _zoom.value = Matrix4.identity();
          });
          game.startSolo(d);
        }
      },
    );
  }

  Widget _chip(AppTheme t, {required Widget child, required VoidCallback onTap}) {
    return Material(
      color: t.fill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: child,
        ),
      ),
    );
  }

  // ── LED 카운터 · 스마일 · 줌 · 깃발 ──
  Widget _counterRow(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          _led(game.minesRemaining),
          const Spacer(),
          _iconBtn(t, child: Text(_face(), style: const TextStyle(fontSize: 24)),
              onTap: _newGame),
          const SizedBox(width: 8),
          _iconBtn(t,
              child: Icon(Icons.zoom_in, color: t.text, size: 24),
              onTap: _toggleZoom),
          const SizedBox(width: 8),
          _iconBtn(t,
              highlighted: flagMode,
              child: Icon(flagMode ? Icons.flag : Icons.flag_outlined,
                  color: flagMode ? Colors.white : t.text, size: 24),
              onTap: () => setState(() => flagMode = !flagMode)),
          const Spacer(),
          _led(game.elapsed),
        ],
      ),
    );
  }

  String _face() {
    switch (game.state) {
      case GameState.won:
        return '😎';
      case GameState.lost:
        return '😵';
      default:
        return '🙂';
    }
  }

  Widget _led(int value) {
    final v = value.clamp(0, 999).toString().padLeft(3, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(v,
          style: const TextStyle(
            color: Color(0xFFFF2A2A),
            fontSize: 30,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
            letterSpacing: 2,
          )),
    );
  }

  Widget _iconBtn(AppTheme t,
      {required Widget child,
      required VoidCallback onTap,
      bool highlighted = false}) {
    return Material(
      color: highlighted ? AppTheme.soloAccent : t.fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(width: 56, height: 52, child: Center(child: child)),
      ),
    );
  }

  Widget _hint(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text('탭: 칸 열기 · 길게 누르기: 깃발 · 숫자 탭: 주변 일괄 열기',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textTertiary, fontSize: 13)),
    );
  }
}
