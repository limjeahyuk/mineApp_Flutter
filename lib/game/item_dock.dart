import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// 아이템 도크 — Swift AutoFlagDock(+ContentView 솔로 서랍) 이식. 솔로·대전·협동·보물 공용.
/// - 작은 판(초급·중급): 우하단 플로팅 버튼(레이더가 있으면 위에 쌓는다).
/// - 큰 판(고급·최고급·보물·닿기): 오른쪽 가장자리 손잡이 `<` → 서랍. 손잡이는 위아래로 끌어 옮긴다.
/// 자동깃발은 누르면 발동 대기(probing) → 호출부 보드가 숫자칸 탭을 onProbe로 보낸다.
class ItemDock extends StatefulWidget {
  const ItemDock({
    super.key,
    required this.tickets,
    required this.isPlaying,
    required this.usesEdgeDrawer,
    required this.probing,
    required this.onProbingChanged,
    this.drawerBottomPadding = 96,
    this.megaphoneTickets,
    this.onMegaphone,
    this.radarTickets,
    this.onRadar,
    this.solo = false,
  });

  final int tickets;
  final bool isPlaying;
  final bool usesEdgeDrawer;
  final bool probing;
  final ValueChanged<bool> onProbingChanged;
  final double drawerBottomPadding;
  final int? megaphoneTickets; // null이면 확성기 항목 없음
  final VoidCallback? onMegaphone;
  final int? radarTickets; // null이면 레이더 항목 없음
  final VoidCallback? onRadar;

  /// 솔로(ContentView) 변형 — 레이더가 0개면 숨기고, 손잡이에 자동깃발 개수를 보인다.
  final bool solo;

  @override
  State<ItemDock> createState() => _ItemDockState();
}

class _ItemDockState extends State<ItemDock> {
  bool drawerOpen = false;
  double offsetY = 0; // 손잡이 세로 위치(0=기본)
  double dragY = 0;

  static const itemAccent = AppTheme.itemPurple;
  static const megaphoneAccent = AppTheme.gold;
  static const radarAccent = AppTheme.radarBlue;

  bool get _disabled => widget.tickets <= 0 || !widget.isPlaying;
  bool get _megaDisabled => (widget.megaphoneTickets ?? 0) <= 0 || !widget.isPlaying;
  bool get _radarDisabled => (widget.radarTickets ?? 0) <= 0 || !widget.isPlaying;
  bool get _anyReady =>
      widget.isPlaying &&
      (widget.tickets > 0 ||
          (widget.megaphoneTickets ?? 0) > 0 ||
          (widget.radarTickets ?? 0) > 0);
  bool get _showRadar =>
      widget.radarTickets != null && (!widget.solo || widget.radarTickets! > 0);

  void _toggleProbing() {
    Haptics.tap();
    if (widget.probing) {
      widget.onProbingChanged(false);
      return;
    }
    if (widget.tickets <= 0 || !widget.isPlaying) return;
    widget.onProbingChanged(true);
    setState(() => drawerOpen = false); // 보드(숫자칸 선택)를 가리지 않게
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return widget.usesEdgeDrawer ? _edgeDrawer(t) : _floating(t);
  }

  // MARK: 칩

