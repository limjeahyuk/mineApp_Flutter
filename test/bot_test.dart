import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/board.dart';
import 'package:mine_app/core/game_model.dart';
import 'package:mine_app/core/types.dart';
import 'package:mine_app/multiplayer/bot_match_service.dart';
import 'package:mine_app/multiplayer/multiplayer.dart';

/// 봇 파트너(합동) — Swift BotMatchService.startCoopBot 이식 검증.
/// 사람 보드(공유)와 봇 미러를 실제로 연결해, 봇이 확정 안전칸만 열어 보드를 넓히고
/// 절대 지뢰를 밟지 않으며(추측 없음) 봇이 연 칸이 사람 화면에 반영되는지 본다.
void main() {
  test('합동 봇은 확정 칸만 열고 지뢰를 밟지 않으며 사람 보드에 반영된다', () {
    // 판에 따라 확정 수가 없으면 봇은 (원본처럼) 사람을 기다린다 → 여러 판에서 검증.
    var grewSomewhere = false;
    for (var round = 0; round < 8; round++) {
      fakeAsync((async) {
        final bot = BotMatchService(rule: RaceRule.coop);
        final human = GameModel();
        MatchInfo? info;
        bot.find(Difficulty.expert, RaceRule.coop).then((i) => info = i);
        async.elapse(const Duration(seconds: 2));
        expect(info!.rule, RaceRule.coop);

        human.difficulty = info!.difficulty;
        human.startSeededGame(info!.seed,
            safeR: info!.safeR, safeC: info!.safeC, rule: RaceRule.coop, shared: true);
        bot.onRemoteBoard = human.applySharedState;
        human.onPushReveal = (safe, exploded) => bot.pushReveal(safe, exploded);
        human.onPushFlag = (i, set) => bot.pushFlag(i, set: set);

        int opened() =>
            human.grid.expand((r) => r).where((c) => c.isRevealed && !c.isMine).length;
        final before = opened();
        bot.beginRace();
        async.elapse(const Duration(seconds: 90));

        expect(human.explodedMines, 0, reason: '합동 봇은 추측하지 않는다');
        expect(human.state, isNot(GameState.lost));
        expect(opened(), greaterThanOrEqualTo(before));
        if (opened() > before) grewSomewhere = true;
        bot.leave();
        human.dispose();
      });
    }
    expect(grewSomewhere, isTrue, reason: '봇이 연 칸이 공유 보드에 반영돼야 한다');
  });

  test('봇 매치에는 봇 이름과 (가끔) 칭호가 붙는다', () {
    fakeAsync((async) {
      final bot = BotMatchService(rule: RaceRule.speed);
      MatchInfo? info;
      bot.find(Difficulty.beginner, RaceRule.speed).then((i) => info = i);
      async.elapse(const Duration(seconds: 2));
      expect(info!.opponentName, endsWith('봇'));
      bot.leave();
    });
  });
}
