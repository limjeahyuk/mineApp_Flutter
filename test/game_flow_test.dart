import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/board.dart';
import 'package:mine_app/core/game_model.dart';
import 'package:mine_app/core/local_store.dart';
import 'package:mine_app/core/theme.dart';
import 'package:mine_app/game/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 솔로 한 판을 실제로 끝까지 진행해 클리어/패배 팝업과 코인 보상·기록이 원본대로 동작하는지.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();
  });

  Widget app(GameModel g) => MaterialApp(
      theme: buildAppTheme(Brightness.dark),
      home: GameScreen(initialDifficulty: Difficulty.beginner, debugGame: g));

  testWidgets('모든 안전칸을 열면 클리어 팝업 + 코인 보상 + 기록', (tester) async {
    final g = GameModel();
    await tester.pumpWidget(app(g));
    g.reveal(4, 4);
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (!g.grid[r][c].isMine && !g.grid[r][c].isRevealed) g.reveal(r, c);
      }
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('클리어!'), findsOneWidget);
    expect(find.text('한 번 더'), findsOneWidget);
    expect(find.text('🏆 최고 기록 경신!'), findsOneWidget);
    expect(LocalStore.shared.coins, 100 + 1, reason: '초급 클리어 보상 1코인');
    expect(LocalStore.shared.soloClearCount(Difficulty.beginner), 1);
    await tester.tap(find.text('결과 보기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('클리어!'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('지뢰를 밟으면 패배 팝업(이어하기 가능) → 이어하기로 계속', (tester) async {
    final g = GameModel();
    await tester.pumpWidget(app(g));
    g.reveal(4, 4);
    late int mr, mc;
    outer:
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (g.grid[r][c].isMine) {
          mr = r;
          mc = c;
          break outer;
        }
      }
    }
    g.reveal(mr, mc);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('지뢰를 밟았어요!'), findsOneWidget);
    expect(find.text('이어하기'), findsOneWidget);
    await tester.tap(find.text('이어하기'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('지뢰를 밟았어요!'), findsNothing);
    expect(g.grid[mr][mc].isFlagged, isTrue, reason: '밟은 지뢰는 깃발로 표시되고 계속');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
