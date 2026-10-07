import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Title;

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'daily.dart';
import 'title.dart';

enum _Tab { challenges, titles }

/// 업적 시트 — Swift AchievementsView 이식. 도전과제(오늘의 도전과제 + 장기 업적) / 칭호(착용·구매).
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final store = LocalStore.shared;
  _Tab tab = _Tab.challenges;
  final _toast = GlobalKey<ToastHostState>();

  static const goldAccent = Color.fromRGBO(245, 194, 61, 1); // (0.96,0.76,0.24)

  @override
  void initState() {
    super.initState();
    // 진입 시 최신 평가(누락분 해금, 배너 없이) + 자정 넘겼으면 일일 갱신.
    store.refreshAchievements(announce: false);
    store.refreshDailyRewards();
  }

  void _showToast(String m) => _toast.currentState?.show(m);

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '업적',
      child: ToastHost(
        key: _toast,
        child: ListenableBuilder(
          listenable: store,
          builder: (_, _) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Column(children: [
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<_Tab>(
                  groupValue: tab,
                  children: {
                    for (final (v, l) in const [(_Tab.challenges, '도전과제'), (_Tab.titles, '칭호')])
                      v: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(l,
                            style: TextStyle(
                                color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                  },
                  onValueChanged: (v) => setState(() => tab = v ?? tab),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: tab == _Tab.challenges ? _challenges(t) : _titles(t),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _coinLabel(AppTheme t) => Row(mainAxisSize: MainAxisSize.min, children: [
        const GoldenMineIcon(size: 13),
        const SizedBox(width: 4),
        Text(fmt(store.coins),
            style: TextStyle(color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
      ]);

  Widget _header(AppTheme t, String s, {Widget? trailing}) => Row(children: [
        Text(s,
            style: TextStyle(color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        ?trailing,
      ]);

  BoxDecoration _rowBox(AppTheme t) => BoxDecoration(
      color: t.fill.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14));

  Widget _iconCircle(IconData icon, Color tint, Color iconColor, {double size = 44}) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tint.withValues(alpha: 0.16), shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.42, color: iconColor),
      );

  Widget _bar(AppTheme t, double f, Color color) => LayoutBuilder(
        builder: (_, b) => Stack(children: [
          Container(
              height: 6,
              decoration:
                  BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(100))),
          Container(
              height: 6,
              width: f.clamp(0.0, 1.0) * b.maxWidth,
              decoration:
                  BoxDecoration(color: color, borderRadius: BorderRadius.circular(100))),
        ]),
      );

  Widget _rarityTag(TitleRarity r) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: r.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100)),
        child: Text(r.label,
            style: TextStyle(color: r.color, fontSize: 9, fontWeight: FontWeight.bold)),
      );

  // MARK: 도전과제 탭

  Widget _challenges(AppTheme t) => Column(children: [
        _header(t, '오늘의 도전과제', trailing: _coinLabel(t)),
        const SizedBox(height: 10),
        for (final c in store.todaysChallenges()) ...[_dailyRow(t, c), const SizedBox(height: 10)],
        Align(
          alignment: Alignment.centerLeft,
          child: Text('매일 자정에 새로 갱신돼요. 달성하면 코인을 받을 수 있어요.',
              style: TextStyle(color: t.textTertiary, fontSize: 11)),
        ),
        const SizedBox(height: 20),
        _achievementsList(t),
      ]);

  Widget _dailyRow(AppTheme t, DailyChallenge c) {
    final s = store.dailyState(c.kind);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _rowBox(t),
      child: Row(children: [
        _iconCircle(c.icon, s.done ? goldAccent : Colors.grey,
            s.done ? goldAccent : t.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            if (s.claimed)
              Row(children: [
                Icon(CupertinoIcons.checkmark_seal_fill, size: 12, color: t.textTertiary),
                const SizedBox(width: 4),
                Text('보상을 받았어요',
                    style: TextStyle(
                        color: t.textTertiary, fontSize: 12, fontWeight: FontWeight.w600)),
              ])
            else ...[
              _bar(t, s.target > 0 ? s.current / s.target : 0, goldAccent),
              const SizedBox(height: 5),
              Text('${s.current} / ${s.target}',
                  style: TextStyle(
                      color: t.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        if (s.claimed)
          Icon(CupertinoIcons.checkmark_circle_fill,
              size: 22, color: goldAccent.withValues(alpha: 0.55))
        else if (s.done)
          Pressable(
            onTap: () {
              final r = store.claimDaily(c.kind);
              if (r == null) return;
              Haptics.success();
              _showToast('일일 보상 +$r 코인을 받았어요!');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                  color: goldAccent, borderRadius: BorderRadius.circular(100)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const GoldenMineIcon(size: 13),
                const SizedBox(width: 3),
                Text('받기 +${c.reward}',
                    style: const TextStyle(
                        color: Color.fromRGBO(64, 41, 0, 1),
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          )
        else
          Row(mainAxisSize: MainAxisSize.min, children: [
            const GoldenMineIcon(size: 12),
            const SizedBox(width: 3),
            Text('+${c.reward}',
                style: TextStyle(
                    color: t.textTertiary, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
      ]),
    );
  }

  Widget _achievementsList(AppTheme t) {
    final all = Title.achievements;
    final done = all.where((x) => store.owns(x.id)).length;
    return Column(children: [
      _header(t, '업적 · 달성 $done / 전체 ${all.length}'),
      const SizedBox(height: 10),
      for (final x in all) ...[_achievementRow(t, x), const SizedBox(height: 10)],
    ]);
  }

  Widget _achievementRow(AppTheme t, Title x) {
    final done = store.owns(x.id);
    final masked = x.hidden && !done;
    final accent = done ? x.rarity.color : t.textSecondary;
    final goal = x.goal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _rowBox(t),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _iconCircle(
            masked
                ? CupertinoIcons.question
                : (done ? CupertinoIcons.checkmark : CupertinoIcons.rosette),
            done ? x.rarity.color : Colors.grey,
            accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(masked ? '???' : x.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              if (!masked) ...[const SizedBox(width: 6), _rarityTag(x.rarity)],
              const Spacer(),
              if (done)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(CupertinoIcons.checkmark_seal_fill, size: 11, color: x.rarity.color),
                  const SizedBox(width: 3),
                  Text('획득',
                      style: TextStyle(
                          color: x.rarity.color, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
            ]),
            const SizedBox(height: 4),
            Text(masked ? '히든 업적 · 숨겨진 조건을 달성하면 공개돼요' : x.hint,
                maxLines: 2,
                style: TextStyle(color: t.textSecondary, fontSize: 12)),
            if (!done && !masked && goal != null) ...[
              const SizedBox(height: 4),
              () {
                final p = store.goalProgress(goal);
                return _bar(t, p.target > 0 ? p.current / p.target : 0, x.rarity.color);
              }(),
              const SizedBox(height: 4),
              Text(store.goalDisplay(goal),
                  style: TextStyle(
                      color: t.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
      ]),
    );
  }

  // MARK: 칭호 탭

  Widget _titles(AppTheme t) => Column(children: [
        _header(t, '내 칭호', trailing: _coinLabel(t)),
        const SizedBox(height: 12),
        _previewCard(t),
        const SizedBox(height: 12),
        for (final x in Title.all) ...[_titleRow(t, x), const SizedBox(height: 12)],
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
              '도전과제를 깨거나 코인으로 칭호를 얻고, 탭하면 착용돼요. 착용한 칭호는 대전·랭킹에서 이름 밑에 보여요.',
              style: TextStyle(color: t.textTertiary, fontSize: 11)),
        ),
      ]);

  Widget _previewCard(AppTheme t) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text('이렇게 보여요',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(store.nickname,
              style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (store.equippedTitleName.isEmpty)
            Text('칭호 미착용', style: TextStyle(color: t.textTertiary, fontSize: 12))
          else ...[
            TitleBadge(name: store.equippedTitleName, size: 11),
            const SizedBox(height: 8),
            TextLink('칭호 떼기',
                fontSize: 12,
                weight: FontWeight.w600,
                onTap: () {
                  store.equip(null);
                  Haptics.tap();
                }),
          ],
        ]),
      );

  String _sourceText(Title x) => switch (x.source.kind) {
        TitleSourceKind.starter => '${x.rarity.label} · 기본 제공',
        TitleSourceKind.achievement => '${x.rarity.label} · 도전과제 보상 — ${x.hint}',
        TitleSourceKind.purchase => '${x.rarity.label} · 코인 구매',
      };

  Widget _titleRow(AppTheme t, Title x) {
    final state = store.titleState(x);
    final owned = state is TitleEquipped || state is TitleOwned;
    final masked = x.hidden && !owned;
    final equipped = state is TitleEquipped;
    Widget trailing = switch (state) {
      TitleEquipped() => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(CupertinoIcons.checkmark_circle_fill, size: 13, color: t.text),
          const SizedBox(width: 3),
          Text('착용 중',
              style: TextStyle(color: t.text, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      TitleOwned() => Text('착용',
          style: TextStyle(color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      TitlePurchasable(:final cost, :final affordable) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          const GoldenMineIcon(size: 12),
          const SizedBox(width: 3),
          Text(fmt(cost),
              style: TextStyle(
                  color: affordable ? t.text : t.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ]),
      TitleLocked() => Icon(CupertinoIcons.lock_fill, size: 12, color: t.textTertiary),
    };
    return Pressable(
      onTap: () => _tapTitle(x),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: equipped ? x.rarity.color.withValues(alpha: 0.14) : t.fill.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: equipped ? x.rarity.color.withValues(alpha: 0.6) : Colors.transparent,
              width: 1.2),
        ),
        child: Row(children: [
          _iconCircle(
              masked
                  ? CupertinoIcons.question
                  : (owned ? CupertinoIcons.rosette : CupertinoIcons.lock_fill),
              owned ? x.rarity.color : Colors.grey,
              owned ? x.rarity.color : t.textSecondary,
              size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(masked ? '???' : x.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                if (!masked) ...[const SizedBox(width: 6), _rarityTag(x.rarity)],
              ]),
              const SizedBox(height: 3),
              Text(masked ? '히든 칭호' : _sourceText(x),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.textTertiary, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          trailing,
        ]),
      ),
    );
  }

  void _tapTitle(Title x) {
    switch (store.titleState(x)) {
      case TitleEquipped():
        store.equip(null); // 한 번 더 누르면 떼기
        Haptics.tap();
      case TitleOwned():
        store.equip(x.id);
        Haptics.tap();
      case TitlePurchasable():
        _confirmBuy(x);
      case TitleLocked():
        Haptics.warning();
        _showToast(x.hidden ? '히든 칭호예요 · 숨겨진 조건을 달성하면 열려요' : '도전과제를 달성하면 열려요');
    }
  }

  void _confirmBuy(Title x) {
    final cost = x.purchaseCost ?? 0;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('칭호 구매'),
        message: Text(
            '‘${x.name}’ 칭호를 ${fmt(cost)}코인에 구매합니다.\n지금 ${fmt(store.coins)}코인 보유 중이에요.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (store.coins < cost) {
                Haptics.error();
                _showToast('코인이 부족해요 · 상점에서 충전할 수 있어요');
                return;
              }
              if (store.purchaseTitle(x.id)) {
                Haptics.success();
                _showToast('‘${x.name}’ 칭호를 착용했어요!');
              }
            },
            child: Text('${fmt(cost)}코인에 구매'),
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
