import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/theme.dart';
import '../core/types.dart';

/// 한 칸 렌더링 — Swift CellView 이식. 원본 팔레트(무채색 적응) 사용.
class CellView extends StatelessWidget {
  const CellView({
    super.key,
    required this.cell,
    required this.gameEnded,
    required this.flagMode,
    required this.size,
    required this.onReveal,
    required this.onFlag,
    this.probing = false,
    this.onProbe,
  });

  final Cell cell;
  final bool gameEnded;
  final bool flagMode;
  final double size;
  final VoidCallback onReveal;
  final VoidCallback onFlag;
  final bool probing; // 자동깃발 발동 대기 — 숫자 칸 탭이 자동깃발로 감
  final VoidCallback? onProbe;

  static const _gold = Color(0xFFF2BC2E);

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 자동깃발 발동 중: 숫자 칸(열린 비지뢰)을 탭하면 자동깃발.
        if (probing &&
            cell.isRevealed &&
            !cell.isMine &&
            cell.adjacent > 0 &&
            onProbe != null) {
          onProbe!();
        } else if (flagMode && !cell.isRevealed) {
          onFlag();
        } else {
          onReveal();
        }
      },
      onLongPress: () {
        if (flagMode) {
          onReveal();
        } else {
          onFlag();
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: _decoration(t),
        alignment: Alignment.center,
        child: _content(t.dark),
      ),
    );
  }

  BoxDecoration _decoration(AppTheme t) {
    if (cell.isRevealed) {
      return BoxDecoration(
        color: cell.exploded ? t.cellExploded : t.cellRevealed,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: t.cellRevealedStroke, width: 0.5),
      );
    }
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [t.cellClosedTop, t.cellClosedBottom],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: t.cellClosedStroke, width: 0.5),
    );
  }

  Widget? _content(bool dark) {
    final unit = size;
    if (cell.isFlagged && !cell.isRevealed) {
      if (gameEnded && !cell.isMine) {
        return Text('❌', style: TextStyle(fontSize: unit * 0.5));
      }
      if (cell.flagOwner != null) {
        return Icon(Icons.flag,
            size: unit * 0.6, color: _flagColor(cell.flagOwner!));
      }
      if (cell.isGolden) {
        return Icon(Icons.flag, size: unit * 0.6, color: _gold);
      }
      return Text('🚩', style: TextStyle(fontSize: unit * 0.5));
    }
    if (cell.isRevealed) {
      if (cell.isMine) {
        return Text(cell.isGolden ? '💰' : '💣',
            style: TextStyle(fontSize: unit * 0.52));
      }
      if (cell.adjacent > 0) {
        return Text(
          '${cell.adjacent}',
          style: TextStyle(
            fontSize: unit * 0.58,
            fontWeight: FontWeight.w800,
            color: minesweeperNumberColor(cell.adjacent, dark),
          ),
        );
      }
    }
    return null;
  }

  Color _flagColor(FlagOwner owner) =>
      owner == FlagOwner.me ? AppTheme.meColor : AppTheme.oppColor;
}
