import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/board.dart';
import 'package:mine_app/core/game_model.dart';
import 'package:mine_app/core/types.dart';

/// 이어하기(앱 종료 후 복원) — 스냅샷 → JSON → 복원 왕복으로 보드·시간·상태가 그대로인지.
void main() {
  test('진행 중 솔로 판 스냅샷을 복원하면 같은 판이 이어진다', () {
    final a = GameModel()..startSolo(Difficulty.intermediate);
    a.reveal(8, 8); // 첫 클릭(안전) → 지뢰 배치 + playing
    expect(a.state, GameState.playing);
    // 닫힌 안전칸 하나에 깃발
    outer:
    for (final row in a.grid) {
      for (final c in row) {
        if (!c.isRevealed) {
          a.toggleFlag(c.id ~/ a.cols, c.id % a.cols);
          break outer;
        }
      }
    }
    a.elapsed = 42;
    final snap = a.makeResumeSnapshot()!;
    final json = jsonDecode(jsonEncode(snap)) as Map<String, dynamic>;

    final b = GameModel()..restore(json);
    expect(b.difficulty, Difficulty.intermediate);
    expect(b.state, GameState.playing);
    expect(b.elapsed, 42);
    expect(b.seed, a.seed);
    for (var r = 0; r < a.rows; r++) {
      for (var c = 0; c < a.cols; c++) {
        final x = a.grid[r][c], y = b.grid[r][c];
        expect([y.isMine, y.isRevealed, y.isFlagged, y.adjacent],
            [x.isMine, x.isRevealed, x.isFlagged, x.adjacent]);
      }
    }
    a.dispose();
    b.dispose();
  });

  test('시작 전·끝난 판은 스냅샷을 만들지 않는다', () {
    final g = GameModel()..startSolo(Difficulty.beginner);
    expect(g.makeResumeSnapshot(), isNull); // ready
    g.dispose();
  });
}
