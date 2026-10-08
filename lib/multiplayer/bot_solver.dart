import 'dart:math';

import '../core/game_model.dart';

/// 봇의 한 수.
class BotMove {
  const BotMove(this.r, this.c, {this.flag = false, this.guess = false});
  final int r, c;
  final bool flag; // true = 지뢰로 확정해 깃발
  final bool guess; // true = 확정 못 해서 찍는 수(지뢰일 수 있음)
}

/// 봇의 '눈' — 화면에 보이는 정보(열린 숫자·깃발·터진 지뢰)만으로 다음 수를 고른다.
/// 정답(isMine)은 보지 않는다. 사람이 쓰는 규칙으로 푼다:
/// - 단일 규칙: 숫자 = 주변 확정 지뢰 수면 나머지는 안전, 숫자 - 확정 = 남은 칸 수면 전부 지뢰(모서리 1 등).
/// - 부분집합 규칙: 한 숫자의 미확정 칸이 다른 숫자의 미확정 칸에 포함되면 차이 칸을 확정(1-2-1, 1-2-2-1, 1-1 등).
/// 그래도 막히면 지뢰 확률이 가장 낮아 보이는 칸을 찍는다 → 50:50이면 진짜로 질 수 있다.
class BotSolver {
  BotSolver(this.rng);
  final Random rng;

  static const _offsets = [
    [-1, -1],
    [-1, 0],
    [-1, 1],
    [0, -1],
    [0, 1],
    [1, -1],
    [1, 0],
    [1, 1],
  ];

  /// 확정 안전 칸 / 확정 지뢰 칸(인덱스 r*cols+c). [knownMines] = 봇이 이미 지뢰로 알고 있는 칸.
  (Set<int> safe, Set<int> mines) deduce(GameModel m, Set<int> knownMines) {
    final safe = <int>{};
    final mines = <int>{...knownMines};
    // 새로 확정되면 다시 돌린다(연쇄 추론). 판이 커도 몇 바퀴면 수렴.
    for (var pass = 0; pass < 30; pass++) {
      final cons = _constraints(m, safe, mines);
      var changed = false;
      for (final (cells, need) in cons) {
        if (need == 0) {
          changed |= _addAll(safe, cells);
        } else if (need == cells.length) {
          changed |= _addAll(mines, cells);
        }
      }
      if (!changed) changed = _subsetRule(cons, safe, mines);
      if (!changed) break;
    }
    return (safe, mines.difference(knownMines));
  }

  /// 다음 수. 아무것도 안 열렸으면 시작 칸(모두에게 공개된 안전 칸)을 연다.
  /// [allowGuess]가 false면 확정 수가 없을 때 null(기다림).
  BotMove? next(
    GameModel m,
    Set<int> knownMines, {
    required int startR,
    required int startC,
    bool allowGuess = true,
  }) {
    if (!_anyRevealed(m)) return BotMove(startR, startC);
    final (safe, mines) = deduce(m, knownMines);
    if (safe.isNotEmpty) {
      final i = safe.elementAt(rng.nextInt(safe.length));
      return BotMove(i ~/ m.cols, i % m.cols);
    }
    if (mines.isNotEmpty) {
      final i = mines.elementAt(rng.nextInt(mines.length));
      return BotMove(i ~/ m.cols, i % m.cols, flag: true);
    }
    // 단순 규칙으로 막히면 경계 칸의 가능한 지뢰 배치를 전부 따져 본다.
    final (g, p, exact) = _bestGuess(m, knownMines);
    if (g == null) return null;
    final sure = exact && p == 0; // 모든 배치에서 안전 → 찍기가 아니라 확정
    if (!sure && !allowGuess) return null;
    return BotMove(g ~/ m.cols, g % m.cols, guess: !sure);
  }

  // ── 내부 ──

