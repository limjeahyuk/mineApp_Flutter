import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// 환경설정 — Swift StartView.SettingsView 이식.
/// 화면 테마(시스템/라이트/다크) + 색상 테마 갤러리(스킨 구매·적용) + 게임 햅틱.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with ToastMixin {
  static const accent = Color.fromRGBO(64, 140, 242, 1); // (0.25,0.55,0.95)
  bool hapticsOn = Haptics.isEnabled;
  bool flagHapticsOn = Haptics.isFlagEnabled;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '환경설정',
      child: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _themeSection(t),
            const SizedBox(height: 20),
            _gallery(t),
            const SizedBox(height: 20),
            _haptics(t),
          ]),
        ),
        toastOverlay(bottom: 8),
      ]),
    );
  }

  Widget _themeSection(AppTheme t) {
    final mode = themeModeNotifier.value;
    const items = [
      (ThemeMode.system, '시스템', SF.iphone),
      (ThemeMode.light, '라이트', SF.sunFill),
      (ThemeMode.dark, '다크', SF.moonFill),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('화면 테마', style: sf(13, weight: W.semibold, color: t.textSecondary)),
      const SizedBox(height: 8),
      Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Tap(
              onTap: () {
                Haptics.tap();
                setThemeMode(items[i].$1);
                setState(() {});
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 66),
                decoration: rr(12, mode == items[i].$1 ? accent : t.fill),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(items[i].$3,
                      size: 18, color: mode == items[i].$1 ? Colors.white : t.textSecondary),
                  const SizedBox(height: 6),
                  Text(items[i].$2,
                      style: sf(13,
                          weight: W.bold,
                          color: mode == items[i].$1 ? Colors.white : t.textSecondary)),
                ]),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 8),
      Text('시스템은 기기 설정을 따르고, 라이트·다크는 그 모드로 고정돼요',
          style: sf(11, color: t.textTertiary)),
    ]);
  }

  // ── 색상 테마 갤러리 ──
  Widget _gallery(AppTheme t) {
    final s = LocalStore.shared;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('색상 테마', style: sf(13, weight: W.semibold, color: t.textSecondary)),
        const Spacer(),
        const GoldenMineIcon(size: 13),
        const SizedBox(width: 4),
        Text(fmt(s.coins), style: sf(13, weight: W.bold, color: t.textSecondary)),
      ]),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(2),
        child: Row(children: [
          for (var i = 0; i < ColorThemeDef.all.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            _card(t, ColorThemeDef.all[i]),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Text('테마를 구매하면 앱 전체 색이 바뀌어요. 보유한 테마는 언제든 바꿀 수 있어요.',
          style: sf(11, color: t.textTertiary)),
    ]);
  }

  Widget _card(AppTheme t, ColorThemeDef th) {
    final s = LocalStore.shared;
    final owned = s.ownsTheme(th.id);
    final selected = colorThemeNotifier.value == th.id;
    Widget status;
    if (selected) {
      status = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(SF.checkCircleFill, size: 11, color: th.accent),
        const SizedBox(width: 3),
        Text('사용 중', style: sf(11, weight: W.bold, color: th.accent)),
      ]);
    } else if (owned) {
      status = Text('적용하기', style: sf(11, weight: W.semibold, color: t.textSecondary));
    } else {
      status = Row(mainAxisSize: MainAxisSize.min, children: [
        const GoldenMineIcon(size: 11),
        const SizedBox(width: 3),
        Text(fmt(LocalStore.themeCost), style: sf(11, weight: W.bold, color: t.text)),
      ]);
    }
    return Tap(
      onTap: () => _tap(th),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? th.accent : t.border.withValues(alpha: 0.4),
              width: selected ? 2 : 1),
        ),
        child: Column(children: [
          _preview(th, owned, t.dark),
          const SizedBox(height: 8),
          Text(th.name, style: sf(13, weight: W.bold, color: t.text)),
          const SizedBox(height: 8),
          status,
        ]),
      ),
    );
  }

  Widget _preview(ColorThemeDef th, bool owned, bool dark) {
    return SizedBox(
      width: 72,
      height: 56,
      child: Stack(alignment: Alignment.center, children: [
        Container(decoration: rr(12, th.tintedSurface(dark ? 0.13 : 0.88, dark))),
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: th.accent, shape: BoxShape.circle)),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          for (var r = 0; r < 2; r++) ...[
            if (r > 0) const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var c = 0; c < 2; c++) ...[
                if (c > 0) const SizedBox(width: 4),
                Container(
                    width: 16,
                    height: 16,
                    decoration: rr(4, th.tintedSurface(dark ? 0.30 : 0.70, dark))),
              ],
            ]),
          ],
        ]),
        if (!owned) ...[
          Container(decoration: rr(12, Colors.black.withValues(alpha: 0.30))),
          Icon(SF.lockFill, size: 18, color: Colors.white.withValues(alpha: 0.95)),
        ],
      ]),
    );
  }

  Future<void> _tap(ColorThemeDef th) async {
    Haptics.tap();
    final s = LocalStore.shared;
    if (s.ownsTheme(th.id)) {
      setColorTheme(th.id);
      return;
    }
    final ok = await showCupertinoConfirm(context,
        title: '테마 구매',
        message:
            '‘${th.name}’ 테마를 ${fmt(LocalStore.themeCost)}코인에 구매합니다.\n지금 ${fmt(s.coins)}코인 보유 중이에요.',
        confirm: '${fmt(LocalStore.themeCost)}코인에 구매');
    if (ok != true || !mounted) return;
    if (s.coins < LocalStore.themeCost) {
      Haptics.error();
      showToast('코인이 부족해요 · 상점에서 충전할 수 있어요');
      return;
    }
    if (s.purchaseTheme(th.id)) {
      Haptics.success();
      setColorTheme(th.id);
    }
  }

  // ── 햅틱 ──
  Widget _haptics(AppTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('게임', style: sf(13, weight: W.semibold, color: t.textSecondary)),
      const SizedBox(height: 8),
      _toggle(t, '진동(햅틱)', '칸 열기·결과 시 진동', hapticsOn, (v) {
        Haptics.isEnabled = v;
        setState(() => hapticsOn = v);
      }),
      const SizedBox(height: 8),
      _toggle(t, '깃발 꽂으면 진동', '깃발을 꽂거나 뺄 때 진동', flagHapticsOn, (v) {
        Haptics.isFlagEnabled = v;
        setState(() => flagHapticsOn = v);
      }),
    ]);
  }

  Widget _toggle(AppTheme t, String title, String sub, bool on, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: rr(12, t.fill),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: sf(16, weight: W.semibold, color: t.text)),
            const SizedBox(height: 2),
            Text(sub, style: sf(11, weight: W.medium, color: t.textSecondary)),
          ]),
        ),
        CupertinoSwitch(value: on, activeTrackColor: accent, onChanged: onChanged),
      ]),
    );
  }
}
