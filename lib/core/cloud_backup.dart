import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../ranking/ranking_service.dart';

<<<<<<< HEAD
/// users/{uid}에 저장하는 "내 정보" 백업 페이로드 — Swift UserBackupData와 같은 스키마
/// (같은 계정으로 옛 Swift 앱에서 올린 백업도 그대로 읽힌다).
class UserBackupData {
  UserBackupData({
    required this.nickname,
    required this.nicknameSetByUser,
    required this.records,
    required this.raceWins,
    required this.raceLosses,
    required this.raceDraws,
    required this.coins,
    required this.ownedFlags,
    required this.ownedMegaphones,
    required this.ownedRadars,
    required this.ownedThemeIds,
    required this.touchBest,
    required this.unlockedTitleIds,
    required this.equippedTitleId,
    required this.goldenMinesFound,
    required this.gachaDraws,
    required this.gachaJackpots,
    required this.bestWinStreak,
    required this.touchClears,
    this.noItemExpertClears = 0,
    this.noItemUltimateClears = 0,
    required this.lastSyncedDeviceId,
  });

  final String nickname;
  final bool nicknameSetByUser;
  final List<ScoreEntry> records;
  final int raceWins, raceLosses, raceDraws, coins;
  final int ownedFlags, ownedMegaphones, ownedRadars;
  final List<String> ownedThemeIds;
  final int? touchBest;
  final List<String> unlockedTitleIds;
  final String? equippedTitleId;
  final int goldenMinesFound, gachaDraws, gachaJackpots, bestWinStreak;
  final int touchClears, noItemExpertClears, noItemUltimateClears;
  final String lastSyncedDeviceId;
}

/// Swift UserBackupService 이식 — users/{uid} 병합 저장/읽기.
class UserBackupService {
=======
/// 개인 진행(닉네임·기록·전적·재화·아이템·칭호·통계)을 users/{uid}에 백업/복원한다.
/// 스키마는 Swift `UserBackupService`와 동일 — iOS(Swift)·Flutter 어느 쪽에서 백업해도 서로 복원된다.
class CloudBackup {
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'mineappdatabase');
  static const _schemaVersion = 1;

<<<<<<< HEAD
  static Future<void> save(String uid, UserBackupData d) async {
    try {
      await _db.collection('users').doc(uid).set({
        'nickname': d.nickname,
        'nicknameSetByUser': d.nicknameSetByUser,
        'records': [
          for (final r in d.records)
            {
              'id': r.id,
              'name': r.name,
              'difficulty': r.difficulty,
              'timeSec': r.timeSec,
              'date': r.date.millisecondsSinceEpoch / 1000,
            }
        ],
        'raceWins': d.raceWins,
        'raceLosses': d.raceLosses,
        'raceDraws': d.raceDraws,
        'coins': d.coins,
        'ownedFlags': d.ownedFlags,
        'ownedMegaphones': d.ownedMegaphones,
        'ownedRadars': d.ownedRadars,
        'ownedThemeIDs': d.ownedThemeIds,
        'touchBest': d.touchBest ?? 0, // 0 = 미기록
        'unlockedTitleIDs': d.unlockedTitleIds,
        'equippedTitleID': d.equippedTitleId ?? '', // "" = 미착용
        'goldenMinesFound': d.goldenMinesFound,
        'gachaDraws': d.gachaDraws,
        'gachaJackpots': d.gachaJackpots,
        'bestWinStreak': d.bestWinStreak,
        'touchClears': d.touchClears,
        'noItemExpertClears': d.noItemExpertClears,
        'noItemUltimateClears': d.noItemUltimateClears,
        'lastSyncedDeviceId': d.lastSyncedDeviceId,
        'schemaVersion': _schemaVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // 백업 실패는 게임 흐름을 막지 않는다(다음 변경 때 다시 시도).
    }
  }

  static Future<UserBackupData?> load(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final m = snap.data();
      if (!snap.exists || m == null) return null;
      return parse(m);
    } catch (_) {
      return null;
    }
  }

  static UserBackupData parse(Map<String, dynamic> m) {
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    List<String> l(String k) =>
        (m[k] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final records = <ScoreEntry>[];
    for (final r in (m['records'] as List?) ?? const []) {
      if (r is! Map) continue;
      final name = r['name'], diff = r['difficulty'], t = r['timeSec'];
      if (name is! String || diff is! String || t is! num) continue;
      records.add(ScoreEntry(
        id: r['id'] as String?,
        name: name,
        difficulty: diff,
        timeSec: t.toInt(),
        date: DateTime.fromMillisecondsSinceEpoch(
            (((r['date'] as num?) ?? 0) * 1000).round()),
      ));
    }
    final touch = i('touchBest');
    final eq = m['equippedTitleID'] as String? ?? '';
    return UserBackupData(
      nickname: m['nickname'] as String? ?? '',
      nicknameSetByUser: m['nicknameSetByUser'] as bool? ?? false,
      records: records,
      raceWins: i('raceWins'),
      raceLosses: i('raceLosses'),
      raceDraws: i('raceDraws'),
      coins: i('coins'),
      ownedFlags: i('ownedFlags'),
      ownedMegaphones: i('ownedMegaphones'),
      ownedRadars: i('ownedRadars'),
      ownedThemeIds: m.containsKey('ownedThemeIDs') ? l('ownedThemeIDs') : const ['classic'],
      touchBest: touch > 0 ? touch : null,
      unlockedTitleIds: l('unlockedTitleIDs'),
      equippedTitleId: eq.isEmpty ? null : eq,
      goldenMinesFound: i('goldenMinesFound'),
      gachaDraws: i('gachaDraws'),
      gachaJackpots: i('gachaJackpots'),
      bestWinStreak: i('bestWinStreak'),
      touchClears: i('touchClears'),
      noItemExpertClears: i('noItemExpertClears'),
      noItemUltimateClears: i('noItemUltimateClears'),
      lastSyncedDeviceId: m['lastSyncedDeviceId'] as String? ?? '',
    );
=======
  /// Apple/Google로 연동된 계정이면 uid, 아니면 null.
  static String? get linkedUid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    final linked = u.providerData
        .any((p) => p.providerId == 'apple.com' || p.providerId == 'google.com');
    return linked ? u.uid : null;
  }

  /// 연동돼 있으면 현재 로컬 상태를 클라우드에 백업(값이 바뀌는 지점에서 호출).
  static void backupIfLinked() {
    final uid = linkedUid;
    if (uid == null) return;
    backup(uid).catchError((_) {});
  }

  static Future<void> backup(String uid) async {
    final data = LocalStore.shared.exportBackup();
    await _db.collection('users').doc(uid).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 연동/계정 전환 직후 — 클라우드와 로컬을 머지하고 최신본을 다시 백업한다(Swift `syncAfterLink`).
  static Future<void> syncAfterLink(String uid, String? suggestedName) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data();
      if (snap.exists && data != null) {
        LocalStore.shared.mergeBackup(data, suggestedName: suggestedName);
      } else {
        LocalStore.shared.applySuggestedName(suggestedName);
      }
    } catch (_) {
      LocalStore.shared.applySuggestedName(suggestedName);
    }
    await backup(uid);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  }
}
