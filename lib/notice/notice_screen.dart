import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/theme.dart';
import 'notice.dart';

/// 공지사항 화면 — Swift NoticeListView 이식. 고정 공지가 위로, 나머지는 최신순.
/// 열면 가장 새 공지 시각을 읽음으로 저장해 홈 종(bell)의 점을 끈다.
///
/// ponytail: 콜드런치 팝업(NoticePopupView)·"오늘은 그만 보기"는 미이식(목록만).
class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  final NoticeService _service = NoticeService();
  List<Notice>? _notices; // null=로딩 중
  static const _accent = Color(0xFF408CF2); // (0.25,0.55,0.95)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.fetchActive();
      if (!mounted) return;
      setState(() => _notices = list);
      if (list.isNotEmpty) {
        final newest = list
            .map((n) => n.date)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        LocalStore.shared.markNoticesSeen(newest);
      }
    } catch (_) {
      if (mounted) setState(() => _notices = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(t),
            Expanded(child: _content(t)),
          ],
        ),
      ),
    );
  }

  Widget _header(AppTheme t) => Padding(
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
              child: Text('공지사항',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.text, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 40),
          ],
        ),
      );

  Widget _content(AppTheme t) {
    final notices = _notices;
    if (notices == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notices.isEmpty) return _emptyState(t);
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: notices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _noticeCard(t, notices[i]),
    );
  }

  Widget _noticeCard(AppTheme t, Notice n) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration:
            BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (n.pinned) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.push_pin, size: 10, color: _accent),
                        SizedBox(width: 3),
                        Text('고정',
                            style: TextStyle(
                                color: _accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(n.title,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(n.dateText,
                style: TextStyle(
                    color: t.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            if (n.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(n.body,
                  style: TextStyle(color: t.textSecondary, fontSize: 14)),
            ],
          ],
        ),
      );

  Widget _emptyState(AppTheme t) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 40, color: t.textTertiary),
            const SizedBox(height: 12),
            Text('등록된 공지가 없어요',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
