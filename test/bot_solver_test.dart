import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/game_model.dart';
import 'package:mine_app/core/types.dart';
import 'package:mine_app/multiplayer/bot_match_service.dart';
import 'package:mine_app/multiplayer/bot_solver.dart';
import 'package:mine_app/multiplayer/multiplayer.dart';

/// 봇이 한 판을 끝까지 둔다(스피드 규칙). (이김?, 클릭 수, 찍은 수)
(bool, int, int) playOut(Difficulty d, int seed, BotSolver solver) {
  final m = GameModel()
    ..difficulty = d
    ..recordsWins = false;
  final sr = d.rows ~/ 2, sc = d.cols ~/ 2;
  m.startSeededGame(seed, safeR: sr, safeC: sc);
  final known = <int>{};
  var clicks = 0, guesses = 0;
  while (m.state == GameState.playing) {
    final mv = solver.next(m, known, startR: sr, startC: sc)!;
    if (mv.flag) {
      known.add(mv.r * m.cols + mv.c);
      continue;
    }
    // 확정 수는 절대 지뢰면 안 된다(정답을 안 보고도 맞아야 함).
    if (!mv.guess) expect(m.grid[mv.r][mv.c].isMine, isFalse);
    if (mv.guess) guesses++;
    clicks++;
    m.reveal(mv.r, mv.c);
  }
  final won = m.state == GameState.won;
  m.dispose();
  return (won, clicks, guesses);
}

void main() {
  speedBotNeverLoses();

  test('봇은 보이는 정보로만 풀고, 막히면 찍어서 질 수도 있다', () {
    final solver = BotSolver(Random(1));
    for (final d in Difficulty.values) {
      const n = 40;
      var wins = 0, clicks = 0, guesses = 0, winClicks = 0;
      for (var s = 0; s < n; s++) {
        final (w, c, g) = playOut(d, 1000 + s, solver);
        if (w) {
          wins++;
          winClicks += c;
        }
        clicks += c;
        guesses += g;
      }
      // ignore: avoid_print
      print(
        '${d.label}: 승률 ${wins * 100 ~/ n}% · 평균 클릭 ${clicks ~/ n} · 평균 찍기 ${(guesses / n).toStringAsFixed(1)} · 이긴 판 클릭 ${wins == 0 ? '-' : winClicks ~/ wins}',
      );
      expect(wins, greaterThan(0));
    }
  });

  test('모서리 1 · 1-2-1 같은 패턴을 추론한다', () {
    // 3x? 대신 실제 보드 대신 subset 규칙 단위 확인: 초급 판 몇 개에서 찍기 없이 시작 영역을 넓힌다.
    final solver = BotSolver(Random(2));
    final m = GameModel()..difficulty = Difficulty.beginner;
    m.startSeededGame(7, safeR: 4, safeC: 4);
    m.reveal(4, 4);
    final (safe, mines) = solver.deduce(m, {});
    for (final i in safe) {
      expect(m.grid[i ~/ m.cols][i % m.cols].isMine, isFalse);
    }
    for (final i in mines) {
      expect(m.grid[i ~/ m.cols][i % m.cols].isMine, isTrue);
    }
    m.dispose();
  });
}

void speedBotNeverLoses() {
  testWidgets('스피드 봇은 찍어야 할 때도 지뢰를 밟지 않고 끝까지 클리어한다', (tester) async {
    for (final d in Difficulty.values) {
      final times = <int>[];
      for (var i = 0; i < 20; i++) {
        final svc = BotMatchService(rule: RaceRule.speed);
        OpponentStatus? last;
        svc.onOpponent = (s) => last = s;
        final f = svc.find(d, RaceRule.speed);
        await tester.pump(const Duration(seconds: 2));
        await f;
        svc.beginRace();
        var waited = 0; // 게임 타이머는 999초에서 멈추므로 흘려보낸 시간으로 잰다
        for (var t = 0; t < 5000 && last?.phase != RacerPhase.won; t++) {
          expect(
            last?.phase,
            isNot(RacerPhase.lost),
            reason: '${d.label} 봇 탈락',
          );
          await tester.pump(const Duration(seconds: 2));
          waited += 2;
        }
        expect(last?.phase, RacerPhase.won, reason: '${d.label} 봇 미완주');
        times.add(waited);
        svc.leave();
      }
      times.sort();
      String mmss(int s) => '${s ~/ 60}분 ${s % 60}초';
      final avg = times.reduce((a, b) => a + b) ~/ times.length;
      // ignore: avoid_print
      print(
        '${d.label} 봇 완주: 평균 ${mmss(avg)} '
        '(최소 ${mmss(times.first)} · 최대 ${mmss(times.last)})',
      );
    }
  });
}
