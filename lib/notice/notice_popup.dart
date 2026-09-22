import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/theme.dart';
import 'notice.dart';

/// 콜드런치 공지 팝업 — Swift NoticePopupView 이식.
/// 바깥 탭/닫기 = 이번만 닫기, "오늘은 그만 보기" = 오늘 하루 이 공지 팝업 차단.
Future<void> showNoticePopup(BuildContext context, Notice notice) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5), // 바깥 탭=닫기
    builder: (_) => _NoticePopup(notice: notice),
  );
}

class _NoticePopup extends StatelessWidget {
  const _NoticePopup({required this.notice});
  final Notice notice;

  static const _accent = Color(0xFF408CF2); // (0.25,0.55,0.95)

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.border.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.campaign, size: 18, color: _accent),
                    const SizedBox(width: 8),
                    Text('공지',
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(notice.dateText,
                        style: TextStyle(
                            color: t.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              // 제목 + 본문(길면 스크롤)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notice.title,
                            style: TextStyle(
                                color: t.text,
                                fontSize: 19,
                                fontWeight: FontWeight.w900)),
                        if (notice.body.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(notice.body,
                              style: TextStyle(
                                  color: t.textSecondary, fontSize: 15)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: t.border.withValues(alpha: 0.4)),
              // 하단 액션
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        LocalStore.shared.dismissNoticeForToday(notice.id);
                        Navigator.of(context).pop();
                      },
                      child: SizedBox(
                        height: 50,
                        child: Center(
                          child: Text('오늘은 그만 보기',
                              style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 28, color: t.border.withValues(alpha: 0.4)),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        height: 50,
                        child: Center(
                          child: Text('닫기',
                              style: TextStyle(
                                  color: _accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
