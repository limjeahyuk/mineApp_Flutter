import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme.dart';

/// 환경설정 화면 — 화면 테마(시스템/라이트/다크) + 게임 햅틱 on/off.
/// Swift StartView.SettingsView 이식.
///
/// ponytail: 색상 테마(스킨) 갤러리는 미이식(클래식 무채색만 있음) — 스킨 이식 시 추가.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _accent = Color(0xFF408CF2); // (0.25,0.55,0.95)

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(t),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  _themeSection(t),
                  const SizedBox(height: 24),
                  _hapticsSection(t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppTheme t) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
        child: Row(
          children: [
            Material(
              color: t.fill,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.close, color: t.textSecondary, size: 20)),
              ),
            ),
            Expanded(
              child: Text('⚙️ 환경설정',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.text, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 40),
          ],
        ),
      );

  Widget _sectionLabel(AppTheme t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(s,
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  Widget _themeSection(AppTheme t) {
    final mode = themeModeNotifier.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(t, '화면 테마'),
        Row(
          children: [
            _themeCard(t, ThemeMode.system, Icons.brightness_auto, '시스템', mode),
            const SizedBox(width: 8),
            _themeCard(t, ThemeMode.light, Icons.light_mode, '라이트', mode),
            const SizedBox(width: 8),
            _themeCard(t, ThemeMode.dark, Icons.dark_mode, '다크', mode),
          ],
        ),
        const SizedBox(height: 8),
        Text('시스템은 기기 설정을 따르고, 라이트·다크는 그 모드로 고정돼요',
            style: TextStyle(color: t.textTertiary, fontSize: 11)),
      ],
    );
  }

  Widget _themeCard(
      AppTheme t, ThemeMode mode, IconData icon, String label, ThemeMode cur) {
    final selected = mode == cur;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Haptics.tap();
          setThemeMode(mode);
          setState(() {});
        },
        child: Container(
          height: 66,
          decoration: BoxDecoration(
              color: selected ? _accent : t.fill,
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : t.textSecondary),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : t.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hapticsSection(AppTheme t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(t, '게임'),
          _toggle(t, '진동(햅틱)', '칸 열기·결과 시 진동', Haptics.isEnabled,
              (v) => setState(() => Haptics.isEnabled = v)),
          const SizedBox(height: 10),
          _toggle(t, '깃발 꽂으면 진동', '깃발을 꽂거나 뺄 때 진동', Haptics.isFlagEnabled,
              (v) => setState(() => Haptics.isFlagEnabled = v)),
        ],
      );

  Widget _toggle(AppTheme t, String title, String subtitle, bool value,
          ValueChanged<bool> onChanged) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
            color: t.fill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: _accent,
              onChanged: (v) {
                Haptics.tap();
                onChanged(v);
              },
            ),
          ],
        ),
      );
}
