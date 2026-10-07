import 'dart:math';

<<<<<<< HEAD
import 'package:flutter/cupertino.dart';
=======
import 'package:flutter/gestures.dart';
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/types.dart';
<<<<<<< HEAD
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
=======
import 'coop_controller.dart';
import 'touch_model.dart';

/// "너에게 닿기를" 보드 — 안개(fog) 렌더링. Swift TouchBoardView 이식.
/// 내가 연 칸 기준 거리 안만 보이고, 그 밖은 구름색으로 가린다. 상대가 연 칸/깃발이
/// 안개 안에 들어오면 보여서 "근처에 누가 왔다"를 알아챌 수 있다.
/// 30pt 고정 셀(가로·세로 스크롤). 처음에 내 시작점이 화면 중앙에 오도록 스크롤한다.
/// 80×80(6,400칸)이라 셀 위젯 대신 한 장의 CustomPaint로 그리고, 탭 위치로 칸을 계산한다.
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
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
<<<<<<< HEAD
=======

>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  final TouchModel game;
  final bool flagMode;
  final List<TouchPing> pings;
  final bool probing;
  final void Function(int r, int c)? onProbe;
<<<<<<< HEAD
=======

  /// 복기 모드 — 안개를 모두 걷어 두 사람이 연 길과 만난 지점을 보여준다.
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  final bool reveal;

  @override
  State<TouchBoard> createState() => _TouchBoardState();
}

