import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import 'coop_controller.dart' show TouchPing;
import 'touch_model.dart';

/// '너에게 닿기를' 안개 보드 — Swift TouchBoardView 이식.
/// 내가 연 칸 근처만 보이고 나머지는 구름(안개). 30pt 고정 셀 2축 스크롤,
/// 처음엔 내 시작점을 화면 중앙에. 복기(reveal) 땐 안개를 걷고 만난 칸을 펄스 링으로 강조.
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

  static const cell = 30.0;
  static const gap = 1.0;
  static const pad = 3.0;

  @override
  State<TouchBoard> createState() => _TouchBoardState();
}

class _TouchBoardState extends State<TouchBoard> with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  int _lastHits = 0;
  Size _viewport = Size.zero;
  bool _didCenter = false;
  (int, int)? _centeredStart;

  static const gold = Color.fromRGBO(242, 199, 77, 1);

  TouchModel get g => widget.game;
  double get _step => TouchBoard.cell + TouchBoard.gap;
  double get _extent => TouchBoard.pad * 2 + g.size * _step - TouchBoard.gap;

  @override
  void initState() {
    super.initState();
    _lastHits = g.minesHit;
    g.addListener(_onGame);
  }

  @override
  void didUpdateWidget(covariant TouchBoard old) {
    super.didUpdateWidget(old);
    if (widget.reveal && !old.reveal) {
      final t = g.meetPoint ?? g.myStart;
      _center(t.$1, t.$2);
    }
  }

  void _onGame() {
    if (g.minesHit != _lastHits) {
      if (g.minesHit > _lastHits) _shake.forward(from: 0);
      _lastHits = g.minesHit;
    }
    // 새 판(시작점 변경) → 다시 내 시작점으로 센터링.
    if (_centeredStart != g.myStart) _didCenter = false;
  }

  Offset _cellCenter(int r, int c) =>
      Offset(TouchBoard.pad + c * _step + TouchBoard.cell / 2, TouchBoard.pad + r * _step + TouchBoard.cell / 2);

  void _center(int r, int c) {
    if (_viewport.width <= 0) return;
    final p = _cellCenter(r, c);
    final dx = (_viewport.width / 2 - p.dx).clamp(math.min(0.0, _viewport.width - _extent), 0.0).toDouble();
    final dy = (_viewport.height / 2 - p.dy).clamp(math.min(0.0, _viewport.height - _extent), 0.0).toDouble();
    _tc.value = Matrix4.identity()..translateByDouble(dx, dy, 0, 1);
  }

  @override
  void dispose() {
    g.removeListener(_onGame);
    _tc.dispose();
    _shake.dispose();
    super.dispose();
  }

  (int, int)? _cellAt(Offset local) {
    final x = local.dx - TouchBoard.pad, y = local.dy - TouchBoard.pad;
    if (x < 0 || y < 0) return null;
    final c = x ~/ _step, r = y ~/ _step;
    if (r >= g.size || c >= g.size) return null;
    return (r, c);
  }

  bool _vis(int r, int c) => widget.reveal || g.isVisible(r, c);

  void _tap(Offset p) {
    final rc = _cellAt(p);
    if (rc == null) return;
    final (r, c) = rc;
    if (!_vis(r, c)) return; // 구름 너머는 만질 수 없다
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
    if (rc == null) return;
    final (r, c) = rc;
    if (!_vis(r, c) || widget.probing || g.grid[r][c].isRevealed) return;
    if (widget.flagMode) {
      g.tap(r, c);
    } else {
      g.toggleFlag(r, c);
    }
  }

  double _heading(TouchPing p) =>
      math.atan2((p.c - g.myStart.$2).toDouble(), -(p.r - g.myStart.$1).toDouble());

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
          offset: Offset(7 * math.sin(_shake.value * math.pi * 3), 0), child: child),
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: t.boardFrame,
            child: LayoutBuilder(builder: (context, box) {
              _viewport = Size(box.maxWidth, box.maxHeight);
              if (!_didCenter && g.grid.isNotEmpty) {
                _didCenter = true;
                _centeredStart = g.myStart;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _center(g.myStart.$1, g.myStart.$2);
                });
              }
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
                            child: CustomPaint(painter: _TouchPainter(g, t, widget.reveal, DefaultTextStyle.of(context).style))),
                        for (final b in g.blasts)
                          Builder(builder: (_) {
                            final p = _cellCenter(b.r, b.c);
                            const s = TouchBoard.cell * 2.6;
                            return Positioned(
                              key: ValueKey(b.id),
                              left: p.dx - s / 2,
                              top: p.dy - s / 2,
                              width: s,
                              height: s,
                              child: const IgnorePointer(child: TouchBlastFx(cell: TouchBoard.cell)),
                            );
                          }),
                        if (widget.reveal && g.meetPoint != null)
                          Builder(builder: (_) {
                            final p = _cellCenter(g.meetPoint!.$1, g.meetPoint!.$2);
                            const s = TouchBoard.cell * 2.6;
                            return Positioned(
                              left: p.dx - s / 2,
                              top: p.dy - s / 2,
                              width: s,
                              height: s,
                              child: const IgnorePointer(child: _MeetMarker(cell: TouchBoard.cell)),
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
        if (widget.pings.isNotEmpty)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Column(children: [
                for (final p in widget.pings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(100)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (!p.mine) ...[
                          Transform.rotate(
                              angle: _heading(p),
                              child: const Icon(SF.locationNorthFill, size: 15, color: Colors.white)),
                          const SizedBox(width: 8),
                        ],
                        Text(p.mine ? '📣 사이렌을 울렸어요! 파트너에게 알렸어요' : '📣 파트너가 이쪽에서 울렸어요',
                            style: sf(13, weight: W.bold, color: Colors.white)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _TouchPainter extends CustomPainter {
  _TouchPainter(this.g, this.t, this.reveal, this.base);
  final TextStyle base;
  final TouchModel g;
  final AppTheme t;
  final bool reveal;

  static const gold = Color.fromRGBO(242, 199, 77, 1);
  static const opp = Color.fromRGBO(242, 115, 77, 1);
  static const fog = Color.fromRGBO(148, 161, 184, 1); // (0.58,0.63,0.72)
  static final Map<String, TextPainter> _cache = {};

  TextPainter _tp(String s, double size, {Color? color, FontWeight? w, IconData? icon}) {
    final key = '$s|$size|${color?.toARGB32()}|$w|${icon?.codePoint}';
    return _cache.putIfAbsent(
        key,
        () => TextPainter(
              text: TextSpan(
                  text: icon != null ? String.fromCharCode(icon.codePoint) : s,
                  style: icon != null
                      ? TextStyle(
                          fontSize: size,
                          color: color,
                          height: 1.0,
                          fontFamily: icon.fontFamily,
                          package: icon.fontPackage)
                      : base.merge(
                          TextStyle(fontSize: size, color: color, fontWeight: w, height: 1.0))),
              textDirection: TextDirection.ltr,
            )..layout());
  }

  void _c(Canvas canvas, TextPainter tp, Rect r) =>
      tp.paint(canvas, Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2));

  @override
  void paint(Canvas canvas, Size size) {
    const cell = TouchBoard.cell;
    const step = cell + TouchBoard.gap;
    final paint = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = gold.withValues(alpha: 0.9);
    for (var r = 0; r < g.size; r++) {
      for (var c = 0; c < g.size; c++) {
        final d = g.grid[r][c];
        final vis = reveal || g.isVisible(r, c);
        final rect = Rect.fromLTWH(TouchBoard.pad + c * step, TouchBoard.pad + r * step, cell, cell);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        Color fill;
        if (!vis) {
          fill = fog;
        } else if (d.isRevealed) {
          if (d.exploded) {
            fill = Colors.red.withValues(alpha: 0.30);
          } else if (d.isMegaphone) {
            fill = gold.withValues(alpha: 0.30);
          } else {
            fill = d.owner == FlagOwner.opponent ? opp.withValues(alpha: 0.32) : t.cellRevealed;
          }
        } else {
          fill = t.cellClosedTop;
        }
        paint.color = fill;
        canvas.drawRRect(rr, paint);
        if (!vis) continue;
        if (!reveal && !d.isRevealed && g.isFrontier(r, c)) canvas.drawRRect(rr.deflate(0.8), stroke);
        if (d.isRevealed) {
          if (d.exploded) {
            _c(canvas, _tp('💣', cell * 0.5), rect);
          } else if (d.isMegaphone) {
            _c(canvas, _tp('📣', cell * 0.55), rect);
          } else if (d.adjacent > 0) {
            final color = d.adjacent == 7
                ? t.text
                : d.adjacent >= 8
                    ? t.textSecondary
                    : minesweeperNumberColor(d.adjacent, t.dark);
            _c(canvas, _tp('${d.adjacent}', cell * 0.5, color: color, w: FontWeight.w800), rect);
          }
        } else if (d.isFlagged) {
          if (d.isGolden) {
            _c(canvas, _tp('', cell * 0.5, color: gold, icon: SF.flagFill), rect);
          } else {
            _c(canvas, _tp('🚩', cell * 0.5), rect);
          }
        } else if (d.oppFlagged) {
          _c(canvas, _tp('', cell * 0.46, color: opp, icon: SF.flagFill), rect);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TouchPainter old) => true;
}

/// 폭발 연출(보물찾기와 동일한 결).
class TouchBlastFx extends StatefulWidget {
  const TouchBlastFx({super.key, required this.cell});
  final double cell;

  @override
  State<TouchBlastFx> createState() => _TouchBlastFxState();
}

class _TouchBlastFxState extends State<TouchBlastFx> with SingleTickerProviderStateMixin {
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
              scale: 0.2 + v,
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

/// 복기 — 두 사람이 처음 맞닿은 칸의 펄스 링 + 🤝.
class _MeetMarker extends StatefulWidget {
  const _MeetMarker({required this.cell});
  final double cell;

  @override
  State<_MeetMarker> createState() => _MeetMarkerState();
}

class _MeetMarkerState extends State<_MeetMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  static const accent = Color.fromRGBO(102, 179, 140, 1);

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
        final v = Curves.easeInOut.transform(_c.value);
        return Stack(alignment: Alignment.center, children: [
          Opacity(
            opacity: 0.85 - 0.7 * v,
            child: Transform.scale(
              scale: 0.82 + 0.30 * v,
              child: Container(
                width: cell * 2.3,
                height: cell * 2.3,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, border: Border.all(color: accent, width: 3)),
              ),
            ),
          ),
          Text('🤝', style: TextStyle(fontSize: cell * 0.85, height: 1)),
        ]);
      },
    );
  }
}
