import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mine_app/core/board.dart';
import 'package:mine_app/core/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exportBackup → mergeBackup(다른 기기): 기록 합집합·재화 합산·칭호 합집합', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await LocalStore.init();
    s.nickname = '테스터';
    s.addCoins(500); // 100 + 500
    s.addFlags(7); // 10 + 7
    s.recordSolo(Difficulty.expert, 42);
    s.recordRaceWin();
    s.unlockTitle('supporter');
    s.equip('supporter');

    final snapshot = s.exportBackup();
    expect(snapshot['nickname'], '테스터');
    expect(snapshot['nicknameSetByUser'], true);
    expect(snapshot['unlockedTitleIDs'], contains('supporter'));
    expect(snapshot['equippedTitleID'], 'supporter');
    expect((snapshot['records'] as List).length, 1);

    // 새 기기(빈 상태)에서 머지 — 다른 기기라 재화는 합산, 기록은 합집합.
    SharedPreferences.setMockInitialValues({});
    final fresh = await LocalStore.init();
    expect(fresh.nicknameSetByUser, isFalse);
    fresh.mergeBackup(snapshot);

    expect(fresh.nickname, '테스터');
    expect(fresh.coins, 100 + 600); // 새 기기 시작 100 + 백업 600
    expect(fresh.soloBest(Difficulty.expert), 42);
    expect(fresh.raceWins, 1);
    expect(fresh.isTitleOwned('supporter'), isTrue);
    expect(fresh.equippedTitleId, isNotNull);
  });

  test('같은 기기 재로그인 머지는 max(2배 방지)', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await LocalStore.init();
    s.addCoins(50); // 150
    final snap = s.exportBackup(); // lastSyncedDeviceId = 이 기기
    s.mergeBackup(snap);
    expect(s.coins, 150);
    expect(s.soloClearCount(Difficulty.beginner), 0);
  });
}
