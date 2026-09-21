/// Swift `SeededGenerator`(SplitMix64) + Swift 표준 라이브러리의 난수 "소비" 방식을
/// Dart에서 비트단위로 동일하게 재현한 것.
///
/// 목적: iOS(Swift)와 Android(Flutter/Dart)가 같은 시드로 **완전히 동일한 보드**를
/// 생성해야 대전·협동의 공유보드 크로스플레이가 성립한다. 정답값은
/// scratchpad/truth.swift 를 실제 Swift stdlib로 실행해 뽑았고
/// (test/seeded_random_test.dart 의 golden vector), 이 파일은 그 값을 재현한다.
///
/// Dart 네이티브(iOS/Android)의 int는 64비트 2의 보수라 곱셈/덧셈이 mod 2^64로 wrap된다.
/// 논리 우측 시프트는 반드시 `>>>` 를 쓴다(`>>`는 부호 확장이라 다름).
library;

class SeededGenerator {
  int _state;

  SeededGenerator(int seed)
      : _state = (seed == 0) ? 0x9E3779B97F4A7C15 : seed;

  /// SplitMix64. 반환값은 64비트 비트패턴(부호 있는 int로 저장됨).
  int next() {
    _state += 0x9E3779B97F4A7C15; // wrap mod 2^64
    var z = _state;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return z ^ (z >>> 31);
  }

  static final BigInt _two64 = BigInt.one << 64;
  static final BigInt _mask64 = _two64 - BigInt.one;

  /// Swift `RandomNumberGenerator.next(upperBound:)` — Lemire의 "nearly divisionless".
  /// upperBound는 부호 없는 값으로 해석. 결과는 [0, upperBound).
  /// 128비트 곱이 필요해 BigInt를 쓴다(보드 생성 시 몇 번만 호출 — 성능 무관).
  int nextBounded(int upperBound) {
    assert(upperBound != 0, 'upperBound cannot be zero.');
    final ub = BigInt.from(upperBound).toUnsigned(64);
    var rnd = BigInt.from(next()).toUnsigned(64);
    var m = rnd * ub;
    var low = m & _mask64;
    var high = m >> 64;
    if (low < ub) {
      final t = ((_two64 - ub) % _two64) % ub; // (0 - ub) mod 2^64, then % ub
      while (low < t) {
        rnd = BigInt.from(next()).toUnsigned(64);
        m = rnd * ub;
        low = m & _mask64;
        high = m >> 64;
      }
    }
    return high.toInt();
  }

  /// Swift `Int.random(in: lower..<upper)` (half-open).
  int intInRange(int lower, int upper) {
    assert(upper > lower, 'range must not be empty');
    final delta = upper - lower; // magnitude
    return lower + nextBounded(delta);
  }

  /// Swift `Int.random(in: lower...upper)` (closed).
  int intInClosed(int lower, int upper) {
    assert(upper >= lower, 'range must not be empty');
    final delta = upper - lower;
    // 전체 범위(Int.min...Int.max)는 이 앱에서 쓰지 않으므로 일반 경로만 구현.
    return lower + nextBounded(delta + 1);
  }

  /// Swift `Double.random(in: 0..<1)` 계열. lower/upper는 half-open.
  /// Swift는 `next(upperBound:)`가 아니라 단일 next()의 하위 53비트 마스크를 쓴다.
  double doubleInRange(double lower, double upper) {
    final delta = upper - lower;
    const significandCount = 53; // Double: significandBitCount(52) + 1
    final maxSignificand = 1 << significandCount; // 2^53
    while (true) {
      final rand = next() & (maxSignificand - 1); // 하위 53비트, next() 1회 소비
      final unitRandom = rand / maxSignificand; // rand * 2^-53
      final v = delta * unitRandom + lower;
      if (v != upper) return v; // Swift는 upper와 같으면 재추첨
    }
  }

  /// Swift `Bool.random(using:)` — 정확히 next() 한 번 소비.
  bool nextBool() => ((next() >>> 17) & 1) == 0;

  /// Swift `MutableCollection.shuffle(using:)` (Durstenfeld, 앞→뒤).
  void shuffle<T>(List<T> a) {
    if (a.length <= 1) return;
    var amount = a.length;
    var i = 0;
    while (amount > 1) {
      final r = intInRange(0, amount);
      amount -= 1;
      final j = i + r;
      final tmp = a[i];
      a[i] = a[j];
      a[j] = tmp;
      i += 1;
    }
  }

  /// Swift `shuffled(using:)` — 복사본을 섞어 반환.
  List<T> shuffled<T>(List<T> src) {
    final a = List<T>.of(src);
    shuffle(a);
    return a;
  }

  /// Swift `Collection.randomElement(using:)`.
  T randomElement<T>(List<T> a) {
    assert(a.isNotEmpty);
    return a[nextBounded(a.length)];
  }
}
