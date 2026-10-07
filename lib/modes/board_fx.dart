import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 보물찾기·닿기 보드 공용 연출 — Swift TreasureBlast/TouchBlast, ShakeEffect, MeetMarker 이식.

/// 지뢰 폭발 — 충격파 링 + 불꽃 코어 + 💥가 커지며 사라진다(0.5초).
class BlastEffect extends StatefulWidget {
  const BlastEffect({super.key, required this.cell});
  final double cell;

  @override
  State<BlastEffect> createState() => _BlastEffectState();
}

class _BlastEffectState extends State<BlastEffect> with SingleTickerProviderStateMixin {
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
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final g = Curves.easeOut.transform(_c.value);
        return SizedBox(
          width: cell * 2.6,
          height: cell * 2.6,
          child: Stack(alignment: Alignment.center, children: [
            Opacity(
              opacity: (1 - g) * 0.9,
              child: Transform.scale(
                scale: 0.25 + 0.75 * g,
                child: Container(
                  width: cell * 2.6,
                  height: cell * 2.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.9), width: 7 - 5.5 * g),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: 1 - g,
              child: Transform.scale(
                scale: 0.2 + 1.0 * g,
                child: Container(
                  width: cell * 2.0,
                  height: cell * 2.0,
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
          ]),
        );
      },
    );
  }
}

/// 지뢰를 밟을 때 보드를 좌우로 잠깐 흔든다 — `trigger`가 바뀔 때마다.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void didUpdateWidget(covariant Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
            offset: Offset(7 * sin(_c.value * pi * 3), 0), child: child),
        child: widget.child,
      );
}

/// 두 사람이 처음 만난 칸 — 펄스 링 + 🤝.
class MeetMarker extends StatefulWidget {
  const MeetMarker({super.key, required this.cell});
  final double cell;

  @override
  State<MeetMarker> createState() => _MeetMarkerState();
}

class _MeetMarkerState extends State<MeetMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 1))
    ..repeat(reverse: true);
  static const _accent = Color.fromRGBO(102, 179, 140, 1);

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
        final p = Curves.easeInOut.transform(_c.value);
        return SizedBox(
          width: cell * 2.6,
          height: cell * 2.6,
          child: Stack(alignment: Alignment.center, children: [
            Opacity(
              opacity: 0.85 - 0.7 * p,
              child: Transform.scale(
                scale: 0.82 + 0.30 * p,
                child: Container(
                  width: cell * 2.3,
                  height: cell * 2.3,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _accent, width: 3)),
                ),
              ),
            ),
            Text('🤝', style: TextStyle(fontSize: cell * 0.85)),
          ]),
        );
      },
    );
  }
}

/// 보물·닿기 보드의 숫자 색 — CellView와 같고 7=본문, 8=보조 텍스트.
Color modeNumberColor(int n, AppTheme t) => switch (n) {
      7 => t.text,
      8 => t.textSecondary,
      _ => minesweeperNumberColor(n, t.dark),
    };
