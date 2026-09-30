import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import 'treasure_model.dart';

/// 보물찾기 보드 — Swift TreasureBoardView 이식(솔로/멀티 공용).
/// 30pt 고정 셀 + 1pt 간격을 가로·세로 스크롤, 프런티어 금색 테두리, 폭발 연출, 밟을 때 흔들림.
/// `flipped`(멀티 게스트)면 180° 뒤집어 그려 "내 출발점 = 좌상단"으로 통일한다.
/// 2601칸을 위젯 하나씩 두지 않고 CustomPaint 한 장으로 그린다(스크롤 성능).
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

  static const cell = 30.0;
  static const gap = 1.0;
  static const pad = 3.0;

  @override
  State<TreasureBoard> createState() => _TreasureBoardState();
}

class _TreasureBoardState extends State<TreasureBoard> with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  int _lastHits = 0;
  Size _viewport = Size.zero;

  TreasureModel get g => widget.game;
  double get _step => TreasureBoard.cell + TreasureBoard.gap;
  double get _extent => TreasureBoard.pad * 2 + g.size * _step - TreasureBoard.gap;

  @override
  void initState() {
    super.initState();
    _lastHits = g.minesHit;
    g.addListener(_onGame);
  }

  @override
  void didUpdateWidget(covariant TreasureBoard old) {
    super.didUpdateWidget(old);
    if (old.game != widget.game) {
      old.game.removeListener(_onGame);
      widget.game.addListener(_onGame);
    }
    if (widget.reviewing && !old.reviewing) _scrollToCenter();
    if (old.game.seed != widget.game.seed || old.flipped != widget.flipped) {
      _tc.value = Matrix4.identity();
    }
  }

  void _onGame() {
    if (g.minesHit != _lastHits) {
      if (g.minesHit > _lastHits) _shake.forward(from: 0);
      _lastHits = g.minesHit;
    }
  }

  void _scrollToCenter() {
    final center = TreasureBoard.pad + g.center * _step + TreasureBoard.cell / 2;
    final dx = (_viewport.width / 2 - center).clamp(math.min(0.0, _viewport.width - _extent), 0.0);
    final dy = (_viewport.height / 2 - center).clamp(math.min(0.0, _viewport.height - _extent), 0.0);
    _tc.value = Matrix4.identity()..translateByDouble(dx.toDouble(), dy.toDouble(), 0, 1);
  }

  @override
  void dispose() {
    g.removeListener(_onGame);
    _tc.dispose();
    _shake.dispose();
    super.dispose();
  }

  (int, int) _flip(int r, int c) => widget.flipped ? (g.size - 1 - r, g.size - 1 - c) : (r, c);

  (int, int)? _cellAt(Offset local) {
    final x = local.dx - TreasureBoard.pad, y = local.dy - TreasureBoard.pad;
    if (x < 0 || y < 0) return null;
    final c = x ~/ _step, r = y ~/ _step;
    if (r >= g.size || c >= g.size) return null;
    return _flip(r, c);
  }

  void _tap(Offset p) {
    final rc = _cellAt(p);
    if (rc == null) return;
    final (r, c) = rc;
    if (widget.probing) {
      widget.onProbe?.call(r, c);
    } else if (g.grid[r][c].isRevealed) {
      g.chord(r, c);
    } else if (widget.flagMode) {
      g.toggleFlag(r, c);
    } else {
      g.tap(r, c);
    }
  }

  void _long(Offset p) {
    final rc = _cellAt(p);
    if (rc == null || widget.probing) return;
    final (r, c) = rc;
    if (g.grid[r][c].isRevealed) return;
    if (widget.flagMode) {
      g.tap(r, c);
    } else {
      g.toggleFlag(r, c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(7 * math.sin(_shake.value * math.pi * 3), 0),
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: t.boardFrame,
          child: LayoutBuilder(builder: (context, box) {
            _viewport = Size(box.maxWidth, box.maxHeight);
            return InteractiveViewer(
              transformationController: _tc,
              constrained: false,
              scaleEnabled: false,
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    () => TapGestureRecognizer(),
                    (r) => r.onTapUp = (d) => _tap(d.localPosition),
                  ),
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 250)),
                    (r) => r.onLongPressStart = (d) => _long(d.localPosition),
                  ),
                },
                child: ListenableBuilder(
                  listenable: g,
                  builder: (context, _) => SizedBox(
                    width: _extent,
                    height: _extent,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TreasurePainter(g, widget.flipped, t, g.won, DefaultTextStyle.of(context).style),
                        ),
                      ),
                      for (final b in g.blasts)
                        Builder(builder: (_) {
                          final (dr, dc) = _flip(b.r, b.c);
                          final cx = TreasureBoard.pad + dc * _step + TreasureBoard.cell / 2;
                          final cy = TreasureBoard.pad + dr * _step + TreasureBoard.cell / 2;
                          const s = TreasureBoard.cell * 2.6;
                          return Positioned(
                            key: ValueKey(b.id),
                            left: cx - s / 2,
                            top: cy - s / 2,
                            width: s,
                            height: s,
                            child: const IgnorePointer(child: _Blast(cell: TreasureBoard.cell)),
                          );
                        }),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _TreasurePainter extends CustomPainter {
  _TreasurePainter(this.g, this.flipped, this.t, this.won, this.base);
  final TextStyle base;
  final TreasureModel g;
  final bool flipped;
  final AppTheme t;
  final bool won;

  static const gold = Color.fromRGBO(242, 199, 77, 1);
  static const opp = Color.fromRGBO(242, 115, 77, 1);
  static final Map<String, TextPainter> _cache = {};

  TextPainter _tp(String s, double size, {Color? color, FontWeight? w}) {
    final key = '$s|$size|${color?.toARGB32()}|$w';
    return _cache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
            text: s,
            style: base.merge(TextStyle(fontSize: size, color: color, fontWeight: w, height: 1.0))),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  void _center(Canvas canvas, TextPainter tp, Rect r, {double opacity = 1}) {
    final o = Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2);
    if (opacity < 1) {
      canvas.saveLayer(r.inflate(4), Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
      tp.paint(canvas, o);
      canvas.restore();
    } else {
      tp.paint(canvas, o);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const cell = TreasureBoard.cell;
    const step = cell + TreasureBoard.gap;
    final paint = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = gold.withValues(alpha: 0.9);
    for (var dr = 0; dr < g.size; dr++) {
      for (var dc = 0; dc < g.size; dc++) {
        final r = flipped ? g.size - 1 - dr : dr;
        final c = flipped ? g.size - 1 - dc : dc;
        final d = g.grid[r][c];
        final rect = Rect.fromLTWH(
            TreasureBoard.pad + dc * step, TreasureBoard.pad + dr * step, cell, cell);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        Color fill;
        if (d.isRevealed) {
          if (d.isTreasure) {
            fill = gold.withValues(alpha: 0.32);
          } else if (d.exploded) {
            fill = Colors.red.withValues(alpha: 0.30);
          } else {
            fill = d.owner == FlagOwner.opponent ? opp.withValues(alpha: 0.30) : t.cellRevealed;
          }
        } else {
          fill = d.isTreasure ? gold.withValues(alpha: 0.18) : t.cellClosedTop;
        }
        paint.color = fill;
        canvas.drawRRect(rr, paint);
        if (!d.isRevealed && g.isFrontier(r, c)) canvas.drawRRect(rr.deflate(0.8), stroke);

        // 라벨
        if (d.isRevealed) {
          if (d.isTreasure) {
            _center(canvas, _tp('💎', cell * 0.6), rect);
          } else if (d.exploded) {
            _center(canvas, _tp('💣', cell * 0.5), rect);
          } else if (d.adjacent > 0) {
            final color = d.adjacent == 7
                ? t.text
                : d.adjacent >= 8
                    ? t.textSecondary
                    : minesweeperNumberColor(d.adjacent, t.dark);
            _center(canvas, _tp('${d.adjacent}', cell * 0.5, color: color, w: FontWeight.w800), rect);
          }
        } else if (d.isFlagged) {
          if (d.isGolden) {
            final tp = TextPainter(
              text: TextSpan(
                  text: String.fromCharCode(SF.flagFill.codePoint),
                  style: TextStyle(
                      fontSize: cell * 0.5,
                      fontFamily: SF.flagFill.fontFamily,
                      package: SF.flagFill.fontPackage,
                      color: gold,
                      height: 1.0)),
              textDirection: TextDirection.ltr,
            )..layout();
            _center(canvas, tp, rect);
          } else {
            _center(canvas, _tp('🚩', cell * 0.5), rect);
          }
        } else if (won && d.isMine) {
          _center(canvas, _tp('💣', cell * 0.5), rect);
        } else if (d.isTreasure) {
          _center(canvas, _tp('💎', cell * 0.5), rect, opacity: 0.5);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreasurePainter old) => true;
}

/// 지뢰 폭발 연출 — 충격파 링 + 불꽃 코어 + 💥가 커지며 사라진다(0.5초).
class _Blast extends StatefulWidget {
  const _Blast({required this.cell});
  final double cell;

  @override
  State<_Blast> createState() => _BlastState();
}

class _BlastState extends State<_Blast> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cell = widget.cell;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final v = Curves.easeOut.transform(_c.value);
        return Stack(alignment: Alignment.center, children: [
          Opacity(
            opacity: (1 - v) * 0.9,
            child: Transform.scale(
              scale: 0.25 + 0.75 * v,
              child: Container(
                width: cell * 2.6,
                height: cell * 2.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.9), width: 7 - 5.5 * v),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: 1 - v,
            child: Transform.scale(
              scale: 0.2 + 1.0 * v,
              child: Container(
                width: cell * 2,
                height: cell * 2,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [Colors.white, Colors.yellow, Colors.orange, Color(0x00FF0000)]),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: 1 - v,
            child: Transform.scale(
                scale: 0.4 + 1.1 * v,
                child: Text('💥', style: TextStyle(fontSize: cell * 1.1, height: 1))),
          ),
        ]);
      },
    );
  }
}
