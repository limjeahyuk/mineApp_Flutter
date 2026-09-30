import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' hide Title;

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'daily.dart';
import 'title.dart';

/// 업적 — Swift AchievementsView 이식. (도전과제 | 칭호) 세그먼트.
/// 도전과제: 오늘의 도전과제(코인) + 장기 업적(칭호 해금). 칭호: 미리보기 + 착용/구매.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

enum _TitleState { equipped, owned, purchasable, locked }

class _AchievementsScreenState extends State<AchievementsScreen> with ToastMixin {
  int tab = 0;
  LocalStore get s => LocalStore.shared;
  static const goldAccent = Color.fromRGBO(245, 194, 61, 1); // (0.96,0.76,0.24)

  @override
  void initState() {
    super.initState();
    refreshAchievements();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '업적',
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(children: [
            Segmented(
                labels: const ['도전과제', '칭호'],
                index: tab,
                onChanged: (i) => setState(() => tab = i)),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: tab == 0 ? _challenges(t) : _titles(t),
              ),
            ),
          ]),
        ),
        toastOverlay(bottom: 12),
      ]),
    );
  }

  Widget _coinsSmall(AppTheme t) => Row(mainAxisSize: MainAxisSize.min, children: [
        const GoldenMineIcon(size: 13),
        const SizedBox(width: 4),
        Text(fmt(s.coins), style: sf(13, weight: W.bold, color: t.textSecondary)),
      ]);

  Widget _progressBar(AppTheme t, double frac, Color color) => SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (_, c) => Stack(children: [
            Container(decoration: BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(3))),
            Container(
              width: frac.clamp(0.0, 1.0) * c.maxWidth,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
          ]),
        ),
      );

  Widget _iconCircle(IconData icon, Color tint, bool on, Color fg, {double size = 44}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: (on ? tint : Colors.grey).withValues(alpha: 0.16), shape: BoxShape.circle),
        child: Icon(icon, size: size == 44 ? 18 : 16, color: fg),
      );

  Widget _rarityTag(TitleRarity r) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: r.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100)),
        child: Text(r.label, style: sf(9, weight: W.bold, color: r.color)),
      );

  BoxDecoration _rowBg(AppTheme t) =>
      rr(14, t.fill.withValues(alpha: 0.5));

  // ── 도전과제 탭 ──
  Widget _challenges(AppTheme t) {
    final today = DailyChallenge.forDay(LocalStore.todayKey());
    final achievements = Title.achievements;
    final done = achievements.where((a) => s.isTitleOwned(a.id)).length;
    return Column(children: [
      Row(children: [
        Text('오늘의 도전과제', style: sf(13, weight: W.semibold, color: t.textSecondary)),
        const Spacer(),
        _coinsSmall(t),
      ]),
      for (final c in today) ...[const SizedBox(height: 10), _dailyRow(t, c)],
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: Text('매일 자정에 새로 갱신돼요. 달성하면 코인을 받을 수 있어요.',
            style: sf(11, color: t.textTertiary)),
      ),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerLeft,
        child: Text('업적 · 달성 $done / 전체 ${achievements.length}',
            style: sf(13, weight: W.semibold, color: t.textSecondary)),
      ),
      for (final a in achievements) ...[const SizedBox(height: 10), _achievementRow(t, a)],
    ]);
  }

  Widget _dailyRow(AppTheme t, DailyChallenge c) {
    final st = Daily.state(c.kind);
    Widget trailing;
    if (st.claimed) {
      trailing = Icon(SF.checkCircleFill, size: 22, color: goldAccent.withValues(alpha: 0.55));
    } else if (st.done) {
      trailing = Tap(
        onTap: () {
          final r = Daily.claim(c.kind);
          if (r == null) return;
          Haptics.success();
          showToast('일일 보상 +$r 코인을 받았어요!');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(color: goldAccent, borderRadius: BorderRadius.circular(100)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const GoldenMineIcon(size: 13),
            const SizedBox(width: 3),
            Text('받기 +${c.reward}',
                style: sf(13, weight: W.bold, color: const Color.fromRGBO(64, 41, 0, 1))),
          ]),
        ),
      );
    } else {
      trailing = Row(mainAxisSize: MainAxisSize.min, children: [
        const GoldenMineIcon(size: 12),
        const SizedBox(width: 3),
        Text('+${c.reward}', style: sf(12, weight: W.bold, color: t.textTertiary)),
      ]);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _rowBg(t),
      child: Row(children: [
        _iconCircle(c.icon, goldAccent, st.done, st.done ? goldAccent : t.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sf(15, weight: W.bold, color: t.text)),
            const SizedBox(height: 5),
            if (st.claimed)
              Row(children: [
                Icon(SF.sealFill, size: 12, color: t.textTertiary),
                const SizedBox(width: 4),
                Text('보상을 받았어요', style: sf(12, weight: W.semibold, color: t.textTertiary)),
              ])
            else ...[
              _progressBar(t, st.target > 0 ? st.current / st.target : 0, goldAccent),
              const SizedBox(height: 5),
              Text('${st.current} / ${st.target}',
                  style: sf(11, weight: W.semibold, color: t.textTertiary)),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        trailing,
      ]),
    );
  }

  String _goalDisplay(Goal g) {
    switch (g) {
      case BestUnderGoal(:final d, :final sec):
        final best = s.soloBest(d);
        return best != null ? '최고 $best초 · 목표 $sec초 이내' : '기록 없음 · 목표 $sec초 이내';
      case TouchUnderGoal(:final sec):
        final best = s.touchBest;
        return best != null ? '최고 $best초 · 목표 $sec초 이내' : '기록 없음 · 목표 $sec초 이내';
      default:
        final p = goalProgress(g);
        return '${p.current} / ${p.target}';
    }
  }

  Widget _achievementRow(AppTheme t, Title a) {
    final done = s.isTitleOwned(a.id);
    final masked = a.hidden && !done;
    final accent = done ? a.rarity.color : t.textSecondary;
    final goal = a.source.goal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _rowBg(t),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _iconCircle(
            masked ? CupertinoIcons.question : (done ? SF.checkmark : SF.rosette),
            a.rarity.color,
            done,
            accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(masked ? '???' : a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sf(15, weight: W.bold, color: t.text)),
              ),
              if (!masked) ...[const SizedBox(width: 6), _rarityTag(a.rarity)],
              const Spacer(),
              if (done)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(SF.sealFill, size: 11, color: a.rarity.color),
                  const SizedBox(width: 3),
                  Text('획득', style: sf(11, weight: W.bold, color: a.rarity.color)),
                ]),
            ]),
            const SizedBox(height: 4),
            Text(masked ? '히든 업적 · 숨겨진 조건을 달성하면 공개돼요' : a.hint,
                maxLines: 2, style: sf(12, color: t.textSecondary)),
            if (!done && !masked && goal != null) ...[
              const SizedBox(height: 4),
              Builder(builder: (_) {
                final p = goalProgress(goal);
                return _progressBar(t, p.target > 0 ? p.current / p.target : 0, a.rarity.color);
              }),
              const SizedBox(height: 4),
              Text(_goalDisplay(goal), style: sf(11, weight: W.semibold, color: t.textTertiary)),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── 칭호 탭 ──
  _TitleState _state(Title ti) {
    final owned = s.isTitleOwned(ti.id);
    if (owned && s.equippedTitleId == ti.id) return _TitleState.equipped;
    if (owned) return _TitleState.owned;
    if (ti.purchaseCost != null) return _TitleState.purchasable;
    return _TitleState.locked;
  }

  Widget _titles(AppTheme t) {
    return Column(children: [
      Row(children: [
        Text('내 칭호', style: sf(13, weight: W.semibold, color: t.textSecondary)),
        const Spacer(),
        _coinsSmall(t),
      ]),
      const SizedBox(height: 12),
      _previewCard(t),
      for (final ti in Title.all) ...[const SizedBox(height: 12), _titleRow(t, ti)],
      const SizedBox(height: 12),
      Text('도전과제를 깨거나 코인으로 칭호를 얻고, 탭하면 착용돼요. 착용한 칭호는 대전·랭킹에서 이름 밑에 보여요.',
          style: sf(11, color: t.textTertiary)),
    ]);
  }

  Widget _previewCard(AppTheme t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: rr(16, t.fill),
      child: Column(children: [
        Text('이렇게 보여요', style: sf(11, weight: W.semibold, color: t.textSecondary)),
        const SizedBox(height: 8),
        Text(s.nickname, style: sf(18, weight: W.bold, color: t.text)),
        const SizedBox(height: 8),
        if (s.equippedTitleName.isEmpty)
          Text('칭호 미착용', style: sf(12, color: t.textTertiary))
        else ...[
          TitleBadge(name: s.equippedTitleName, size: 11),
          const SizedBox(height: 8),
          Tap(
            onTap: () {
              Haptics.tap();
              setState(s.unequipTitle);
            },
            child: Text('칭호 떼기', style: sf(12, weight: W.semibold, color: t.textSecondary)),
          ),
        ],
      ]),
    );
  }

  String _sourceText(Title ti) => switch (ti.source.kind) {
        TitleSourceKind.starter => '${ti.rarity.label} · 기본 제공',
        TitleSourceKind.achievement => '${ti.rarity.label} · 도전과제 보상 — ${ti.hint}',
        TitleSourceKind.purchase => '${ti.rarity.label} · 코인 구매',
      };

  Widget _titleRow(AppTheme t, Title ti) {
    final st = _state(ti);
    final owned = st == _TitleState.equipped || st == _TitleState.owned;
    final masked = ti.hidden && !owned;
    final equipped = st == _TitleState.equipped;
    Widget trailing;
    switch (st) {
      case _TitleState.equipped:
        trailing = Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(SF.checkCircleFill, size: 12, color: t.text),
          const SizedBox(width: 3),
          Text('착용 중', style: sf(12, weight: W.bold, color: t.text)),
        ]);
      case _TitleState.owned:
        trailing = Text('착용', style: sf(12, weight: W.semibold, color: t.textSecondary));
      case _TitleState.purchasable:
        final cost = ti.purchaseCost!;
        trailing = Row(mainAxisSize: MainAxisSize.min, children: [
          const GoldenMineIcon(size: 12),
          const SizedBox(width: 3),
          Text(fmt(cost),
              style: sf(12, weight: W.bold, color: s.coins >= cost ? t.text : t.textTertiary)),
        ]);
      case _TitleState.locked:
        trailing = Icon(SF.lockFill, size: 12, color: t.textTertiary);
    }
    return Tap(
      onTap: () => _tapTitle(ti, st),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: equipped ? ti.rarity.color.withValues(alpha: 0.14) : t.fill.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: equipped ? ti.rarity.color.withValues(alpha: 0.6) : Colors.transparent,
              width: 1.2),
        ),
        child: Row(children: [
          _iconCircle(
              masked ? CupertinoIcons.question : (owned ? SF.rosette : SF.lockFill),
              ti.rarity.color,
              owned,
              owned ? ti.rarity.color : t.textSecondary,
              size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(masked ? '???' : ti.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sf(15, weight: W.bold, color: t.text)),
                ),
                if (!masked) ...[const SizedBox(width: 6), _rarityTag(ti.rarity)],
              ]),
              const SizedBox(height: 3),
              Text(masked ? '히든 칭호' : _sourceText(ti),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sf(11, color: t.textTertiary)),
            ]),
          ),
          const SizedBox(width: 12),
          trailing,
        ]),
      ),
    );
  }

  Future<void> _tapTitle(Title ti, _TitleState st) async {
    switch (st) {
      case _TitleState.equipped:
        Haptics.tap();
        setState(s.unequipTitle);
      case _TitleState.owned:
        Haptics.tap();
        setState(() => s.equipTitle(ti.id, ti.name));
      case _TitleState.purchasable:
        final cost = ti.purchaseCost!;
        final ok = await showCupertinoConfirm(
          context,
          title: '칭호 구매',
          message: '‘${ti.name}’ 칭호를 ${fmt(cost)}코인에 구매합니다.\n지금 ${fmt(s.coins)}코인 보유 중이에요.',
          confirm: '${fmt(cost)}코인에 구매',
        );
        if (ok != true || !mounted) return;
        if (s.coins < cost) {
          Haptics.error();
          showToast('코인이 부족해요 · 상점에서 충전할 수 있어요');
          return;
        }
        if (s.purchaseTitle(ti.id, ti.name, cost)) {
          Haptics.success();
          setState(() {});
          showToast('‘${ti.name}’ 칭호를 착용했어요!');
        }
      case _TitleState.locked:
        Haptics.warning();
        showToast(ti.hidden ? '히든 칭호예요 · 숨겨진 조건을 달성하면 열려요' : '도전과제를 달성하면 열려요');
    }
  }
}
