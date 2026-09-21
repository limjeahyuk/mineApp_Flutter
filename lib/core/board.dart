import 'seeded_random.dart';

/// 난이도 — Swift `Difficulty`와 동일한 수치(보드 크기/지뢰 수/레이더 상한).
enum Difficulty {
  beginner(rows: 9, cols: 9, mineCount: 10, radarCap: 1, code: 'B'),
  intermediate(rows: 16, cols: 16, mineCount: 40, radarCap: 1, code: 'I'),
  expert(rows: 30, cols: 16, mineCount: 99, radarCap: 2, code: 'E'),
  ultimate(rows: 40, cols: 20, mineCount: 190, radarCap: 3, code: 'U');

  const Difficulty({
    required this.rows,
    required this.cols,
    required this.mineCount,
    required this.radarCap,
    required this.code,
  });

  final int rows;
  final int cols;
  final int mineCount;
  final int radarCap;
  final String code;

  bool get prefersLandscape => this == Difficulty.ultimate;

  /// Firestore 매치 문서의 `difficulty` 필드값 — Swift `Difficulty.rawValue`와 동일(한국어).
  String get label {
    switch (this) {
      case Difficulty.beginner:
        return '초급';
      case Difficulty.intermediate:
        return '중급';
      case Difficulty.expert:
        return '고급';
      case Difficulty.ultimate:
        return '최고급';
    }
  }

  static Difficulty? fromLabel(String label) {
    for (final d in Difficulty.values) {
      if (d.label == label) return d;
    }
    return null;
  }

  static Difficulty? fromCode(String c) {
    switch (c.toUpperCase()) {
      case 'B':
        return Difficulty.beginner;
      case 'I':
        return Difficulty.intermediate;
      case 'E':
        return Difficulty.expert;
      case 'U':
        return Difficulty.ultimate;
    }
    return null;
  }
}

const List<List<int>> _offsets = [
  [-1, -1], [-1, 0], [-1, 1],
  [0, -1], [0, 1],
  [1, -1], [1, 0], [1, 1],
];

/// base(솔로/대전) 모드 지뢰 배치 결과. 위치는 `r * cols + c` 인덱스.
class MinePlacement {
  MinePlacement(this.mines, this.golden);
  final Set<int> mines;
  final Set<int> golden;
}

/// Swift `GameModel.placeMines(safeR:safeC:using:)` 의 결정적 부분을 그대로 이식.
/// RNG 소비 순서: candidates.shuffle → Int.random(1...2) → minePositions.shuffled.
MinePlacement placeBaseMines({
  required Difficulty difficulty,
  required int seed,
  required int safeR,
  required int safeC,
}) {
  final rows = difficulty.rows, cols = difficulty.cols;
  bool inB(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  final rng = SeededGenerator(seed);
  final forbidden = <int>{safeR * cols + safeC};
  for (final o in _offsets) {
    final nr = safeR + o[0], nc = safeC + o[1];
    if (inB(nr, nc)) forbidden.add(nr * cols + nc);
  }

  final candidates = [
    for (var i = 0; i < rows * cols; i++)
      if (!forbidden.contains(i)) i,
  ];
  rng.shuffle(candidates);

  final minePositions = candidates.take(difficulty.mineCount).toList();
  final mines = minePositions.toSet();

  // Swift: min(count, Int.random(in:1...2)) — random은 항상 소비된다(min이 둘 다 평가).
  final roll = rng.intInClosed(1, 2);
  final goldenCount = minePositions.length < roll ? minePositions.length : roll;
  final golden =
      rng.shuffled(minePositions).take(goldenCount).toSet();

  return MinePlacement(mines, golden);
}
