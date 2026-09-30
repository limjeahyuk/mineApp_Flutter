import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/theme.dart';
import '../core/types.dart';
import 'cell_view.dart';

/// 보드 렌더링(솔로·대전 공용) — Swift BoardView 이식.
/// 가용 영역(가로·세로) 안에 보드 전체가 들어오는 정사각형 셀(최대 64pt)로 그리고,
/// 사진 앱처럼 두 손가락 핀치 줌(1~4배) + 드래그 패닝. 확대 버튼은 2.5배.
class BoardWidget extends StatelessWidget {
  const BoardWidget(
      {super.key,
      required this.game,
      required this.flagMode,
      this.controller,
      this.probing = false,
      this.onProbe});

  final GameModel game;
  final bool flagMode;
  final TransformationController? controller;
  final bool probing;
  final void Function(int r, int c)? onProbe;

  static const maxCell = 64.0;
  static const spacing = 1.5;
  static const boardPadding = 5.0;
  static const buttonZoomScale = 2.5;

  /// 확대 토글: 1배 ↔ 2.5배(보드 중앙 기준).
  static void toggleZoom(TransformationController c, Size viewport) {
    final zoomed = c.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed) {
      c.value = Matrix4.identity();
    } else {
      const s = buttonZoomScale;
      final dx = -(viewport.width * (s - 1)) / 2;
      final dy = -(viewport.height * (s - 1)) / 2;
      c.value = Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final gameEnded =
        game.state == GameState.won || game.state == GameState.lost;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = game.cols, rows = game.rows;
        final usableW =
            constraints.maxWidth - boardPadding * 2 - spacing * (cols - 1);
        final usableH =
            constraints.maxHeight - boardPadding * 2 - spacing * (rows - 1);
        var side = [usableW / cols, usableH / rows, maxCell]
            .reduce((a, b) => a < b ? a : b);
        if (side < 1) side = 1;
        return InteractiveViewer(
          transformationController: controller,
          minScale: 1,
          maxScale: 4,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(boardPadding),
                decoration: BoxDecoration(
                  color: t.boardFrame,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var r = 0; r < rows; r++)
                      Padding(
                        padding: EdgeInsets.only(top: r == 0 ? 0 : spacing),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var c = 0; c < cols; c++)
                              Padding(
                                padding:
                                    EdgeInsets.only(left: c == 0 ? 0 : spacing),
                                child: CellView(
                                  cell: game.grid[r][c],
                                  gameEnded: gameEnded,
                                  flagMode: flagMode,
                                  size: side,
                                  probing: probing,
                                  onProbe: () => onProbe?.call(r, c),
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
        );
      },
    );
  }
}
