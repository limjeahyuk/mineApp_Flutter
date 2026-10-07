import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'haptics.dart';
import 'theme.dart';

/// SwiftUI `.buttonStyle(.plain)` 느낌의 버튼 — 잉크 리플 없이 누르는 동안 살짝 흐려진다.
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key,
      required this.child,
      this.onTap,
      this.onLongPress,
      this.haptic = false,
      this.enabled = true});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool haptic; // 누를 때 Haptics.tap()
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTap: active
          ? () {
              if (widget.haptic) Haptics.tap();
              widget.onTap?.call();
            }
          : null,
      onLongPress: active ? widget.onLongPress : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 90),
        opacity: _down ? 0.55 : 1,
        child: widget.child,
      ),
    );
  }
}

/// 코드로 그린 '황금 지뢰' 아이콘 — 코인 표시에 쓴다(Swift GoldenMineIcon 이식).
class GoldenMineIcon extends StatelessWidget {
  const GoldenMineIcon({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoldenMinePainter()));
}

class _GoldenMinePainter extends CustomPainter {
  static const highlight = Color.fromRGBO(255, 237, 148, 1);
  static const goldMid = Color.fromRGBO(245, 194, 61, 1);
  static const goldDeep = Color.fromRGBO(179, 117, 15, 1);

  @override
  void paint(Canvas canvas, Size sz) {
    final s = sz.width;
    final c = Offset(s / 2, s / 2);
    // 스파이크 8개(구 뒤에서 45°씩 바깥으로).
    final spikeW = s * 0.11, spikeH = s * 0.26;
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * pi / 4);
      final rect = Rect.fromCenter(
          center: Offset(0, -s * 0.36), width: spikeW, height: spikeH);
      final p = Paint()
        ..shader = const LinearGradient(
                colors: [goldMid, goldDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter)
            .createShader(rect);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(spikeW / 2)), p);
      canvas.restore();
    }
    // 본체 구.
    final r = s * 0.35;
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.32, -0.40),
        radius: 0.40 / 0.70, // Swift endRadius 0.40s ÷ 구 지름 0.70s
        colors: const [highlight, goldMid, goldDeep],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, body);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.5, s * 0.02)
          ..color = goldDeep.withValues(alpha: 0.55));
    // 하이라이트.
    canvas.drawCircle(
        c.translate(-s * 0.12, -s * 0.13),
        s * 0.075,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.015));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// iOS `.sheet` 모양 — 모달 카드(뒤 화면이 살짝 작아짐) + 위쪽 "제목 / 닫기" 바.
/// 원본의 NavigationStack(.inline 제목 + 우측 "닫기") 시트를 그대로 옮긴다.
Future<T?> presentSheet<T>(BuildContext context, Widget Function(BuildContext) builder) {
  return showCupertinoSheet<T>(
    context: context,
    scrollableBuilder: (ctx, _) => builder(ctx),
  );
}

