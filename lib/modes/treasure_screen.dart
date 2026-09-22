import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../multiplayer/firebase_match_service.dart';
import '../multiplayer/multiplayer.dart';
import 'treasure_controller.dart';
import 'treasure_model.dart';

/// 보물찾기 화면 — 중앙의 보물을 상대보다 먼저 열면 승리.
class TreasureScreen extends StatefulWidget {
  const TreasureScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<TreasureScreen> createState() => _TreasureScreenState();
}

class _TreasureScreenState extends State<TreasureScreen> {
  late final TreasureController ctrl =
      TreasureController(FirebaseMatchService(kind: 'treasure'));
  bool flagMode = false;

  static const _gem = Color(0xFF4FB0E0);

  @override
  void initState() {
    super.initState();
    ctrl.start(widget.mode);
  }

  @override
  void dispose() {
    ctrl.leave();
    ctrl.dispose();
    super.dispose();
  }

  void _exit() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: ctrl,
          builder: (_, _) {
            if (ctrl.failure != null) return _failure(t, ctrl.failure!);
            switch (ctrl.flow) {
              case TreasureFlow.searching:
                return _searching(t);
              case TreasureFlow.starting:
                return _countdown(t);
              case TreasureFlow.racing:
              case TreasureFlow.finished:
                return _race(t);
            }
          },
        ),
      ),
    );
  }

  Widget _searching(AppTheme t) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('상대를 찾는 중…',
                style: TextStyle(
                    color: t.text, fontSize: 18, fontWeight: FontWeight.w600)),
            if (ctrl.roomCode != null) ...[
              const SizedBox(height: 20),
              Text('방 코드', style: TextStyle(color: t.textSecondary)),
              const SizedBox(height: 6),
              Text(ctrl.roomCode!,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6)),
            ],
            const SizedBox(height: 40),
            TextButton(onPressed: _exit, child: const Text('취소')),
          ],
        ),
      );

  Widget _countdown(AppTheme t) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('상대를 만났어요!',
                style: TextStyle(
                    color: t.text, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (ctrl.match != null)
              Text('vs ${ctrl.match!.opponentName}',
                  style: TextStyle(color: t.textSecondary, fontSize: 15)),
            const SizedBox(height: 20),
            Text('${ctrl.startCountdown}',
                style: const TextStyle(
                    color: _gem, fontSize: 64, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('💎 중앙의 보물을 먼저 여세요',
                style: TextStyle(color: t.textSecondary, fontSize: 14)),
          ],
        ),
      );

  Widget _race(AppTheme t) {
    final m = ctrl.model;
    return Column(
      children: [
        _topBar(t),
        const SizedBox(height: 4),
        _bar(t, '나', ctrl.myProgress, AppTheme.meColor),
        const SizedBox(height: 6),
        _bar(t, ctrl.match?.opponentName ?? '상대', ctrl.opponentProgress,
            AppTheme.oppColor),
        const SizedBox(height: 8),
        Expanded(child: _board(t, m)),
        if (ctrl.flow == TreasureFlow.finished) _resultBanner(t),
      ],
    );
  }

  Widget _topBar(AppTheme t) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _iconBtn(t, Icons.close, _exit),
            const Spacer(),
            Text('💎 보물찾기',
                style: TextStyle(
                    color: t.text, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            _iconBtn(t, flagMode ? Icons.flag : Icons.flag_outlined,
                () => setState(() => flagMode = !flagMode),
                highlighted: flagMode),
          ],
        ),
      );

  Widget _iconBtn(AppTheme t, IconData icon, VoidCallback onTap,
          {bool highlighted = false}) =>
      Material(
        color: highlighted ? AppTheme.soloAccent : t.fill,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
              width: 44,
              height: 40,
              child: Icon(icon,
                  color: highlighted ? Colors.white : t.text, size: 22)),
        ),
      );

  Widget _bar(AppTheme t, String name, double progress, Color color) {
    final p = progress.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 72,
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 10,
                backgroundColor: t.fill,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 40,
              child: Text('${(p * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _board(AppTheme t, TreasureModel m) {
    return LayoutBuilder(builder: (context, box) {
      // 셀마다 좌우 0.5px 마진(=1px)을 빼야 오버플로가 안 난다.
      final side = ((box.maxWidth - 8) / m.size - 1.0).clamp(8.0, 44.0);
      return Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Container(
            padding: const EdgeInsets.all(4),
            color: t.boardFrame,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < m.size; r++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var c = 0; c < m.size; c++) _cell(t, m, r, c, side),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _cell(AppTheme t, TreasureModel m, int r, int c, double side) {
    final cell = m.grid[r][c];
    Widget? content;
    Color bg;
    if (cell.exploded) {
      bg = t.cellExploded;
      content = Text('💥', style: TextStyle(fontSize: side * 0.6));
    } else if (cell.isRevealed) {
      bg = t.cellRevealed;
      if (cell.isTreasure) {
        content = Text('💎', style: TextStyle(fontSize: side * 0.6));
      } else if (cell.adjacent > 0) {
        content = Text('${cell.adjacent}',
            style: TextStyle(
                fontSize: side * 0.6,
                fontWeight: FontWeight.w800,
                color: minesweeperNumberColor(cell.adjacent, t.dark)));
      }
    } else {
      bg = t.cellClosedTop;
      if (cell.isFlagged) {
        content = Icon(Icons.flag, size: side * 0.6, color: AppTheme.meColor);
      } else if (cell.isTreasure) {
        // 미공개 보물칸: 중앙 위치 힌트(살짝 반짝).
        bg = t.cellClosedTop;
      }
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (flagMode) {
          m.toggleFlag(r, c);
        } else {
          m.primaryTap(r, c);
        }
      },
      onLongPress: () => m.toggleFlag(r, c),
      child: Container(
        width: side,
        height: side,
        margin: const EdgeInsets.all(0.5),
        alignment: Alignment.center,
        color: bg,
        child: content,
      ),
    );
  }

  Widget _resultBanner(AppTheme t) {
    final r = ctrl.result!;
    final (label, color) = switch (r) {
      RaceResult.win => (ctrl.opponentLeft ? '부전승! 🎉' : '보물 획득! 🎉',
          const Color(0xFF1A801F)),
      RaceResult.lose => ('아깝네요 💥', const Color(0xFFCC0D0D)),
      RaceResult.draw => ('무승부 🤝', t.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: _exit, child: const Text('나가기'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(ctrl.rematch),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppTheme.multiAccent),
                  child: const Text('다시하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _failure(AppTheme t, MatchError e) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: t.textSecondary),
            const SizedBox(height: 16),
            Text(e.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text, fontSize: 16)),
            const SizedBox(height: 28),
            FilledButton(onPressed: _exit, child: const Text('나가기')),
          ],
        ),
      );
}
