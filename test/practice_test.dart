import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/guide/practice.dart';

/// 연습 보드 스크립트대로 따라 눌렀을 때 — 반짝이는 칸이 항상 보이고/열 수 있고, 끝에 목표가 이뤄지는지.
void main() {
  bool met(PracticeBoard b) {
    for (var r = 0; r < b.s.rows; r++) {
      for (var c = 0; c < b.s.cols; c++) {
        if (!b.isMine((r, c))) continue;
        for (final q in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
          if (b.inBounds(q) && b.partner.contains(q)) return true;
        }
      }
    }
    return false;
  }

  PracticeBoard play(OnboardKind kind) {
    final s = kind.script;
    final b = PracticeBoard(s);
    for (final step in s.steps) {
      final p = step.at;
      if (p == null) continue;
      expect(b.isVisible(p), isTrue, reason: '${kind.name} $p 안개에 가림');
      switch (step.kind) {
        case PKind.tap:
          if (s.frontierOnly) {
            expect(b.isFrontier(p), isTrue, reason: '${kind.name} $p 프런티어 아님');
          }
          if (b.at(p).isMine) {
            b.explode(p);
            b.resetAround(p, s.mineResetRadius!);
          } else {
            b.flood(p);
          }
          if (kind == OnboardKind.touch && step != s.steps[s.steps.length - 2]) {
            expect(met(b), isFalse, reason: '마지막 탭 전에 이미 만남');
          }
        case PKind.flag:
          expect(b.at(p).isMine, isTrue);
          b.at(p).isFlagged = true;
        case PKind.chord:
          final flags = b.neighbors(p).where((n) => b.at(n).isFlagged).length;
          expect(flags, b.at(p).adjacent, reason: '깃발 수 ≠ 숫자');
          b.chord(p);
        case PKind.flagMode:
        case PKind.info:
          break;
      }
    }
    return b;
  }

  bool allSafeOpen(PracticeBoard b) => [
        for (final row in b.grid)
          for (final c in row) c.isMine || c.isRevealed
      ].every((x) => x);

  test('솔로·대전: 숫자 탭으로 보드 클리어', () {
    expect(allSafeOpen(play(OnboardKind.solo)), isTrue);
    expect(allSafeOpen(play(OnboardKind.mine)), isTrue);
  });

  test('보물찾기: 지뢰 밟은 뒤 다시 뚫어 보물 도달', () {
    final b = play(OnboardKind.treasure);
    expect(b.at(OnboardKind.treasure.script.treasure!).isRevealed, isTrue);
  });

  test('너에게 닿기를: 마지막 탭에서 파트너와 만남', () {
    expect(met(play(OnboardKind.touch)), isTrue);
  });
}
