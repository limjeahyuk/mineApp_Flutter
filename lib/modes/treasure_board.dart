<<<<<<< HEAD
import 'dart:async';

=======
import 'dart:math';

import 'package:flutter/gestures.dart';
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/types.dart';
<<<<<<< HEAD
import 'board_fx.dart';
import 'cell_painter.dart';
import 'treasure_model.dart';

/// 보물찾기 보드 — Swift TreasureBoardView 이식(솔로/멀티 공용).
/// 프런티어 금색 테두리 + 폭발 + 흔들림. `flipped`(멀티 게스트)면 180° 뒤집어
/// 양쪽 모두 "내 출발점은 좌상단"으로 보이게 한다. 복기(`reviewing`) 진입 시 가운데 💎로 이동.
=======
import 'treasure_model.dart';

/// 보물찾기 보드 렌더링 — 솔로/멀티 공용. Swift TreasureBoardView 이식.
/// 30pt 고정 셀 그리드(가로·세로 스크롤) + 프런티어 금색 테두리 + 지뢰 폭발 효과 + 밟을 때 보드 흔들림.
/// `flipped`(멀티 게스트)면 180° 뒤집어 그려 양쪽 모두 "내 출발점은 좌상단"으로 보인다.
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
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
<<<<<<< HEAD
=======

