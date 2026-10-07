import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../ranking/ranking_service.dart';

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
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'mineappdatabase');
  static const _schemaVersion = 1;

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
  }
}
