import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'account_auth.dart';

/// Sign in with Apple ↔ Firebase 연동. Swift AppleAuthService 이식.
/// 익명 사용자를 Apple 계정으로 승격(link)하거나, 이미 영구계정이면 그쪽으로 전환(signIn).
class AppleAuth {
  static bool get isLinked =>
      FirebaseAuth.instance.currentUser?.providerData
          .any((p) => p.providerId == 'apple.com') ??
      false;

  static Future<LinkOutcome> signIn() async {
    try {
      // Apple에는 SHA256 해시를, Firebase에는 raw nonce를 보낸다(뒤바꾸면 거부됨).
      final rawNonce = _randomNonce();
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256(rawNonce),
      );
      final idToken = cred.identityToken;
      if (idToken == null) return const LinkFailed('Apple ID 토큰을 받지 못했습니다.');

      final credential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
      );
      // fullName은 그 Apple ID로 이 앱에 "처음" 로그인할 때만 채워진다 → 지금 잡는다.
      final name = [cred.givenName, cred.familyName]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' ')
          .trim();
      return firebaseLinkOrSignIn(credential, name.isEmpty ? null : name);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return const LinkCancelled();
      return LinkFailed(e);
    } catch (e) {
      return LinkFailed(e);
    }
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
