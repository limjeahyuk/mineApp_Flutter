import 'dart:math' as math;

/// 시드 기반 결정성 난수. 같은 seed면 iOS/Android 어디서든 동일한 수열을 낸다
/// (`dart:math`의 `Random(seed)`는 플랫폼과 무관하게 결정적 — 양쪽 다 Flutter라 이걸로 충분).
///
/// 대전·협동의 공유보드 크로스플레이: 호스트가 정한 seed 하나만 주고받으면
/// 양쪽이 각자 이 클래스로 같은 보드를 생성한다.
///
/// (이전엔 App Store의 옛 Swift 앱과도 매칭시키려고 Swift stdlib 난수를 비트단위로
///  복제했으나, Flutter가 Swift를 완전 대체하기로 하여 표준 Dart 난수로 단순화함.)
class SeededGenerator {
  final math.Random _r;

  SeededGenerator(int seed) : _r = math.Random(seed);

  /// 원시 난수 1회(테스트/결정성 확인용). 32비트 양의 정수.
  int next() => _r.nextInt(1 << 32);

  /// [0, upperBound) 범위 정수.
  int nextBounded(int upperBound) {
    assert(upperBound > 0, 'upperBound must be positive');
    return _r.nextInt(upperBound);
  }

  /// [lower, upper) (half-open).
  int intInRange(int lower, int upper) {
    assert(upper > lower, 'range must not be empty');
    return lower + _r.nextInt(upper - lower);
  }

  /// [lower, upper] (closed).
  int intInClosed(int lower, int upper) {
    assert(upper >= lower, 'range must not be empty');
    return lower + _r.nextInt(upper - lower + 1);
  }

  /// [lower, upper) 실수.
  double doubleInRange(double lower, double upper) =>
      lower + (upper - lower) * _r.nextDouble();

  bool nextBool() => _r.nextBool();

  /// 리스트를 제자리에서 섞는다(Fisher–Yates, dart:math 결정적).
  void shuffle<T>(List<T> a) => a.shuffle(_r);

  /// 복사본을 섞어 반환.
  List<T> shuffled<T>(List<T> src) => List<T>.of(src)..shuffle(_r);

  T randomElement<T>(List<T> a) {
    assert(a.isNotEmpty);
    return a[_r.nextInt(a.length)];
  }
}
