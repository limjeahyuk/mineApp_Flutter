import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/local_store.dart';

/// 칭호(타이틀) 시스템 — Swift Title.swift 이식. 데이터 카탈로그 + 목표 평가 + 해금.
/// 보유/장착/통계는 LocalStore가, 카탈로그(이 파일)는 순수 데이터다.

enum TitleRarity {
  common('일반', Color.fromRGBO(158, 166, 179, 1), CupertinoIcons.rosette),
  rare('레어', Color.fromRGBO(77, 158, 242, 1), CupertinoIcons.checkmark_seal_fill),
  epic('에픽', Color.fromRGBO(171, 117, 245, 1), CupertinoIcons.sparkles),
  legendary('전설', Color.fromRGBO(250, 199, 77, 1), Icons.workspace_premium_rounded);

  const TitleRarity(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

/// 업적 달성 조건.
sealed class Goal {
  const Goal();
}

class ClearsGoal extends Goal {
  const ClearsGoal(this.d, this.n);
  final Difficulty d;
  final int n;
}

class TotalClearsGoal extends Goal {
  const TotalClearsGoal(this.n);
  final int n;
}

class BestUnderGoal extends Goal {
  const BestUnderGoal(this.d, this.sec);
  final Difficulty d;
  final int sec;
}

class RaceWinsGoal extends Goal {
  const RaceWinsGoal(this.n);
  final int n;
}

class WinStreakGoal extends Goal {
  const WinStreakGoal(this.n);
  final int n;
}

class NoItemClearGoal extends Goal {
  const NoItemClearGoal(this.d, this.n);
  final Difficulty d;
  final int n;
}

class GoldenMinesGoal extends Goal {
  const GoldenMinesGoal(this.n);
  final int n;
}

class DrawsGoal extends Goal {
  const DrawsGoal(this.n);
  final int n;
}

class JackpotGoal extends Goal {
  const JackpotGoal(this.n);
  final int n;
}

class CoinsAtLeastGoal extends Goal {
  const CoinsAtLeastGoal(this.n);
  final int n;
}

/// 협동("너에게 닿기를") 누적 성공 횟수.
class TouchClearsGoal extends Goal {
  const TouchClearsGoal(this.n);
  final int n;
}

/// 협동 최고 기록이 sec초 이내.
class TouchUnderGoal extends Goal {
  const TouchUnderGoal(this.sec);
  final int sec;
}

/// 색상 테마 보유 수(클래식 포함).
class ThemesOwnedGoal extends Goal {
  const ThemesOwnedGoal(this.n);
  final int n;
}

/// 협동/테마 등 미이식 스탯에 기대는 목표(항상 진행 0으로 잠김).
class UnportedGoal extends Goal {
  const UnportedGoal(this.n);
  final int n;
}

enum TitleSourceKind { starter, achievement, purchase }

class TitleSource {
  const TitleSource.starter()
      : kind = TitleSourceKind.starter,
        goal = null,
        cost = 0;
  const TitleSource.achievement(this.goal)
      : kind = TitleSourceKind.achievement,
        cost = 0;
  const TitleSource.purchase(this.cost)
      : kind = TitleSourceKind.purchase,
        goal = null;

  final TitleSourceKind kind;
  final Goal? goal;
  final int cost;
}

class Title {
  const Title(this.id, this.name, this.rarity, this.source, this.hint,
      {this.hidden = false});
  final String id;
  final String name;
  final TitleRarity rarity;
  final TitleSource source;
  final String hint;
  final bool hidden;

  int? get purchaseCost =>
      source.kind == TitleSourceKind.purchase ? source.cost : null;

  /// 전체 카탈로그(단일 출처) — Swift Title.all과 동일.
  static const List<Title> all = [
    // 스타터
    Title('rookie', '지뢰 입문자', TitleRarity.common, TitleSource.starter(),
        '처음부터 함께하는 칭호'),
    // 클리어형
    Title('grad_beginner', '초급 졸업', TitleRarity.common,
        TitleSource.achievement(ClearsGoal(Difficulty.beginner, 10)),
        '초급 10회 클리어'),
    Title('hunter_inter', '중급 사냥꾼', TitleRarity.rare,
        TitleSource.achievement(ClearsGoal(Difficulty.intermediate, 10)),
        '중급 10회 클리어'),
    Title('expert_pro', '고급 전문가', TitleRarity.rare,
        TitleSource.achievement(ClearsGoal(Difficulty.expert, 10)),
        '고급 10회 클리어'),
    Title('ultimate_conq', '최고급 정복자', TitleRarity.epic,
        TitleSource.achievement(ClearsGoal(Difficulty.ultimate, 5)),
        '최고급 5회 클리어'),
    Title('mine_master', '지뢰 마스터', TitleRarity.epic,
        TitleSource.achievement(TotalClearsGoal(100)), '전체 100회 클리어'),
    Title('flawless_expert', '고급 무결점', TitleRarity.epic,
        TitleSource.achievement(NoItemClearGoal(Difficulty.expert, 1)),
        '아이템 없이 고급 클리어'),
    Title('flawless_ultimate', '최고급 무결점', TitleRarity.legendary,
        TitleSource.achievement(NoItemClearGoal(Difficulty.ultimate, 1)),
        '아이템 없이 최고급 클리어'),
    // 스피드형
    Title('speedrunner', '스피드러너', TitleRarity.rare,
        TitleSource.achievement(BestUnderGoal(Difficulty.beginner, 5)),
        '초급을 5초 이내에 클리어'),
    Title('flash_inter', '전광석화', TitleRarity.epic,
        TitleSource.achievement(BestUnderGoal(Difficulty.intermediate, 40)),
        '중급을 40초 이내에 클리어'),
    // 대전형
    Title('race_rookie', '대전 새내기', TitleRarity.common,
        TitleSource.achievement(RaceWinsGoal(1)), '대전에서 1승'),
    Title('streak5', '연승가도', TitleRarity.rare,
        TitleSource.achievement(WinStreakGoal(5)), '대전 5연승'),
    Title('duelist', '승부사', TitleRarity.epic,
        TitleSource.achievement(RaceWinsGoal(50)), '대전에서 50승'),
    // 협동형
    Title('soulmate', '환상의 짝꿍', TitleRarity.rare,
        TitleSource.achievement(TouchClearsGoal(10)), "'너에게 닿기를' 10회 성공"),
    Title('telepathy', '텔레파시', TitleRarity.epic,
        TitleSource.achievement(TouchUnderGoal(30)), "'너에게 닿기를' 30초 이내 성공"),
    // 경제/뽑기형
    Title('golden_hand', '황금손', TitleRarity.rare,
        TitleSource.achievement(GoldenMinesGoal(100)), '황금지뢰 100개 발견'),
    Title('gacha_addict', '뽑기 중독', TitleRarity.rare,
        TitleSource.achievement(DrawsGoal(100)), '뽑기 100회'),
    Title('collector', '수집가', TitleRarity.rare,
        TitleSource.achievement(ThemesOwnedGoal(3)), '색상 테마 3개 보유'),
    // 히든
    Title('jackpot', '잭팟 주인공', TitleRarity.legendary,
        TitleSource.achievement(JackpotGoal(1)), 'x3 뽑기에서 잭팟 터뜨리기',
        hidden: true),
    Title('millionaire', '지뢰 백만장자', TitleRarity.epic,
        TitleSource.achievement(CoinsAtLeastGoal(9999)), '코인 9,999개 보유',
        hidden: true),
    // 구매형
    Title('supporter', '후원자', TitleRarity.rare, TitleSource.purchase(1000),
        '상점에서 코인으로 구매'),
    Title('gold_member', '골드 멤버', TitleRarity.epic, TitleSource.purchase(1500),
        '상점에서 코인으로 구매'),
    Title('vip', 'VIP', TitleRarity.legendary, TitleSource.purchase(5000),
        '상점에서 코인으로 구매'),
  ];

  static Title? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static Title? byName(String name) {
    for (final t in all) {
      if (t.name == name) return t;
    }
    return null;
  }

  static List<Title> get achievements =>
      all.where((t) => t.source.kind == TitleSourceKind.achievement).toList();
  static List<Title> get purchasables =>
      all.where((t) => t.purchaseCost != null).toList();
}

/// 목표 진행도 (현재값, 목표값, 달성여부). Swift RankingStore.goalProgress 이식.
({int current, int target, bool done}) goalProgress(Goal g) {
  final s = LocalStore.shared;
  int totalClears() =>
      Difficulty.values.fold(0, (a, d) => a + s.soloClearCount(d));

  switch (g) {
    case ClearsGoal(:final d, :final n):
      final c = s.soloClearCount(d);
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case TotalClearsGoal(:final n):
      final c = totalClears();
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case BestUnderGoal(:final d, :final sec):
      final best = s.soloBest(d);
      final done = best != null && best <= sec;
      return (current: done ? sec : 0, target: sec, done: done);
    case RaceWinsGoal(:final n):
      final c = s.raceWins;
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case WinStreakGoal(:final n):
      final c = s.bestWinStreak;
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case NoItemClearGoal(:final d, :final n):
      final c = d == Difficulty.expert
          ? s.noItemExpertClears
          : s.noItemUltimateClears;
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case GoldenMinesGoal(:final n):
      final c = s.goldenMinesFound;
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case DrawsGoal(:final n):
      final c = s.gachaDraws;
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case JackpotGoal(:final n):
      final c = s.gachaJackpots;
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case CoinsAtLeastGoal(:final n):
      final c = s.coins;
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case TouchClearsGoal(:final n):
      final c = s.touchClears;
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case TouchUnderGoal(:final sec):
      final best = s.touchBest;
      final done = best != null && best <= sec;
      return (current: done ? sec : 0, target: sec, done: done);
    case ThemesOwnedGoal(:final n):
      final c = s.ownedThemeIds.length;
      return (current: c.clamp(0, n), target: n, done: c >= n);
    case UnportedGoal(:final n):
      return (current: 0, target: n, done: false);
  }
}

/// 달성한 업적 칭호를 해금한다. 새로 해금된 칭호 목록 반환.
List<Title> refreshAchievements() {
  final s = LocalStore.shared;
  final newly = <Title>[];
  for (final t in Title.achievements) {
    final goal = t.source.goal;
    if (goal == null) continue;
    if (goalProgress(goal).done && !s.isTitleOwned(t.id)) {
      s.unlockTitle(t.id);
      newly.add(t);
    }
  }
  return newly;
}

/// 칭호 배지 — Swift TitleBadgeView 이식(희귀도 색 캡슐 + 아이콘).
class TitleBadge extends StatelessWidget {
  const TitleBadge({super.key, required this.name, this.size = 10});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();
    final rarity = Title.byName(name)?.rarity ?? TitleRarity.common;
    final c = rarity.color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.8, vertical: size * 0.3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.24), c.withValues(alpha: 0.10)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: c.withValues(alpha: 0.45), width: 0.8),
        boxShadow: rarity == TitleRarity.legendary
            ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 1))]
            : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(rarity.icon, size: size, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: c)),
        ),
      ]),
    );
  }
}
