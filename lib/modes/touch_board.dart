import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/types.dart';
import 'board_fx.dart';
import 'cell_painter.dart';
import 'touch_model.dart';

/// 확성기 핑 — mine=true면 내가 울린 확인, false면 파트너가 울린 방향 화살표.
class TouchPing {
  TouchPing(this.id, this.r, this.c, {this.mine = false});
  final int id;
  final int r, c;
  final bool mine;
}

/// "너에게 닿기를" 보드 — Swift TouchBoardView 이식. 안개(내가 연 칸 기준 3칸)만 보이고,
/// 처음엔 내 시작점이 화면 중앙에 오도록 한 번 맞춘다. 복기(`reveal`)면 안개를 걷고 만난 지점으로.
class TouchBoard extends StatefulWidget {
  const TouchBoard({
    super.key,
    required this.game,
    required this.flagMode,
    this.pings = const [],
    this.probing = false,
    this.onProbe,
    this.reveal = false,
  });
  final TouchModel game;
  final bool flagMode;
  final List<TouchPing> pings;
  final bool probing;
  final void Function(int r, int c)? onProbe;
  final bool reveal;

  @override
  State<TouchBoard> createState() => _TouchBoardState();
}

class _TouchBoardState extends State<TouchBoard> with SingleTickerProviderStateMixin {
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
  int? _centeredSeed; // 판마다 한 번 시작점 중앙 정렬(이후엔 사용자 스크롤 존중)

  TouchModel get g => widget.game;
  BigBoardMetrics get _m => BigBoardMetrics(g.size);

  @override
  void didUpdateWidget(covariant TouchBoard old) {
    super.didUpdateWidget(old);
    if (widget.reveal && !old.reveal) {
      final t = g.meetPoint ?? g.myStart;
      _tween = Matrix4Tween(begin: _tc.value.clone(), end: centerOn(_m, _viewport, t.$1, t.$2));
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _tc.dispose();
    super.dispose();
  }

  void _tap(int r, int c) {
    final vis = widget.reveal || g.isVisible(r, c);
    if (!vis) return; // 구름 너머는 만질 수 없다
    final d = g.grid[r][c];
    if (widget.probing) {
      widget.onProbe?.call(r, c);
    } else if (d.isRevealed) {
      g.chord(r, c);
    } else if (widget.flagMode) {
      g.toggleFlag(r, c);
    } else {
      g.tap(r, c);
    }
  }

  void _long(int r, int c) {
    final vis = widget.reveal || g.isVisible(r, c);
    if (!vis || widget.probing || g.grid[r][c].isRevealed) return;
    widget.flagMode ? g.tap(r, c) : g.toggleFlag(r, c);
  }

  /// 내 시작점에서 핑 쪽을 향하는 각도(화면 위=0, 시계방향).
  double _heading(TouchPing p) =>
      atan2((p.c - g.myStart.$2).toDouble(), -(p.r - g.myStart.$1).toDouble());

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final m = _m;
    return LayoutBuilder(builder: (context, box) {
      _viewport = box.biggest;
      if (_centeredSeed != g.seed && box.maxWidth > 0) {
        _centeredSeed = g.seed;
        final target = centerOn(m, _viewport, g.myStart.$1, g.myStart.$2);
        WidgetsBinding.instance.addPostFrameCallback((_) => _tc.value = target);
      }
      return Shake(
        trigger: g.minesHit,
        child: Stack(children: [
          BigBoardViewport(
            metrics: m,
            controller: _tc,
            background: t.boardFrame,
            painter: _TouchPainter(g, widget.reveal, t, _glyphs, m),
            onTap: _tap,
            onLongPress: _long,
            overlay: [
              for (final b in g.blasts)
                atCell(m, b.r, b.c, 30 * 2.6, BlastEffect(key: ValueKey(b.id), cell: 30)),
              if (widget.reveal && g.meetPoint != null)
                atCell(m, g.meetPoint!.$1, g.meetPoint!.$2, 30 * 2.6,
                    const MeetMarker(cell: 30)),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final p in widget.pings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(100)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (!p.mine) ...[
                            Transform.rotate(
                              angle: _heading(p),
                              child: const Icon(CupertinoIcons.location_north_fill,
                                  size: 15, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                              p.mine
                                  ? '📣 사이렌을 울렸어요! 파트너에게 알렸어요'
                                  : '📣 파트너가 이쪽에서 울렸어요',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

class _TouchPainter extends CustomPainter {
  _TouchPainter(this.g, this.reveal, this.t, this.glyphs, this.m);
  final TouchModel g;
  final bool reveal;
  final AppTheme t;
  final GlyphCache glyphs;
  final BigBoardMetrics m;

  static const gold = AppTheme.gold;
  static const opp = AppTheme.raceOpp;
  static const fog = Color.fromRGBO(148, 161, 184, 1); // (0.58,0.63,0.72)

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = gold.withValues(alpha: 0.9);
    const cell = 30.0;
    for (var r = 0; r < g.size; r++) {
      for (var c = 0; c < g.size; c++) {
        final d = g.grid[r][c];
        final vis = reveal || g.isVisible(r, c);
        final rect = m.rect(r, c);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        if (!vis) {
          canvas.drawRRect(rr, fill..color = fog);
          continue;
        }
        Color bg;
        if (d.isRevealed) {
          if (d.exploded) {
            bg = Color.alphaBlend(Colors.red.withValues(alpha: 0.30), t.boardFrame);
          } else if (d.isMegaphone) {
            bg = Color.alphaBlend(gold.withValues(alpha: 0.30), t.boardFrame);
          } else if (d.owner == FlagOwner.opponent) {
            bg = Color.alphaBlend(opp.withValues(alpha: 0.32), t.boardFrame);
          } else {
            bg = t.cellRevealed;
          }
        } else {
          bg = t.cellClosedTop;
        }
        canvas.drawRRect(rr, fill..color = bg);
        if (!reveal && !d.isRevealed && g.isFrontier(r, c)) canvas.drawRRect(rr, stroke);
        final ctr = rect.center;
        if (d.isRevealed) {
          if (d.exploded) {
            GlyphCache.drawCentered(canvas, glyphs.text('💣', cell * 0.5), ctr);
          } else if (d.isMegaphone) {
            GlyphCache.drawCentered(canvas, glyphs.text('📣', cell * 0.55), ctr);
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
        } else if (d.oppFlagged) {
          GlyphCache.drawCentered(canvas, glyphs.icon(flagIcon, cell * 0.46, opp), ctr);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
