import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';

/// 한 칸 렌더링 — Swift CellView 이식. 원본 팔레트(무채색 적응) 사용.
/// 일반 모드 → 탭: 칸 열기 / 길게(0.3초): 깃발
/// 깃발 모드 → 탭: 깃발(열린 숫자는 chord) / 길게: 칸 열기
/// 자동깃발 발동 대기(probing) → 어떤 탭이든 onProbe.
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

  static const _gold = Color.fromRGBO(242, 189, 46, 1); // (0.95,0.74,0.18)

  void _flagAction() {
    Haptics.flagTap();
    onFlag();
  }

  void _tap() {
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

  void _longPress() {
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
          () => TapGestureRecognizer(),
          (r) => r.onTap = _tap,
        ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
              duration: const Duration(milliseconds: 300)),
          (r) => r.onLongPress = _longPress,
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

  Widget? _emoji(String e, double scale) => Text(e,
      textScaler: TextScaler.noScaling,
      style: TextStyle(fontSize: size * scale, height: 1.0));

  Widget? _content(bool dark) {
    final unit = size;
    if (cell.isFlagged && !cell.isRevealed) {
      if (gameEnded && !cell.isMine) return _emoji('❌', 0.5);
      if (cell.flagOwner != null) {
        return Icon(SF.flagFill,
            size: unit * 0.5, color: _flagColor(cell.flagOwner!));
      }
      if (cell.isGolden) {
        return Icon(SF.flagFill, size: unit * 0.5, color: _gold, shadows: [
          Shadow(color: _gold.withValues(alpha: 0.7), blurRadius: unit * 0.12)
        ]);
      }
      return _emoji('🚩', 0.5);
    }
    if (cell.isRevealed) {
      if (cell.isMine) return _emoji(cell.isGolden ? '💰' : '💣', 0.52);
      if (cell.adjacent > 0) {
        return Text(
          '${cell.adjacent}',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: unit * 0.58,
            height: 1.0,
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
