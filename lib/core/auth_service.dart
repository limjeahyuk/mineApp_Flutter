import 'package:firebase_auth/firebase_auth.dart';

/// 익명 인증 — 보안 규칙(auth != null)을 만족시키기 위해 모든 읽기/쓰기 전에 로그인 상태를 보장한다.
/// Swift AppDelegate의 signInAnonymously + FirebaseMatchService.ensureSignedIn 대응.
class AuthService {
  static final _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static String? get uid => _auth.currentUser?.uid;

  /// 로그인 상태 보장. 이미 로그인돼 있으면 즉시 반환, 아니면 익명 로그인.
  static Future<User> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }
}
