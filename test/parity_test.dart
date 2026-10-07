import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mine_app/core/game_model.dart';
import 'package:mine_app/core/local_store.dart';
import 'package:mine_app/core/types.dart';

/// Swift 원본(RankingStore/GameModel)과 동작을 맞춘 규칙들의 회귀 테스트.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('첫 실행 지급·기본값이 Swift와 같다', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await LocalStore.init();
    expect(s.coins, 100);
    expect(s.ownedFlags, 10);
    expect(s.ownedRadars, 5);
    expect(s.ownedMegaphones, 5);
    expect(s.flagHapticsEnabled, isFalse); // 깃발 진동 기본 꺼짐
    expect(s.equippedTitleId, isNull); // 칭호 미착용으로 시작
    expect(s.nickname, isNotEmpty); // 자동 생성 닉네임
    expect(s.nicknameSetByUser, isFalse);
  });

  test('솔로 클리어 코인 보상(초1·중5·고10·최고20)과 황금지뢰 +10', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await LocalStore.init();
    expect(s.awardClearReward(Difficulty.beginner), 1);
    expect(s.awardClearReward(Difficulty.ultimate), 20);
    expect(s.coins, 121);
    s.awardGoldenMine();
    expect(s.coins, 131);
    expect(s.goldenMinesFound, 1);
  });

  test('협동 기록: 성공 횟수 누적 + 최고 기록(짧을수록)', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await LocalStore.init();
    expect(s.recordTouch(90), isTrue);
    expect(s.recordTouch(120), isFalse);
    expect(s.recordTouch(45), isTrue);
    expect(s.touchBest, 45);
    expect(s.touchClears, 3);
  });

  test('솔로 이어하기 스냅샷 왕복 — 같은 판·같은 진행으로 복원', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();
    final a = GameModel()..startSolo(Difficulty.intermediate);
    a.reveal(8, 8);
    expect(a.state, GameState.playing);
    final snap = a.makeResumeSnapshot()!;

    final b = GameModel()..restore(Map<String, dynamic>.from(snap));
    expect(b.difficulty, Difficulty.intermediate);
    expect(b.state, GameState.playing);
    expect(b.seed, a.seed);
    for (var r = 0; r < a.rows; r++) {
      for (var c = 0; c < a.cols; c++) {
        expect(b.grid[r][c].isMine, a.grid[r][c].isMine);
        expect(b.grid[r][c].isRevealed, a.grid[r][c].isRevealed);
      }
    }
    a.dispose();
    b.dispose();
  });

  test('판 코드별 최고 기록이 저장된다', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await LocalStore.init();
    s.recordCodeBest('B-ABC', 30);
    s.recordCodeBest('B-ABC', 40);
    expect(s.bestTimeForCode('B-ABC'), 30);
  });
}
