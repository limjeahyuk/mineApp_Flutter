import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Title;

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'daily.dart';
import 'title.dart';

<<<<<<< HEAD
enum _Tab { challenges, titles }

/// 업적 시트 — Swift AchievementsView 이식. 도전과제(오늘의 도전과제 + 장기 업적) / 칭호(착용·구매).
=======
/// 업적 탭 — 도전과제 진행/달성과 칭호(착용·코인 구매)를 한 화면에서 본다. Swift AchievementsView 이식.
/// 위: 매일 갱신되는 일일 도전과제(코인), 아래: 장기 업적(칭호 해금).
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

enum _Tab { challenges, titles }

class _AchievementsScreenState extends State<AchievementsScreen> {
<<<<<<< HEAD
  final store = LocalStore.shared;
  _Tab tab = _Tab.challenges;
  final _toast = GlobalKey<ToastHostState>();

  static const goldAccent = Color.fromRGBO(245, 194, 61, 1); // (0.96,0.76,0.24)
=======
  final LocalStore _s = LocalStore.shared;
  final _toast = ToastController();
  _Tab _tab = _Tab.challenges;

  /// 일일 도전과제(코인 보상) 강조색 — 황금지뢰 금색.
  static const _goldAccent = Color.fromRGBO(245, 194, 61, 1);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    // 진입 시 최신 평가(누락분 해금, 배너 없이) + 자정 넘겼으면 일일 갱신.
    store.refreshAchievements(announce: false);
    store.refreshDailyRewards();
  }

  void _showToast(String m) => _toast.currentState?.show(m);
=======
    // 진입 시 최신 평가(누락분 해금). 배너는 띄우지 않는다(시트 위라 안 보이므로).
    _s.refreshAchievements(announce: false);
  }

  @override
  void dispose() {
    _toast.dispose();
    super.dispose();
  }
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '업적',
<<<<<<< HEAD
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
=======
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: _s,
            builder: (_, _) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Column(
                children: [
                  SegmentedPicker<_Tab>(
                    value: _tab,
                    items: const {
                      _Tab.challenges: '도전과제',
                      _Tab.titles: '칭호'
                    },
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _tab == _Tab.challenges
                          ? _challengesSection(t)
                          : _titlesSection(t),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ToastOverlay(controller: _toast, padding: const EdgeInsets.only(bottom: 12)),
        ],
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      ),
    );
  }

