import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mine_app/core/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('첫 실행 시작 지급 + 소비/충전', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();
    final s = LocalStore.shared;

    expect(s.ownedFlags, 10); // 시작 지급
    expect(s.ownedRadars, 5);

    s.consumeFlag();
    s.consumeRadar();
    expect(s.ownedFlags, 9);
    expect(s.ownedRadars, 4);

    s.addFlags(3);
    expect(s.ownedFlags, 12);

    // 0 아래로 안 내려감
    for (var i = 0; i < 20; i++) {
      s.consumeRadar();
    }
    expect(s.ownedRadars, 0);
  });
}
