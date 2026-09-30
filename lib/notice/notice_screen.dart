import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'notice.dart';

/// 공지사항 목록 — Swift NoticeListView 이식. 고정 공지 위로, 나머지 최신순. 열면 모두 읽음 처리.
class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  List<Notice> _notices = const [];
  static const accent = Color.fromRGBO(64, 140, 242, 1);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await NoticeService().fetchActive();
      if (!mounted) return;
      setState(() => _notices = list);
      if (list.isNotEmpty) {
        final newest = list.map((n) => n.date).reduce((a, b) => a.isAfter(b) ? a : b);
        LocalStore.shared.markNoticesSeen(newest);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '공지사항',
      child: _notices.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(SF.bellSlash, size: 40, color: t.textTertiary),
                const SizedBox(height: 12),
                Text('등록된 공지가 없어요',
                    style: sf(15, weight: W.medium, color: t.textSecondary)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _notices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _card(t, _notices[i]),
            ),
    );
  }

  Widget _card(AppTheme t, Notice n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: rr(14, t.fill),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (n.pinned) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(SF.pinFill, size: 10, color: accent),
                const SizedBox(width: 3),
                Text('고정', style: sf(11, weight: W.bold, color: accent)),
              ]),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(n.title, style: sf(16, weight: W.bold, color: t.text))),
        ]),
        const SizedBox(height: 8),
        Text(n.dateText, style: sf(11, weight: W.medium, color: t.textTertiary)),
        if (n.body.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(n.body, style: sf(14, color: t.textSecondary)),
        ],
      ]),
    );
  }
}
