import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/auth_service.dart';

/// 운영 선물 한 건 — Firestore `mailGifts` 문서 1:1. Swift MailGift 이식.
/// 작성은 콘솔(어드민), 앱은 읽기만 + "받기"로 로컬 지급.
class MailGift {
  MailGift({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.coins,
    required this.flags,
    required this.megaphones,
    required this.radars,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime date;
  final int coins;
  final int flags;
  final int megaphones;
  final int radars;
  final DateTime? expiresAt;

  String get dateText =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  bool isAvailable(DateTime now) => expiresAt == null || now.isBefore(expiresAt!);

  bool get hasReward => coins > 0 || flags > 0 || megaphones > 0 || radars > 0;

  /// "🪙 500 · 🚩 3" 요약(0인 항목 생략).
  String get rewardSummary {
    final parts = <String>[];
    if (coins > 0) parts.add('🪙 $coins');
    if (flags > 0) parts.add('🚩 $flags');
    if (megaphones > 0) parts.add('📢 $megaphones');
    if (radars > 0) parts.add('📡 $radars');
    return parts.join(' · ');
  }
}

/// 선물 읽기 전용 서비스(Firestore `mailGifts`, named DB `mineappdatabase`).
/// 규칙: 읽기 auth != null, 쓰기 차단(콘솔=admin). Swift MailService 이식.
class MailService {
  MailService({FirebaseFirestore? firestore})
      : _db = firestore ??
            FirebaseFirestore.instanceFor(
                app: Firebase.app(), databaseId: 'mineappdatabase');

  final FirebaseFirestore _db;
  static const _collection = 'mailGifts';

  /// 활성 선물(전체 대상, 미만료, 보상 있음)만 최신순으로.
  Future<List<MailGift>> fetchActive({int limit = 50}) async {
    await AuthService.ensureSignedIn();
    final snap = await _db
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();
    final now = DateTime.now();
    final items = <MailGift>[];
    for (final doc in snap.docs) {
      final m = doc.data();
      final audience = (m['audience'] as String?) ?? 'all';
      if (audience != 'all') continue;
      final title = m['title'];
      if (title is! String) continue;
      DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : now;
      final gift = MailGift(
        id: doc.id,
        title: title,
        body: (m['body'] as String?) ?? '',
        date: ts(m['createdAt']),
        coins: (m['rewardCoins'] as num?)?.toInt() ?? 0,
        flags: (m['rewardFlags'] as num?)?.toInt() ?? 0,
        megaphones: (m['rewardMegaphones'] as num?)?.toInt() ?? 0,
        radars: (m['rewardRadars'] as num?)?.toInt() ?? 0,
        expiresAt: m['expiresAt'] is Timestamp
            ? (m['expiresAt'] as Timestamp).toDate()
            : null,
      );
      if (gift.isAvailable(now) && gift.hasReward) items.add(gift);
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }
}
