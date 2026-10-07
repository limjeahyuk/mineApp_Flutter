<<<<<<< HEAD
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
=======
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// SwiftUI 표현 방식을 흉내 내는 공용 UI 헬퍼.
/// - `presentSheet`: `.sheet` (iOS 카드형 시트, 아래로 끌어 닫기)
/// - `presentFullScreen`: `.fullScreenCover`
/// - `presentMediumSheet`: `.presentationDetents([.medium])` 반높이 시트
/// - `PlainButton`: `.buttonStyle(.plain)` — 누르는 동안 살짝 흐려지는 버튼(물결 효과 없음)
/// - `SheetScaffold`: 시트 안의 `NavigationStack` + inline 제목 + 우상단 "닫기"

/// iOS 시스템 강조색(닫기 버튼 등 툴바 텍스트).
const kSystemBlue = Color(0xFF0A84FF);
const kSystemBlueLight = Color(0xFF007AFF);

Color systemBlue(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? kSystemBlue : kSystemBlueLight;

Future<T?> presentSheet<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context).push<T>(CupertinoSheetRoute<T>(
    scrollableBuilder: (ctx, _) => builder(ctx),
  ));
}

Future<T?> presentFullScreen<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context).push<T>(MaterialPageRoute<T>(
    fullscreenDialog: true,
    builder: builder,
  ));
}

/// 반높이(medium) 시트 + 드래그 인디케이터. `large`면 끌어서 전체 높이까지 키울 수 있다.
Future<T?> presentMediumSheet<T>(BuildContext context, WidgetBuilder builder,
    {bool large = false}) {
  final t = AppTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) {
      final h = MediaQuery.of(ctx).size.height;
      if (!large) {
        // 키보드가 올라오면 시트를 그만큼 위로 밀어 올린다.
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(height: h * 0.5, child: builder(ctx)),
        );
      }
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        builder: (ctx, _) => builder(ctx),
      );
    },
  );
}

/// 시트 안의 내비게이션 바(inline 제목 + 우상단 "닫기") + 배경.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.background,
    this.closeLabel = '닫기',
    this.leading,
  });

  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final Color? background;
  final String closeLabel;
  final Widget? leading;
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Material(
<<<<<<< HEAD
      color: t.surface,
      child: Column(
        children: [
          SizedBox(
=======
      color: background ?? t.surface,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(title,
                    style: TextStyle(
<<<<<<< HEAD
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
=======
                        color: t.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                if (leading != null)
                  Positioned(left: 8, child: leading!),
                Positioned(
                  right: 8,
                  child: PlainButton(
                    onTap: onClose ?? () => Navigator.of(context).maybePop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Text(closeLabel,
                          style: TextStyle(
                              color: systemBlue(context), fontSize: 17)),
                    ),
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
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

<<<<<<< HEAD
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
=======
/// `.buttonStyle(.plain)` 버튼 — 누르는 동안 흐려진다. 비활성(onTap==null)이면 그대로 표시.
class PlainButton extends StatefulWidget {
  const PlainButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.disabled = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool disabled;

  @override
  State<PlainButton> createState() => _PlainButtonState();
}

class _PlainButtonState extends State<PlainButton> {
  bool _down = false;

  bool get _enabled => !widget.disabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: _enabled ? () => setState(() => _down = false) : null,
      onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
      onTap: _enabled ? widget.onTap : null,
      onLongPress: widget.disabled ? null : widget.onLongPress,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _down ? 0.55 : 1,
        child: widget.child,
      ),
    );
  }
}

/// 하단/상단에 잠깐 떴다 사라지는 검은 캡슐 안내(Swift toast 패턴).
class CapsuleToast extends StatelessWidget {
  const CapsuleToast(this.message, {super.key, this.fontSize = 13});
  final String message;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold)),
    );
  }
}

/// 위젯에 붙여 쓰는 토스트 상태 — `show(msg)`로 띄우고 일정 시간 후 자동으로 내린다.
class ToastController extends ValueNotifier<String?> {
  ToastController() : super(null);

