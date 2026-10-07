import 'package:flutter/material.dart';

/// 일일 도전과제 — Swift DailyChallenge 이식. 매일 풀에서 결정적으로 3개가 뽑히고,
/// 목표를 채우면 코인을 준다(장기 업적과 달리 매일 갱신 + '받기' 수령).
/// 진행/수령/롤오버 저장은 LocalStore(Swift RankingStore), 카탈로그는 여기(순수 데이터 + 결정적 forDay).

/// 미션 종류. name(rawValue)이 진행/수령 저장 키다 — 바꾸지 않는다.
enum DailyKind { clears, raceWins, golden, draws, touch }

class DailyChallenge {
  const DailyChallenge(this.kind, this.title, this.goal, this.reward, this.icon);
  final DailyKind kind;
  final String title;
  final int goal;
  final int reward;
  final IconData icon;

  String get id => kind.name;

  /// 전체 풀 — 매일 이 중 [dailyCount]개가 뽑힌다. 추가/튜닝은 여기 한 곳에서.
  static const pool = <DailyChallenge>[
    DailyChallenge(DailyKind.clears, '아무 난이도나 3판 클리어', 3, 20, Icons.sports_score),
    DailyChallenge(DailyKind.raceWins, '대전에서 1승 하기', 1, 25, Icons.bolt),
    DailyChallenge(DailyKind.golden, '황금지뢰 5개 발견하기', 5, 20, Icons.workspace_premium),
    DailyChallenge(DailyKind.draws, '뽑기 1회 돌리기', 1, 15, Icons.card_giftcard),
    DailyChallenge(DailyKind.touch, "'너에게 닿기를' 1회 성공", 1, 25, Icons.handshake),
  ];

  static const dailyCount = 3;

  /// 주어진 날짜 키("yyyy-MM-dd")의 오늘 미션(결정적). 날짜+kind FNV-1a 해시로 정렬 후 앞 3개.
  static List<DailyChallenge> forDay(String dayKey) {
    final ordered = [...pool]
      ..sort((a, b) => _hash(dayKey + a.kind.name)
          .compareTo(_hash(dayKey + b.kind.name)));
    return ordered.take(dailyCount).toList();
  }

  static DailyChallenge named(DailyKind kind) =>
      pool.firstWhere((c) => c.kind == kind);

  /// 결정적 해시(FNV-1a, 32bit) — String.hashCode는 실행마다 달라 쓰지 않는다.
  static int _hash(String s) {
    var h = 2166136261;
    for (final b in s.codeUnits) {
      h = (h ^ b) & 0xFFFFFFFF;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }
}
