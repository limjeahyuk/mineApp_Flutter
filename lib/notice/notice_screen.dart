import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import 'notice.dart';

/// 공지사항 시트 — Swift NoticeListView 이식. 고정 공지가 위로, 나머지는 최신순.
class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  final store = NoticeStore.shared;
  static const _accent = AppTheme.soloAccent;

  @override
  void initState() {
    super.initState();
    store.reload().then((_) => store.markAllSeen());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '공지사항',
      child: ListenableBuilder(
        listenable: store,
        builder: (_, _) => store.notices.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(CupertinoIcons.bell_slash, size: 40, color: t.textTertiary),
                  const SizedBox(height: 12),
                  Text('등록된 공지가 없어요',
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ]),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: store.notices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _card(t, store.notices[i]),
              ),
      ),
    );
  }

  Widget _card(AppTheme t, Notice n) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration:
            BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (n.pinned) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(CupertinoIcons.pin_fill, size: 10, color: _accent),
                  SizedBox(width: 3),
                  Text('고정',
                      style: TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(n.title,
                  style: TextStyle(
                      color: t.text, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(n.dateText,
              style: TextStyle(
                  color: t.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
          if (n.body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(n.body, style: TextStyle(color: t.textSecondary, fontSize: 14)),
          ],
        ]),
      );
}