/// 시트 안 기본 골격 — 상단 바(가운데 제목 + 오른쪽 "닫기") + 배경 surface.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold(
      {super.key, required this.title, required this.child, this.onClose});
  final String title;
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Material(
      color: t.surface,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(title,
                    style: TextStyle(
                        color: t.text, fontSize: 17, fontWeight: FontWeight.w600)),
                Positioned(
                  right: 16,
                  child: Pressable(
                    onTap: onClose ?? () => Navigator.of(context).maybePop(),
                    child: const Text('닫기',
                        style: TextStyle(
                            color: AppTheme.iosBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w400)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 작은 섹션 제목 — 색 점 + 굵은 회색 글자(원본 sectionLabel).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, required this.accent, this.trailing});
  final String text;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Row(children: [
      Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
      const SizedBox(width: 7),
      Text(text,
          style: TextStyle(
              color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
      const Spacer(),
      ?trailing,
    ]);
  }
}

/// 하단/상단에 잠깐 떴다 사라지는 검은 캡슐 토스트.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.child, this.top = false});
  final Widget child;
  final bool top;

  static ToastHostState? of(BuildContext c) =>
      c.findAncestorStateOfType<ToastHostState>();

  @override
  State<ToastHost> createState() => ToastHostState();
}

class ToastHostState extends State<ToastHost> {
  String? _msg;
  Timer? _timer;

  void show(String msg, {Duration duration = const Duration(milliseconds: 1800)}) {
    _timer?.cancel();
    setState(() => _msg = msg);
    _timer = Timer(duration, () {
      if (mounted) setState(() => _msg = null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _msg;
    return Stack(children: [
      widget.child,
      Positioned(
        left: 0,
        right: 0,
        top: widget.top ? MediaQuery.paddingOf(context).top + 8 : null,
        bottom: widget.top ? null : MediaQuery.paddingOf(context).bottom + 30,
        child: IgnorePointer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                    position: Tween(
                            begin: Offset(0, widget.top ? -0.6 : 0.6),
                            end: Offset.zero)
                        .animate(a),
                    child: child)),
            child: m == null
                ? const SizedBox.shrink()
                : Center(
                    key: ValueKey(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(100)),
                      child: Text(m,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
          ),
        ),
      ),
    ]);
  }
}

/// 숫자에 천 단위 쉼표(Swift `.formatted()`).
String fmt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// 60초 미만은 "X초", 그 이상은 "M:SS".
String timeLabel(int sec) => sec < 60
    ? '$sec초'
    : '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

/// 가운데 팝업 카드(반투명 검은 배경 + 둥근 카드) — 원본 오버레이 공통 골격.
class PopupCard extends StatelessWidget {
  const PopupCard(
      {super.key,
      required this.child,
      this.borderColor,
      this.glow,
      this.maxWidth = 300,
      this.padding = 26});
  final Widget child;
  final Color? borderColor;
  final Color? glow;
  final double maxWidth;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(36),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: borderColor ?? t.fillElevated,
                width: borderColor != null ? 1.5 : 1),
            boxShadow: glow != null
                ? [BoxShadow(color: glow!, blurRadius: 26)]
                : null,
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

/// 꽉 찬 너비 큰 버튼(높이 50, 둥근 12) — 원본 팝업 버튼.
class BigButton extends StatelessWidget {
  const BigButton(
      {super.key,
      required this.label,
      required this.onTap,
      required this.color,
      this.textColor = Colors.white,
      this.icon,
      this.height = 50,
      this.fontSize = 17});
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: fontSize + 1),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// 테두리만 있는 꽉 찬 버튼("보드 보기" 등).
class OutlineButton extends StatelessWidget {
  const OutlineButton(
      {super.key,
      required this.label,
      required this.onTap,
      required this.color,
      this.icon,
      this.height = 46});
  final String label;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5)),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

/// 텍스트만 있는 작은 버튼("보드 보기"/"나가기"/"결과 보기" 등).
class TextLink extends StatelessWidget {
  const TextLink(this.label,
      {super.key, required this.onTap, this.color, this.fontSize = 14, this.weight = FontWeight.w500});
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final double fontSize;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label,
              style: TextStyle(
                  color: color ?? AppTheme.of(context).textSecondary,
                  fontSize: fontSize,
                  fontWeight: weight)),
        ),
      );
}

/// iOS 알림창(제목·메시지·버튼들). 버튼은 (라벨, 파괴적?, 콜백).
Future<void> showIOSAlert(BuildContext context,
    {required String title,
    String? message,
    Widget? content,
    required List<(String, bool, VoidCallback?)> actions}) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: content ?? (message == null ? null : Text(message)),
      actions: [
        for (final a in actions)
          CupertinoDialogAction(
            isDestructiveAction: a.$2,
            onPressed: () {
              Navigator.of(ctx).pop();
              a.$3?.call();
            },
            child: Text(a.$1),
          ),
      ],
    ),
  );
}
