import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// 원본(SwiftUI)의 SF Symbols 대응 아이콘. Material 아이콘(각진 형태) 대신
/// SF Symbols와 같은 모양의 CupertinoIcons를 쓴다. 없는 것만 둥근 Material로 대체.
class SF {
  static const flagFill = CupertinoIcons.flag_fill;
  static const warningFill = CupertinoIcons.exclamationmark_triangle_fill;
  static const checkCircleFill = CupertinoIcons.checkmark_circle_fill;
  static const xmark = CupertinoIcons.xmark;
  static const chevronRight = CupertinoIcons.chevron_right;
  static const chevronLeft = CupertinoIcons.chevron_left;
  static const sealFill = CupertinoIcons.checkmark_seal_fill;
  static const arrowClockwise = CupertinoIcons.arrow_clockwise;
  static const trophyFill = Icons.emoji_events_rounded;
  static const rosette = CupertinoIcons.rosette;
  static const plusCircleFill = CupertinoIcons.plus_circle_fill;
  static const personFill = CupertinoIcons.person_fill;
  static const megaphoneFill = Icons.campaign_rounded;
  static const lockFill = CupertinoIcons.lock_fill;
  static const giftFill = CupertinoIcons.gift_fill;
  static const gift = CupertinoIcons.gift;
  static const ellipsis = CupertinoIcons.ellipsis;
  static const radar = CupertinoIcons.dot_radiowaves_left_right;
  static const uturnBackward = CupertinoIcons.arrow_uturn_left;
  static const trash = CupertinoIcons.trash;
  static const playRectFill = CupertinoIcons.play_rectangle_fill;
  static const pinFill = CupertinoIcons.pin_fill;
  static const personCropCircle = CupertinoIcons.person_crop_circle;
  static const person2Fill = CupertinoIcons.person_2_fill;
  static const pencil = CupertinoIcons.pencil;
  static const locationNorthFill = CupertinoIcons.location_north_fill;
  static const lightbulbFill = CupertinoIcons.lightbulb_fill;
  static const houseFill = CupertinoIcons.house_fill;
  static const globe = CupertinoIcons.globe;
  static const gamecontrollerFill = CupertinoIcons.gamecontroller_fill;
  static const checkmark = CupertinoIcons.checkmark;
  static const bookFill = CupertinoIcons.book_fill;
  static const bellSlash = CupertinoIcons.bell_slash;
  static const bellFill = CupertinoIcons.bell_fill;
  static const bagFill = CupertinoIcons.bag_fill;
  static const gearFill = CupertinoIcons.gear_alt_fill;
  static const zoomIn = CupertinoIcons.zoom_in;
  static const zoomOut = CupertinoIcons.zoom_out;
  static const docOnDoc = CupertinoIcons.doc_on_doc;
  static const sunFill = CupertinoIcons.sun_max_fill;
  static const moonFill = CupertinoIcons.moon_fill;
  static const iphone = CupertinoIcons.device_phone_portrait;
  static const shareUp = CupertinoIcons.square_arrow_up;
  static const bolt = CupertinoIcons.bolt_fill;
  static const sparkles = CupertinoIcons.sparkles;
  static const hourglass = CupertinoIcons.hourglass;
  static const clockFill = CupertinoIcons.clock_fill;
  static const starFill = CupertinoIcons.star_fill;
}

/// SwiftUI `.font(.system(size:, weight:, design:))` 대응 텍스트 스타일.
TextStyle sf(double size,
    {FontWeight weight = FontWeight.w400,
    Color? color,
    bool mono = false,
    double? height}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    fontFamily: mono ? 'Menlo' : null,
    fontFamilyFallback: mono ? const ['Courier', 'monospace'] : null,
    fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
  );
}

/// SwiftUI weight 이름 대응.
class W {
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semibold = FontWeight.w600;
  static const bold = FontWeight.w700;
  static const heavy = FontWeight.w800;
  static const black = FontWeight.w900;
}

/// 원본의 `Button { } .buttonStyle(.plain)` 대응 — 리플 없이 누르는 동안 살짝 흐려진다.
class Tap extends StatefulWidget {
  const Tap({super.key, required this.child, this.onTap, this.onLongPress});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedOpacity(
        opacity: _down ? 0.55 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

/// 코드로 그린 '황금 지뢰' 코인 아이콘 — Swift `GoldenMineIcon` 이식.
class GoldenMineIcon extends StatelessWidget {
  const GoldenMineIcon({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size, height: size, child: CustomPaint(painter: _GoldenMinePainter()));
}

class _GoldenMinePainter extends CustomPainter {
  static const highlight = Color.fromRGBO(255, 237, 148, 1); // (1.00,0.93,0.58)
  static const goldMid = Color.fromRGBO(245, 194, 61, 1); // (0.96,0.76,0.24)
  static const goldDeep = Color.fromRGBO(179, 117, 15, 1); // (0.70,0.46,0.06)

  @override
  void paint(Canvas canvas, Size sz) {
    final s = sz.width;
    final c = Offset(s / 2, s / 2);
    // 스파이크 8개 — 폭 0.11s, 길이 0.26s, 중심에서 -0.36s 떨어진 캡슐.
    final spikeW = s * 0.11, spikeH = s * 0.26;
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * math.pi / 4);
      final rect = Rect.fromCenter(
          center: Offset(0, -s * 0.36), width: spikeW, height: spikeH);
      final p = Paint()
        ..shader = const LinearGradient(
          colors: [goldMid, goldDeep],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(spikeW / 2)), p);
      canvas.restore();
    }
    // 본체 구.
    final r = s * 0.35;
    final body = Rect.fromCircle(center: c, radius: r);
    final center = Offset(body.left + body.width * 0.34, body.top + body.height * 0.30);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: const [highlight, goldMid, goldDeep],
            center: Alignment(
                (center.dx - body.left) / body.width * 2 - 1,
                (center.dy - body.top) / body.height * 2 - 1),
            radius: (s * 0.40) / body.width,
          ).createShader(body));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.5, s * 0.02)
          ..color = goldDeep.withValues(alpha: 0.55));
    // 반짝임.
    canvas.drawCircle(
        Offset(c.dx - s * 0.12, c.dy - s * 0.13),
        s * 0.075,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.015 + 0.01));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 원본 `.sheet { NavigationStack { ... .navigationTitle(.inline) .toolbar { 닫기 } } }` 대응.
