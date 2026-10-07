import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
import '../core/types.dart';

/// 한 칸 렌더링 — Swift CellView 이식. 원본 팔레트(무채색 적응) 사용.
/// 일반 모드 → 탭: 칸 열기 / 길게(0.3초): 깃발
/// 깃발 모드 → 탭: 깃발(열린 숫자는 주변 일괄 열기) / 길게: 칸 열기
/// 자동깃발 발동 대기(probing) → 어떤 탭이든 이 칸을 발동(onProbe)으로 보낸다.
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
  final bool probing;
  final VoidCallback? onProbe;

  /// 황금지뢰 깃발 색(금색) — (0.95, 0.74, 0.18)
  static const _goldFlag = Color.fromRGBO(242, 189, 46, 1);

  void _flagAction() {
    Haptics.flagTap();
    onFlag();
  }

  void _onTap() {
    if (probing) {
      onProbe?.call();
      return;
    }
    if (flagMode) {
      if (cell.isRevealed) {
        onReveal();
      } else {
        _flagAction();
      }
    } else {
      onReveal();
    }
  }

  void _onLongPress() {
    if (probing) {
      onProbe?.call();
      return;
    }
    if (flagMode) {
      onReveal();
    } else {
      _flagAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          TapGestureRecognizer.new,
          (r) => r.onTap = _onTap,
        ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
              duration: const Duration(milliseconds: 300)),
          (r) => r.onLongPress = _onLongPress,
        ),
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
      // 게임이 끝났는데 지뢰가 아닌 곳에 깃발이면 오답 표시
      if (gameEnded && !cell.isMine) {
        return Text('❌', style: TextStyle(fontSize: unit * 0.5, height: 1));
      }
      if (cell.flagOwner != null) {
        return Icon(Icons.flag,
            size: unit * 0.62, color: _flagColor(cell.flagOwner!));
      }
      if (cell.isGolden) {
        return Icon(Icons.flag, size: unit * 0.62, color: _goldFlag, shadows: [
          Shadow(
              color: _goldFlag.withValues(alpha: 0.7), blurRadius: unit * 0.12)
        ]);
      }
      return Text('🚩', style: TextStyle(fontSize: unit * 0.5, height: 1));
    }
    if (cell.isRevealed) {
      if (cell.isMine) {
        return Text(cell.isGolden ? '💰' : '💣',
            style: TextStyle(fontSize: unit * 0.52, height: 1));
      }
      if (cell.adjacent > 0) {
        return Text(
          '${cell.adjacent}',
          style: TextStyle(
            fontSize: unit * 0.58,
            height: 1,
            fontWeight: FontWeight.w900,
            color: minesweeperNumberColor(cell.adjacent, dark),
          ),
        );
      }
    }
    return null;
  }

  /// 깃발 소유자 색 (나=파랑, 상대=주황)
  Color _flagColor(FlagOwner owner) =>
      owner == FlagOwner.me ? AppTheme.meColor : AppTheme.oppColor;
}