<<<<<<< HEAD
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
=======
class _TouchBoardState extends State<TouchBoard>
    with SingleTickerProviderStateMixin {
  static const cell = 30.0;
  static const gap = 1.0;
  static const pad = 3.0;
  static const _gold = AppTheme.gold;

  final _h = ScrollController();
  final _v = ScrollController();
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  int _lastHits = 0;
  int _lastSeed = 0;
  bool _didCenter = false;

  TouchModel get game => widget.game;

  @override
  void initState() {
    super.initState();
    _lastHits = game.minesHit;
    _lastSeed = game.seed;
    game.addListener(_onGame);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerStart());
  }
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  @override
  void didUpdateWidget(covariant TouchBoard old) {
    super.didUpdateWidget(old);
    if (widget.reveal && !old.reveal) {
<<<<<<< HEAD
      final t = g.meetPoint ?? g.myStart;
      _tween = Matrix4Tween(begin: _tc.value.clone(), end: centerOn(_m, _viewport, t.$1, t.$2));
      _anim.forward(from: 0);
=======
      final t = game.meetPoint ?? game.myStart;
      _centerCamera(t.$1, t.$2, animated: true);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    }
  }

  @override
  void dispose() {
<<<<<<< HEAD
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
=======
    game.removeListener(_onGame);
    _h.dispose();
    _v.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onGame() {
    if (game.minesHit != _lastHits) {
      _lastHits = game.minesHit;
      if (game.minesHit > 0) _shake.forward(from: 0);
    }
    // 새 판(재대결)이면 다시 시작점으로.
    if (game.seed != _lastSeed) {
      _lastSeed = game.seed;
      _didCenter = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerStart());
    }
  }

  void _centerStart([int tries = 0]) {
    if (_didCenter || !mounted) return;
    if (!_h.hasClients || !_v.hasClients) {
      if (tries < 40) {
        Future.delayed(
            const Duration(milliseconds: 100), () => _centerStart(tries + 1));
      }
      return;
    }
    _centerCamera(game.myStart.$1, game.myStart.$2, animated: false);
    _didCenter = true;
  }

  Offset _cellCenter(int r, int c) {
    const step = cell + gap;
    return Offset(pad + c * step + cell / 2, pad + r * step + cell / 2);
  }

  void _centerCamera(int r, int c, {required bool animated}) {
    if (!_h.hasClients || !_v.hasClients) return;
    final p = _cellCenter(r, c);
    void go(ScrollController s, double v) {
      final target =
          (v - s.position.viewportDimension / 2).clamp(0.0, s.position.maxScrollExtent);
      if (animated) {
        s.animateTo(target,
            duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else {
        s.jumpTo(target);
      }
    }

    go(_h, p.dx);
    go(_v, p.dy);
  }

  (int, int)? _cellAt(Offset local) {
    const step = cell + gap;
    final c = ((local.dx - pad) / step).floor();
    final r = ((local.dy - pad) / step).floor();
    if (!game.inBounds(r, c)) return null;
    return (r, c);
  }

  bool _vis(int r, int c) => widget.reveal || game.isVisible(r, c);

  void _onTap(Offset local) {
    final p = _cellAt(local);
    if (p == null) return;
    final (r, c) = p;
    if (!_vis(r, c)) return; // 구름 너머는 만질 수 없다
    final d = game.grid[r][c];
    if (widget.probing) {
      widget.onProbe?.call(r, c);
    } else if (d.isRevealed) {
      game.chord(r, c);
    } else if (widget.flagMode) {
      game.toggleFlag(r, c);
    } else {
      game.tap(r, c);
    }
  }

  void _onLongPress(Offset local) {
    final p = _cellAt(local);
    if (p == null) return;
    final (r, c) = p;
    if (!_vis(r, c) || widget.probing || game.grid[r][c].isRevealed) return;
    if (widget.flagMode) {
      game.tap(r, c);
    } else {
      game.toggleFlag(r, c);
    }
  }
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
<<<<<<< HEAD
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
=======
    final n = game.size;
    final side = pad * 2 + n * cell + (n - 1) * gap;
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) => Transform.translate(
          offset: Offset(7 * sin(_shake.value * pi * 3), 0), child: child),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: t.boardFrame,
          child: Stack(
            children: [
              Scrollbar(
                controller: _v,
                child: SingleChildScrollView(
                  controller: _v,
                  child: Scrollbar(
                    controller: _h,
                    notificationPredicate: (n) => n.depth == 0,
                    child: SingleChildScrollView(
                      controller: _h,
                      scrollDirection: Axis.horizontal,
                      child: RawGestureDetector(
                        behavior: HitTestBehavior.opaque,
                        gestures: {
                          TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                              TapGestureRecognizer>(
                            TapGestureRecognizer.new,
                            (rec) => rec.onTapUp = (d) => _onTap(d.localPosition),
                          ),
                          LongPressGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                  LongPressGestureRecognizer>(
                            () => LongPressGestureRecognizer(
                                duration: const Duration(milliseconds: 250)),
                            (rec) => rec.onLongPressStart =
                                (d) => _onLongPress(d.localPosition),
                          ),
                        },
                        child: ListenableBuilder(
                          listenable: game,
                          builder: (_, _) => SizedBox(
                            width: side,
                            height: side,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _TouchPainter(
                                      game: game,
                                      theme: t,
                                      reveal: widget.reveal,
                                      version: Object(),
                                    ),
                                  ),
                                ),
                                for (final b in game.blasts)
                                  Builder(builder: (_) {
                                    final p = _cellCenter(b.r, b.c);
                                    return Positioned(
                                      left: p.dx - cell * 1.3,
                                      top: p.dy - cell * 1.3,
                                      child: IgnorePointer(
                                          child: TouchBlast(
                                              key: ValueKey(b.id), cell: cell)),
                                    );
                                  }),
                                if (widget.reveal && game.meetPoint != null)
                                  Builder(builder: (_) {
                                    final m = game.meetPoint!;
                                    final p = _cellCenter(m.$1, m.$2);
                                    return Positioned(
                                      left: p.dx - cell * 1.15,
                                      top: p.dy - cell * 1.15,
                                      child: const IgnorePointer(
                                          child: _MeetMarker(cell: cell)),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.pings.isNotEmpty)
                Align(
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(child: _pingBanner()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pingBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in widget.pings)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(100)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: p.mine
                    ? const [
                        Text('📣 사이렌을 울렸어요! 파트너에게 알렸어요',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ]
                    : [
                        Transform.rotate(
                          angle: atan2((p.c - game.myStart.$2).toDouble(),
                              -(p.r - game.myStart.$1).toDouble()),
                          child: const Icon(Icons.navigation,
                              size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Text('📣 파트너가 이쪽에서 울렸어요',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
              ),
            ),
        ],
      ),
    );
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  }
}

class _TouchPainter extends CustomPainter {
<<<<<<< HEAD
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
=======
  _TouchPainter(
      {required this.game,
      required this.theme,
      required this.reveal,
      required this.version});
  final TouchModel game;
  final AppTheme theme;
  final bool reveal;
  final Object version;

  static const cell = _TouchBoardState.cell;
  static const gap = _TouchBoardState.gap;
  static const pad = _TouchBoardState.pad;
  static const _gold = AppTheme.gold;
  static const _opp = Color.fromRGBO(242, 115, 77, 1);
  static const _fog = Color.fromRGBO(148, 161, 184, 1);

  static final Map<String, TextPainter> _cache = {};

  TextPainter _tp(String key, InlineSpan span) {
    return _cache.putIfAbsent(key, () {
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      return tp;
    });
  }

  TextPainter _emoji(String e, double size) =>
      _tp('e$e$size', TextSpan(text: e, style: TextStyle(fontSize: size, height: 1)));

  TextPainter _icon(IconData icon, double size, Color color,
          [List<Shadow>? shadows]) =>
      _tp(
          'i${icon.codePoint}$size${color.toARGB32()}',
          TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                fontSize: size,
                height: 1,
                color: color,
                shadows: shadows),
          ));

  TextPainter _number(int n, Color color) => _tp(
      'n$n${color.toARGB32()}',
      TextSpan(
          text: '$n',
          style: TextStyle(
              fontSize: cell * 0.5,
              height: 1,
              fontWeight: FontWeight.w900,
              color: color)));

  void _center(Canvas canvas, TextPainter tp, Offset c) =>
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
<<<<<<< HEAD
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
=======
      ..color = _gold.withValues(alpha: 0.9);
    const step = cell + gap;
    final n = game.size;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final d = game.grid[r][c];
        final vis = reveal || game.isVisible(r, c);
        final rect = Rect.fromLTWH(pad + c * step, pad + r * step, cell, cell);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        Color bg;
        if (!vis) {
          bg = _fog;
        } else if (d.isRevealed) {
          if (d.exploded) {
            bg = Colors.red.withValues(alpha: 0.30);
          } else if (d.isMegaphone) {
            bg = _gold.withValues(alpha: 0.30);
          } else {
            bg = d.owner == FlagOwner.opponent
                ? _opp.withValues(alpha: 0.32)
                : t.cellRevealed;
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
          }
        } else {
          bg = t.cellClosedTop;
        }
<<<<<<< HEAD
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
=======
        fill.color = bg;
        canvas.drawRRect(rr, fill);
        if (!vis) continue;
        if (!reveal && !d.isRevealed && game.isFrontier(r, c)) {
          canvas.drawRRect(rr.deflate(0.8), stroke);
        }
        final center = rect.center;
        if (d.isRevealed) {
          if (d.exploded) {
            _center(canvas, _emoji('💣', cell * 0.5), center);
          } else if (d.isMegaphone) {
            _center(canvas, _emoji('📣', cell * 0.55), center);
          } else if (d.adjacent > 0) {
            final color = d.adjacent == 7
                ? t.text
                : d.adjacent >= 8
                    ? t.textSecondary
                    : minesweeperNumberColor(d.adjacent, t.dark);
            _center(canvas, _number(d.adjacent, color), center);
          }
        } else if (d.isFlagged) {
          if (d.isGolden) {
            _center(
                canvas,
                _icon(Icons.flag, cell * 0.6, _gold, [
                  Shadow(color: _gold.withValues(alpha: 0.7), blurRadius: 3.6)
                ]),
                center);
          } else {
            _center(canvas, _emoji('🚩', cell * 0.5), center);
          }
        } else if (d.oppFlagged) {
          _center(canvas, _icon(Icons.flag, cell * 0.56, _opp), center);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
        }
      }
    }
  }

  @override
<<<<<<< HEAD
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
=======
  bool shouldRepaint(covariant _TouchPainter old) =>
      old.version != version || old.reveal != reveal || old.theme.dark != theme.dark;
}

/// 복기 화면에서 "두 사람이 처음 만난 칸"을 가리키는 펄스 링 + 🤝.
class _MeetMarker extends StatefulWidget {
  const _MeetMarker({required this.cell});
  final double cell;

  @override
  State<_MeetMarker> createState() => _MeetMarkerState();
}

class _MeetMarkerState extends State<_MeetMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);
  static const _accent = Color.fromRGBO(102, 179, 140, 1);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.cell * 2.3;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final v = Curves.easeInOut.transform(_c.value);
          return Stack(alignment: Alignment.center, children: [
            Opacity(
              opacity: 0.85 - 0.7 * v,
              child: Transform.scale(
                scale: 0.82 + 0.30 * v,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _accent, width: 3)),
                ),
              ),
            ),
            Text('🤝', style: TextStyle(fontSize: widget.cell * 0.85)),
          ]);
        },
      ),
    );
  }
}

/// 지뢰를 밟았을 때의 폭발 연출(보물찾기와 동일한 결).
class TouchBlast extends StatefulWidget {
  const TouchBlast({super.key, required this.cell});
  final double cell;

  @override
  State<TouchBlast> createState() => _TouchBlastState();
}

class _TouchBlastState extends State<TouchBlast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cell = widget.cell;
    final box = cell * 2.6;
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final g = Curves.easeOut.transform(_c.value);
          return Stack(alignment: Alignment.center, children: [
            Opacity(
              opacity: 0.9 * (1 - g),
              child: Transform.scale(
                scale: 0.25 + 0.75 * g,
                child: Container(
                  width: box,
                  height: box,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.9),
                        width: 7 - 5.5 * g),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: 1 - g,
              child: Transform.scale(
                scale: 0.2 + 1.0 * g,
                child: Container(
                  width: cell * 2,
                  height: cell * 2,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Colors.white,
                      Colors.yellow,
                      Colors.orange,
                      Color(0x00F44336),
                    ]),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: 1 - g,
              child: Transform.scale(
                scale: 0.4 + 1.1 * g,
                child: Text('💥', style: TextStyle(fontSize: cell * 1.1)),
              ),
            ),
          ]);
        },
      ),
    );
  }
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
}
