import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/theme.dart';
import '../core/types.dart';
import 'cell_view.dart';

/// 보드 렌더링(솔로·대전 공용) — Swift BoardView 이식.
<<<<<<< HEAD
/// 1배에선 가용 영역에 꽉 맞는 정사각형 셀(최대 64), 핀치로 최대 4배, 확대 버튼은 2.5배.
/// `zoomed`는 확대 버튼 ↔ 핀치 상태를 양방향 동기화한다.
=======
/// 가용 영역 안에 보드 전체가 들어오는 정사각형 셀 크기를 정하고, 사진 앱처럼
/// 두 손가락 핀치 줌 + 드래그 패닝(1배에선 화면에 꽉 맞고 패닝 없음).
/// `zoomedIn`은 확대 버튼과 핀치 상태를 양방향으로 동기화한다(버튼 확대 2.5배).
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
class BoardWidget extends StatefulWidget {
  const BoardWidget({
    super.key,
    required this.game,
    required this.flagMode,
<<<<<<< HEAD
    this.zoomed = false,
=======
    this.zoomedIn = false,
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    this.onZoomChanged,
    this.probing = false,
    this.onProbe,
  });

  final GameModel game;
  final bool flagMode;
<<<<<<< HEAD
  final bool zoomed;
=======
  final bool zoomedIn;
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
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
<<<<<<< HEAD
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
=======
  static const _padding = 5.0;
  static const _buttonZoom = 2.5;
  static const _maxZoom = 4.0;

  final _controller = TransformationController();
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  Animation<Matrix4>? _tween;
  late bool _applied = widget.zoomedIn;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final t = _tween;
      if (t != null) _controller.value = t.value;
    });
    _controller.addListener(_onTransform);
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  }

  @override
  void dispose() {
<<<<<<< HEAD
    _anim.dispose();
    _ctrl.dispose();
    super.dispose();
  }
=======
    _controller.removeListener(_onTransform);
    _controller.dispose();
    _anim.dispose();
    super.dispose();
  }

  // 핀치로 줌이 바뀌면 버튼 상태(zoomedIn)도 따라가게 한다.
  void _onTransform() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed != _applied) {
      _applied = zoomed;
      if (widget.zoomedIn != zoomed) widget.onZoomChanged?.call(zoomed);
    }
  }

  @override
  void didUpdateWidget(covariant BoardWidget old) {
    super.didUpdateWidget(old);
    // 버튼으로 zoomedIn이 바뀐 경우에만 배율을 프로그램으로 적용(핀치 루프 방지).
    if (widget.zoomedIn != _applied) {
      _applied = widget.zoomedIn;
      final s = widget.zoomedIn ? _buttonZoom : 1.0;
      final target = Matrix4.identity()
        ..translateByDouble(_viewport.width * (1 - s) / 2,
            _viewport.height * (1 - s) / 2, 0, 1)
        ..scaleByDouble(s, s, 1, 1);
      _tween = Matrix4Tween(begin: _controller.value, end: target).animate(
          CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
      _anim.forward(from: 0);
    }
  }

  double _fitSide(Size size) {
    final cols = widget.game.cols, rows = widget.game.rows;
    final usableW = size.width - _padding * 2 - _spacing * (cols - 1);
    final usableH = size.height - _padding * 2 - _spacing * (rows - 1);
    final side = [usableW / cols, usableH / rows, _maxCell]
        .reduce((a, b) => a < b ? a : b);
    return side < 1 ? 1 : side;
  }
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final game = widget.game;
<<<<<<< HEAD
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
=======
    final gameEnded =
        game.state == GameState.won || game.state == GameState.lost;
    return LayoutBuilder(builder: (context, constraints) {
      _viewport = constraints.biggest;
      final cell = _fitSide(_viewport);
      return ClipRect(
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 1,
          maxScale: _maxZoom,
          child: SizedBox(
            width: _viewport.width,
            height: _viewport.height,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(_padding),
                decoration: BoxDecoration(
                  color: t.boardFrame,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var r = 0; r < game.rows; r++)
                      Padding(
                        padding: EdgeInsets.only(top: r == 0 ? 0 : _spacing),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var c = 0; c < game.cols; c++)
                              Padding(
                                padding: EdgeInsets.only(
                                    left: c == 0 ? 0 : _spacing),
                                child: CellView(
                                  cell: game.grid[r][c],
                                  gameEnded: gameEnded,
                                  flagMode: widget.flagMode,
                                  size: cell,
                                  probing: widget.probing,
                                  onProbe: () => widget.onProbe?.call(r, c),
                                  onReveal: () => game.reveal(r, c),
                                  onFlag: () => game.toggleFlag(r, c),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
            ),
          ),
        ),
      );
    });
  }
}
