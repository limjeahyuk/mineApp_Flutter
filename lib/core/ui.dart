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

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Material(
      color: background ?? t.surface,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(title,
                    style: TextStyle(
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
    );
  }
}

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
          ),
      ],
    ),
  );
}

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
