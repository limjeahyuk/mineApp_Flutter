import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'local_store.dart';

/// 개인 진행(재화·아이템·칭호·기록)을 users/{uid}에 백업/복원한다.
/// 계정 연동 시: linked → backup(로컬을 클라우드로), switched → restore(클라우드를 로컬로).
class CloudBackup {
  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'mineappdatabase');

  static Future<void> backup(String uid) async {
    final data = LocalStore.shared.exportBackup();
    await _db.collection('users').doc(uid).set({
      ...data,
      'deviceId': LocalStore.shared.deviceId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 클라우드 백업을 로컬에 복원. 문서가 없으면 false(복원할 것이 없음).
  static Future<bool> restore(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    if (!snap.exists || data == null) return false;
    LocalStore.shared.restoreBackup(data);
    return true;
  }
}
