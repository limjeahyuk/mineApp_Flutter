import 'package:flutter/material.dart' hide Title;

import '../core/local_store.dart';
import '../core/theme.dart';
import 'title.dart';

/// 업적 화면 — 도전과제(진행/달성) + 칭호(장착·구매). Swift AchievementsView 이식.
///
/// ponytail: 일일 도전과제(DailyChallenge)와 협동/테마 조건 칭호는 미이식
/// (협동·테마 목표는 항상 잠금 표시). 나머지 통계 기반 업적은 정상 평가.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final LocalStore _s = LocalStore.shared;
  int _tab = 0; // 0=도전과제, 1=칭호

  @override
  void initState() {
    super.initState();
    refreshAchievements(); // 진입 시 달성분 해금
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(t),
            const SizedBox(height: 8),
            _segment(t),
            const SizedBox(height: 8),
            Expanded(
                child: _tab == 0 ? _challengesTab(t) : _titlesTab(t)),
          ],
        ),
      ),
    );
  }

  Widget _header(AppTheme t) {
    return Padding(
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
            child: Text('업적',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.text, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _segment(AppTheme t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: t.fill, borderRadius: BorderRadius.circular(13)),
      child: Row(
        children: [
          _segBtn(t, 0, '도전과제'),
          _segBtn(t, 1, '칭호'),
        ],
      ),
    );
  }

  Widget _segBtn(AppTheme t, int idx, String label) {
    final selected = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: selected ? AppTheme.soloAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(9)),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : t.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ── 도전과제 탭 ──
  Widget _challengesTab(AppTheme t) {
    final list = Title.achievements;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _challengeRow(t, list[i]),
    );
  }

  Widget _challengeRow(AppTheme t, Title title) {
    final owned = _s.isTitleOwned(title.id);
    final p = goalProgress(title.source.goal!);
    final locked = title.hidden && !owned;
    final name = locked ? '???' : title.name;
    final hint = locked ? '히든 업적' : title.hint;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: owned
                ? title.rarity.color.withValues(alpha: 0.45)
                : Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: (owned ? title.rarity.color : t.textSecondary)
                    .withValues(alpha: 0.16),
                shape: BoxShape.circle),
            child: Icon(title.rarity.icon,
                color: owned ? title.rarity.color : t.textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: t.text,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    if (owned)
                      Icon(Icons.check_circle,
                          color: title.rarity.color, size: 16),
                  ],
                ),
                const SizedBox(height: 3),
                Text(hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                _progressBar(t, p.current, p.target, owned, title.rarity.color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar(
      AppTheme t, int current, int target, bool done, Color color) {
    final ratio = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done ? 1 : ratio,
              minHeight: 6,
              backgroundColor: t.fillElevated,
              valueColor: AlwaysStoppedAnimation(done ? color : t.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(done ? '달성' : '$current/$target',
            style: TextStyle(
                color: done ? color : t.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── 칭호 탭 ──
  Widget _titlesTab(AppTheme t) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      itemCount: Title.all.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _titleRow(t, Title.all[i]),
    );
  }

  Widget _titleRow(AppTheme t, Title title) {
    final owned = _s.isTitleOwned(title.id);
    final equipped = _s.equippedTitleId == title.id;
    final locked = title.hidden && !owned;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: equipped
                ? title.rarity.color
                : (owned
                    ? title.rarity.color.withValues(alpha: 0.35)
                    : Colors.transparent),
            width: equipped ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(title.rarity.icon,
              color: owned ? title.rarity.color : t.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(locked ? '???' : title.name,
                    style: TextStyle(
                        color: owned ? t.text : t.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${title.rarity.label} · ${locked ? "히든" : title.hint}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _titleAction(t, title, owned, equipped),
        ],
      ),
    );
  }

  Widget _titleAction(AppTheme t, Title title, bool owned, bool equipped) {
    if (owned) {
      return Material(
        color: equipped ? t.fillElevated : title.rarity.color,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: equipped
              ? null
              : () {
                  _s.equipTitle(title.id, title.name);
                  setState(() {});
                  _toast("'${title.name}' 장착");
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(equipped ? '장착됨' : '장착',
                style: TextStyle(
                    color: equipped ? t.textSecondary : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }
    final cost = title.purchaseCost;
    if (cost != null) {
      return Material(
        color: AppTheme.soloAccent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _buy(title, cost),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('☀️ $cost',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }
    // 업적으로 해금되는 잠긴 칭호
    return Icon(Icons.lock, color: t.textTertiary, size: 18);
  }

  void _buy(Title title, int cost) {
    if (!_s.spendCoins(cost)) {
      _toast('코인이 부족해요 ($cost 필요)');
      return;
    }
    _s.unlockTitle(title.id);
    _s.equipTitle(title.id, title.name);
    setState(() {});
    _toast("'${title.name}' 구매·장착 완료!");
  }
}
