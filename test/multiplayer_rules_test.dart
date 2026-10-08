import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/game_model.dart';
import 'package:mine_app/core/local_store.dart';
import 'package:mine_app/core/types.dart';
import 'package:mine_app/modes/coop_controller.dart';
import 'package:mine_app/modes/treasure_controller.dart';
import 'package:mine_app/multiplayer/multiplayer.dart';
import 'package:mine_app/multiplayer/race_controller.dart';

import 'prefs_helper.dart';

/// 두 사람이 한 방에 있는 것처럼 컨트롤러 둘을 메모리에서 잇는 가짜 서비스.
/// FirebaseMatchService와 같은 계약: report→상대 onOpponent, 공유 보드(RTDB)는
/// 방 하나의 상태를 양쪽에 통째로 다시 보내고(myFlags/oppFlags는 받는 쪽 기준), leave→상대 onOpponentLeft.
class _Room {
  _Room(this.seed);
  final int seed;
  Difficulty difficulty = Difficulty.beginner;
  RaceRule rule = RaceRule.speed;
  final reveal = <int>{}, exploded = <int>{};
  final flags = <int, String>{};
  late _Link a, b;
}

class _Link extends MatchService {
  _Link(this.room, this.id, this.isHost);
  final _Room room;
  final String id;
  final bool isHost;
  bool left = false;
  _Link get other => identical(room.a, this) ? room.b : room.a;

  MatchInfo _info() => MatchInfo(
        seed: room.seed,
        difficulty: room.difficulty,
        safeR: room.difficulty.rows ~/ 2,
        safeC: room.difficulty.cols ~/ 2,
        opponentName: other.id,
        rule: room.rule,
        isHost: isHost,
      );

  @override
  Future<MatchInfo> find(Difficulty d, RaceRule r) => createRoom(d, r);
  @override
  Future<MatchInfo> createRoom(Difficulty d, RaceRule r) {
    room
      ..difficulty = d
      ..rule = r;
    return Future.value(_info());
  }

  @override
  Future<MatchInfo> joinRoom(String code) => Future.value(_info());
  @override
  Future<MatchInfo> rematch() => Future.value(_info());
  @override
  void beginRace() {}

  @override
  void report(
      {required double progress,
      required RacerPhase phase,
      required int elapsed,
      required int score}) {
    if (left) return;
    final s = OpponentStatus(
        progress: progress, phase: phase, elapsed: elapsed, score: score);
    Future.microtask(() => other.onOpponent?.call(s));
  }

  void _emit() {
    for (final l in [room.a, room.b]) {
      final s = SharedBoardState(
        revealed: room.reveal.toList(),
        exploded: room.exploded.toList(),
        myFlags: [
          for (final e in room.flags.entries)
            if (e.value == l.id) e.key
        ],
        oppFlags: [
          for (final e in room.flags.entries)
            if (e.value != l.id) e.key
        ],
      );
      Future.microtask(() => l.onRemoteBoard?.call(s));
    }
  }

  @override
  void pushReveal(List<int> safe, List<int> exp) {
    room.reveal.addAll(safe);
    room.exploded.addAll(exp);
    _emit();
  }

  @override
  void pushFlag(int index, {required bool set}) {
    set ? room.flags[index] = id : room.flags.remove(index);
    _emit();
  }

  @override
  void pushPing(int index) => Future.microtask(() => other.onPing?.call(index));
  @override
  void pushFlagPenalty() => Future.microtask(() => other.onFlagPenalty?.call());

  @override
  void leave() {
    if (left) return;
    left = true;
    Future.microtask(() => other.onOpponentLeft?.call());
  }
}

/// 테스트 끝에 정리할 컨트롤러(남은 타이머가 있으면 testWidgets가 실패한다).
final _live = <ChangeNotifier>[];

void _mpTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    for (final c in _live) {
      switch (c) {
        case RaceController x:
          x.leave();
        case TreasureController x:
          x.leave();
        case CoopController x:
          x.leave();
      }
    }
    await tester.pump(const Duration(seconds: 6)); // 기절·핑·폭발 연출 타이머
    for (final c in _live) {
      c.dispose();
    }
    _live.clear();
    await tester.pump(const Duration(seconds: 2));
  });
}

(_Link, _Link) _pair(int seed) {
  final room = _Room(seed);
  room.a = _Link(room, 'A', true);
  room.b = _Link(room, 'B', false);
  return (room.a, room.b);
}

/// 지뢰찾기 대전 두 명을 같은 방에서 시작해 레이스 상태까지 진행.
Future<(RaceController, RaceController)> _race(
    WidgetTester tester, Difficulty d, RaceRule rule) async {
  final (la, lb) = _pair(4242);
  final a = RaceController(la), b = RaceController(lb);
  _live.addAll([a, b]);
  a.start(RaceMode.host(d, rule));
  await tester.pump();
  b.start(RaceMode.join('ROOM'));
  await tester.pump(const Duration(seconds: 3)); // 카운트다운
  expect(a.flow, RaceFlow.racing);
  expect(b.flow, RaceFlow.racing);
  return (a, b);
}

