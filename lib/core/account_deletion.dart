import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'board.dart';
import 'local_store.dart';

/// 계정 삭제(회원탈퇴) — App Store 심사 가이드라인 5.1.1(v) 필수. Swift AccountDeletionService 이식.
/// 순서: 1) 연동 계정이면 재인증(+Apple 토큰 폐기) 2) 클라우드 데이터 삭제 3) 인증 사용자 삭제
///       4) 로컬 초기화 + 새 익명 계정으로 재시작.
class AccountDeletion {
  /// 사용자가 본인 확인을 취소하면 `DeletionCancelled`를 던지고 아무것도 지우지 않는다.
  static Future<void> deleteAccount() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      await LocalStore.shared.wipeLocalData();
      await auth.signInAnonymously();
      return;
    }

    final uid = user.uid;
    final deviceId = LocalStore.shared.deviceId;
    final providers = user.providerData.map((p) => p.providerId).toList();

    // 1) 연동 계정이면 먼저 재인증(취소 시 데이터 보존을 위해 삭제보다 먼저).
    if (providers.contains('apple.com')) {
      await _reauthAndRevokeApple(user);
    } else if (providers.contains('google.com')) {
      await _reauthGoogle(user);
    }
    // 익명 계정은 재인증 없이 바로 삭제 가능.

    // 2) 클라우드 데이터 삭제(백업·랭킹) — best-effort.
    await _deleteCloudData(uid, deviceId);

    // 3) 인증 계정 삭제.
    await user.delete();

    // 4) 로컬 초기화 + 새 익명 계정으로 재시작.
    await LocalStore.shared.wipeLocalData();
    await auth.signInAnonymously();
  }

  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'mineappdatabase');

  static Future<void> _deleteCloudData(String uid, String deviceId) async {
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (_) {}
    for (final d in Difficulty.values) {
      try {
        await _db.collection('scores').doc('${deviceId}_${d.code}').delete();
      } catch (_) {}
    }
    try {
      await _db.collection('touchScores').doc(deviceId).delete();
    } catch (_) {}
  }

  static Future<void> _reauthAndRevokeApple(User user) async {
    final rawNonce = _randomNonce();
    final cred = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: _sha256(rawNonce),
    ).catchError((Object e) {
      if (e is SignInWithAppleAuthorizationException &&
          e.code == AuthorizationErrorCode.canceled) {
        throw const DeletionCancelled();
      }
      throw e;
    });
    final idToken = cred.identityToken;
    if (idToken == null) throw const DeletionCancelled();
    final credential =
        OAuthProvider('apple.com').credential(idToken: idToken, rawNonce: rawNonce);
    // 최근 로그인(재인증) — user.delete()의 requiresRecentLogin 충족.
    await user.reauthenticateWithCredential(credential);
    // 토큰 폐기(Apple 요구사항) — 실패해도 삭제는 진행(best-effort).
    final code = cred.authorizationCode;
    if (code.isNotEmpty) {
      try {
        await FirebaseAuth.instance.revokeTokenWithAuthorizationCode(code);
      } catch (_) {}
    }
  }

  static Future<void> _reauthGoogle(User user) async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: Firebase.app().options.iosClientId,
      );
    } catch (_) {}
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(scopeHint: const ['email']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const DeletionCancelled();
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const DeletionCancelled();
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await user.reauthenticateWithCredential(credential);
  }

  static String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rng = Random.secure();
    return List.generate(length, (_) => charset[rng.nextInt(charset.length)])
        .join();
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}

/// 본인 확인 취소 — 아무것도 삭제하지 않았음을 알린다.
class DeletionCancelled implements Exception {
  const DeletionCancelled();
  @override
  String toString() => '본인 확인이 취소되어 삭제하지 않았어요.';
}
