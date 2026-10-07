import 'dart:math';

import 'package:flutter/material.dart';

/// 클리어 팝업 뒤에서 쏟아지는 색종이 — Swift ConfettiView 이식(입력은 통과).
/// 무작위 색·크기·낙하 속도·회전·좌우 흩날림으로 반복해서 떨어진다.
class ConfettiView extends StatefulWidget {
  const ConfettiView({super.key, this.count = 70});
  final int count;

  @override
  State<ConfettiView> createState() => _ConfettiViewState();
}

class _Piece {
  _Piece(Random r)
      : x = r.nextDouble(),
        color = _palette[r.nextInt(_palette.length)],
        size = 7 + r.nextDouble() * 6,
        delay = r.nextDouble() * 1.4,
        duration = 2.2 + r.nextDouble() * 1.6,
        spin = (240 + r.nextDouble() * 660) * (r.nextBool() ? 1 : -1),
        drift = -45 + r.nextDouble() * 90,
        isRect = r.nextBool();

  final double x, size, delay, duration, spin, drift;
  final Color color;
  final bool isRect;

  static const _palette = [
    Color.fromRGBO(242, 77, 102, 1),
    Color.fromRGBO(250, 199, 77, 1),
    Color.fromRGBO(77, 191, 140, 1),
    Color.fromRGBO(77, 140, 242, 1),
    Color.fromRGBO(179, 115, 242, 1),
    Color.fromRGBO(250, 140, 191, 1),
  ];
}

class _ConfettiViewState extends State<ConfettiView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(days: 1))
    ..forward();
  late final List<_Piece> _pieces =
      List.generate(widget.count, (_) => _Piece(Random()));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
              _pieces, (_c.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = t - p.delay;
      if (local < 0) continue;
      final phase = (local % p.duration) / p.duration;
      final eased = phase * phase; // easeIn
      final x = p.x * size.width + p.drift * eased;
      final y = -50 + (size.height + 100) * eased;
      final paint = Paint()..color = p.color;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * eased * pi / 180);
      if (p.isRect) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero, width: p.size, height: p.size * 0.45),
                const Radius.circular(1.5)),
            paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
