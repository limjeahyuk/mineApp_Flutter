import 'dart:math';

/// 랭킹 한 줄 — 한 번의 클리어 기록(난이도 + 시간). Swift `ScoreEntry` 이식.
/// 로컬 개인 기록(난이도별 최근 50개)과 온라인 랭킹 행에 함께 쓴다.
class ScoreEntry {
  ScoreEntry({
    String? id,
    required this.name,
    required this.difficulty,
    required this.timeSec,
    DateTime? date,
    this.deviceId = '',
    this.title = '',
  })  : id = id ?? _newId(),
        date = date ?? DateTime.now();

  final String id;
  final String name;
  final String difficulty; // Difficulty.label ("초급"…), 협동은 "touch"
  final int timeSec;
  final DateTime date;
  final String deviceId; // 내 기록 식별용(온라인 목록에서 "나" 표시)
  /// 기록 당시 장착 칭호(랭킹 행 배지). 로컬 영속화엔 넣지 않는다(Swift와 동일).
  final String title;

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'difficulty': difficulty,
        'timeSec': timeSec,
        'date': date.millisecondsSinceEpoch / 1000.0,
        'deviceId': deviceId,
      };

  static ScoreEntry? fromJson(Map<String, dynamic> m) {
    final name = m['name'];
    final diff = m['difficulty'];
    final time = m['timeSec'];
    if (name is! String || diff is! String || time is! num) return null;
    final d = m['date'];
    return ScoreEntry(
      id: m['id'] as String?,
      name: name,
      difficulty: diff,
      timeSec: time.toInt(),
      date: d is num
          ? DateTime.fromMillisecondsSinceEpoch((d * 1000).round())
          : DateTime.now(),
      deviceId: (m['deviceId'] as String?) ?? '',
    );
  }

  // Swift JSONEncoder 기본 Date = 2001-01-01 기준 초. 원본 앱의 로컬 기록(UserDefaults)과 같은 형식.
  static const _refEpochSec = 978307200;

  /// 기기 로컬 저장용(원본 Swift `[ScoreEntry]` Codable과 같은 모양 — 옛 앱 기록을 그대로 읽는다).
  Map<String, Object> toLocalJson() => {
        ...toJson(),
        'date': date.millisecondsSinceEpoch / 1000.0 - _refEpochSec,
      };

  static ScoreEntry? fromLocalJson(Map<String, dynamic> m) {
    final d = m['date'];
    return fromJson({...m, 'date': d is num ? d + _refEpochSec : null});
  }

  static String _newId() {
    final r = Random();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}'.toUpperCase();
  }
}
