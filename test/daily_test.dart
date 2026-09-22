import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mine_app/core/local_store.dart';
import 'package:mine_app/progression/daily.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('forDay: 같은 날짜면 결정적, 정확히 3개', () {
    final a = DailyChallenge.forDay('2026-09-22');
    final b = DailyChallenge.forDay('2026-09-22');
    expect(a.length, DailyChallenge.dailyCount);
    expect(a.map((c) => c.kind), b.map((c) => c.kind)); // 재현성
  });

  test('forDay: 날짜가 바뀌면 조합이 회전한다', () {
    final days = ['2026-09-20', '2026-09-21', '2026-09-22', '2026-09-23', '2026-09-24'];
    final combos = days
        .map((d) =>
            (DailyChallenge.forDay(d).map((c) => c.kind.name).toList()..sort())
                .join(','))
        .toSet();
    expect(combos.length, greaterThan(1)); // 매일 같지 않다
  });

  test('bump은 오늘 뽑힌 미션만 누적하고, claim은 1회만 지급', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();
    final s = LocalStore.shared;

    final today = DailyChallenge.forDay(LocalStore.todayKey());
    final c = today.first;
    final before = s.coins;

    // 목표만큼 누적 → 달성
    for (var i = 0; i < c.goal; i++) {
      Daily.bump(c.kind);
    }
    final st = Daily.state(c.kind);
    expect(st.done, isTrue);
    expect(st.claimed, isFalse);

    // 수령: 보상 지급 + 재수령 불가
    final reward = Daily.claim(c.kind);
    expect(reward, c.reward);
    expect(s.coins, before + c.reward);
    expect(Daily.claim(c.kind), isNull); // 두 번째는 null
    expect(Daily.state(c.kind).claimed, isTrue);

    // 오늘 안 뽑힌 kind는 bump해도 안 쌓인다
    final notToday =
        DailyKind.values.firstWhere((k) => !today.any((x) => x.kind == k));
    Daily.bump(notToday);
    expect(s.dailyProgress(notToday.name), 0);
  });
}