  void show(String msg, {Duration duration = const Duration(milliseconds: 1800)}) {
    value = msg;
    Future.delayed(duration, () {
      if (value == msg) value = null;
    });
  }
}

/// 토스트를 화면 위(top) 또는 아래(bottom)에 겹쳐 그린다.
class ToastOverlay extends StatelessWidget {
  const ToastOverlay({
    super.key,
    required this.controller,
    this.alignment = Alignment.bottomCenter,
    this.padding = const EdgeInsets.only(bottom: 24),
    this.fontSize = 13,
  });

  final ToastController controller;
  final Alignment alignment;
  final EdgeInsets padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: padding,
            child: ValueListenableBuilder<String?>(
              valueListenable: controller,
              builder: (_, msg, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                            begin: Offset(
                                0, alignment.y < 0 ? -0.6 : 0.6),
                            end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: msg == null
                    ? const SizedBox.shrink()
                    : CapsuleToast(msg, key: ValueKey(msg), fontSize: fontSize),
              ),
            ),
          ),
        ),
      ),
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    );
  }
}

<<<<<<< HEAD
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
=======
/// SwiftUI `.alert` 스타일 확인 대화상자(iOS 모양). 버튼은 (라벨, 파괴적 여부, 값).
Future<T?> showAppAlert<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<AlertAction<T>> actions,
}) {
  return showCupertinoDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        for (final a in actions)
          CupertinoDialogAction(
            isDestructiveAction: a.destructive,
            isDefaultAction: a.isCancel,
            onPressed: () => Navigator.of(ctx).pop(a.value),
            child: Text(a.label),
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
          ),
      ],
    ),
  );
}
<<<<<<< HEAD
=======

class AlertAction<T> {
  const AlertAction(this.label, this.value,
      {this.destructive = false, this.isCancel = false});
  final String label;
  final T? value;
  final bool destructive;
  final bool isCancel;
}

/// 시간 라벨 — 60초 미만은 "X초", 그 이상은 "M:SS" (Swift winTimeLabel/timeLabel).
String timeLabel(int sec) => sec < 60
    ? '$sec초'
    : '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

/// 천 단위 콤마(Swift `.formatted()`).
String formatNumber(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// 화면 방향 — 기본 세로, 최고급 판만 가로 회전 허용(Swift setAppOrientation/bigBoardOrientations).
void setAppOrientation({bool allowLandscape = false}) {
  SystemChrome.setPreferredOrientations(allowLandscape
      ? const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]
      : const [DeviceOrientation.portraitUp]);
}

/// SwiftUI `.confirmationDialog` — iOS 액션 시트. 확인 버튼을 누르면 true.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final r = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(title),
      message: Text(message),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: destructive,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(ctx).pop(false),
        child: const Text('취소'),
      ),
    ),
  );
  return r ?? false;
}

/// SwiftUI `Picker(.segmented)` — iOS 세그먼트 컨트롤.
class SegmentedPicker<T extends Object> extends StatelessWidget {
  const SegmentedPicker({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: t.dark
            ? const Color(0xFF2C2C2E).withValues(alpha: 0.9)
            : const Color(0xFF767680).withValues(alpha: 0.12),
        thumbColor: t.dark ? const Color(0xFF636366) : Colors.white,
        children: {
          for (final e in items.entries)
            e.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(e.value,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 13,
                      fontWeight: e.key == value
                          ? FontWeight.w600
                          : FontWeight.w500)),
            ),
        },
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// 얇은 캡슐 진행 바(Swift progressBar).
class CapsuleProgress extends StatelessWidget {
  const CapsuleProgress(
      {super.key, required this.fraction, required this.color, this.height = 6});
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (_, c) => Stack(
          children: [
            Container(
                decoration: BoxDecoration(
                    color: t.fill,
                    borderRadius: BorderRadius.circular(height))),
            Container(
              width: c.maxWidth * fraction.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(height)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 홈 ↔ 게임 화면 전환 — Swift RootView의 `.transition(.opacity)`(0.25초 크로스페이드).
Route<T> fadeRoute<T>(WidgetBuilder builder) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, _, _) => builder(ctx),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: child),
    );
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
