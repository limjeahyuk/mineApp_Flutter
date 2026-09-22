import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/theme.dart';
import '../core/types.dart';
import 'cell_view.dart';

/// 보드 렌더링(솔로·대전 공용). 가용 영역에 맞춰 정사각형 셀 크기를 정하고,
/// 큰 보드는 InteractiveViewer로 핀치줌·패닝. Swift BoardView 이식.
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
  final bool probing; // 자동깃발 발동 대기
  final void Function(int r, int c)? onProbe;

  static const _maxCell = 44.0;
  static const _spacing = 1.5;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final gameEnded =
        game.state == GameState.won || game.state == GameState.lost;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = game.cols, rows = game.rows;
        final usableW = constraints.maxWidth - 10 - _spacing * (cols - 1);
        final usableH = constraints.maxHeight - 10 - _spacing * (rows - 1);
        final side = [usableW / cols, usableH / rows, _maxCell]
            .reduce((a, b) => a < b ? a : b);
        final cell = side < 1 ? 1.0 : side;
        return Center(
          child: InteractiveViewer(
            transformationController: controller,
            minScale: 1,
            maxScale: 4,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: t.boardFrame,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < rows; r++)
                    Padding(
                      padding: EdgeInsets.only(top: r == 0 ? 0 : _spacing),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var c = 0; c < cols; c++)
                            Padding(
                              padding:
                                  EdgeInsets.only(left: c == 0 ? 0 : _spacing),
                              child: CellView(
                                cell: game.grid[r][c],
                                gameEnded: gameEnded,
                                flagMode: flagMode,
                                size: cell,
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
        );
      },
    );
  }
}
