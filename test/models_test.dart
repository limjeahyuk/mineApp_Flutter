import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/board.dart';
import 'package:mine_app/core/game_model.dart';
import 'package:mine_app/core/types.dart';
import 'package:mine_app/modes/touch_model.dart';
import 'package:mine_app/modes/treasure_model.dart';

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

  // 같은 seed로 두 번 생성해 스냅샷을 비교하는 헬퍼(크로스플레이 결정성 = 이게 성립).
  ({List<int> mines, List<int> golden, String starts}) snapTouch() {
    final m = TouchModel(size: 40);
    m.startShared(seed: seed, asHost: true);
    final mines = <int>[], golden = <int>[];
    for (var r = 0; r < m.size; r++) {
      for (var c = 0; c < m.size; c++) {
        if (m.grid[r][c].isMine) mines.add(r * m.size + c);
        if (m.grid[r][c].isGolden) golden.add(r * m.size + c);
      }
    }
    final s = '${m.myStart.$1},${m.myStart.$2},${m.oppStart.$1},${m.oppStart.$2}';
    m.dispose();
    return (mines: mines..sort(), golden: golden..sort(), starts: s);
  }

  test('Touch 보드: 같은 seed면 재현 + 기본 정합성', () {
    final a = snapTouch(), b = snapTouch();
    expect(a.mines, b.mines);
    expect(a.golden, b.golden);
    expect(a.starts, b.starts);
    expect(a.mines, isNotEmpty);
    expect(a.golden.every(a.mines.contains), isTrue); // 황금지뢰는 지뢰의 부분집합
  });

  ({List<int> mines, List<int> golden}) snapTreasure() {
    final m = TreasureModel(size: 15);
    m.start(seed);
    final mines = <int>[], golden = <int>[];
    for (var r = 0; r < m.size; r++) {
      for (var c = 0; c < m.size; c++) {
        if (m.grid[r][c].isMine) mines.add(r * m.size + c);
        if (m.grid[r][c].isGolden) golden.add(r * m.size + c);
      }
    }
    m.dispose();
    return (mines: mines..sort(), golden: golden..sort());
  }

  test('Treasure 보드: 같은 seed면 재현 + 기본 정합성', () {
    final a = snapTreasure(), b = snapTreasure();
    expect(a.mines, b.mines);
    expect(a.golden, b.golden);
    expect(a.mines, isNotEmpty);
    expect(a.golden.every(a.mines.contains), isTrue);
  });
}
