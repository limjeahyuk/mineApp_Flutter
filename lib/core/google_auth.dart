import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'account_auth.dart';

/// Google 로그인 ↔ Firebase 연동. Swift GoogleAuthService 이식.
/// 익명 사용자를 Google 계정으로 승격(link)하거나, 이미 영구계정이면 전환(signIn).
class GoogleAuth {
  /// 안드로이드 Google 로그인용 웹 OAuth 클라이언트(공개 식별자, google-services.json type 3).
  static const _webClientId =
      '470995040821-1mbqfb2q86h3n8qrkabpue0qjf67b5ba.apps.googleusercontent.com';

  static bool _initialized = false;

  static bool get isLinked =>
      FirebaseAuth.instance.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  static Future<void> _ensureInit() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      // iOS는 GoogleService-Info의 iOS 클라이언트, Android는 SHA-1 클라이언트(자동) + 웹(server) 클라이언트.
      clientId: Platform.isIOS ? Firebase.app().options.iosClientId : null,
      serverClientId: _webClientId,
    );
    _initialized = true;
  }

  static Future<LinkOutcome> signIn() async {
    try {
      await _ensureInit();
      final account =
          await GoogleSignIn.instance.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null) return const LinkFailed('Google ID 토큰을 받지 못했습니다.');
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return firebaseLinkOrSignIn(credential, account.displayName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const LinkCancelled();
      }
      return LinkFailed(e);
    } catch (e) {
      return LinkFailed(e);
    }
  }
}
