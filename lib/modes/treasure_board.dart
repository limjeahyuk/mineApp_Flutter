import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/types.dart';
import 'board_fx.dart';
import 'cell_painter.dart';
import 'treasure_model.dart';

/// 보물찾기 보드 — Swift TreasureBoardView 이식(솔로/멀티 공용).
/// 프런티어 금색 테두리 + 폭발 + 흔들림. `flipped`(멀티 게스트)면 180° 뒤집어
/// 양쪽 모두 "내 출발점은 좌상단"으로 보이게 한다. 복기(`reviewing`) 진입 시 가운데 💎로 이동.
class TreasureBoard extends StatefulWidget {
  const TreasureBoard({
    super.key,
    required this.game,
    required this.flagMode,
    this.flipped = false,
    this.probing = false,
    this.onProbe,
    this.reviewing = false,
  });
  final TreasureModel game;
  final bool flagMode;
  final bool flipped;
  final bool probing;
  final void Function(int r, int c)? onProbe;
  final bool reviewing;

  @override
  State<TreasureBoard> createState() => _TreasureBoardState();
}

class _TreasureBoardState extends State<TreasureBoard>
    with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  final _glyphs = GlyphCache();
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400))
    ..addListener(() {
      final tw = _tween;
      if (tw != null) _tc.value = tw.evaluate(_anim);
    });
  Matrix4Tween? _tween;
  Size _viewport = Size.zero;

  TreasureModel get g => widget.game;
  (int, int) _flip(int r, int c) =>
      widget.flipped ? (g.size - 1 - r, g.size - 1 - c) : (r, c);

  @override
  void didUpdateWidget(covariant TreasureBoard old) {
    super.didUpdateWidget(old);
    if (widget.reviewing && !old.reviewing) {
      // 중앙 칸은 뒤집어도 중앙이라 화면 좌표 그대로.
      for (final ms in [0, 200, 450, 800]) {
        Timer(Duration(milliseconds: ms), () {
          if (!mounted) return;
          _tween = Matrix4Tween(
              begin: _tc.value.clone(),
              end: centerOn(BigBoardMetrics(g.size), _viewport, g.center, g.center));
          _anim.forward(from: 0);
        });
      }
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _tap(int dr, int dc) {
    final (r, c) = _flip(dr, dc);
    if (widget.probing) {
      widget.onProbe?.call(r, c);
    } else if (g.grid[r][c].isRevealed) {
      g.chord(r, c); // 열린 숫자 탭 = 주변 일괄 열기(모드 무관)
    } else if (widget.flagMode) {
      g.toggleFlag(r, c);
    } else {
      g.tap(r, c);
    }
  }

  void _long(int dr, int dc) {
    final (r, c) = _flip(dr, dc);
    if (widget.probing || g.grid[r][c].isRevealed) return;
    widget.flagMode ? g.tap(r, c) : g.toggleFlag(r, c);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final m = BigBoardMetrics(g.size);
    return LayoutBuilder(builder: (context, box) {
      _viewport = box.biggest;
      return Shake(
        trigger: g.minesHit,
        child: BigBoardViewport(
          metrics: m,
          controller: _tc,
          background: t.boardFrame,
          painter: _TreasurePainter(g, widget.flipped, t, _glyphs, m),
          onTap: _tap,
          onLongPress: _long,
          overlay: [
            for (final b in g.blasts)
              () {
                final (dr, dc) = _flip(b.r, b.c);
                return atCell(m, dr, dc, 30 * 2.6,
                    BlastEffect(key: ValueKey(b.id), cell: 30));
              }(),
          ],
        ),
      );
    });
  }
}

class _TreasurePainter extends CustomPainter {
  _TreasurePainter(this.g, this.flipped, this.t, this.glyphs, this.m);
  final TreasureModel g;
  final bool flipped;
  final AppTheme t;
  final GlyphCache glyphs;
  final BigBoardMetrics m;

  static const gold = AppTheme.gold;
  static const opp = AppTheme.raceOpp;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = gold.withValues(alpha: 0.9);
    const cell = 30.0;
    for (var dr = 0; dr < g.size; dr++) {
      for (var dc = 0; dc < g.size; dc++) {
        final r = flipped ? g.size - 1 - dr : dr;
        final c = flipped ? g.size - 1 - dc : dc;
        final d = g.grid[r][c];
        final rect = m.rect(dr, dc);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        // 배경
        Color bg;
        if (d.isRevealed) {
          if (d.isTreasure) {
            bg = Color.alphaBlend(gold.withValues(alpha: 0.32), t.boardFrame);
          } else if (d.exploded) {
            bg = Color.alphaBlend(Colors.red.withValues(alpha: 0.30), t.boardFrame);
          } else if (d.owner == FlagOwner.opponent) {
            bg = Color.alphaBlend(opp.withValues(alpha: 0.30), t.boardFrame);
          } else {
            bg = t.cellRevealed;
          }
        } else {
          bg = d.isTreasure
              ? Color.alphaBlend(gold.withValues(alpha: 0.18), t.boardFrame)
              : t.cellClosedTop;
        }
        canvas.drawRRect(rr, fill..color = bg);
        if (!d.isRevealed && g.isFrontier(r, c)) canvas.drawRRect(rr, stroke);
        // 라벨
        final ctr = rect.center;
        if (d.isRevealed) {
          if (d.isTreasure) {
            GlyphCache.drawCentered(canvas, glyphs.text('💎', cell * 0.6), ctr);
          } else if (d.exploded) {
            GlyphCache.drawCentered(canvas, glyphs.text('💣', cell * 0.5), ctr);
          } else if (d.adjacent > 0) {
            GlyphCache.drawCentered(
                canvas,
                glyphs.text('${d.adjacent}', cell * 0.5,
                    color: modeNumberColor(d.adjacent, t), weight: FontWeight.w900),
                ctr);
          }
        } else if (d.isFlagged) {
          if (d.isGolden) {
            GlyphCache.drawCentered(
                canvas,
                glyphs.icon(flagIcon, cell * 0.55, gold, shadows: [
                  Shadow(color: gold.withValues(alpha: 0.7), blurRadius: cell * 0.12)
                ]),
                ctr);
          } else {
            GlyphCache.drawCentered(canvas, glyphs.text('🚩', cell * 0.5), ctr);
          }
        } else if (g.won && d.isMine) {
          GlyphCache.drawCentered(canvas, glyphs.text('💣', cell * 0.5), ctr);
        } else if (d.isTreasure) {
          GlyphCache.drawCentered(canvas, glyphs.text('💎', cell * 0.5), ctr,
              opacity: 0.5);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
