import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/theme.dart';
import '../core/types.dart';
import 'cell_view.dart';

/// 보드 렌더링(솔로·대전 공용) — Swift BoardView 이식.
/// 1배에선 가용 영역에 꽉 맞는 정사각형 셀(최대 64), 핀치로 최대 4배, 확대 버튼은 2.5배.
/// `zoomed`는 확대 버튼 ↔ 핀치 상태를 양방향 동기화한다.
class BoardWidget extends StatefulWidget {
  const BoardWidget({
    super.key,
    required this.game,
    required this.flagMode,
    this.zoomed = false,
    this.onZoomChanged,
    this.probing = false,
    this.onProbe,
  });

  final GameModel game;
  final bool flagMode;
  final bool zoomed;
  final ValueChanged<bool>? onZoomChanged;
  final bool probing;
  final void Function(int r, int c)? onProbe;

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget>
    with SingleTickerProviderStateMixin {
  static const _maxCell = 64.0;
  static const _spacing = 1.5;
  static const _pad = 5.0;
  static const _buttonZoom = 2.5;

  final _ctrl = TransformationController();
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300))
    ..addListener(() => _ctrl.value = _tween?.evaluate(_anim) ?? _ctrl.value);
  Matrix4Tween? _tween;
  bool _applied = false;
  Size _viewport = Size.zero;

  @override
  void didUpdateWidget(covariant BoardWidget old) {
    super.didUpdateWidget(old);
    if (widget.zoomed != _applied) {
      _applied = widget.zoomed;
      _animateTo(widget.zoomed ? _buttonZoom : 1.0);
    }
  }

  void _animateTo(double scale) {
    final c = Offset(_viewport.width / 2, _viewport.height / 2);
    final target = scale == 1.0
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..translateByDouble(c.dx * (1 - scale), c.dy * (1 - scale), 0, 1)
          ..scaleByDouble(scale, scale, 1, 1));
    _tween = Matrix4Tween(begin: _ctrl.value.clone(), end: target);
    _anim.forward(from: 0);
  }

  void _onInteractionEnd(ScaleEndDetails _) {
    final z = _ctrl.value.getMaxScaleOnAxis() > 1.02;
    _applied = z;
    if (z != widget.zoomed) widget.onZoomChanged?.call(z);
  }

  @override
  void dispose() {
    _anim.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final game = widget.game;
    final ended = game.state == GameState.won || game.state == GameState.lost;
    return LayoutBuilder(builder: (context, box) {
      _viewport = box.biggest;
      final cols = game.cols, rows = game.rows;
      final w = box.maxWidth - _pad * 2 - _spacing * (cols - 1);
      final h = box.maxHeight - _pad * 2 - _spacing * (rows - 1);
      final side = max(1.0, [w / cols, h / rows, _maxCell].reduce(min));
      return InteractiveViewer(
        transformationController: _ctrl,
        minScale: 1,
        maxScale: 4,
        onInteractionEnd: _onInteractionEnd,
        child: SizedBox(
          width: box.maxWidth,
          height: box.maxHeight,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(_pad),
              decoration: BoxDecoration(
                  color: t.boardFrame, borderRadius: BorderRadius.circular(8)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var r = 0; r < rows; r++)
                  Padding(
                    padding: EdgeInsets.only(top: r == 0 ? 0 : _spacing),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var c = 0; c < cols; c++)
                        Padding(
                          padding: EdgeInsets.only(left: c == 0 ? 0 : _spacing),
                          child: CellView(
                            cell: game.grid[r][c],
                            gameEnded: ended,
                            flagMode: widget.flagMode,
                            size: side,
                            probing: widget.probing,
                            onProbe: () => widget.onProbe?.call(r, c),
                            onReveal: () => game.reveal(r, c),
                            onFlag: () => game.toggleFlag(r, c),
                          ),
                        ),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      );
    });
  }
}
