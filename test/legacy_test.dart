import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/game_model.dart';
import 'package:mine_app/core/local_store.dart';
import 'package:mine_app/core/types.dart';

import 'prefs_helper.dart';

/// 옛 Swift 앱(같은 번들 ID)에서 업데이트한 사용자 — UserDefaults 키/형식을 그대로 읽는지.
/// (Data·Date·Dictionary는 AppDelegate가 *.json/*Ms 키로 변환해 둔 상태를 가정)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Swift 저장값을 그대로 이어받는다(시작 지급 중복 없음)', () async {
    // 2024-01-01T00:00:00Z = 2001 기준 725760000초
    final records = jsonEncode([
      {
        'id': 'A1',
        'name': '옛유저',
        'difficulty': '초급',
        'timeSec': 42,
        'date': 725760000.0,
        'deviceId': 'DEV-1',
      },
    ]);
    mockSavedPrefs({
      'ranking.deviceId': 'DEV-1',
      'ranking.nickname': '옛유저',
      'ranking.localRecords.json': records,
      'ranking.raceWins': 7,
      'shop.coins': 345,
      'shop.ownedFlags': 3,
      'shop.starterFlagsGranted': true,
      'shop.ownedRadars': 0,
      'shop.starterRadarsGranted': true,
      'shop.ownedMegaphones': 1,
      'shop.starterMegaphonesGranted': true,
      'titles.unlocked': ['grad_beginner'],
      'titles.equipped': 'grad_beginner',
      'daily.day': LocalStore.todayKey(),
      'daily.progress.json': '{"clears":2}',
      'daily.claimed': ['clears'],
    });
    final s = await LocalStore.init();
    expect(s.deviceId, 'DEV-1');
    expect(s.nickname, '옛유저');
    expect(s.coins, 345);
    expect(s.ownedFlags, 3);
    expect(s.ownedRadars, 0);
    expect(s.ownedMegaphones, 1);
    expect(s.raceWins, 7);
    expect(s.isTitleOwned('grad_beginner'), isTrue);
    expect(s.equippedTitleId, 'grad_beginner');
    expect(s.soloBest(Difficulty.beginner), 42);
    expect(s.localRecords.single.date.toUtc(), DateTime.utc(2024));
    expect(s.dailyProgress('clears'), 2);
    expect(s.isDailyClaimed('clears'), isTrue);
  });

  test('Swift SoloSnapshot(칸=딕셔너리, 황금지뢰 키 없음)도 복원된다', () {
    const d = Difficulty.beginner;
    final cells = [
      for (var i = 0; i < d.rows * d.cols; i++)
        {'m': i == 0, 'r': i == 80, 'f': false, 'x': false, 'a': 0},
    ];
    final g = GameModel()
      ..restore({
        'difficulty': d.label,
        'seed': 12345,
        'elapsed': 33,
        'didContinue': false,
        'cells': cells,
      });
    expect(g.state, GameState.playing);
    expect(g.elapsed, 33);
    expect(g.grid[0][0].isMine, isTrue);
    expect(g.grid[8][8].isRevealed, isTrue);
    g.dispose();
  });
}
