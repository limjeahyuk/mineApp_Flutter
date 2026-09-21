import 'dart:math';

import '../core/board.dart';
import '../core/types.dart';

export '../core/types.dart' show RaceRule, SharedBoardState;

/// RaceRule의 로직 확장(제목/부제는 UI 단계에서). Swift RaceRule 대응.
extension RaceRuleX on RaceRule {
  /// 한 보드를 실시간 공유하는 규칙인지(지뢰 대결·합동). 스피드는 같은 보드를 각자 푼다.
  bool get sharesBoard => this == RaceRule.score || this == RaceRule.coop;

  /// 이 규칙에서 고를 수 있는 난이도(합동은 고급·최고급만).
  List<Difficulty> get allowedDifficulties => this == RaceRule.coop
      ? const [Difficulty.expert, Difficulty.ultimate]
      : Difficulty.values;

  String get ruleKey {
    switch (this) {
      case RaceRule.speed:
        return 'speed';
      case RaceRule.score:
        return 'score';
      case RaceRule.coop:
        return 'coop';
    }
  }

  static RaceRule fromKey(String? key) {
    switch (key) {
      case 'score':
        return RaceRule.score;
      case 'coop':
        return RaceRule.coop;
      default:
        return RaceRule.speed;
    }
  }
}

/// 매치 정보 — 서버가 양쪽에 동일하게 전달. 같은 seed → 동일 보드.
class MatchInfo {
  MatchInfo({
    required this.seed,
    required this.difficulty,
    required this.safeR,
    required this.safeC,
    required this.opponentName,
    this.rule = RaceRule.speed,
    this.isHost = false,
    this.opponentTitle = '',
  });
  final int seed;
  final Difficulty difficulty;
  final int safeR;
  final int safeC;
  final String opponentName;
  final RaceRule rule;
  final bool isHost;
  final String opponentTitle;
}

/// 레이스 진입 방식 — 홈/메뉴에서 고른 모드. (오프라인 봇은 미이식)
enum RaceModeKind { quick, host, join }

class RaceMode {
  RaceMode.quick(Difficulty this.difficulty, this.rule)
      : kind = RaceModeKind.quick,
        code = null;
  RaceMode.host(Difficulty this.difficulty, this.rule)
      : kind = RaceModeKind.host,
        code = null;
  RaceMode.join(String this.code)
      : kind = RaceModeKind.join,
        difficulty = null,
        rule = RaceRule.speed;

  final RaceModeKind kind;
  final Difficulty? difficulty;
  final RaceRule rule;
  final String? code;
}

/// 레이서(나/상대)의 진행 상태
enum RacerPhase {
  playing,
  won,
  lost;

  String get key {
    switch (this) {
      case RacerPhase.playing:
        return 'playing';
      case RacerPhase.won:
        return 'won';
      case RacerPhase.lost:
        return 'lost';
    }
  }

  /// 서버 키 → phase. "left"는 lost로 취급(부전승 처리는 별도 콜백).
  static RacerPhase fromKey(String? key) {
    switch (key) {
      case 'won':
        return RacerPhase.won;
      case 'lost':
      case 'left':
        return RacerPhase.lost;
      default:
        return RacerPhase.playing;
    }
  }
}

/// 상대의 현재 상황
class OpponentStatus {
  OpponentStatus({
    this.progress = 0,
    this.phase = RacerPhase.playing,
    this.elapsed = 0,
    this.score = 0,
  });
  final double progress;
  final RacerPhase phase;
  final int elapsed;
  final int score;
}

enum RaceResult { win, lose, draw }

/// 매칭 중 발생할 수 있는 오류
enum MatchError implements Exception {
  roomNotFound('해당 코드의 방을 찾을 수 없어요'),
  roomFull('이미 다른 상대가 입장한 방이에요'),
  cancelled('취소되었습니다'),
  opponentLeft('상대가 게임에서 나갔어요'),
  noOpponent('상대를 찾지 못했어요. 잠시 후 다시 시도해 주세요');

  const MatchError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 친구 초대용 방 코드 — 헷갈리는 글자(0·O·1·I·L) 제외 6자리.
class RoomCode {
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static final _rng = Random();

  static String generate([int length = 6]) =>
      List.generate(length, (_) => _alphabet[_rng.nextInt(_alphabet.length)])
          .join();

  static String normalize(String raw) => raw
      .toUpperCase()
      .split('')
      .where(_alphabet.contains)
      .join();
}

/// 매치메이킹 + 상대 동기화 추상화. FirebaseMatchService가 구현한다.
/// 콜백은 필드로 두고 구현체가 그대로 상속해 쓴다(Swift protocol의 var 프로퍼티 대응).
abstract class MatchService {
  void Function(OpponentStatus)? onOpponent;
  void Function(String code)? onRoomCode;
  void Function(SharedBoardState)? onRemoteBoard;
  void Function()? onOpponentLeft;
  void Function(int index)? onPing;
  void Function()? onFlagPenalty;

  Future<MatchInfo> find(Difficulty difficulty, RaceRule rule);
  Future<MatchInfo> createRoom(Difficulty difficulty, RaceRule rule);
  Future<MatchInfo> joinRoom(String code);
  Future<MatchInfo> rematch();
  void beginRace();
  void report(
      {required double progress,
      required RacerPhase phase,
      required int elapsed,
      required int score});
  void pushReveal(List<int> safe, List<int> exploded);
  void pushFlag(int index, {required bool set});
  void pushPing(int index) {}
  void pushFlagPenalty() {}
  void leave();
}
