import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/theme.dart';
import '../core/types.dart';
import 'board_widget.dart';

/// 솔로 게임 화면 — Swift ContentView(솔로) 이식. 원본 팔레트 사용.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.initialDifficulty = Difficulty.beginner});

  final Difficulty initialDifficulty;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameModel game = GameModel();
  bool flagMode = false;

  @override
  void initState() {
    super.initState();
    game.startSolo(widget.initialDifficulty);
  }

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  String _fmtTime(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('지뢰찾기'),
        backgroundColor: t.surface,
        foregroundColor: t.text,
        actions: [
          ListenableBuilder(
            listenable: game,
            builder: (_, _) => DropdownButtonHideUnderline(
              child: DropdownButton<Difficulty>(
                value: game.difficulty,
                dropdownColor: t.surface,
                iconEnabledColor: t.text,
                style: TextStyle(color: t.text, fontSize: 15),
                items: [
                  for (final d in Difficulty.values)
                    DropdownMenuItem(value: d, child: Text(d.label)),
                ],
                onChanged: (d) {
                  if (d != null) game.startSolo(d);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _statusBar(t),
            Expanded(
              child: ListenableBuilder(
                listenable: game,
                builder: (_, _) => BoardWidget(game: game, flagMode: flagMode),
              ),
            ),
            _controls(t),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(AppTheme t) {
    return ListenableBuilder(
      listenable: game,
      builder: (_, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _pill(t, '🚩 ${game.minesRemaining}'),
            _stateLabel(),
            _pill(t, '⏱ ${_fmtTime(game.elapsed)}'),
          ],
        ),
      ),
    );
  }

  Widget _stateLabel() {
    switch (game.state) {
      case GameState.won:
        return const Text('클리어! 🎉',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A801F)));
      case GameState.lost:
        return const Text('실패 💥',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCC0D0D)));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _pill(AppTheme t, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: t.text, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _controls(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: _button(
              t,
              icon: flagMode ? Icons.flag : Icons.flag_outlined,
              label: flagMode ? '깃발 모드 ON' : '깃발 모드',
              highlighted: flagMode,
              onTap: () => setState(() => flagMode = !flagMode),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _button(
              t,
              icon: Icons.refresh,
              label: '새 판',
              onTap: () => game.startSolo(game.difficulty),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(
    AppTheme t, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Material(
      color: highlighted ? AppTheme.soloAccent : t.fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: highlighted ? Colors.white : t.text, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: highlighted ? Colors.white : t.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