  /// 열린 숫자마다 (아직 모르는 주변 칸들, 그 안의 남은 지뢰 수).
  List<(Set<int>, int)> _constraints(
    GameModel m,
    Set<int> safe,
    Set<int> mines,
  ) {
    final out = <(Set<int>, int)>[];
    for (var r = 0; r < m.rows; r++) {
      for (var c = 0; c < m.cols; c++) {
        final cell = m.grid[r][c];
        if (!cell.isRevealed || cell.exploded || cell.adjacent == 0) continue;
        final hidden = <int>{};
        var known = 0;
        for (final o in _offsets) {
          final nr = r + o[0], nc = c + o[1];
          if (nr < 0 || nr >= m.rows || nc < 0 || nc >= m.cols) continue;
          final n = m.grid[nr][nc];
          final i = nr * m.cols + nc;
          if (n.exploded || n.isFlagged || mines.contains(i)) {
            known += 1;
          } else if (!n.isRevealed && !safe.contains(i)) {
            hidden.add(i);
          }
        }
        if (hidden.isNotEmpty) out.add((hidden, cell.adjacent - known));
      }
    }
    return out;
  }

  bool _subsetRule(List<(Set<int>, int)> cons, Set<int> safe, Set<int> mines) {
    // 칸 → 그 칸을 포함하는 제약들(겹치는 쌍만 비교).
    final byCell = <int, List<int>>{};
    for (var k = 0; k < cons.length; k++) {
      for (final i in cons[k].$1) {
        (byCell[i] ??= []).add(k);
      }
    }
    var changed = false;
    for (var a = 0; a < cons.length; a++) {
      final (ac, an) = cons[a];
      final others = <int>{for (final i in ac) ...byCell[i]!}..remove(a);
      for (final b in others) {
        final (bc, bn) = cons[b];
        if (bc.length <= ac.length || !bc.containsAll(ac)) continue;
        final diff = bc.difference(ac);
        final dn = bn - an;
        if (dn == 0) {
          changed |= _addAll(safe, diff);
        } else if (dn == diff.length) {
          changed |= _addAll(mines, diff);
        }
      }
    }
    return changed;
  }

  /// 찍을 칸과 그 칸의 지뢰 확률. 경계 칸은 연결된 묶음별로 가능한 지뢰 배치를 전부 세어
  /// 칸마다 '지뢰인 배치 비율'을 구하고(정확), 안쪽 칸은 남은 지뢰 밀도로 어림한다.
  /// exact=false면 배치가 너무 많아 중간에 끊은 어림값.
  /// ponytail: 남은 지뢰 총수로 배치에 가중치를 주지 않는다 — 막판 정확도가 아쉬우면 추가.
  (int?, double, bool) _bestGuess(GameModel m, Set<int> knownMines) {
    final cons = _constraints(m, const {}, knownMines);
    final risk = <int, double>{};
    var exact = true;
    for (final comp in _components(cons)) {
      final (probs, ok) = _enumerate(comp);
      exact &= ok;
      risk.addAll(probs);
    }
    final interior = <int>[];
    var unknown = 0, foundMines = 0;
    for (var r = 0; r < m.rows; r++) {
      for (var c = 0; c < m.cols; c++) {
        final cell = m.grid[r][c];
        final i = r * m.cols + c;
        if (cell.exploded || cell.isFlagged || knownMines.contains(i)) {
          foundMines += 1;
        } else if (!cell.isRevealed) {
          unknown += 1;
          if (!risk.containsKey(i)) interior.add(i);
        }
      }
    }
    if (unknown == 0) return (null, 1, false);
    final density = (m.difficulty.mineCount - foundMines) / unknown;
    var best = <int>[];
    var bestP = 2.0;
    var bestExact = false;
    void consider(int i, double p, bool isExact) {
      if (p < bestP - 1e-9) {
        bestP = p;
        best = [i];
        bestExact = isExact;
      } else if ((p - bestP).abs() < 1e-9) {
        best.add(i);
      }
    }

    risk.forEach((i, p) => consider(i, p, exact));
    if (interior.isNotEmpty) {
      consider(interior[rng.nextInt(interior.length)], density, false);
    }
    if (best.isEmpty) return (null, 1, false);
    return (best[rng.nextInt(best.length)], bestP, bestExact);
  }

