import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mine_app/core/local_store.dart';
import 'package:mine_app/core/types.dart';
import 'package:mine_app/modes/touch_model.dart';

/// 협동('너에게 닿기를') 만남→승리 end-to-end 검증.
/// 두 TouchModel(host/guest)을 실서비스의 MatchService처럼 서로 연결해,
/// 보장 안전통로(onPath)를 따라 파 들어가면 만나서 **양쪽 다** 승리하는지 확인한다.
/// (실기기 매칭은 시뮬 네트워크 상황을 타므로, 만남·동기화 로직 자체는 이 결정적 테스트로 고정한다.)
void main() {
  test('두 플레이어가 안전통로로 만나면 둘 다 승리 + 동기화', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStore.init();

    const size = 40;
    const seed = 20240923;
    final host = TouchModel(size: size);
    final guest = TouchModel(size: size);

    // 내가 연 칸/터진 칸을 상대 보드에 반영(FirebaseMatchService 동기화 역할).
    host.onPushReveal = (safe, exp) =>
        guest.applyRemote(SharedBoardState(revealed: safe, exploded: exp));
    guest.onPushReveal = (safe, exp) =>
        host.applyRemote(SharedBoardState(revealed: safe, exploded: exp));

    host.startShared(seed: seed, asHost: true);
    guest.startShared(seed: seed, asHost: false);

    expect(host.state, GameState.playing);
    expect(guest.state, GameState.playing);
    expect(host.won, isFalse);

    // host가 안전통로(onPath, 지뢰 없음)를 프런티어를 따라 상대 쪽으로 판다.
    // onPath는 두 시작점을 연결하므로 결국 guest가 연 영역과 4방향으로 맞닿아 만난다.
    var progressed = true;
    var guard = 0;
    while (!host.won && progressed && guard < size * size) {
      guard++;
      progressed = false;
      for (var r = 0; r < size && !host.won; r++) {
        for (var c = 0; c < size && !host.won; c++) {
          final cell = host.grid[r][c];
          if (cell.onPath && !cell.isRevealed && host.isFrontier(r, c)) {
            host.tap(r, c);
            progressed = true;
          }
        }
      }
    }

    expect(host.won, isTrue, reason: '안전통로를 파면 상대와 만나 승리해야 한다');
    expect(guest.won, isTrue, reason: '만남이 동기화되어 상대도 승리해야 한다');
    expect(host.meetPoint, isNotNull);
  });
}
