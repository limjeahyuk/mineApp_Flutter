import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'local_store.dart';

/// 개인 진행(닉네임·기록·전적·재화·아이템·칭호·통계)을 users/{uid}에 백업/복원한다.
/// 스키마는 Swift `UserBackupService`와 동일 — iOS(Swift)·Flutter 어느 쪽에서 백업해도 서로 복원된다.
class CloudBackup {
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'mineappdatabase');

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
  }
}
