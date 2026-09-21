import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/board.dart';
import 'package:mine_app/multiplayer/firebase_match_service.dart';
import 'package:mine_app/multiplayer/multiplayer.dart';

/// 매칭 시스템 검증 — 인메모리 Firestore(fake) 하나를 두 서비스가 공유해
/// 호스트↔게스트 매칭을 실제로 재현한다. 같은 시드/난이도를 양쪽이 받는지가 핵심
/// (같은 시드 → SeededGenerator로 양쪽 동일 보드 → 크로스플레이 성립).
void main() {
  FirebaseMatchService host(FakeFirebaseFirestore fs) => FirebaseMatchService(
        deviceIdOverride: 'host-id',
        firestore: fs,
        myName: '호스트',
        myTitle: '스피드러너',
        signIn: () async {},
      );
  FirebaseMatchService guest(FakeFirebaseFirestore fs) => FirebaseMatchService(
        deviceIdOverride: 'guest-id',
        firestore: fs,
        myName: '게스트',
        myTitle: '',
        signIn: () async {},
      );

  test('방 코드 매칭 — 호스트/게스트가 같은 시드·난이도를 받는다', () async {
    final fs = FakeFirebaseFirestore();
    final h = host(fs);
    final g = guest(fs);

    String? code;
    h.onRoomCode = (c) => code = c;

    final hostFuture = h.createRoom(Difficulty.expert, RaceRule.score);
    // 방 생성 + 코드 발급이 끝날 때까지 잠깐 양보
    await Future.delayed(const Duration(milliseconds: 50));
    expect(code, isNotNull, reason: '코드가 발급돼야 한다');

    final guestInfo = await g.joinRoom(code!);
    final hostInfo = await hostFuture;

    // 같은 판(시드/난이도/규칙/안전칸) — 크로스플레이의 핵심
    expect(hostInfo.seed, guestInfo.seed);
    expect(hostInfo.difficulty, Difficulty.expert);
    expect(guestInfo.difficulty, Difficulty.expert);
    expect(hostInfo.rule, RaceRule.score);
    expect(guestInfo.rule, RaceRule.score);
    expect(guestInfo.safeR, hostInfo.safeR);
    expect(guestInfo.safeC, hostInfo.safeC);

    // 역할 + 상대 정보(닉네임/칭호)가 서로에게 보인다
    expect(hostInfo.isHost, true);
    expect(guestInfo.isHost, false);
    expect(hostInfo.opponentName, '게스트');
    expect(guestInfo.opponentName, '호스트');
    expect(guestInfo.opponentTitle, '스피드러너');

    h.leave();
    g.leave();
  });

  test('자동 대기열 매칭 — find()끼리 같은 판으로 붙는다', () async {
    final fs = FakeFirebaseFirestore();
    final h = host(fs);
    final g = guest(fs);

    final hostFuture = h.find(Difficulty.beginner, RaceRule.speed);
    await Future.delayed(const Duration(milliseconds: 50)); // 호스트 대기방 생성

    final guestInfo = await g.find(Difficulty.beginner, RaceRule.speed);
    final hostInfo = await hostFuture;

    expect(hostInfo.seed, guestInfo.seed);
    expect(hostInfo.isHost, true);
    expect(guestInfo.isHost, false);
    expect(guestInfo.opponentName, '호스트');

    // 매칭 후 문서는 active 상태여야 한다
    final docs = await fs.collection('matches').get();
    expect(docs.docs.single.data()['status'], 'active');

    h.leave();
    g.leave();
  });

  test('없는 코드로 참가하면 roomNotFound', () async {
    final fs = FakeFirebaseFirestore();
    final g = guest(fs);
    await expectLater(
      g.joinRoom('ZZZZZZ'),
      throwsA(MatchError.roomNotFound),
    );
  });

  test('다른 난이도끼리는 매칭되지 않는다(각자 호스트로 대기)', () async {
    final fs = FakeFirebaseFirestore();
    final h = host(fs);
    final g = guest(fs);

    // 호스트는 초급 대기방을 만든다(타임아웃 전까지 대기)
    unawaited(h.find(Difficulty.beginner, RaceRule.speed));
    await Future.delayed(const Duration(milliseconds: 50));

    // 게스트가 고급으로 찾으면 초급 방을 점유하지 못하고 자기 방을 만든다 → 대기방 2개
    unawaited(g.find(Difficulty.expert, RaceRule.speed));
    await Future.delayed(const Duration(milliseconds: 50));

    final waiting = await fs
        .collection('matches')
        .where('status', isEqualTo: 'waiting')
        .get();
    expect(waiting.docs.length, 2, reason: '난이도가 다르면 서로 점유하지 못한다');

    h.leave();
    g.leave();
  });
}

void unawaited(Future<void> f) {}
