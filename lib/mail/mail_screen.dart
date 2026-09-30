import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'mail.dart';

/// 선물함 — Swift MailListView 이식. 최신순 선물 카드 + "받기"로 코인·아이템 지급(1회).
class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  List<MailGift> _gifts = const [];
  static const accent = Color.fromRGBO(242, 158, 64, 1); // (0.95,0.62,0.25)

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await MailService().fetchActive();
      if (mounted) setState(() => _gifts = list);
    } catch (_) {}
  }

  void _claim(MailGift g) {
    final s = LocalStore.shared;
    if (s.isMailClaimed(g.id)) return;
    Haptics.tap();
    s.grantMailReward(
        coins: g.coins, flags: g.flags, megaphones: g.megaphones, radars: g.radars);
    s.markMailClaimed(g.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '선물함',
      child: _gifts.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(SF.gift, size: 40, color: t.textTertiary),
                const SizedBox(height: 12),
                Text('받을 선물이 없어요',
                    style: sf(15, weight: W.medium, color: t.textSecondary)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _gifts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _card(t, _gifts[i]),
            ),
    );
  }

  Widget _card(AppTheme t, MailGift g) {
    final claimed = LocalStore.shared.isMailClaimed(g.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: rr(14, t.fill,
          stroke: claimed ? Colors.transparent : accent.withValues(alpha: 0.35)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(SF.giftFill, size: 14, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(g.title, style: sf(16, weight: W.bold, color: t.text))),
        ]),
        const SizedBox(height: 8),
        Text(g.dateText, style: sf(11, weight: W.medium, color: t.textTertiary)),
        if (g.body.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(g.body, style: sf(14, color: t.textSecondary)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100)),
              child: Text(g.rewardSummary, style: sf(14, weight: W.bold, color: t.text)),
            ),
          ),
          const Spacer(),
          Tap(
            onTap: claimed ? null : () => _claim(g),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: claimed ? t.fill : accent,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                    color: claimed ? t.border.withValues(alpha: 0.5) : Colors.transparent),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(claimed ? SF.checkmark : CupertinoIcons.tray_arrow_down_fill,
                    size: 12, color: claimed ? t.textTertiary : Colors.white),
                const SizedBox(width: 5),
                Text(claimed ? '받음' : '받기',
                    style: sf(14,
                        weight: W.bold, color: claimed ? t.textTertiary : Colors.white)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}
