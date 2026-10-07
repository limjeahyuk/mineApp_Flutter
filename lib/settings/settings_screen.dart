import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// 환경설정 시트 — Swift StartView.SettingsView 이식.
/// 화면 테마(시스템/라이트/다크) + 색상 테마(스킨) 갤러리 + 공용 햅틱·깃발 진동 on/off.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _accent = AppTheme.soloAccent; // (0.25,0.55,0.95)
  bool _hapticsOn = Haptics.isEnabled;
  bool _flagHapticsOn = Haptics.isFlagEnabled;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '환경설정',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _themeSection(t),
            const SizedBox(height: 20),
            const _ColorThemeGallery(),
            const SizedBox(height: 20),
            _hapticsSection(t),
          ],
        ),
      ),
    );
  }

  Widget _label(AppTheme t, String s) => Text(s,
      style: TextStyle(
          color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.w600));

  /// 화면 테마(시스템/라이트/다크) — 고르면 즉시 반영되고 이후로 고정된다.
  Widget _themeSection(AppTheme t) {
    final current = themeModeNotifier.value;
    const modes = [
      (ThemeMode.system, '시스템', Icons.phone_iphone),
      (ThemeMode.light, '라이트', Icons.wb_sunny),
      (ThemeMode.dark, '다크', Icons.dark_mode),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(t, '화면 테마'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (mode, label, icon) in modes) ...[
              if (mode != ThemeMode.system) const SizedBox(width: 8),
              Expanded(
                child: PlainButton(
                  onTap: () {
                    Haptics.tap();
                    setThemeMode(mode);
                    setState(() {});
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 66),
                    decoration: BoxDecoration(
                        color: current == mode ? _accent : t.fill,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon,
                            size: 20,
                            color: current == mode
                                ? Colors.white
                                : t.textSecondary),
                        const SizedBox(height: 6),
                        Text(label,
                            style: TextStyle(
                                color: current == mode
                                    ? Colors.white
                                    : t.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text('시스템은 기기 설정을 따르고, 라이트·다크는 그 모드로 고정돼요',
            style: TextStyle(color: t.textTertiary, fontSize: 11)),
      ],
    );
  }

  Widget _hapticsSection(AppTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(t, '게임'),
        const SizedBox(height: 8),
        _toggle(t, '진동(햅틱)', '칸 열기·결과 시 진동', _hapticsOn, (v) {
          setState(() => _hapticsOn = v);
          Haptics.isEnabled = v;
        }),
        const SizedBox(height: 8),
        _toggle(t, '깃발 꽂으면 진동', '깃발을 꽂거나 뺄 때 진동', _flagHapticsOn, (v) {
          setState(() => _flagHapticsOn = v);
          Haptics.isFlagEnabled = v;
        }),
      ],
    );
  }

  Widget _toggle(AppTheme t, String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:
          BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(12)),
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
          CupertinoSwitch(
              value: value, activeTrackColor: _accent, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 색상 테마(스킨) 갤러리 — 보유 테마는 탭으로 바로 적용, 미보유는 1000코인에 구매.
class _ColorThemeGallery extends StatefulWidget {
  const _ColorThemeGallery();

  @override
  State<_ColorThemeGallery> createState() => _ColorThemeGalleryState();
}

class _ColorThemeGalleryState extends State<_ColorThemeGallery> {
  final LocalStore _s = LocalStore.shared;
  final _toast = ToastController();

  @override
  void dispose() {
    _toast.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_s, colorThemeNotifier]),
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('색상 테마',
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                const GoldenMineIcon(size: 13),
                const SizedBox(width: 4),
                Text(formatNumber(_s.coins),
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(2),
                child: Row(children: [
                  for (final theme in ColorTheme.all) ...[
                    if (theme != ColorTheme.classic) const SizedBox(width: 12),
                    _card(t, theme),
                  ],
                ]),
              ),
              const SizedBox(height: 10),
              Text('테마를 구매하면 앱 전체 색이 바뀌어요. 보유한 테마는 언제든 바꿀 수 있어요.',
                  style: TextStyle(color: t.textTertiary, fontSize: 11)),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -6,
            child: ToastOverlay(
                controller: _toast, padding: const EdgeInsets.only(bottom: 8)),
          ),
        ],
      ),
    );
  }

  Widget _card(AppTheme t, ColorTheme theme) {
    final owned = _s.ownsTheme(theme.id);
    final selected = ColorTheme.active.id == theme.id;
    return PlainButton(
      onTap: () => _tap(theme),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected
                  ? theme.accent
                  : t.border.withValues(alpha: 0.4),
              width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            _preview(t, theme, owned),
            const SizedBox(height: 8),
            Text(theme.name,
                style: TextStyle(
                    color: t.text, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (selected)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, size: 12, color: theme.accent),
                const SizedBox(width: 3),
                Text('사용 중',
                    style: TextStyle(
                        color: theme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ])
            else if (owned)
              Text('적용하기',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600))
            else
              Row(mainAxisSize: MainAxisSize.min, children: [
                const GoldenMineIcon(size: 11),
                const SizedBox(width: 3),
                Text(formatNumber(LocalStore.themeCost),
                    style: TextStyle(
                        color: t.text,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
          ],
        ),
      ),
    );
  }

  /// 테마 고유색으로 만든 미니 보드 미리보기. 미보유면 자물쇠를 덮는다.
  Widget _preview(AppTheme t, ColorTheme theme, bool owned) {
    Widget sq() => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
              color: theme.tintedSurface(t.dark ? 0.30 : 0.30, t.dark),
              borderRadius: BorderRadius.circular(4)),
        );
    return SizedBox(
      width: 72,
      height: 56,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
                color: theme.tintedSurface(0.13, t.dark),
                borderRadius: BorderRadius.circular(12)),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: theme.accent, shape: BoxShape.circle)),
          ),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min,
                  children: [sq(), const SizedBox(width: 4), sq()]),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min,
                  children: [sq(), const SizedBox(width: 4), sq()]),
            ]),
          ),
          if (!owned) ...[
            Container(
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(12)),
            ),
            Center(
                child: Icon(Icons.lock,
                    size: 20, color: Colors.white.withValues(alpha: 0.95))),
          ],
        ],
      ),
    );
  }

  Future<void> _tap(ColorTheme theme) async {
    Haptics.tap();
    if (_s.ownsTheme(theme.id)) {
      selectColorTheme(theme.id);
      return;
    }
    final ok = await showConfirmSheet(context,
        title: '테마 구매',
        message:
            '‘${theme.name}’ 테마를 ${formatNumber(LocalStore.themeCost)}코인에 구매합니다.\n지금 ${formatNumber(_s.coins)}코인 보유 중이에요.',
        confirmLabel: '${formatNumber(LocalStore.themeCost)}코인에 구매');
    if (!ok) return;
    if (_s.coins < LocalStore.themeCost) {
      Haptics.error();
      _toast.show('코인이 부족해요 · 상점에서 충전할 수 있어요');
      return;
    }
    if (_s.purchaseTheme(theme.id)) {
      Haptics.success();
      selectColorTheme(theme.id);
      _toast.show('‘${theme.name}’ 테마를 적용했어요!');
    }
  }
}
