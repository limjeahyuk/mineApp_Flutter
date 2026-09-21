import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/theme.dart';
import 'multiplayer.dart';
import 'versus_screen.dart';

/// 대전 메뉴 — 규칙(스피드/지뢰대결) + 난이도 선택 후 빠른대전/방만들기/코드참가.
/// Swift MultiplayerMenuView의 핵심 이식(봇대전 제외).
class VersusMenuScreen extends StatefulWidget {
  const VersusMenuScreen({super.key});

  @override
  State<VersusMenuScreen> createState() => _VersusMenuScreenState();
}

class _VersusMenuScreenState extends State<VersusMenuScreen> {
  RaceRule rule = RaceRule.speed;
  Difficulty difficulty = Difficulty.beginner;

  void _launch(RaceMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VersusScreen(mode: mode)),
    );
  }

  Future<void> _joinByCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('코드로 참가'),
          content: TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: '방 코드 6자리'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text),
                child: const Text('참가')),
          ],
        );
      },
    );
    if (code != null && code.trim().isNotEmpty) {
      _launch(RaceMode.join(code.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('멀티 플레이'),
        backgroundColor: t.surface,
        foregroundColor: t.text,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionTitle(t, '규칙'),
            const SizedBox(height: 10),
            Row(
              children: [
                _ruleCard(t, RaceRule.speed, '스피드', '먼저 다 클리어하면 승'),
                const SizedBox(width: 12),
                _ruleCard(t, RaceRule.score, '지뢰 대결', '보드 끝났을 때 더 많이 찾으면 승'),
              ],
            ),
            const SizedBox(height: 24),
            _sectionTitle(t, '난이도'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final d in Difficulty.values) _diffChip(t, d),
              ],
            ),
            const SizedBox(height: 32),
            _bigButton(t, '⚡ 빠른 대전', AppTheme.multiAccent,
                () => _launch(RaceMode.quick(difficulty, rule))),
            const SizedBox(height: 12),
            _bigButton(t, '🚪 방 만들기', AppTheme.soloAccent,
                () => _launch(RaceMode.host(difficulty, rule))),
            const SizedBox(height: 12),
            _bigButton(t, '🔑 코드로 참가', t.fillElevated, _joinByCode,
                dark: true),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(AppTheme t, String s) => Text(s,
      style: TextStyle(
          color: t.textSecondary, fontSize: 14, fontWeight: FontWeight.w600));

  Widget _ruleCard(AppTheme t, RaceRule r, String title, String sub) {
    final selected = rule == r;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => rule = r),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppTheme.multiAccent : t.border,
                width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(color: t.textTertiary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _diffChip(AppTheme t, Difficulty d) {
    final selected = difficulty == d;
    return GestureDetector(
      onTap: () => setState(() => difficulty = d),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.soloAccent : t.fill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(d.label,
            style: TextStyle(
                color: selected ? Colors.white : t.text,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _bigButton(AppTheme t, String label, Color color, VoidCallback onTap,
      {bool dark = false}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: dark ? t.text : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
