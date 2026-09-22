import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/auth_service.dart';

/// 운영 공지 한 건 — Firestore `notices` 문서 1:1. Swift Notice 이식.
/// 작성은 콘솔(어드민), 앱은 읽기만.
class Notice {
  Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.pinned,
    required this.showPopup,
  });

  final String id;
  final String title;
  final String body;
  final DateTime date;
  final bool pinned; // 목록 상단 고정
  final bool showPopup; // 시작 팝업 대상(현재 팝업 미이식)

  String get dateText =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

/// 공지 읽기 전용 서비스(Firestore `notices`, named DB `mineappdatabase`).
/// 규칙: 읽기 auth != null, 쓰기 차단(콘솔=admin). Swift NoticeService 이식.
class NoticeService {
  NoticeService({FirebaseFirestore? firestore})
      : _db = firestore ??
            FirebaseFirestore.instanceFor(
                app: Firebase.app(), databaseId: 'mineappdatabase');

  final FirebaseFirestore _db;
  static const _collection = 'notices';

  /// 활성 공지 — isActive 단일 equality만 쓰고 정렬은 클라이언트(고정 먼저, 최신순).
  Future<List<Notice>> fetchActive({int limit = 50}) async {
    await AuthService.ensureSignedIn();
    final snap = await _db
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();
    final now = DateTime.now();
    final items = <Notice>[];
    for (final doc in snap.docs) {
      final m = doc.data();
      final title = m['title'];
      if (title is! String) continue;
      items.add(Notice(
        id: doc.id,
        title: title,
        body: (m['body'] as String?) ?? '',
        date: m['createdAt'] is Timestamp
            ? (m['createdAt'] as Timestamp).toDate()
            : now,
        pinned: (m['pinned'] as bool?) ?? false,
        showPopup: (m['showPopup'] as bool?) ?? false,
      ));
    }
    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.date.compareTo(a.date);
    });
    return items;
  }
}
