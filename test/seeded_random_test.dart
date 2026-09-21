import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/seeded_random.dart';
import 'package:mine_app/core/board.dart';

/// Golden vector: scratchpad/truth.swift 를 실제 Swift stdlib(macOS)로 실행해 얻은 값.
/// 이 테스트가 통과 = Dart 포팅이 Swift와 비트단위로 동일 = 공유보드 크로스플레이 성립.
/// seed = 12345.
void main() {
  const seed = 12345;

  String u64(int x) => BigInt.from(x).toUnsigned(64).toString();

  test('SplitMix64 next() raw sequence', () {
    final g = SeededGenerator(seed);
    final out = [for (var i = 0; i < 8; i++) u64(g.next())];
    expect(out.join(','),
        '2454886589211414944,3778200017661327597,2205171434679333405,3248800117070709450,9350289611492784363,6217189988962137646,2262534019502804546,7959005890829367068');
  });

  test('Int.random(in: 0..<100)', () {
    final g = SeededGenerator(seed);
    final out = [for (var i = 0; i < 8; i++) g.intInRange(0, 100)];
    expect(out.join(','), '13,20,11,17,50,33,12,43');
  });

  test('Int.random(in: 1...2)', () {
    final g = SeededGenerator(seed);
    final out = [for (var i = 0; i < 8; i++) g.intInClosed(1, 2)];
    expect(out.join(','), '1,1,1,1,2,1,1,1');
  });

  test('Double.random(in: 0..<1)', () {
    final g = SeededGenerator(seed);
    final out = [for (var i = 0; i < 4; i++) g.doubleInRange(0, 1).toString()];
    expect(out.join(','),
        '0.5471614186031282,0.46446512467789847,0.8232100026685348,0.6892692376805709');
  });

  test('Bool.random', () {
    final g = SeededGenerator(seed);
    final out = [for (var i = 0; i < 8; i++) g.nextBool() ? '1' : '0'];
    expect(out.join(','), '1,0,0,0,1,0,0,1');
  });

  test('shuffle([0..<10])', () {
    final g = SeededGenerator(seed);
    final arr = [for (var i = 0; i < 10; i++) i];
    g.shuffle(arr);
    expect(arr.join(','), '1,2,0,4,7,6,5,8,3,9');
  });

  test('randomElement([0..<10]) x6', () {
    final g = SeededGenerator(seed);
    final arr = [for (var i = 0; i < 10; i++) i];
    final out = [for (var i = 0; i < 6; i++) g.randomElement(arr)];
    expect(out.join(','), '1,2,1,1,5,3');
  });

  test('base 모드 보드 생성 (초급, safe (4,4)) — 지뢰/황금 위치 일치', () {
    final p = placeBaseMines(
      difficulty: Difficulty.beginner,
      seed: seed,
      safeR: 4,
      safeC: 4,
    );
    final mines = p.mines.toList()..sort();
    final golden = p.golden.toList()..sort();
    expect(mines.join(','), '1,4,9,10,14,15,27,38,44,72');
    expect(golden.join(','), '38');
  });
}
