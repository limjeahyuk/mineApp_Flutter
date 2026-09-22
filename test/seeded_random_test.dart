import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/seeded_random.dart';
import 'package:mine_app/core/board.dart';

/// 결정성 검증: 같은 seed면 항상 같은 결과여야 크로스플레이(공유보드)가 성립한다.
/// (dart:math Random(seed)는 플랫폼 무관 결정적이므로, iOS/Android가 동일 보드를 만든다.)
void main() {
  const seed = 12345;

  /// 같은 seed로 두 번 돌려 수열이 완전히 같은지 확인하는 헬퍼.
  void expectSameSequence(List<Object> Function(SeededGenerator) draw) {
    expect(draw(SeededGenerator(seed)), draw(SeededGenerator(seed)));
  }

  test('nextBounded 재현성', () {
    expectSameSequence((g) => [for (var i = 0; i < 8; i++) g.nextBounded(100)]);
  });

  test('intInRange / intInClosed 재현성', () {
    expectSameSequence((g) => [
          for (var i = 0; i < 8; i++) g.intInRange(0, 100),
          for (var i = 0; i < 8; i++) g.intInClosed(1, 2),
        ]);
  });

  test('doubleInRange 재현성 + 범위', () {
    final g = SeededGenerator(seed);
    for (var i = 0; i < 100; i++) {
      final v = g.doubleInRange(0, 1);
      expect(v >= 0 && v < 1, isTrue);
    }
    expectSameSequence(
        (g) => [for (var i = 0; i < 8; i++) g.doubleInRange(0, 1)]);
  });

  test('nextBool 재현성', () {
    expectSameSequence((g) => [for (var i = 0; i < 8; i++) g.nextBool()]);
  });

  test('shuffle 재현성 (원소 보존)', () {
    final a = [for (var i = 0; i < 10; i++) i];
    final b = [for (var i = 0; i < 10; i++) i];
    SeededGenerator(seed).shuffle(a);
    SeededGenerator(seed).shuffle(b);
    expect(a, b);
    expect(a.toSet(), {for (var i = 0; i < 10; i++) i}); // 원소 유실 없음
  });

  test('randomElement 재현성', () {
    final arr = [for (var i = 0; i < 10; i++) i];
    expectSameSequence((g) => [for (var i = 0; i < 6; i++) g.randomElement(arr)]);
  });

  test('base 보드 생성: 같은 seed면 지뢰/황금 위치 동일', () {
    p() => placeBaseMines(
        difficulty: Difficulty.beginner, seed: seed, safeR: 4, safeC: 4);
    final a = p(), b = p();
    expect(a.mines, b.mines);
    expect(a.golden, b.golden);
    // safe 칸엔 지뢰가 없어야 한다(4*cols+4 인덱스).
    final safeIdx = 4 * Difficulty.beginner.cols + 4;
    expect(a.mines.contains(safeIdx), isFalse);
  });
}
