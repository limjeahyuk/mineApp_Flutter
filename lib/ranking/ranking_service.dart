import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/auth_service.dart';
import '../core/board.dart';

/// 랭킹 한 줄 — 한 번의 클리어 기록. Swift ScoreEntry 이식.
class ScoreEntry {
  ScoreEntry({
    String? id,
    required this.name,
    required this.difficulty,
    required this.timeSec,
    DateTime? date,
    this.deviceId = '',
    this.title = '',
  })  : id = id ?? _newId(),
        date = date ?? DateTime.now();

  final String id;
  final String name;
  final String difficulty; // Difficulty.label ("초급"…) 또는 "touch"
  final int timeSec;
  final DateTime date;
  final String deviceId;
  final String title; // 기록 당시 장착 칭호(온라인 전용 — 로컬 저장엔 안 넣음)

  Difficulty? get diff => Difficulty.fromLabel(difficulty);

  static String _newId() {
    final r = Random();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  // Swift JSONEncoder 기본 Date = 2001-01-01 기준 초. 원본 로컬 기록(마이그레이션분)과 같은 형식.
  static const _refEpochSec = 978307200;

  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'name': name,
        'difficulty': difficulty,
        'timeSec': timeSec,
        'date': date.millisecondsSinceEpoch / 1000 - _refEpochSec,
        'deviceId': deviceId,
      };

  factory ScoreEntry.fromLocalJson(Map<String, dynamic> m) => ScoreEntry(
        id: m['id'] as String?,
        name: m['name'] as String? ?? '',
        difficulty: m['difficulty'] as String? ?? '',
        timeSec: (m['timeSec'] as num?)?.toInt() ?? 0,
        date: DateTime.fromMillisecondsSinceEpoch(
            ((((m['date'] as num?) ?? 0) + _refEpochSec) * 1000).round()),
        deviceId: m['deviceId'] as String? ?? '',
      );
}

/// 온라인 랭킹(Firestore `scores` / `touchScores`, named DB `mineappdatabase`).
/// docId = "<deviceId>_<난이도>" 로 기기·난이도별 1행(최고 기록)만 유지 — Swift와 동일.
class RankingService {
  RankingService({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db =>
      _injected ??
      FirebaseFirestore.instanceFor(
          app: Firebase.app(), databaseId: 'mineappdatabase');

  static const _collection = 'scores';
  static const _touchCollection = 'touchScores';

  /// 개인 신기록 upsert. 실패해도 게임 흐름을 막지 않는다.
  Future<void> submitBest(ScoreEntry e) async {
    try {
      await AuthService.ensureSignedIn();
      await _db.collection(_collection).doc('${e.deviceId}_${e.difficulty}').set({
        'name': e.name,
        'title': e.title,
        'difficulty': e.difficulty,
        'timeSec': e.timeSec,
        'deviceId': e.deviceId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// 난이도별 상위 기록(빠른 순). difficulty equality만 쓰고 정렬은 클라이언트에서.
  Future<List<ScoreEntry>> top(Difficulty d, {int limit = 50}) async {
    await AuthService.ensureSignedIn();
    final snap = await _db
        .collection(_collection)
        .where('difficulty', isEqualTo: d.label)
        .limit(300)
        .get();
    return _parse(snap.docs, limit, fixedDifficulty: null);
  }

  /// 협동 개인 최고 기록 upsert(문서 ID = deviceId).
  Future<void> submitTouchBest(
      {required String name,
      required int timeSec,
      required String deviceId,
      required String title}) async {
    try {
      await AuthService.ensureSignedIn();
      await _db.collection(_touchCollection).doc(deviceId).set({
        'name': name,
        'title': title,
        'timeSec': timeSec,
        'deviceId': deviceId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<List<ScoreEntry>> topTouch({int limit = 50}) async {
    await AuthService.ensureSignedIn();
    final snap = await _db.collection(_touchCollection).limit(300).get();
    return _parse(snap.docs, limit, fixedDifficulty: 'touch');
  }

  List<ScoreEntry> _parse(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, int limit,
      {String? fixedDifficulty}) {
    final all = <ScoreEntry>[];
    for (final doc in docs) {
      final m = doc.data();
      final name = m['name'];
      final time = m['timeSec'];
      final diff = fixedDifficulty ?? m['difficulty'];
      if (name is! String || time is! num || diff is! String) continue;
      final ts = m['createdAt'];
      all.add(ScoreEntry(
        id: doc.id,
        name: name,
        difficulty: diff,
        timeSec: time.toInt(),
        date: ts is Timestamp ? ts.toDate() : DateTime.now(),
        deviceId: (m['deviceId'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
      ));
    }
    all.sort((a, b) => a.timeSec.compareTo(b.timeSec));
    return all.take(limit).toList();
  }
}
