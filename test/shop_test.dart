import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mine_app/core/local_store.dart';
import 'package:mine_app/core/types.dart';
import 'package:mine_app/shop/shop_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('뽑기: 코인 차감 + 아이템 지급, 부족하면 null', () async {
    SharedPreferences.setMockInitialValues({'shop.coins': 60});
    await LocalStore.init();
    final s = LocalStore.shared;
    final shop = ShopLogic(rng: Random(1));

    final before = s.ownedFlags + s.ownedMegaphones + s.ownedRadars;

    final a = shop.draw();
    expect(a, isNotNull);
    expect(s.coins, 30); // 60 - 30
    expect(s.ownedFlags + s.ownedMegaphones + s.ownedRadars, before + 1);

    final b = shop.draw();
    expect(b, isNotNull);
    expect(s.coins, 0);

    // 코인 0 → 더는 못 뽑음
    expect(shop.draw(), isNull);
    expect(s.coins, 0);
  });

  test('×3 뽑기: 90코인 차감 + 3개 지급', () async {
    SharedPreferences.setMockInitialValues({'shop.coins': 100});
    await LocalStore.init();
    final s = LocalStore.shared;
    final shop = ShopLogic(rng: Random(2));
    final before = s.ownedFlags + s.ownedMegaphones + s.ownedRadars;

    final r = shop.drawTriple();
    expect(r, isNotNull);
    expect(r!.reels.length, 3);
    expect(s.coins, 10); // 100 - 90
    final gained = s.ownedFlags + s.ownedMegaphones + s.ownedRadars - before;
    // 잭팟이면 모든 아이템 3개씩(9), 아니면 3개
    expect(gained, r.jackpot ? GachaItem.values.length * 3 : 3);
  });

  test('광고 무료 코인: 하루 5회 한도', () async {
    SharedPreferences.setMockInitialValues({'shop.coins': 0});
    await LocalStore.init();
    final s = LocalStore.shared;

    for (var i = 0; i < LocalStore.dailyAdLimit; i++) {
      expect(s.claimRewardedAd(), LocalStore.adRewardCoins);
    }
    expect(s.remainingRewardedAds, 0);
    expect(s.claimRewardedAd(), isNull); // 한도 소진
    expect(s.coins, LocalStore.dailyAdLimit * LocalStore.adRewardCoins);
  });
}
