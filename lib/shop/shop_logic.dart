import 'dart:math';

import '../core/local_store.dart';
import '../core/types.dart';
import '../progression/daily.dart';

/// 가챠(뽑기) 로직 — Swift RankingStore.draw/drawTriple 이식.
/// 코인 차감·아이템 지급은 LocalStore에 위임. 확률은 균등(각 1/3).
class ShopLogic {
  ShopLogic({Random? rng}) : _rng = rng ?? Random();
  final Random _rng;

  LocalStore get _s => LocalStore.shared;

  GachaItem _weightedRandom() {
    final items = GachaItem.values;
    final total = items.fold<double>(0, (a, b) => a + b.drawPercent);
    var r = _rng.nextDouble() * total;
    for (final it in items) {
      if (r < it.drawPercent) return it;
      r -= it.drawPercent;
    }
    return items.last;
  }

  void _grant(GachaItem item, {int count = 1}) {
    switch (item) {
      case GachaItem.flag:
        _s.addFlags(count);
      case GachaItem.megaphone:
        _s.addMegaphones(count);
      case GachaItem.radar:
        _s.addRadars(count);
    }
  }

  /// 단일 뽑기 — 코인 부족이면 null.
  GachaItem? draw() {
    if (!_s.spendCoins(LocalStore.drawCost)) return null;
    final item = _weightedRandom();
    _grant(item);
    _s.addGachaDraws(1);
    Daily.bump(DailyKind.draws);
    return item;
  }

  /// ×3 뽑기 — 3개 결과 + 잭팟(3개 일치 시 모든 아이템 3개씩 추가). 코인 부족이면 null.
  TripleDrawResult? drawTriple() {
    if (!_s.spendCoins(LocalStore.tripleDrawCost)) return null;
    final reels = [_weightedRandom(), _weightedRandom(), _weightedRandom()];
    final jackpot = reels.every((r) => r == reels.first);
    if (jackpot) {
      for (final it in GachaItem.values) {
        _grant(it, count: 3);
      }
      _s.addJackpot();
    } else {
      for (final it in reels) {
        _grant(it);
      }
    }
    _s.addGachaDraws(3);
    Daily.bump(DailyKind.draws, by: 3);
    return TripleDrawResult(reels, jackpot);
  }
}

class TripleDrawResult {
  TripleDrawResult(this.reels, this.jackpot);
  final List<GachaItem> reels;
  final bool jackpot;
}
