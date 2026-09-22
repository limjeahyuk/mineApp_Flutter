import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../multiplayer/firebase_match_service.dart';
import '../multiplayer/multiplayer.dart';
import 'coop_controller.dart';
import 'touch_model.dart';

/// 협동('너에게 닿기를') 화면 — 안개 공유 보드에서 파트너와 만나면 승리.
class CoopScreen extends StatefulWidget {
  const CoopScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<CoopScreen> createState() => _CoopScreenState();
}

class _CoopScreenState extends State<CoopScreen> {
  late final CoopController ctrl =
      CoopController(FirebaseMatchService(kind: 'touch'));
  bool flagMode = false;

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

  static const _coop = Color(0xFF39A085);

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
              case CoopFlow.searching:
                return _searching(t);
              case CoopFlow.starting:
                return _countdown(t);
              case CoopFlow.racing:
              case CoopFlow.finished:
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
            Text('파트너를 찾는 중…',
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
            Text('파트너를 만났어요!',
                style: TextStyle(
                    color: t.text, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (ctrl.match != null)
              Text(ctrl.match!.opponentName,
                  style: TextStyle(color: t.textSecondary, fontSize: 15)),
            const SizedBox(height: 20),
            Text('${ctrl.startCountdown}',
                style: const TextStyle(
                    color: _coop, fontSize: 64, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('잠시 후 함께 시작합니다',
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
        _progress(t),
        const SizedBox(height: 8),
        Expanded(child: _board(t, m)),
        if (ctrl.flow == CoopFlow.finished) _resultBanner(t),
      ],
    );
  }

  Widget _topBar(AppTheme t) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _iconBtn(t, Icons.close, _exit),
            const Spacer(),
            Text('🤝 함께 만나기',
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
        color: highlighted ? _coop : t.fill,
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

  Widget _progress(AppTheme t) {
    final p = ctrl.progress.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 40,
              child: Text('함께',
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
                valueColor: const AlwaysStoppedAnimation(_coop),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(p * 100).round()}%',
              style: const TextStyle(
                  color: _coop, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _board(AppTheme t, TouchModel m) {
    return LayoutBuilder(builder: (context, box) {
      // 셀마다 좌우 0.5px 마진(=1px)을 빼야 오버플로가 안 난다.
      final side = ((box.maxWidth - 8) / m.size - 1.0).clamp(6.0, 40.0);
      return Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 6,
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
                      for (var c = 0; c < m.size; c++)
                        _cell(t, m, r, c, side),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _cell(AppTheme t, TouchModel m, int r, int c, double side) {
    final cell = m.grid[r][c];
    final visible = m.isVisible(r, c);
    final isMyStart = m.myStart == (r, c);
    final isOppStart = m.oppStart == (r, c);
    Widget? content;
    Color bg;
    if (!visible) {
      bg = t.dark ? const Color(0xFF060606) : const Color(0xFF9AA0A8); // 안개
    } else if (cell.exploded) {
      bg = t.cellExploded;
      content = Text('💥', style: TextStyle(fontSize: side * 0.6));
    } else if (cell.isRevealed) {
      bg = t.cellRevealed;
      if (cell.adjacent > 0) {
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
      } else if (cell.oppFlagged) {
        content = Icon(Icons.flag, size: side * 0.6, color: AppTheme.oppColor);
      } else if (cell.isMegaphone) {
        content = Text('📣', style: TextStyle(fontSize: side * 0.55));
      }
    }
    if (content == null && (isMyStart || isOppStart)) {
      content = Text(isMyStart ? '🙂' : '🧑',
          style: TextStyle(fontSize: side * 0.6));
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: visible
          ? () {
              if (flagMode) {
                m.toggleFlag(r, c);
              } else {
                m.primaryTap(r, c);
              }
            }
          : null,
      onLongPress: visible ? () => m.toggleFlag(r, c) : null,
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
    final win = ctrl.result == RaceResult.win;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        children: [
          Text(win ? '만났어요! 🎉' : (ctrl.opponentLeft ? '파트너가 나갔어요' : '실패 💥'),
              style: TextStyle(
                  color: win ? _coop : const Color(0xFFCC0D0D),
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
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
                  style: FilledButton.styleFrom(backgroundColor: _coop),
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
