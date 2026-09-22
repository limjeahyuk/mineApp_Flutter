import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mine_app/core/board.dart';
import 'package:mine_app/core/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('솔로 기록: 최고 기록(최소)·클리어 수', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();
    final s = LocalStore.shared;
    const d = Difficulty.beginner;

    expect(s.soloBest(d), isNull);
    expect(s.soloClearCount(d), 0);

    expect(s.recordSolo(d, 50), isTrue); // 첫 기록 = 신기록
    expect(s.soloBest(d), 50);
    expect(s.soloClearCount(d), 1);

    expect(s.recordSolo(d, 70), isFalse); // 더 느림 → 신기록 아님
    expect(s.soloBest(d), 50);
    expect(s.soloClearCount(d), 2);

    expect(s.recordSolo(d, 40), isTrue); // 더 빠름 → 신기록
    expect(s.soloBest(d), 40);
    expect(s.soloClearCount(d), 3);

    // 난이도 분리
    expect(s.soloBest(Difficulty.expert), isNull);
  });

  test('대전 전적: 승/패/무·승률', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();
    final s = LocalStore.shared;

    s.recordRaceWin();
    s.recordRaceWin();
    s.recordRaceWin();
    s.recordRaceLoss();
    s.recordRaceDraw();

    expect(s.raceWins, 3);
    expect(s.raceLosses, 1);
    expect(s.raceDraws, 1);
    expect(s.raceTotal, 5);
    expect(s.raceWinRate, 75); // 3 / (3+1) = 75% (무는 제외)
  });
}
