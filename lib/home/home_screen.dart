import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/theme.dart';
import '../game/game_screen.dart';
import '../multiplayer/versus_menu_screen.dart';

/// 홈 화면 — Swift StartView 이식(핵심). 타이틀 + 솔로/멀티 모드 카드.
/// (샵/랭킹/우편/설정 등은 후속 단계)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _titleBlock(t),
                  const SizedBox(height: 40),
                  _modeCard(
                    t,
                    emoji: '🎯',
                    title: '솔로 플레이',
                    subtitle: '초급 · 중급 · 고급 난이도 도전',
                    color: AppTheme.soloAccent,
                    onTap: () => _pickSolo(context),
                  ),
                  const SizedBox(height: 12),
                  _modeCard(
                    t,
                    emoji: '🏁',
                    title: '멀티 플레이',
                    subtitle: '지뢰찾기 온라인 대전',
                    color: AppTheme.multiAccent,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const VersusMenuScreen())),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleBlock(AppTheme t) {
    return Column(
      children: [
        const Text('💣', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 8),
        Text('지뢰 찾기',
            style: TextStyle(
                color: t.text, fontSize: 34, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('실시간 대전 · 랭킹 지뢰찾기',
            style: TextStyle(color: t.textSecondary, fontSize: 14)),
      ],
    );
  }

  void _pickSolo(BuildContext context) {
    final t = AppTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('솔로 플레이',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              for (final d in Difficulty.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: t.fill,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                GameScreen(initialDifficulty: d)));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(d.label,
                                style: TextStyle(
                                    color: t.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Text('${d.rows}×${d.cols} · 지뢰 ${d.mineCount}',
                                style: TextStyle(
                                    color: t.textTertiary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeCard(
    AppTheme t, {
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: t.fill,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.textTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