Iterable<(int, int)> _cells(GameModel g, bool Function(Cell) f) sync* {
  for (var r = 0; r < g.rows; r++) {
    for (var c = 0; c < g.cols; c++) {
      if (f(g.grid[r][c])) yield (r, c);
    }
  }
}

Future<void> _clearAll(WidgetTester tester, GameModel g) async {
  for (final (r, c) in _cells(g, (c) => !c.isMine).toList()) {
    if (g.state != GameState.playing) break;
    if (!g.grid[r][c].isRevealed) g.reveal(r, c);
  }
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockSavedPrefs({});
    await LocalStore.init();
  });

  group('지뢰찾기 · 스피드', () {
    _mpTest('먼저 다 열면 승, 상대는 패', (tester) async {
      final (a, b) = await _race(tester, Difficulty.beginner, RaceRule.speed);
      await _clearAll(tester, a.game);
      expect(a.result, RaceResult.win);
      expect(b.result, RaceResult.lose);
    });

    _mpTest('지뢰 밟으면 나만 패 — 상대는 계속하다 다 열면 승', (tester) async {
      final (a, b) = await _race(tester, Difficulty.beginner, RaceRule.speed);
      final (mr, mc) = _cells(a.game, (c) => c.isMine).first;
      a.game.reveal(mr, mc);
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.result, RaceResult.lose);
      expect(b.result, isNull, reason: '상대 지뢰로 내 판이 끝나면 안 된다');
      expect(b.opponent.phase, RacerPhase.lost);
      await _clearAll(tester, b.game);
      expect(b.result, RaceResult.win);
    });

    _mpTest('상대가 나가면 부전승', (tester) async {
      final (a, b) = await _race(tester, Difficulty.beginner, RaceRule.speed);
      a.leave();
      await tester.pump(const Duration(milliseconds: 100));
      expect(b.result, RaceResult.win);
      expect(b.opponentLeft, isTrue);
    });
  });

  group('지뢰찾기 · 지뢰 대결', () {
    _mpTest('지뢰를 모두 차지하면 끝 — 많이 찾은 쪽 승', (tester) async {
      final (a, b) = await _race(tester, Difficulty.beginner, RaceRule.score);
      for (final (r, c) in _cells(a.game, (c) => c.isMine).toList()) {
        a.game.toggleFlag(r, c);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.myScore, Difficulty.beginner.mineCount);
      expect(a.result, RaceResult.win);
      expect(b.result, RaceResult.lose);
      expect(b.opponentScore, Difficulty.beginner.mineCount);
    });

    _mpTest('반씩 찾으면 무승부', (tester) async {
      final (a, b) = await _race(tester, Difficulty.beginner, RaceRule.score);
      final mines = _cells(a.game, (c) => c.isMine).toList();
      for (var i = 0; i < mines.length; i++) {
        final (r, c) = mines[i];
        (i.isEven ? a : b).game.toggleFlag(r, c);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.result, RaceResult.draw);
      expect(b.result, RaceResult.draw);
    });

    _mpTest('지뢰를 밟아도 탈락하지 않는다(그 지뢰는 아무도 못 가짐)', (tester) async {
      final (a, b) = await _race(tester, Difficulty.beginner, RaceRule.score);
      final (mr, mc) = _cells(a.game, (c) => c.isMine).first;
      a.game.reveal(mr, mc);
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.result, isNull);
      expect(b.result, isNull);
      expect(b.game.grid[mr][mc].exploded, isTrue,
          reason: '터진 칸이 상대에게도 보여야 한다');
    });
  });

  group('지뢰찾기 · 합동', () {
    _mpTest('둘이 함께 다 열면 둘 다 승', (tester) async {
      final (a, b) = await _race(tester, Difficulty.expert, RaceRule.coop);
      final safe = _cells(a.game, (c) => !c.isMine).toList();
      for (var i = 0; i < safe.length; i++) {
        final (r, c) = safe[i];
        final g = (i.isEven ? a : b).game;
        if (!g.grid[r][c].isRevealed && g.state == GameState.playing) {
          g.reveal(r, c);
        }
        if (i % 50 == 0) await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.result, RaceResult.win);
      expect(b.result, RaceResult.win);
    });

    _mpTest('누구든 지뢰를 밟으면 둘 다 패', (tester) async {
      final (a, b) = await _race(tester, Difficulty.expert, RaceRule.coop);
      final (mr, mc) = _cells(b.game, (c) => c.isMine).first;
      b.game.reveal(mr, mc);
      await tester.pump(const Duration(milliseconds: 100));
      expect(b.result, RaceResult.lose);
      expect(a.result, RaceResult.lose);
    });
  });

  group('보물찾기', () {
    Future<(TreasureController, TreasureController)> start(
        WidgetTester tester) async {
      final (la, lb) = _pair(777);
      final a = TreasureController(la), b = TreasureController(lb);
      _live.addAll([a, b]);
      a.start(RaceMode.host(Difficulty.beginner, RaceRule.speed));
      b.start(RaceMode.join('ROOM'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.flow, TreasureFlow.racing);
      expect(b.flow, TreasureFlow.racing);
      return (a, b);
    }

    _mpTest('보물을 먼저 열면 승, 상대는 패', (tester) async {
      final (a, b) = await start(tester);
      final g = a.game;
      var moved = true;
      while (moved && !g.won) {
        moved = false;
        for (var r = 0; r < g.size && !g.won; r++) {
          for (var c = 0; c < g.size && !g.won; c++) {
            final cell = g.grid[r][c];
            if (!cell.isRevealed && !cell.isMine && g.isFrontier(r, c)) {
              g.tap(r, c);
              moved = true;
            }
          }
        }
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.result, RaceResult.win);
      expect(b.result, RaceResult.lose);
      expect(b.game.opponentProgress, greaterThan(0.9),
          reason: '상대 진행도가 공유 보드로 보여야 한다');
    });

    _mpTest('지뢰를 5번 밟으면 자멸 — 상대 승', (tester) async {
      final (a, b) = await start(tester);
      final g = a.game;
      while (g.minesHit < 5 && g.state == GameState.playing) {
        final mines = <(int, int)>[];
        final safe = <(int, int)>[];
        for (var r = 0; r < g.size; r++) {
          for (var c = 0; c < g.size; c++) {
            final cell = g.grid[r][c];
            if (cell.isRevealed || !g.isFrontier(r, c)) continue;
            (cell.isMine ? mines : safe).add((r, c));
          }
        }
        final (r, c) = mines.isNotEmpty ? mines.first : safe.first;
        g.tap(r, c);
        await tester.pump(const Duration(seconds: 2)); // 지뢰 기절 1.5초
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.result, RaceResult.lose);
      expect(b.result, RaceResult.win);
      expect(b.opponentFailedByMines, isTrue);
    });

    _mpTest('상대가 나가면 부전승', (tester) async {
      final (a, b) = await start(tester);
      b.leave();
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.result, RaceResult.win);
      expect(a.opponentLeft, isTrue);
    });
  });

  group('너에게 닿기를(협동)', () {
    Future<(CoopController, CoopController)> start(WidgetTester tester) async {
      final (la, lb) = _pair(20240923);
      final a = CoopController(la), b = CoopController(lb);
      _live.addAll([a, b]);
      a.start(RaceMode.host(Difficulty.beginner, RaceRule.coop));
      b.start(RaceMode.join('ROOM'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.flow, CoopFlow.racing);
      expect(b.flow, CoopFlow.racing);
      return (a, b);
    }

    _mpTest('만나면 둘 다 성공', (tester) async {
      final (a, b) = await start(tester);
      final g = a.game;
      var moved = true;
      while (moved && !g.won) {
        moved = false;
        for (var r = 0; r < g.size && !g.won; r++) {
          for (var c = 0; c < g.size && !g.won; c++) {
            final cell = g.grid[r][c];
            if (cell.onPath && !cell.isRevealed && g.isFrontier(r, c)) {
              g.tap(r, c);
              moved = true;
            }
          }
        }
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.result, RaceResult.win);
      expect(b.result, RaceResult.win);
    });

    _mpTest('지뢰를 밟으면 탈락 대신 파트너 깃발 1개가 떨어진다', (tester) async {
      final (a, b) = await start(tester);
      // b가 자기 쪽에 깃발 하나를 꽂아 둔다(어느 칸이든 덮인 칸).
      final (fr, fc) = () {
        for (var r = 0; r < b.game.size; r++) {
          for (var c = 0; c < b.game.size; c++) {
            if (!b.game.grid[r][c].isRevealed) return (r, c);
          }
        }
        throw StateError('덮인 칸 없음');
      }();
      b.game.toggleFlag(fr, fc);
      expect(b.game.grid[fr][fc].isFlagged, isTrue);
      // a가 프런티어 지뢰를 밟는다(없으면 안전칸을 열어 넓힌다).
      final g = a.game;
      while (g.minesHit == 0) {
        (int, int)? mine, safe;
        for (var r = 0; r < g.size && mine == null; r++) {
          for (var c = 0; c < g.size; c++) {
            final cell = g.grid[r][c];
            if (cell.isRevealed || !g.isFrontier(r, c)) continue;
            if (cell.isMine) {
              mine = (r, c);
              break;
            }
            safe ??= (r, c);
          }
        }
        final (r, c) = mine ?? safe!;
        g.tap(r, c);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump(const Duration(seconds: 2));
      expect(a.result, isNull, reason: '협동은 지뢰로 끝나지 않는다');
      expect(b.result, isNull);
      expect(b.game.grid[fr][fc].isFlagged, isFalse, reason: '파트너 깃발이 떨어져야 한다');
    });

    _mpTest('파트너가 나가면 종료(실패)', (tester) async {
      final (a, b) = await start(tester);
      b.leave();
      await tester.pump(const Duration(milliseconds: 100));
      expect(a.result, RaceResult.lose);
      expect(a.opponentLeft, isTrue);
    });
  });
}
