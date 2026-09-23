import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mine_app/core/board.dart';
import 'package:mine_app/core/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exportBackup → restoreBackup 왕복으로 진행 데이터가 보존된다', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await LocalStore.init();

    // 진행을 만든다.
    s.nickname = '테스터';
    s.addCoins(500);
    s.addFlags(7);
    s.recordSolo(Difficulty.expert, 42);
    s.recordRaceWin();
    s.equipTitle('speedster', '스피드스터');
    s.unlockTitle('speedster');

    final snapshot = s.exportBackup();
    expect(snapshot['ranking.nickname'], '테스터');
    expect(snapshot['title.owned'], contains('speedster'));

    // 새 기기(빈 상태)로 복원.
    SharedPreferences.setMockInitialValues({});
    final fresh = await LocalStore.init();
    expect(fresh.nickname, '플레이어'); // 복원 전 기본값
    fresh.restoreBackup(snapshot);

    expect(fresh.nickname, '테스터');
    expect(fresh.coins, 600); // 시작 100 + 500 백업분(복원이 shop.coins를 덮어씀)
    expect(fresh.soloBest(Difficulty.expert), 42);
    expect(fresh.raceWins, 1);
    expect(fresh.equippedTitleId, 'speedster');
    expect(fresh.isTitleOwned('speedster'), isTrue);
  });
}
