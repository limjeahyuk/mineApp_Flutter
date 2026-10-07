import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// 아이템(자동깃발·확성기·레이더) 도크 — Swift `AutoFlagDock`(대전·협동·보물) +
/// ContentView 솔로 아이템 UI 이식. 보드 위 Stack에 `Positioned.fill`로 겹쳐 쓴다.
/// - 초급·중급: 화면 우측 하단에 떠 있는 버튼(레이더가 있으면 위에 함께 쌓는다).
/// - 고급·최고급(·보물): 오른쪽 가장자리 탭(서랍). 손잡이를 눌러 열고, 위아래로 드래그해 옮긴다.
/// `probing`이 켜지면 호출부(BoardWidget)가 보드 탭을 자동깃발(onProbe)로 보낸다.
class ItemDock extends StatefulWidget {
  const ItemDock({
    super.key,
    required this.tickets,
    required this.isPlaying,
    required this.usesEdgeDrawer,
    required this.probing,
    required this.onProbingChanged,
    this.drawerBottomPadding = 96,
    this.floatingBottomPadding = 52,
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
  final double floatingBottomPadding;

  /// 확성기 남은 수 — null이면 확성기 항목 없음(협동 전용).
  final int? megaphoneTickets;
  final VoidCallback? onMegaphone;

  /// 레이더 남은 수 — null이면 레이더 항목 없음(솔로·대전 전용).
  final int? radarTickets;
  final VoidCallback? onRadar;

  /// 솔로(ContentView) 스타일 — 레이더는 보유분이 있을 때만 보이고, 손잡이에 남은 자동깃발 수를 표시.
  final bool solo;

  @override
  State<ItemDock> createState() => _ItemDockState();
}

class _ItemDockState extends State<ItemDock> {
  bool _drawerOpen = false;
  double _drawerOffsetY = 0; // 손잡이 세로 위치(드래그로 이동)
  double _drag = 0;

  static const _itemAccent = AppTheme.itemPurple;
  static const _megaphoneAccent = AppTheme.gold;
  static const _radarAccent = AppTheme.radarSky;

  bool get _disabled => widget.tickets <= 0 || !widget.isPlaying;
  bool get _megaphoneDisabled =>
      (widget.megaphoneTickets ?? 0) <= 0 || !widget.isPlaying;
  bool get _radarDisabled =>
      (widget.radarTickets ?? 0) <= 0 || !widget.isPlaying;
  bool get _anyItemReady =>
      widget.isPlaying &&
      (widget.tickets > 0 ||
          (widget.megaphoneTickets ?? 0) > 0 ||
          (widget.radarTickets ?? 0) > 0);

  bool get _showRadar => widget.solo
      ? (widget.radarTickets ?? 0) > 0
      : widget.radarTickets != null;

  void _toggleProbing() {
    Haptics.tap();
    if (widget.probing) {
      widget.onProbingChanged(false);
      return;
    }
    if (widget.tickets <= 0 || !widget.isPlaying) return;
    widget.onProbingChanged(true);
    setState(() => _drawerOpen = false); // 서랍을 닫아 보드(숫자칸 선택)를 가리지 않는다
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    if (widget.usesEdgeDrawer) {
      final limit = MediaQuery.of(context).size.height / 2 - 110;
      final y = (_drawerOffsetY + _drag).clamp(-limit, limit);
      return Positioned(
        right: 0,
        bottom: widget.drawerBottomPadding - y,
        child: _edgeDrawer(t, limit),
      );
    }
    return Positioned(
      right: 14,
      bottom: widget.floatingBottomPadding,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showRadar) ...[
              _radarButton(t, dense: false),
              const SizedBox(height: 8),
            ],
            _flagButton(t, dense: false),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    AppTheme t, {
    required bool dense,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required bool disabled,
    bool active = false,
    required VoidCallback? onTap,
  }) {
    final fg = active ? Colors.white : (disabled ? t.textTertiary : t.text);
    return PlainButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 16, vertical: dense ? 8 : 11),
        decoration: BoxDecoration(
          color: active ? accent : t.fill,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active
                ? Colors.white.withValues(alpha: 0.85)
                : accent.withValues(alpha: disabled ? 0 : 0.55),
            width: active ? 2 : 1.5,
          ),
          boxShadow: active
              ? [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 8)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                Text(subtitle,
                    style: TextStyle(
                        color: fg.withValues(alpha: 0.85),
                        fontSize: dense ? 9 : 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _flagButton(AppTheme t, {required bool dense}) {
    final probing = widget.probing;
    return _chip(
      t,
      dense: dense,
      icon: Icons.flag,
      title: '자동깃발',
      subtitle: probing
          ? '숫자칸 선택'
          : (widget.tickets > 0 ? '남은 ${widget.tickets}개' : '상점에서 충전'),
      accent: _itemAccent,
      disabled: _disabled,
      active: probing,
      onTap: (_disabled && !probing) ? null : _toggleProbing,
    );
  }

  Widget _megaphoneButton(AppTheme t, {required bool dense}) {
    final count = widget.megaphoneTickets ?? 0;
    return _chip(
      t,
      dense: dense,
      icon: Icons.campaign,
      title: '확성기',
      subtitle: count > 0 ? '남은 $count개' : '상점에서 충전',
      accent: _megaphoneAccent,
      disabled: _megaphoneDisabled,
      onTap: _megaphoneDisabled
          ? null
          : () {
              Haptics.tap();
              widget.onMegaphone?.call();
              setState(() => _drawerOpen = false);
            },
    );
  }

  Widget _radarButton(AppTheme t, {required bool dense}) {
    final count = widget.radarTickets ?? 0;
    return _chip(
      t,
      dense: dense,
      icon: Icons.wifi_tethering,
      title: '레이더',
      subtitle: count > 0 ? '남은 $count개' : '상점에서 충전',
      accent: _radarAccent,
      disabled: _radarDisabled,
      onTap: _radarDisabled
          ? null
          : () {
              Haptics.tap();
              widget.onRadar?.call();
              setState(() => _drawerOpen = false);
            },
    );
  }

  Widget _edgeDrawer(AppTheme t, double limit) {
    final probing = widget.probing;
    final handleIcon = probing
        ? Icons.close
        : (_drawerOpen ? Icons.chevron_right : Icons.chevron_left);
    final handleColor = probing
        ? _itemAccent
        : (widget.solo || _anyItemReady
            ? _itemAccent.withValues(alpha: 0.9)
            : Colors.grey.withValues(alpha: 0.55));
    return GestureDetector(
      onVerticalDragUpdate: (d) => setState(() => _drag += d.delta.dy),
      onVerticalDragEnd: (_) => setState(() {
        _drawerOffsetY = (_drawerOffsetY + _drag).clamp(-limit, limit);
        _drag = 0;
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.4, 0), end: Offset.zero)
                    .animate(anim),
                child: child,
              ),
            ),
            child: !_drawerOpen
                ? const SizedBox.shrink()
                : Container(
                    key: const ValueKey('drawer'),
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
                          _flagButton(t, dense: true),
                          if (widget.megaphoneTickets != null) ...[
                            const SizedBox(height: 6),
                            _megaphoneButton(t, dense: true),
                          ],
                          if (_showRadar) ...[
                            const SizedBox(height: 6),
                            _radarButton(t, dense: true),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          // 가장자리 손잡이 — 발동 중이면 취소, 아니면 서랍 열고닫기
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.tap();
              if (probing) {
                widget.onProbingChanged(false);
              } else {
                setState(() => _drawerOpen = !_drawerOpen);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 84,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12)),
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
                  Icon(handleIcon, size: 14, color: Colors.white),
                  if (widget.solo && !probing && widget.tickets > 0) ...[
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
    );
  }
}