  Widget _chip(AppTheme t,
      {required IconData icon,
      required String title,
      required String sub,
      required Color accent,
      required bool disabled,
      required bool highlighted,
      required bool dense,
      required VoidCallback onTap,
      double? width}) {
    final fg = highlighted ? Colors.white : (disabled ? t.textTertiary : t.text);
    return Pressable(
      enabled: !disabled || highlighted,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 16, vertical: dense ? 8 : 11),
        decoration: BoxDecoration(
          color: highlighted ? accent : t.fill,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: highlighted
                  ? Colors.white.withValues(alpha: 0.85)
                  : accent.withValues(alpha: disabled ? 0 : 0.55),
              width: highlighted ? 2 : 1.5),
          boxShadow: highlighted
              ? [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 8)]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: dense ? 16 : 18, color: fg),
          SizedBox(width: dense ? 6 : 8),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: TextStyle(
                        color: fg,
                        fontSize: dense ? 11 : 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 1),
                Text(sub,
                    style: TextStyle(
                        color: fg.withValues(alpha: 0.85),
                        fontSize: dense ? 9 : 11,
                        fontWeight: FontWeight.w500)),
              ]),
        ]),
      ),
    );
  }

  Widget _flagChip(AppTheme t, bool dense, double? w) => _chip(t,
      icon: CupertinoIcons.flag_fill,
      title: '자동깃발',
      sub: widget.probing
          ? '숫자칸 선택'
          : (widget.tickets > 0 ? '남은 ${widget.tickets}개' : '상점에서 충전'),
      accent: itemAccent,
      disabled: _disabled,
      highlighted: widget.probing,
      dense: dense,
      width: w,
      onTap: _toggleProbing);

  Widget _radarChip(AppTheme t, bool dense, double? w) {
    final n = widget.radarTickets ?? 0;
    return _chip(t,
        icon: CupertinoIcons.dot_radiowaves_left_right,
        title: '레이더',
        sub: n > 0 ? '남은 $n개' : '상점에서 충전',
        accent: radarAccent,
        disabled: _radarDisabled,
        highlighted: false,
        dense: dense,
        width: w, onTap: () {
      Haptics.tap();
      if (n <= 0 || !widget.isPlaying) return;
      widget.onRadar?.call();
      setState(() => drawerOpen = false);
    });
  }

  Widget _megaChip(AppTheme t, bool dense, double? w) {
    final n = widget.megaphoneTickets ?? 0;
    return _chip(t,
        icon: Icons.campaign,
        title: '확성기',
        sub: n > 0 ? '남은 $n개' : '상점에서 충전',
        accent: megaphoneAccent,
        disabled: _megaDisabled,
        highlighted: false,
        dense: dense,
        width: w, onTap: () {
      Haptics.tap();
      if (n <= 0 || !widget.isPlaying) return;
      widget.onMegaphone?.call();
      setState(() => drawerOpen = false);
    });
  }

  // MARK: 플로팅(작은 판)

  Widget _floating(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.only(right: 14, bottom: 52),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showRadar) ...[_radarChip(t, false, null), const SizedBox(height: 8)],
            _flagChip(t, false, null),
          ],
        ),
      ),
    );
  }

  // MARK: 엣지 서랍(큰 판)

  Widget _edgeDrawer(AppTheme t) {
    final limit = MediaQuery.sizeOf(context).height / 2 - 110;
    final handleIcon = widget.probing
        ? CupertinoIcons.xmark
        : (drawerOpen ? CupertinoIcons.chevron_right : CupertinoIcons.chevron_left);
    final handleColor = widget.probing
        ? itemAccent
        : (widget.solo || _anyReady
            ? itemAccent.withValues(alpha: 0.9)
            : Colors.grey.withValues(alpha: 0.55));
    return Padding(
      padding: EdgeInsets.only(bottom: widget.drawerBottomPadding),
      child: Transform.translate(
        offset: Offset(0, offsetY + dragY),
        child: GestureDetector(
          onVerticalDragUpdate: (d) => setState(() => dragY += d.delta.dy),
          onVerticalDragEnd: (_) => setState(() {
            offsetY = (offsetY + dragY).clamp(-limit, limit);
            dragY = 0;
          }),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                        position: Tween(
                                begin: const Offset(0.4, 0), end: Offset.zero)
                            .animate(a),
                        child: c)),
                child: !drawerOpen
                    ? const SizedBox.shrink()
                    : Container(
                        key: const ValueKey('open'),
                        margin: const EdgeInsets.only(right: 2),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: t.border),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(-2, 2))
                          ],
                        ),
                        child: IntrinsicWidth(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _flagChip(t, true, null),
                              if (widget.megaphoneTickets != null) ...[
                                const SizedBox(height: 6),
                                _megaChip(t, true, null),
                              ],
                              if (_showRadar) ...[
                                const SizedBox(height: 6),
                                _radarChip(t, true, null),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
              Pressable(
                onTap: () {
                  Haptics.tap();
                  if (widget.probing) {
                    widget.onProbingChanged(false);
                  } else {
                    setState(() => drawerOpen = !drawerOpen);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 18,
                  height: 84,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(-2, 0))
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(handleIcon, size: 13, color: Colors.white),
                      if (widget.solo && !widget.probing && widget.tickets > 0) ...[
                        const SizedBox(height: 3),
                        Text('${widget.tickets}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