  /// 칸을 공유하는 숫자 제약끼리 묶는다(서로 독립인 묶음은 따로 센다).
  List<List<(Set<int>, int)>> _components(List<(Set<int>, int)> cons) {
    final parent = List<int>.generate(cons.length, (i) => i);
    int find(int x) => parent[x] == x ? x : (parent[x] = find(parent[x]));
    final owner = <int, int>{};
    for (var k = 0; k < cons.length; k++) {
      for (final i in cons[k].$1) {
        final o = owner[i];
        if (o == null) {
          owner[i] = k;
        } else {
          parent[find(o)] = find(k);
        }
      }
    }
    final groups = <int, List<(Set<int>, int)>>{};
    for (var k = 0; k < cons.length; k++) {
      (groups[find(k)] ??= []).add(cons[k]);
    }
    return groups.values.toList();
  }

  /// 한 묶음의 모든 지뢰 배치를 백트래킹으로 세어 칸별 지뢰 확률을 낸다.
  /// 탐색량이 상한을 넘으면 그때까지 센 값으로 어림(ok=false).
  (Map<int, double>, bool) _enumerate(List<(Set<int>, int)> comp) {
    final cells = <int>{for (final (c, _) in comp) ...c}.toList();
    final idx = {for (var k = 0; k < cells.length; k++) cells[k]: k};
    // 칸 k가 속한 제약들, 제약별 (필요 지뢰, 아직 안 정한 칸 수, 현재 지뢰 수)
    final cellCons = List.generate(cells.length, (_) => <int>[]);
    final need = <int>[], left = <int>[], have = <int>[];
    for (var j = 0; j < comp.length; j++) {
      final (cs, n) = comp[j];
      need.add(n);
      left.add(cs.length);
      have.add(0);
      for (final i in cs) {
        cellCons[idx[i]!].add(j);
      }
    }
    final mineCount = List<int>.filled(cells.length, 0);
    final assign = List<bool>.filled(cells.length, false);
    var solutions = 0, nodes = 0;
    const maxNodes = 200000;
    var ok = true;

    bool fits(int k) {
      for (final j in cellCons[k]) {
        if (have[j] > need[j] || have[j] + left[j] < need[j]) return false;
      }
      return true;
    }

    void go(int k) {
      if (!ok) return;
      if (++nodes > maxNodes) {
        ok = false;
        return;
      }
      if (k == cells.length) {
        solutions++;
        for (var t = 0; t < cells.length; t++) {
          if (assign[t]) mineCount[t]++;
        }
        return;
      }
      for (final mine in const [false, true]) {
        assign[k] = mine;
        for (final j in cellCons[k]) {
          left[j]--;
          if (mine) have[j]++;
        }
        if (fits(k)) go(k + 1);
        for (final j in cellCons[k]) {
          left[j]++;
          if (mine) have[j]--;
        }
      }
    }

    go(0);
    if (solutions == 0) {
      // 모순(틀린 깃발 등) — 단순 비율로 대신한다.
      final probs = <int, double>{};
      for (final (cs, n) in comp) {
        for (final i in cs) {
          probs[i] = max(probs[i] ?? 0, (n / cs.length).clamp(0.0, 1.0));
        }
      }
      return (probs, false);
    }
    return (
      {
        for (var k = 0; k < cells.length; k++)
          cells[k]: mineCount[k] / solutions,
      },
      ok,
    );
  }

  bool _anyRevealed(GameModel m) {
    for (final row in m.grid) {
      for (final c in row) {
        if (c.isRevealed) return true;
      }
    }
    return false;
  }

  static bool _addAll(Set<int> to, Iterable<int> xs) {
    var changed = false;
    for (final x in xs) {
      changed |= to.add(x);
    }
    return changed;
  }
}
