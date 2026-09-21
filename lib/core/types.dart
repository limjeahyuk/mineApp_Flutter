// 세 게임 모델이 공유하는 값 타입들. Swift의 흩어진 enum/struct를 한곳에 모았다.

/// 게임 진행 상태
enum GameState { ready, playing, won, lost }

/// 깃발/칸 소유자 — 공유 보드에서 누가 꽂았는지/열었는지 구분.
enum FlagOwner { me, opponent }

/// 대전 승리 규칙.
enum RaceRule {
  speed, // 같은 보드를 더 빨리 클리어한 사람 승 (기본)
  score, // 보드가 끝났을 때 지뢰를 더 많이 찾은 사람 승 (지뢰 대결)
  coop, // 둘이 함께 풀어 클리어. 누구든 지뢰를 밟으면 함께 패배.
}

/// 서버(공유 보드)의 최신 상태 조각 — 상대 동작 수신용.
class SharedBoardState {
  SharedBoardState({
    this.revealed = const [],
    this.exploded = const [],
    this.myFlags = const [],
    this.oppFlags = const [],
  });
  final List<int> revealed; // 열린 안전 칸(공유)
  final List<int> exploded; // 실수로 열린 지뢰 칸(공유)
  final List<int> myFlags; // 내가 꽂은 깃발
  final List<int> oppFlags; // 상대가 꽂은 깃발
}

/// 가챠 아이템 — 한 판 상한(perGameCap)만 로직에 쓰인다.
enum GachaItem {
  flag(3),
  megaphone(2),
  radar(3);

  const GachaItem(this.perGameCap);
  final int perGameCap;
}
