import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mine_app/core/board.dart';
import 'package:mine_app/core/local_store.dart';
import 'package:mine_app/progression/title.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('업적 해금: 조건 충족 시 칭호 획득', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();
    final s = LocalStore.shared;

    // 스타터는 항상 보유
    expect(s.isTitleOwned('rookie'), isTrue);
    // 초급 졸업(초급 10회) — 아직 미달
    expect(s.isTitleOwned('grad_beginner'), isFalse);

    for (var i = 0; i < 10; i++) {
      s.recordSolo(Difficulty.beginner, 30);
    }
    final newly = refreshAchievements();
    expect(newly.map((t) => t.id), contains('grad_beginner'));
    expect(s.isTitleOwned('grad_beginner'), isTrue);

    // 대전 1승 → 대전 새내기
    s.recordRaceWin();
    refreshAchievements();
    expect(s.isTitleOwned('race_rookie'), isTrue);
  });

  test('연승 최고 기록 갱신', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();
    final s = LocalStore.shared;
    s.recordRaceWin();
    s.recordRaceWin();
    s.recordRaceWin();
    expect(s.currentWinStreak, 3);
    expect(s.bestWinStreak, 3);
    s.recordRaceLoss();
    expect(s.currentWinStreak, 0);
    expect(s.bestWinStreak, 3); // 최고는 유지
    s.recordRaceWin();
    expect(s.currentWinStreak, 1);
    expect(s.bestWinStreak, 3);
  });

  test('칭호 구매: 코인 차감 + 장착', () async {
    SharedPreferences.setMockInitialValues({'shop.coins': 1200});
    await LocalStore.init();
    final s = LocalStore.shared;

    final supporter = Title.byId('supporter')!;
    expect(supporter.purchaseCost, 1000);
    expect(s.isTitleOwned('supporter'), isFalse);

    expect(s.spendCoins(supporter.purchaseCost!), isTrue);
    s.unlockTitle('supporter');
    s.equipTitle('supporter', supporter.name);
    expect(s.coins, 200);
    expect(s.isTitleOwned('supporter'), isTrue);
    expect(s.equippedTitleId, 'supporter');
    expect(s.equippedTitleName, '후원자');
  });
}