/// iOS 페이지 시트처럼 위에서 살짝 내려온 카드로 띄운다.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder,
    {bool full = true}) {
  final t = AppTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.surface,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) => full
        ? SizedBox(
            height: MediaQuery.of(ctx).size.height -
                MediaQuery.of(ctx).padding.top -
                10,
            child: builder(ctx))
        : builder(ctx),
  );
}

/// 네비게이션 바(인라인 제목 + 오른쪽 "닫기") 있는 시트 본문.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.leading,
  });
  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return ColoredBox(
      color: t.surface,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(title, style: sf(17, weight: W.semibold, color: t.text)),
                if (leading != null)
                  Positioned(left: 16, top: 0, bottom: 0, child: Center(child: leading)),
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Tap(
                      onTap: onClose ?? () => Navigator.of(context).maybePop(),
                      child: Text('닫기',
                          style: sf(17, color: const Color(0xFF0A84FF))),
                    ),
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

/// 원본 섹션 제목(13 semibold, secondary).
Widget sectionLabel(AppTheme t, String text) => Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: sf(13, weight: W.semibold, color: t.textSecondary)),
    );

/// 둥근 사각 배경 박스 — `.background(RoundedRectangle(cornerRadius:).fill())` 대응.
BoxDecoration rr(double radius, Color fill, {Color? stroke, double width = 1}) =>
    BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: stroke == null ? null : Border.all(color: stroke, width: width),
    );

/// 화면 하단/상단에 잠깐 뜨는 검정 캡슐 안내.
Widget toastCapsule(String msg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(100)),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: sf(14, weight: W.bold, color: Colors.white)),
    );

/// 숫자 천 단위 콤마(`Int.formatted()`).
String fmt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// iOS `Picker(.segmented)` 대응 세그먼트 컨트롤.
class Segmented extends StatelessWidget {
  const Segmented(
      {super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: rr(9, t.dark ? const Color(0xFF2C2C2E) : const Color(0xFFE3E3E8)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i != index) onChanged(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: i == index
                      ? BoxDecoration(
                          color: t.dark ? const Color(0xFF636366) : Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 2)),
                          ],
                        )
                      : null,
                  child: Text(labels[i],
                      style: sf(13,
                          weight: i == index ? W.semibold : W.medium, color: t.text)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 섹션 라벨(색 점 + 제목) — Shop/Ranking 등의 sectionLabel(accent:).
Widget dotLabel(AppTheme t, String text, Color accent) => Row(children: [
      Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
      const SizedBox(width: 7),
      Text(text, style: sf(13, weight: W.bold, color: t.textSecondary)),
    ]);

/// 시트 안 하단 토스트를 띄우는 믹스인 — `showToast(msg)` 후 `toastOverlay()`를 Stack에 둔다.
mixin ToastMixin<T extends StatefulWidget> on State<T> {
  String? toast;
  void showToast(String msg) {
    setState(() => toast = msg);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && toast == msg) setState(() => toast = null);
    });
  }

  Widget toastOverlay({double bottom = 30}) => Positioned(
        left: 20,
        right: 20,
        bottom: bottom,
        child: IgnorePointer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: toast == null
                ? const SizedBox.shrink()
                : Center(key: ValueKey(toast), child: toastCapsule(toast!)),
          ),
        ),
      );
}

/// SwiftUI `.confirmationDialog` 대응 — iOS 액션 시트(확인/취소). 확인이면 true.
Future<bool?> showCupertinoConfirm(BuildContext context,
    {required String title,
    String? message,
    required String confirm,
    bool destructive = false}) {
  return showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(title),
      message: message == null ? null : Text(message),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: destructive,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx, false),
        child: const Text('취소'),
      ),
    ),
  );
}

/// SwiftUI `.alert` 대응 — iOS 알럿. 버튼 라벨 목록 중 누른 인덱스를 돌려준다.
Future<int?> showCupertinoAlert(BuildContext context,
    {required String title,
    String? message,
    List<String> actions = const ['확인'],
    int? destructiveIndex,
    int? cancelIndex}) {
  return showCupertinoDialog<int>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        for (var i = 0; i < actions.length; i++)
          CupertinoDialogAction(
            isDestructiveAction: i == destructiveIndex,
            isDefaultAction: i == cancelIndex,
            onPressed: () => Navigator.pop(ctx, i),
            child: Text(actions[i]),
          ),
      ],
    ),
  );
}

/// 텍스트 입력 알럿(닉네임 변경 등). 저장이면 입력값, 취소면 null.
Future<String?> showCupertinoTextAlert(BuildContext context,
    {required String title,
    String? message,
    String initial = '',
    String placeholder = '',
    String confirm = '저장'}) {
  final c = TextEditingController(text: initial);
  return showCupertinoDialog<String>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Column(children: [
        if (message != null) Text(message),
        const SizedBox(height: 10),
        CupertinoTextField(controller: c, placeholder: placeholder, autofocus: true),
      ]),
      actions: [
        CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, c.text), child: Text(confirm)),
        CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소')),
      ],
    ),
  );
}
