import 'package:firebase_auth/firebase_auth.dart';

/// 계정 연동 결과(Apple·Google 공통). Swift AccountAuth.LinkOutcome 이식.
/// - linked: 익명 계정을 그대로 승격(같은 uid) → 로컬 데이터를 클라우드로 백업.
/// - switched: 이미 그 계정으로 만든 영구계정이 있어 전환(새 폰/재설치) → 클라우드에서 복원.
/// - cancelled: 사용자가 로그인 취소.
/// - failed: 그 외 오류.
sealed class LinkOutcome {
  const LinkOutcome();
}

class LinkLinked extends LinkOutcome {
  const LinkLinked(this.uid, this.suggestedName);
  final String uid;
  final String? suggestedName;
}

class LinkSwitched extends LinkOutcome {
  const LinkSwitched(this.uid, this.suggestedName);
  final String uid;
  final String? suggestedName;
}

class LinkCancelled extends LinkOutcome {
  const LinkCancelled();
}

class LinkFailed extends LinkOutcome {
  const LinkFailed(this.error);
  final Object error;
}

/// 익명 사용자면 link(승격), 이미 그 자격증명이 쓰이는 중이면 그 계정으로 signIn 전환.
/// Apple·Google 등 provider 공통 — 넘어오는 credential만 다르다.
Future<LinkOutcome> firebaseLinkOrSignIn(
    AuthCredential credential, String? suggestedName) async {
  final auth = FirebaseAuth.instance;
  try {
    final UserCredential result;
    final user = auth.currentUser;
    if (user != null) {
      result = await user.linkWithCredential(credential); // 같은 uid 유지하며 승격
    } else {
      result = await auth.signInWithCredential(credential);
    }
    return LinkLinked(result.user!.uid, suggestedName);
  } on FirebaseAuthException catch (e) {
    // 이미 그 계정으로 만든 영구계정이 있음(= 새 폰/재설치). 그 계정으로 전환.
    // ★ 원본 credential은 소비됐을 수 있어 예외의 갱신본을 쓰는 게 안정적이다.
    if (e.code == 'credential-already-in-use') {
      final updated = e.credential ?? credential;
      try {
        final result = await auth.signInWithCredential(updated);
        return LinkSwitched(result.user!.uid, suggestedName);
      } catch (err) {
        return LinkFailed(err);
      }
    }
    return LinkFailed(e);
  } catch (e) {
    return LinkFailed(e);
  }
}
