import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/auth_service.dart';
import '../core/board.dart';
import '../core/local_store.dart';
import '../core/score_entry.dart';

<<<<<<< HEAD
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
=======
export '../core/score_entry.dart';

/// Firestore `scores`/`touchScores` 컬렉션(named DB `mineappdatabase`) 랭킹 제출/조회.
/// docId = `deviceId_난이도` 로 기기·난이도별 1행(최고 기록)만 유지 — Swift `RankingService`와 동일.
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
class RankingService {
  RankingService({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db =>
      _injected ??
      FirebaseFirestore.instanceFor(
          app: Firebase.app(), databaseId: 'mineappdatabase');

  static const _collection = 'scores';
<<<<<<< HEAD
=======
  // 협동("너에게 닿기를")은 난이도 개념이 없어 별도 컬렉션(난이도 랭킹과 섞이지 않게).
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
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

<<<<<<< HEAD
  /// 난이도별 상위 기록(빠른 순). difficulty equality만 쓰고 정렬은 클라이언트에서.
=======
  static ScoreEntry? _parse(QueryDocumentSnapshot<Map<String, dynamic>> doc,
      {String? difficulty}) {
    final m = doc.data();
    final name = m['name'];
    final diff = difficulty ?? m['difficulty'];
    final time = m['timeSec'];
    if (name is! String || diff is! String || time is! num) return null;
    final ts = m['createdAt'];
    return ScoreEntry(
      id: doc.id,
      name: name,
      difficulty: diff,
      timeSec: time.toInt(),
      date: ts is Timestamp ? ts.toDate() : DateTime.now(),
      deviceId: (m['deviceId'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
    );
  }

  /// 난이도별 상위 기록(빠른 순). difficulty equality만 쓰고 정렬은 클라이언트에서(복합색인 불필요).
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  Future<List<ScoreEntry>> top(Difficulty d, {int limit = 50}) async {
    await AuthService.ensureSignedIn();
    final snap = await _db
        .collection(_collection)
        .where('difficulty', isEqualTo: d.label)
        .limit(300)
        .get();
<<<<<<< HEAD
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
=======
    final all = [for (final doc in snap.docs) ?_parse(doc)]
      ..sort((a, b) => a.timeSec.compareTo(b.timeSec));
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    return all.take(limit).toList();
  }

  /// 협동 개인 최고 기록을 1기기 1행으로 갱신(upsert). 문서 ID = deviceId.
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

  /// 협동 상위 기록(빠른 순).
  Future<List<ScoreEntry>> topTouch({int limit = 50}) async {
    await AuthService.ensureSignedIn();
    final snap = await _db.collection(_touchCollection).limit(300).get();
    final all = [for (final doc in snap.docs) ?_parse(doc, difficulty: 'touch')]
      ..sort((a, b) => a.timeSec.compareTo(b.timeSec));
    return all.take(limit).toList();
  }

  /// 온라인 전체에서 내 최고 기록의 등수(1부터). 오프라인/기록 없음이면 null.
  /// 내 행이 아직 서버에 반영되기 전이어도 정확하도록 "나보다 빠른 다른 기기 수 + 1".
  Future<int?> onlineRank(Difficulty d) async {
    final s = LocalStore.shared;
    final myBest = s.soloBest(d);
    if (myBest == null) return null;
    try {
      final list = await top(d, limit: 300);
      if (list.isEmpty) return null;
      return list
              .where((e) => e.deviceId != s.deviceId && e.timeSec < myBest)
              .length +
          1;
    } catch (_) {
      return null;
    }
  }

  /// 협동 온라인 전체에서 내 최고 기록의 등수.
  Future<int?> touchOnlineRank() async {
    final s = LocalStore.shared;
    final myBest = s.touchBest;
    if (myBest == null) return null;
    try {
      final list = await topTouch(limit: 300);
      if (list.isEmpty) return null;
      return list
              .where((e) => e.deviceId != s.deviceId && e.timeSec < myBest)
              .length +
          1;
    } catch (_) {
      return null;
    }
  }
}
