import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/types.dart';
import 'coop_controller.dart';
import 'touch_model.dart';

/// "너에게 닿기를" 보드 — 안개(fog) 렌더링. Swift TouchBoardView 이식.
/// 내가 연 칸 기준 거리 안만 보이고, 그 밖은 구름색으로 가린다. 상대가 연 칸/깃발이
/// 안개 안에 들어오면 보여서 "근처에 누가 왔다"를 알아챌 수 있다.
/// 30pt 고정 셀(가로·세로 스크롤). 처음에 내 시작점이 화면 중앙에 오도록 스크롤한다.
/// 80×80(6,400칸)이라 셀 위젯 대신 한 장의 CustomPaint로 그리고, 탭 위치로 칸을 계산한다.
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

  /// 복기 모드 — 안개를 모두 걷어 두 사람이 연 길과 만난 지점을 보여준다.
  final bool reveal;

  @override
  State<TouchBoard> createState() => _TouchBoardState();
}

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

  @override
  void didUpdateWidget(covariant TouchBoard old) {
    super.didUpdateWidget(old);
    if (widget.reveal && !old.reveal) {
      final t = game.meetPoint ?? game.myStart;
      _centerCamera(t.$1, t.$2, animated: true);
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
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
  }
}

class _TouchPainter extends CustomPainter {
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
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
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
          }
        } else {
          bg = t.cellClosedTop;
        }
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
        }
      }
    }
  }

  @override
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
}
