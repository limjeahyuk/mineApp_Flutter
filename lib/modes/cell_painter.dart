import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 큰 보드(보물 51×51, 닿기 80×80)를 위젯 수천 개 대신 한 번에 그리는 도우미.
/// 셀 = 고정 30pt + 간격 1 + 바깥 패딩 3 (원본 LazyVGrid와 동일 치수).
class BigBoardMetrics {
  const BigBoardMetrics(this.size, {this.cell = 30, this.gap = 1, this.pad = 3});
  final int size;
  final double cell, gap, pad;

  double get step => cell + gap;
  double get extent => pad * 2 + size * cell + (size - 1) * gap;

  Offset center(int r, int c) =>
      Offset(pad + c * step + cell / 2, pad + r * step + cell / 2);

  Rect rect(int r, int c) =>
      Rect.fromLTWH(pad + c * step, pad + r * step, cell, cell);

  /// 화면(콘텐츠) 좌표 → 칸. 간격을 눌러도 가까운 칸으로.
  (int, int)? hit(Offset p) {
    final c = ((p.dx - pad) / step).floor();
    final r = ((p.dy - pad) / step).floor();
    if (r < 0 || c < 0 || r >= size || c >= size) return null;
    return (r, c);
  }
}

/// 글자/이모지/아이콘 TextPainter 캐시 — 매 프레임 레이아웃하지 않는다.
class GlyphCache {
  final Map<String, TextPainter> _cache = {};

  TextPainter text(String s, double size, {Color? color, FontWeight? weight}) {
    final key = '$s|$size|${color?.toARGB32()}|$weight';
    return _cache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                fontSize: size, color: color, fontWeight: weight, height: 1.0)),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  TextPainter icon(IconData icon, double size, Color color, {List<Shadow>? shadows}) {
    final key = 'i${icon.codePoint}|$size|${color.toARGB32()}|${shadows != null}';
    return _cache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: size,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color,
            height: 1.0,
            shadows: shadows,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  static void drawCentered(Canvas canvas, TextPainter tp, Offset c, {double opacity = 1}) {
    final o = c - Offset(tp.width / 2, tp.height / 2);
    if (opacity >= 1) {
      tp.paint(canvas, o);
    } else {
      canvas.saveLayer(null, Paint()..color = Colors.black.withValues(alpha: opacity));
      tp.paint(canvas, o);
      canvas.restore();
    }
  }
}

const flagIcon = CupertinoIcons.flag_fill;

/// 큰 보드 뷰포트 — 두 방향 스크롤(확대 없음, 원본 ScrollView([.horizontal,.vertical])).
/// 탭/길게(0.25초)를 칸 좌표로 바꿔 넘긴다. `overlay`는 보드 좌표계 위에 얹을 연출(폭발 등).
class BigBoardViewport extends StatefulWidget {
  const BigBoardViewport({
    super.key,
    required this.metrics,
    required this.painter,
    required this.onTap,
    required this.onLongPress,
    required this.controller,
    this.overlay = const [],
    this.background,
  });
  final BigBoardMetrics metrics;
  final CustomPainter painter;
  final void Function(int r, int c) onTap;
  final void Function(int r, int c) onLongPress;
  final TransformationController controller;
  final List<Widget> overlay;
  final Color? background;

  @override
  State<BigBoardViewport> createState() => _BigBoardViewportState();
}

class _BigBoardViewportState extends State<BigBoardViewport> {
  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final e = m.extent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: widget.background ?? Colors.transparent,
        child: InteractiveViewer(
          transformationController: widget.controller,
          constrained: false,
          scaleEnabled: false,
          minScale: 1,
          maxScale: 1,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                      TapGestureRecognizer.new, (r) {
                r.onTapUp = (d) {
                  final h = m.hit(d.localPosition);
                  if (h != null) widget.onTap(h.$1, h.$2);
                };
              }),
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                      () => LongPressGestureRecognizer(
                          duration: const Duration(milliseconds: 250)), (r) {
                r.onLongPressStart = (d) {
                  final h = m.hit(d.localPosition);
                  if (h != null) widget.onLongPress(h.$1, h.$2);
                };
              }),
            },
            child: SizedBox(
              width: e,
              height: e,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                    child: RepaintBoundary(child: CustomPaint(painter: widget.painter))),
                ...widget.overlay,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 뷰포트에서 (r,c)가 화면 정중앙에 오도록 하는 변환(경계 안으로 클램프).
Matrix4 centerOn(BigBoardMetrics m, Size viewport, int r, int c) {
  final p = m.center(r, c);
  final maxX = (m.extent - viewport.width).clamp(0.0, double.infinity);
  final maxY = (m.extent - viewport.height).clamp(0.0, double.infinity);
  final x = (p.dx - viewport.width / 2).clamp(0.0, maxX);
  final y = (p.dy - viewport.height / 2).clamp(0.0, maxY);
  return Matrix4.translationValues(-x, -y, 0);
}

/// 오버레이 연출을 보드 좌표 (r,c) 중심에 놓는다.
Widget atCell(BigBoardMetrics m, int r, int c, double box, Widget child) {
  final p = m.center(r, c);
  return Positioned(
    left: p.dx - box / 2,
    top: p.dy - box / 2,
    width: box,
    height: box,
    child: IgnorePointer(child: Center(child: child)),
  );
}