>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
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
<<<<<<< HEAD
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
=======
  static const _cell = 30.0;
  static const _gap = 1.0;
  static const _pad = 3.0;
  static const _gold = AppTheme.gold;
  static const _opp = Color.fromRGBO(242, 115, 77, 1);

  final _h = ScrollController();
  final _v = ScrollController();
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  int _lastHits = 0;

  TreasureModel get game => widget.game;

  @override
  void initState() {
    super.initState();
    _lastHits = game.minesHit;
    game.addListener(_onGame);
  }
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  @override
  void didUpdateWidget(covariant TreasureBoard old) {
    super.didUpdateWidget(old);
<<<<<<< HEAD
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
=======
    if (old.game != widget.game) {
      old.game.removeListener(_onGame);
      widget.game.addListener(_onGame);
    }
    // 복기 진입 시 가운데 보물(💎)이 화면 중앙에 오도록 이동한다.
    if (widget.reviewing && !old.reviewing) {
      for (final d in const [0, 200, 450, 800]) {
        Future.delayed(Duration(milliseconds: d), _scrollToCenter);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      }
    }
  }

  @override
  void dispose() {
<<<<<<< HEAD
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
=======
    game.removeListener(_onGame);
    _h.dispose();
    _v.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onGame() {
    // 지뢰를 밟을 때마다 보드를 잠깐 흔든다.
    if (game.minesHit != _lastHits) {
      _lastHits = game.minesHit;
      if (game.minesHit > 0) _shake.forward(from: 0);
    }
  }

  void _scrollToCenter() {
    if (!mounted || !_h.hasClients || !_v.hasClients) return;
    final step = _cell + _gap;
    final mid = _pad + game.center * step + _cell / 2;
    void go(ScrollController s) {
      final target = (mid - s.position.viewportDimension / 2)
          .clamp(0.0, s.position.maxScrollExtent);
      s.animateTo(target,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }

    go(_h);
    go(_v);
  }

  (int, int) _flip(int r, int c) => widget.flipped
      ? (game.size - 1 - r, game.size - 1 - c)
      : (r, c);

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final n = game.size;
    final side = _pad * 2 + n * _cell + (n - 1) * _gap;
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) => Transform.translate(
        offset: Offset(7 * sin(_shake.value * pi * 3), 0),
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: t.boardFrame,
          child: Scrollbar(
            controller: _v,
            child: SingleChildScrollView(
              controller: _v,
              child: Scrollbar(
                controller: _h,
                notificationPredicate: (n) => n.depth == 0,
                child: SingleChildScrollView(
                  controller: _h,
                  scrollDirection: Axis.horizontal,
                  child: ListenableBuilder(
                    listenable: game,
                    builder: (_, _) => SizedBox(
                      width: side,
                      height: side,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(_pad),
                            child: Column(
                              children: [
                                for (var dr = 0; dr < n; dr++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        top: dr == 0 ? 0 : _gap),
                                    child: Row(
                                      children: [
                                        for (var dc = 0; dc < n; dc++)
                                          Padding(
                                            padding: EdgeInsets.only(
                                                left: dc == 0 ? 0 : _gap),
                                            child: _cellView(t, dr, dc),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          for (final b in game.blasts)
                            Builder(builder: (_) {
                              final (dr, dc) = _flip(b.r, b.c);
                              final step = _cell + _gap;
                              final cx = _pad + dc * step + _cell / 2;
                              final cy = _pad + dr * step + _cell / 2;
                              return Positioned(
                                left: cx - _cell * 1.3,
                                top: cy - _cell * 1.3,
                                child: IgnorePointer(
                                  child: _TreasureBlast(
                                      key: ValueKey(b.id), cell: _cell),
                                ),
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
      ),
    );
  }

  Widget _cellView(AppTheme t, int dr, int dc) {
    final (r, c) = _flip(dr, dc); // 화면 → 모델
    final d = game.grid[r][c];
    final frontier = !d.isRevealed && game.isFrontier(r, c);
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          TapGestureRecognizer.new,
          (rec) => rec.onTap = () {
            if (widget.probing) {
              widget.onProbe?.call(r, c); // 자동깃발 발동
            } else if (game.grid[r][c].isRevealed) {
              game.chord(r, c); // 열린 숫자 탭 = 주변 일괄 열기(모드 무관)
            } else if (widget.flagMode) {
              game.toggleFlag(r, c);
            } else {
              game.tap(r, c);
            }
          },
        ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
              duration: const Duration(milliseconds: 250)),
          (rec) => rec.onLongPress = () {
            if (widget.probing || game.grid[r][c].isRevealed) return;
            if (widget.flagMode) {
              game.tap(r, c);
            } else {
              game.toggleFlag(r, c);
            }
          },
        ),
      },
      child: Container(
        width: _cell,
        height: _cell,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _fill(t, d),
          borderRadius: BorderRadius.circular(3),
          border: frontier
              ? Border.all(color: _gold.withValues(alpha: 0.9), width: 1.6)
              : null,
        ),
        child: _label(t, d),
      ),
    );
  }

  Color _fill(AppTheme t, TrCell d) {
    if (d.isRevealed) {
      if (d.isTreasure) return _gold.withValues(alpha: 0.32);
      if (d.exploded) return Colors.red.withValues(alpha: 0.30);
      // 상대가 연 칸은 상대 색으로 → "상대가 어디까지 왔는지" 한눈에 보인다.
      return d.owner == FlagOwner.opponent
          ? _opp.withValues(alpha: 0.30)
          : t.cellRevealed;
    }
    return d.isTreasure ? _gold.withValues(alpha: 0.18) : t.cellClosedTop;
  }

  Widget? _label(AppTheme t, TrCell d) {
    const s = _cell;
    if (d.isRevealed) {
      if (d.isTreasure) {
        return const Text('💎', style: TextStyle(fontSize: s * 0.6, height: 1));
      }
      if (d.exploded) {
        return const Text('💣', style: TextStyle(fontSize: s * 0.5, height: 1));
      }
      if (d.adjacent > 0) {
        final color = d.adjacent == 7
            ? t.text
            : d.adjacent >= 8
                ? t.textSecondary
                : minesweeperNumberColor(d.adjacent, t.dark);
        return Text('${d.adjacent}',
            style: TextStyle(
                fontSize: s * 0.5,
                height: 1,
                fontWeight: FontWeight.w900,
                color: color));
      }
      return null;
    }
    if (d.isFlagged) {
      if (d.isGolden) {
        return Icon(Icons.flag, size: s * 0.6, color: _gold, shadows: [
          Shadow(color: _gold.withValues(alpha: 0.7), blurRadius: s * 0.12)
        ]);
      }
      return const Text('🚩', style: TextStyle(fontSize: s * 0.5, height: 1));
    }
    if (game.won && d.isMine) {
      return const Text('💣', style: TextStyle(fontSize: s * 0.5, height: 1));
    }
    if (d.isTreasure) {
      return const Opacity(
          opacity: 0.5,
          child: Text('💎', style: TextStyle(fontSize: s * 0.5, height: 1)));
    }
    return null;
  }
}

/// 지뢰를 밟았을 때의 폭발 연출 — 충격파 링 + 불꽃 코어 + 💥가 커지며 사라진다.
class _TreasureBlast extends StatefulWidget {
  const _TreasureBlast({super.key, required this.cell});
  final double cell;

  @override
  State<_TreasureBlast> createState() => _TreasureBlastState();
}

class _TreasureBlastState extends State<_TreasureBlast>
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
          return Stack(
            alignment: Alignment.center,
            children: [
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Colors.white,
                        Colors.yellow,
                        Colors.orange,
                        Colors.red.withValues(alpha: 0),
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
            ],
          );
        },
      ),
    );
  }
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
}
