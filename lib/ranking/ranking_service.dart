import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/auth_service.dart';
import '../core/board.dart';

/// 온라인 랭킹 1행 — Swift ScoreEntry 이식(표시에 필요한 필드만).
class ScoreEntry {
  ScoreEntry({
    required this.name,
    required this.difficulty,
    required this.timeSec,
    required this.deviceId,
    this.title = '',
  });

  final String name;
  final String difficulty; // Difficulty.label ("초급"…)
  final int timeSec;
  final String deviceId;
  final String title;
}

/// Firestore `scores` 컬렉션(named DB `mineappdatabase`) 랭킹 제출/조회.
/// docId = `deviceId_난이도` 로 기기·난이도별 1행(최고 기록)만 유지 — Swift와 동일.
class RankingService {
  RankingService({FirebaseFirestore? firestore})
      : _db = firestore ??
            FirebaseFirestore.instanceFor(
                app: Firebase.app(), databaseId: 'mineappdatabase');

  final FirebaseFirestore _db;
  static const _collection = 'scores';

  /// 개인 신기록 upsert. 규칙(auth != null) 만족 위해 익명 로그인 보장.
  Future<void> submitBest(ScoreEntry e) async {
    try {
      await AuthService.ensureSignedIn();
      final docId = '${e.deviceId}_${e.difficulty}';
      await _db.collection(_collection).doc(docId).set({
        'name': e.name,
        'title': e.title,
        'difficulty': e.difficulty,
        'timeSec': e.timeSec,
        'deviceId': e.deviceId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // 랭킹 제출 실패는 게임 흐름을 막지 않는다.
    }
  }

  /// 난이도별 상위 기록(빠른 순). difficulty equality만 쓰고 정렬은 클라이언트에서(복합색인 불필요).
  Future<List<ScoreEntry>> top(Difficulty d, {int limit = 50}) async {
    await AuthService.ensureSignedIn();
    final snap = await _db
        .collection(_collection)
        .where('difficulty', isEqualTo: d.label)
        .limit(300)
        .get();
    final all = <ScoreEntry>[];
    for (final doc in snap.docs) {
      final m = doc.data();
      final name = m['name'];
      final diff = m['difficulty'];
      final time = m['timeSec'];
      if (name is! String || diff is! String || time is! num) continue;
      all.add(ScoreEntry(
        name: name,
        difficulty: diff,
        timeSec: time.toInt(),
        deviceId: (m['deviceId'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
      ));
    }
    all.sort((a, b) => a.timeSec.compareTo(b.timeSec));
    return all.take(limit).toList();
  }
}