<<<<<<< HEAD
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
=======
  // MARK: - 도전과제 탭

  Widget _challengesSection(AppTheme t) => Column(
        children: [
          _dailySection(t),
          const SizedBox(height: 20),
          _achievementsList(t),
        ],
      );

  Widget _sectionHeader(AppTheme t, String title, {bool coins = false}) {
    return Row(
      children: [
        Text(title,
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        if (coins) ...[
          const GoldenMineIcon(size: 13),
          const SizedBox(width: 4),
          Text(formatNumber(_s.coins),
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  Widget _dailySection(AppTheme t) {
    final today = DailyChallenge.forDay(LocalStore.todayKey());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(t, '오늘의 도전과제', coins: true),
        for (final c in today) ...[
          const SizedBox(height: 10),
          _dailyRow(t, c),
        ],
        const SizedBox(height: 10),
        Text('매일 자정에 새로 갱신돼요. 달성하면 코인을 받을 수 있어요.',
            style: TextStyle(color: t.textTertiary, fontSize: 11)),
      ],
    );
  }

  Widget _iconCircle(Color color, bool on, IconData icon, Color fg,
      {double size = 44, double iconSize = 18}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: (on ? color : Colors.grey).withValues(alpha: 0.16),
          shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: fg),
    );
  }

  Widget _rowCard(AppTheme t, Widget child,
      {Color? fill, Color? stroke}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fill ?? t.fill.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: stroke == null ? null : Border.all(color: stroke, width: 1.2),
      ),
      child: child,
    );
  }

  Widget _dailyRow(AppTheme t, DailyChallenge c) {
    final s = Daily.state(c.kind);
    return _rowCard(
      t,
      Row(
        children: [
          _iconCircle(_goldAccent, s.done, c.icon,
              s.done ? _goldAccent : t.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                if (s.claimed)
                  Row(children: [
                    Icon(Icons.verified, size: 13, color: t.textTertiary),
                    const SizedBox(width: 4),
                    Text('보상을 받았어요',
                        style: TextStyle(
                            color: t.textTertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ])
                else ...[
                  CapsuleProgress(
                      fraction: s.target > 0 ? s.current / s.target : 0,
                      color: _goldAccent),
                  const SizedBox(height: 5),
                  Text('${s.current} / ${s.target}',
                      style: TextStyle(
                          color: t.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _dailyTrailing(t, c, s.done, s.claimed),
        ],
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      ),
    );
  }

<<<<<<< HEAD
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
=======
  Widget _dailyTrailing(AppTheme t, DailyChallenge c, bool done, bool claimed) {
    if (claimed) {
      return Icon(Icons.check_circle,
          size: 22, color: _goldAccent.withValues(alpha: 0.55));
    }
    if (done) {
      return PlainButton(
        onTap: () => _claimDaily(c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
              color: _goldAccent, borderRadius: BorderRadius.circular(100)),
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
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const GoldenMineIcon(size: 12),
      const SizedBox(width: 3),
      Text('+${c.reward}',
          style: TextStyle(
              color: t.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _achievementsList(AppTheme t) {
    final all = Title.achievements;
    final done = all.where((x) => _s.isTitleOwned(x.id)).length;
    return Column(
      children: [
        _sectionHeader(t, '업적 · 달성 $done / 전체 ${all.length}'),
        for (final x in all) ...[
          const SizedBox(height: 10),
          _achievementRow(t, x),
        ],
      ],
    );
  }

  Widget _rarityTag(TitleRarity r) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: r.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(100)),
        child: Text(r.label,
            style: TextStyle(
                color: r.color, fontSize: 9, fontWeight: FontWeight.bold)),
      );

  Widget _achievementRow(AppTheme t, Title x) {
    final done = _s.isTitleOwned(x.id);
    final masked = x.hidden && !done;
    final accent = done ? x.rarity.color : t.textSecondary;
    final goal = x.source.goal;
    return _rowCard(
      t,
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _iconCircle(
              x.rarity.color,
              done,
              masked
                  ? Icons.question_mark
                  : (done ? Icons.check : Icons.workspace_premium_outlined),
              accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(masked ? '???' : x.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (!masked) ...[
                    const SizedBox(width: 6),
                    _rarityTag(x.rarity)
                  ],
                  const Spacer(),
                  if (done)
                    Row(children: [
                      Icon(Icons.verified, size: 12, color: x.rarity.color),
                      const SizedBox(width: 3),
                      Text('획득',
                          style: TextStyle(
                              color: x.rarity.color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ]),
                ]),
                const SizedBox(height: 4),
                Text(masked ? '히든 업적 · 숨겨진 조건을 달성하면 공개돼요' : x.hint,
                    maxLines: 2,
                    style: TextStyle(color: t.textSecondary, fontSize: 12)),
                if (!done && !masked && goal != null) ...[
                  const SizedBox(height: 4),
                  Builder(builder: (_) {
                    final p = goalProgress(goal);
                    return CapsuleProgress(
                        fraction: p.target > 0 ? p.current / p.target : 0,
                        color: x.rarity.color);
                  }),
                  const SizedBox(height: 4),
                  Text(goalDisplay(goal),
                      style: TextStyle(
                          color: t.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - 칭호 탭

  Widget _titlesSection(AppTheme t) => Column(
        children: [
          _sectionHeader(t, '내 칭호', coins: true),
          const SizedBox(height: 12),
          _previewCard(t),
          for (final x in Title.all) ...[
            const SizedBox(height: 12),
            _titleRow(t, x),
          ],
          const SizedBox(height: 12),
          Text('도전과제를 깨거나 코인으로 칭호를 얻고, 탭하면 착용돼요. 착용한 칭호는 대전·랭킹에서 이름 밑에 보여요.',
              style: TextStyle(color: t.textTertiary, fontSize: 11)),
        ],
      );

  Widget _previewCard(AppTheme t) {
    final name = _s.equippedTitleName;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: t.fill, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text('이렇게 보여요',
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_s.nickname,
              style: TextStyle(
                  color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (name.isEmpty)
            Text('칭호 미착용',
                style: TextStyle(color: t.textTertiary, fontSize: 12))
          else ...[
            TitleBadge(name: name, size: 11),
            const SizedBox(height: 8),
            PlainButton(
              onTap: () {
                _s.equip(null);
                Haptics.tap();
              },
              child: Text('칭호 떼기',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  String _sourceText(Title x) {
    switch (x.source.kind) {
      case TitleSourceKind.starter:
        return '${x.rarity.label} · 기본 제공';
      case TitleSourceKind.achievement:
        return '${x.rarity.label} · 도전과제 보상 — ${x.hint}';
      case TitleSourceKind.purchase:
        return '${x.rarity.label} · 코인 구매';
    }
  }

  Widget _titleRow(AppTheme t, Title x) {
    final owned = _s.isTitleOwned(x.id);
    final equipped = owned && _s.equippedTitleId == x.id;
    final masked = x.hidden && !owned;
    return PlainButton(
      onTap: () => _tapTitle(x),
      child: _rowCard(
        t,
        fill: equipped
            ? x.rarity.color.withValues(alpha: 0.14)
            : t.fill.withValues(alpha: 0.5),
        stroke: equipped ? x.rarity.color.withValues(alpha: 0.6) : null,
        Row(
          children: [
            _iconCircle(
                x.rarity.color,
                owned,
                masked
                    ? Icons.question_mark
                    : (owned ? Icons.workspace_premium_outlined : Icons.lock),
                owned ? x.rarity.color : t.textSecondary,
                size: 40,
                iconSize: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(masked ? '???' : x.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: t.text,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                    if (!masked) ...[
                      const SizedBox(width: 6),
                      _rarityTag(x.rarity)
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(masked ? '히든 칭호' : _sourceText(x),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: t.textTertiary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _trailing(t, x, owned, equipped),
          ],
        ),
      ),
    );
  }

  Widget _trailing(AppTheme t, Title x, bool owned, bool equipped) {
    if (equipped) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, size: 13, color: t.text),
        const SizedBox(width: 3),
        Text('착용 중',
            style: TextStyle(
                color: t.text, fontSize: 12, fontWeight: FontWeight.bold)),
      ]);
    }
    if (owned) {
      return Text('착용',
          style: TextStyle(
              color: t.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600));
    }
    final cost = x.purchaseCost;
    if (cost != null) {
      final affordable = _s.coins >= cost;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const GoldenMineIcon(size: 12),
        const SizedBox(width: 3),
        Text(formatNumber(cost),
            style: TextStyle(
                color: affordable ? t.text : t.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ]);
    }
    return Icon(Icons.lock, size: 12, color: t.textTertiary);
  }

  // MARK: - 동작

  Future<void> _tapTitle(Title x) async {
    final owned = _s.isTitleOwned(x.id);
    if (owned && _s.equippedTitleId == x.id) {
      _s.equip(null); // 한 번 더 누르면 떼기
      Haptics.tap();
    } else if (owned) {
      _s.equip(x.id);
      Haptics.tap();
    } else if (x.purchaseCost != null) {
      final cost = x.purchaseCost!;
      final ok = await showConfirmSheet(context,
          title: '칭호 구매',
          message:
              '‘${x.name}’ 칭호를 ${formatNumber(cost)}코인에 구매합니다.\n지금 ${formatNumber(_s.coins)}코인 보유 중이에요.',
          confirmLabel: '${formatNumber(cost)}코인에 구매');
      if (ok) _buy(x);
    } else {
      Haptics.warning();
      _toast.show(x.hidden
          ? '히든 칭호예요 · 숨겨진 조건을 달성하면 열려요'
          : '도전과제를 달성하면 열려요');
    }
  }

  void _buy(Title x) {
    final cost = x.purchaseCost;
    if (cost == null) return;
    if (_s.coins < cost) {
      Haptics.error();
      _toast.show('코인이 부족해요 · 상점에서 충전할 수 있어요');
      return;
    }
    if (_s.purchaseTitle(x.id)) {
      Haptics.success();
      _toast.show('‘${x.name}’ 칭호를 착용했어요!');
    }
  }

  void _claimDaily(DailyChallenge c) {
    final reward = Daily.claim(c.kind);
    if (reward == null) return;
    Haptics.success();
    _toast.show('일일 보상 +$reward 코인을 받았어요!');
  }
}

/// 새 칭호를 얻었을 때 화면 상단에 잠깐 뜨는 배너(Swift TitleUnlockBanner).
class TitleUnlockBanner extends StatelessWidget {
  const TitleUnlockBanner({super.key, required this.title});
  final Title title;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final c = title.rarity.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_outlined, size: 22, color: c),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('새 칭호 획득!',
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(title.name,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(100)),
                child: Text(title.rarity.label,
                    style: TextStyle(
                        color: c, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
        ),
      ),
    );
  }
}
