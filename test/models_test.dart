import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/board.dart';
import 'package:mine_app/core/game_model.dart';
import 'package:mine_app/core/types.dart';
import 'package:mine_app/modes/touch_model.dart';
import 'package:mine_app/modes/treasure_model.dart';

/// FNV-1a 64bit — truth2.swift와 동일 상수/연산(Dart int는 mod 2^64 wrap).
String fnv(List<int> xs) {
  var h = 1469598103934665603; // FNV offset
  for (final p in xs) {
    h = (h ^ p) * 1099511628211;
  }
  return BigInt.from(h).toUnsigned(64).toString();
}

void main() {
  const seed = 777;

  test('GameModel 첫 클릭 안전 + 내부 지뢰배치 == placeBaseMines', () {
    final g = GameModel();
    g.startSolo(Difficulty.beginner);
    g.startSeeded(12345);
    g.reveal(4, 4); // 첫 클릭 → (4,4) 안전칸으로 지뢰 배치
    expect(g.state, GameState.playing);
    expect(g.grid[4][4].isMine, false);
    expect(g.grid[4][4].isRevealed, true);

    // 순수 함수 결과와 동일해야 한다(내부 placeMines == board.placeBaseMines)
    final expected = placeBaseMines(
      difficulty: Difficulty.beginner,
      seed: 12345,
      safeR: 4,
      safeC: 4,
    );
    final actual = <int>{};
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (g.grid[r][c].isMine) actual.add(r * g.cols + c);
      }
    }
    expect(actual, expected.mines);
    g.dispose();
  });

  test('보드 코드 왕복(makeCode/parse)', () {
    final code = GameModel.makeCode(Difficulty.expert, 0xABCDEF);
    final parsed = GameModel.parse(code);
    expect(parsed, isNotNull);
    expect(parsed!.$1, Difficulty.expert);
    expect(parsed.$2, 0xABCDEF);
  });

  test('Touch 보드 생성 결정성 (size 40, seed 777) — Swift 실측 일치', () {
    final m = TouchModel(size: 40);
    m.startShared(seed: seed, asHost: true);

    expect('${m.myStart.$1},${m.myStart.$2},${m.oppStart.$1},${m.oppStart.$2}',
        '6,6,14,28');

    final mines = <int>[];
    final golden = <int>[];
    for (var r = 0; r < m.size; r++) {
      for (var c = 0; c < m.size; c++) {
        if (m.grid[r][c].isMine) mines.add(r * m.size + c);
        if (m.grid[r][c].isGolden) golden.add(r * m.size + c);
      }
    }
    mines.sort();
    golden.sort();
    final megs = [for (final p in m.megaphones) p.$1 * m.size + p.$2]..sort();

    expect(mines.length, 301);
    expect(fnv(mines), '1219224300736106177');
    expect(golden.join(','), '93,318,541,545,717,726,1129,1393');
    expect(megs.join(','), '35,86,138,842,879');
    m.dispose();
  });

  test('Treasure 보드 생성 결정성 (size 15, seed 777, solo) — Swift 실측 일치', () {
    final m = TreasureModel(size: 15);
    m.start(seed);

    final mines = <int>[];
    final golden = <int>[];
    for (var r = 0; r < m.size; r++) {
      for (var c = 0; c < m.size; c++) {
        if (m.grid[r][c].isMine) mines.add(r * m.size + c);
        if (m.grid[r][c].isGolden) golden.add(r * m.size + c);
      }
    }
    mines.sort();
    golden.sort();

    expect(mines.length, 46);
    expect(fnv(mines), '3137610989423994778');
    expect(golden.join(','), '23,116,132,192,203');
    m.dispose();
  });
}
