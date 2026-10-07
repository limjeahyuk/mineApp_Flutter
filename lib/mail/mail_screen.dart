import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'mail.dart';

/// 선물함 시트 — Swift MailListView 이식. 최신순 + "받기"로 코인·아이템 지급.
class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  final store = MailStore.shared;
  static const _accent = Color.fromRGBO(242, 158, 64, 1); // (0.95,0.62,0.25)

  @override
  void initState() {
    super.initState();
    store.reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '선물함',
      child: ListenableBuilder(
        listenable: store,
        builder: (_, _) => store.gifts.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(CupertinoIcons.gift, size: 40, color: t.textTertiary),
                  const SizedBox(height: 12),
                  Text('받을 선물이 없어요',
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ]),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: store.gifts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _card(t, store.gifts[i]),
              ),
      ),
    );
  }

  Widget _card(AppTheme t, MailGift g) {
    final claimed = store.isClaimed(g.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: claimed ? Colors.transparent : _accent.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(CupertinoIcons.gift_fill, size: 15, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(g.title,
                style: TextStyle(
                    color: t.text, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(g.dateText,
            style: TextStyle(
                color: t.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
        if (g.body.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(g.body, style: TextStyle(color: t.textSecondary, fontSize: 14)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(100)),
            child: Text(g.rewardSummary,
                style: TextStyle(
                    color: t.text, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          Pressable(
            enabled: !claimed,
            onTap: () {
              Haptics.tap();
              store.claim(g);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: claimed ? t.fill : _accent,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                    color: claimed
                        ? t.border.withValues(alpha: 0.5)
                        : Colors.transparent),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    claimed
                        ? CupertinoIcons.checkmark
                        : CupertinoIcons.tray_arrow_down_fill,
                    size: 13,
                    color: claimed ? t.textTertiary : Colors.white),
                const SizedBox(width: 5),
                Text(claimed ? '받음' : '받기',
                    style: TextStyle(
                        color: claimed ? t.textTertiary : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}
