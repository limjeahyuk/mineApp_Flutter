import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// 환경설정 시트 — Swift SettingsView 이식. 화면 테마 · 색상 테마(스킨) 갤러리 · 햅틱.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool hapticsOn = Haptics.isEnabled;
  bool flagHapticsOn = Haptics.isFlagEnabled;
  final _toast = GlobalKey<ToastHostState>();

  static const accent = AppTheme.soloAccent;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '환경설정',
      child: ToastHost(
        key: _toast,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _themeSection(t),
            const SizedBox(height: 20),
            _ColorThemeGallery(onToast: (m) => _toast.currentState?.show(m)),
            const SizedBox(height: 20),
            _hapticsSection(t),
          ]),
        ),
      ),
    );
  }

  Widget _label(AppTheme t, String s) => Text(s,
      style: TextStyle(color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.w600));

  Widget _themeSection(AppTheme t) {
    final current = themeModeNotifier.value;
    final modes = [
      (ThemeMode.system, '시스템', CupertinoIcons.device_phone_portrait),
      (ThemeMode.light, '라이트', CupertinoIcons.sun_max_fill),
      (ThemeMode.dark, '다크', CupertinoIcons.moon_fill),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(t, '화면 테마'),
      const SizedBox(height: 8),
      Row(children: [
        for (final (m, label, icon) in modes) ...[
          if (m != ThemeMode.system) const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              haptic: true,
              onTap: () => setState(() => setThemeMode(m)),
              child: Container(
                constraints: const BoxConstraints(minHeight: 66),
                decoration: BoxDecoration(
                    color: current == m ? accent : t.fill,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 19, color: current == m ? Colors.white : t.textSecondary),
                  const SizedBox(height: 6),
                  Text(label,
                      style: TextStyle(
                          color: current == m ? Colors.white : t.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 8),
      Text('시스템은 기기 설정을 따르고, 라이트·다크는 그 모드로 고정돼요',
          style: TextStyle(color: t.textTertiary, fontSize: 11)),
    ]);
  }

  Widget _hapticsSection(AppTheme t) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(t, '게임'),
        const SizedBox(height: 8),
        _toggle(t, '진동(햅틱)', '칸 열기·결과 시 진동', hapticsOn, (v) {
          setState(() => hapticsOn = v);
          Haptics.isEnabled = v;
        }),
        const SizedBox(height: 8),
        _toggle(t, '깃발 꽂으면 진동', '깃발을 꽂거나 뺄 때 진동', flagHapticsOn, (v) {
          setState(() => flagHapticsOn = v);
          Haptics.isFlagEnabled = v;
        }),
      ]);

  Widget _toggle(AppTheme t, String title, String sub, bool on, ValueChanged<bool> onChanged) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
          ),
          CupertinoSwitch(value: on, activeTrackColor: accent, onChanged: onChanged),
        ]),
      );
}

/// 색상 테마(스킨) 갤러리 — 보유 테마는 탭으로 적용, 미보유는 1000코인에 구매(Swift ColorThemeGallery).
class _ColorThemeGallery extends StatelessWidget {
  const _ColorThemeGallery({required this.onToast});
  final void Function(String) onToast;

  @override
  Widget build(BuildContext context) {
    final store = LocalStore.shared;
    return ListenableBuilder(
      listenable: Listenable.merge([store, colorThemeNotifier]),
      builder: (context, _) {
        final t = AppTheme.of(context);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('색상 테마',
                style: TextStyle(
                    color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            const GoldenMineIcon(size: 13),
            const SizedBox(width: 4),
            Text(fmt(store.coins),
                style: TextStyle(
                    color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(2),
            child: Row(children: [
              for (final th in ColorTheme.all) ...[
                if (th != ColorTheme.classic) const SizedBox(width: 12),
                _card(context, t, store, th),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          Text('테마를 구매하면 앱 전체 색이 바뀌어요. 보유한 테마는 언제든 바꿀 수 있어요.',
              style: TextStyle(color: t.textTertiary, fontSize: 11)),
        ]);
      },
    );
  }

  Widget _card(BuildContext context, AppTheme t, LocalStore store, ColorTheme th) {
    final owned = store.ownsTheme(th.id);
    final selected = colorThemeNotifier.value.id == th.id;
    return Pressable(
      onTap: () {
        Haptics.tap();
        if (owned) {
          selectColorTheme(th.id);
        } else {
          _confirmBuy(context, store, th);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
          _preview(t, th, owned),
          const SizedBox(height: 8),
          Text(th.name,
              style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (selected)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(CupertinoIcons.checkmark_circle_fill, size: 11, color: th.accent),
              const SizedBox(width: 3),
              Text('사용 중',
                  style: TextStyle(color: th.accent, fontSize: 11, fontWeight: FontWeight.bold)),
            ])
          else if (owned)
            Text('적용하기',
                style: TextStyle(
                    color: t.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              const GoldenMineIcon(size: 11),
              const SizedBox(width: 3),
              Text(fmt(LocalStore.themeCost),
                  style: TextStyle(color: t.text, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
        ]),
      ),
    );
  }

  Widget _preview(AppTheme t, ColorTheme th, bool owned) {
    Color sw(double w) => th.tintedSurface(w, t.dark);
    return SizedBox(
      width: 72,
      height: 56,
      child: Stack(children: [
        Container(
            decoration:
                BoxDecoration(color: sw(0.13), borderRadius: BorderRadius.circular(12))),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var j = 0; j < 2; j++) ...[
                  if (j > 0) const SizedBox(width: 4),
                  Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                          color: sw(0.30), borderRadius: BorderRadius.circular(4))),
                ],
              ]),
            ],
          ]),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: th.accent, shape: BoxShape.circle)),
        ),
        if (!owned) ...[
          Container(
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(12))),
          Center(
              child: Icon(CupertinoIcons.lock_fill,
                  size: 19, color: Colors.white.withValues(alpha: 0.95))),
        ],
      ]),
    );
  }

  void _confirmBuy(BuildContext context, LocalStore store, ColorTheme th) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('테마 구매'),
        message: Text(
            '‘${th.name}’ 테마를 ${fmt(LocalStore.themeCost)}코인에 구매합니다.\n지금 ${fmt(store.coins)}코인 보유 중이에요.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (store.coins < LocalStore.themeCost) {
                Haptics.error();
                onToast('코인이 부족해요 · 상점에서 충전할 수 있어요');
                return;
              }
              if (store.purchaseTheme(th.id)) {
                Haptics.success();
                selectColorTheme(th.id);
                onToast('‘${th.name}’ 테마를 적용했어요!');
              }
            },
            child: Text('${fmt(LocalStore.themeCost)}코인에 구매'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('취소'),
        ),
      ),
    );
  }
}
