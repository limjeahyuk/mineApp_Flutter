import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/theme.dart';
import '../core/types.dart';
import 'cell_view.dart';

/// 보드 렌더링(솔로·대전 공용) — Swift BoardView 이식.
/// 가용 영역 안에 보드 전체가 들어오는 정사각형 셀 크기를 정하고, 사진 앱처럼
/// 두 손가락 핀치 줌 + 드래그 패닝(1배에선 화면에 꽉 맞고 패닝 없음).
class BoardWidget extends StatefulWidget {
  const BoardWidget({
    super.key,
    required this.game,
    required this.flagMode,
    this.probing = false,
    this.onProbe,
  });

  final GameModel game;
  final bool flagMode;
  final bool probing;
  final void Function(int r, int c)? onProbe;

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  static const _maxCell = 64.0;
  static const _spacing = 1.5;
  static const _padding = 5.0;
  static const _maxZoom = 4.0;

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
      final viewport = constraints.biggest;
      final cell = _fitSide(viewport);
      return ClipRect(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: _maxZoom,
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
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
