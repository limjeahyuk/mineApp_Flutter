import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// 아이템 도크 — Swift `AutoFlagDock` 이식(솔로·대전·협동 공용).
/// - 초급·중급(`usesEdgeDrawer == false`): 화면 우측 하단에 떠 있는 캡슐 버튼.
/// - 고급·최고급·보물찾기(`usesEdgeDrawer == true`): 오른쪽 가장자리 손잡이(서랍 `<`).
///   손잡이를 눌러 열고, 위아래로 드래그해 위치를 옮긴다.
/// 자동깃발은 누르면 발동 대기(probing) → 호출부가 보드 탭을 onProbe로 보낸다.
class ItemDock extends StatefulWidget {
  const ItemDock({
    super.key,
    required this.autoFlagTickets,
    required this.isPlaying,
    required this.probing,
    required this.onProbingChanged,
    required this.usesEdgeDrawer,
    this.radarTickets,
    this.onRadar,
    this.megaphoneTickets,
    this.onMegaphone,
    this.hideRadarWhenEmpty = false,
    this.soloHandle = false,
  });

  final int autoFlagTickets;
  final bool isPlaying;
  final bool probing;
  final ValueChanged<bool> onProbingChanged;
  final bool usesEdgeDrawer;

  /// null이면 레이더 항목 없음.
  final int? radarTickets;
  final VoidCallback? onRadar;

  /// null이면 확성기 항목 없음('너에게 닿기를' 전용).
  final int? megaphoneTickets;
  final VoidCallback? onMegaphone;

  /// 솔로(ContentView)는 레이더가 0개면 버튼 자체를 숨긴다.
  final bool hideRadarWhenEmpty;

  /// 솔로(ContentView) 손잡이: 항상 보라 + 남은 자동깃발 수 표시. 다른 모드(AutoFlagDock)는 보유 여부로 회색/보라.
  final bool soloHandle;

  static const itemAccent = Color.fromRGBO(148, 107, 245, 1); // (0.58,0.42,0.96)
  static const megaphoneAccent = Color.fromRGBO(242, 199, 77, 1); // (0.95,0.78,0.30)
  static const radarAccent = Color.fromRGBO(51, 173, 219, 1); // (0.20,0.68,0.86)

  @override
  State<ItemDock> createState() => _ItemDockState();
}

class _ItemDockState extends State<ItemDock> {
  bool _drawerOpen = false;
  double _offsetY = 0;

  bool get _disabled => widget.autoFlagTickets <= 0 || !widget.isPlaying;
  bool get _radarDisabled => (widget.radarTickets ?? 0) <= 0 || !widget.isPlaying;
  bool get _megaDisabled =>
      (widget.megaphoneTickets ?? 0) <= 0 || !widget.isPlaying;
  bool get _anyReady =>
      widget.isPlaying &&
      (widget.autoFlagTickets > 0 ||
          (widget.megaphoneTickets ?? 0) > 0 ||
          (widget.radarTickets ?? 0) > 0);
  bool get _showRadar =>
      widget.radarTickets != null &&
      !(widget.hideRadarWhenEmpty && (widget.radarTickets ?? 0) <= 0);

