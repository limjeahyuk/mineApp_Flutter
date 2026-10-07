import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/theme.dart';
import '../core/types.dart';
import 'cell_view.dart';

/// 보드 렌더링(솔로·대전 공용) — Swift BoardView 이식.
/// 가용 영역 안에 보드 전체가 들어오는 정사각형 셀 크기를 정하고, 사진 앱처럼
/// 두 손가락 핀치 줌 + 드래그 패닝(1배에선 화면에 꽉 맞고 패닝 없음).
/// `zoomedIn`은 확대 버튼과 핀치 상태를 양방향으로 동기화한다(버튼 확대 2.5배).
class BoardWidget extends StatefulWidget {
  const BoardWidget({
    super.key,
    required this.game,
    required this.flagMode,
    this.zoomedIn = false,
    this.onZoomChanged,
    this.probing = false,
    this.onProbe,
  });

  final GameModel game;
  final bool flagMode;
  final bool zoomedIn;
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
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final game = widget.game;
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
            ),
          ),
        ),
      );
    });
  }
}