  void _toggleProbing() {
    Haptics.tap();
    if (widget.probing) {
      widget.onProbingChanged(false);
      return;
    }
    if (widget.autoFlagTickets <= 0 || !widget.isPlaying) return;
    widget.onProbingChanged(true);
    setState(() => _drawerOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return widget.usesEdgeDrawer ? _edgeDrawer(t) : _floating(t);
  }

  // ── 초급·중급: 우하단 플로팅 ──
  Widget _floating(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.only(right: 14, bottom: 52),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showRadar) ...[_radarButton(t, dense: false), const SizedBox(height: 8)],
            _flagButton(t, dense: false),
          ],
        ),
      ),
    );
  }

  // ── 고급·최고급: 오른쪽 엣지 서랍 ──
  Widget _edgeDrawer(AppTheme t) {
    final handleIcon = widget.probing
        ? SF.xmark
        : (_drawerOpen ? SF.chevronRight : SF.chevronLeft);
    final limit = MediaQuery.of(context).size.height / 2 - 110;
    return Transform.translate(
      offset: Offset(0, _offsetY),
      child: GestureDetector(
        onVerticalDragUpdate: (d) => setState(
            () => _offsetY = (_offsetY + d.delta.dy).clamp(-limit, limit)),
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
              child: _drawerOpen
                  ? Container(
                      key: const ValueKey('open'),
                      margin: const EdgeInsets.only(right: 2),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: t.border, width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(-2, 2)),
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
                              _megaphoneButton(t),
                            ],
                            if (_showRadar) ...[
                              const SizedBox(height: 6),
                              _radarButton(t, dense: true),
                            ],
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('closed')),
            ),
            Tap(
              onTap: () {
                Haptics.tap();
                if (widget.probing) {
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
                  color: widget.probing
                      ? ItemDock.itemAccent
                      : ((_anyReady || widget.soloHandle)
                          ? ItemDock.itemAccent.withValues(alpha: 0.9)
                          : Colors.grey.withValues(alpha: 0.55)),
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(-2, 0)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(handleIcon, size: 13, color: Colors.white),
                    if (widget.soloHandle && !widget.probing && widget.autoFlagTickets > 0) ...[
                      const SizedBox(height: 3),
                      Text('${widget.autoFlagTickets}',
                          style: sf(10, weight: W.heavy, color: Colors.white)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 칩 공통 ──
  Widget _chip(
    AppTheme t, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool dense,
    required Color fg,
    required Color fill,
    required Color stroke,
    double strokeWidth = 1.5,
    List<BoxShadow>? shadow,
    VoidCallback? onTap,
  }) {
    return Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            horizontal: dense ? 12 : 16, vertical: dense ? 8 : 11),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: stroke, width: strokeWidth),
          boxShadow: shadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: dense ? 16 : 18, color: fg),
            SizedBox(width: dense ? 6 : 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: sf(dense ? 11 : 13, weight: W.bold, color: fg, height: 1.2)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: sf(dense ? 9 : 11,
                        weight: W.medium,
                        color: fg.withValues(alpha: fg.a * 0.85),
                        height: 1.2)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _flagButton(AppTheme t, {required bool dense}) {
    final p = widget.probing;
    final n = widget.autoFlagTickets;
    return _chip(
      t,
      icon: SF.flagFill,
      title: '자동깃발',
      subtitle: p ? '숫자칸 선택' : (n > 0 ? '남은 $n개' : '상점에서 충전'),
      dense: dense,
      fg: p ? Colors.white : (_disabled ? t.textTertiary : t.text),
      fill: p ? ItemDock.itemAccent : t.fill,
      stroke: p
          ? Colors.white.withValues(alpha: 0.85)
          : ItemDock.itemAccent.withValues(alpha: _disabled ? 0 : 0.55),
      strokeWidth: p ? 2 : 1.5,
      shadow: p
          ? [
              BoxShadow(
                  color: ItemDock.itemAccent.withValues(alpha: 0.6),
                  blurRadius: 16)
            ]
          : null,
      onTap: (_disabled && !p) ? null : _toggleProbing,
    );
  }

  Widget _radarButton(AppTheme t, {required bool dense}) {
    final n = widget.radarTickets ?? 0;
    return _chip(
      t,
      icon: SF.radar,
      title: '레이더',
      subtitle: n > 0 ? '남은 $n개' : '상점에서 충전',
      dense: dense,
      fg: _radarDisabled ? t.textTertiary : t.text,
      fill: t.fill,
      stroke: ItemDock.radarAccent.withValues(alpha: _radarDisabled ? 0 : 0.55),
      onTap: _radarDisabled
          ? null
          : () {
              Haptics.tap();
              widget.onRadar?.call();
              setState(() => _drawerOpen = false);
            },
    );
  }

  Widget _megaphoneButton(AppTheme t) {
    final n = widget.megaphoneTickets ?? 0;
    return _chip(
      t,
      icon: SF.megaphoneFill,
      title: '확성기',
      subtitle: n > 0 ? '남은 $n개' : '상점에서 충전',
      dense: true,
      fg: _megaDisabled ? t.textTertiary : t.text,
      fill: t.fill,
      stroke:
          ItemDock.megaphoneAccent.withValues(alpha: _megaDisabled ? 0 : 0.55),
      onTap: _megaDisabled
          ? null
          : () {
              Haptics.tap();
              widget.onMegaphone?.call();
              setState(() => _drawerOpen = false);
            },
    );
  }
}
