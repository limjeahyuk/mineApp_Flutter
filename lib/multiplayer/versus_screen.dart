import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/theme.dart';
import '../game/board_widget.dart';
import 'firebase_match_service.dart';
import 'multiplayer.dart';
import 'race_controller.dart';

/// 대전(레이스) 화면 — Swift MultiplayerView 이식. 매칭→카운트다운→레이스→결과.
class VersusScreen extends StatefulWidget {
  const VersusScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

class _VersusScreenState extends State<VersusScreen> {
  late final RaceController ctrl =
      RaceController(FirebaseMatchService(kind: 'mine'));
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

  Future<void> _exit() async {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: ctrl,
            builder: (_, _) {
              if (ctrl.failure != null) return _failure(t, ctrl.failure!);
              switch (ctrl.flow) {
                case RaceFlow.searching:
                  return _searching(t);
                case RaceFlow.starting:
                  return _countdown(t);
                case RaceFlow.racing:
                case RaceFlow.finished:
                  return _race(t);
              }
            },
          ),
        ),
      ),
    );
  }

  // ── 상대 찾는 중 ──
  Widget _searching(AppTheme t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(ctrl.rematching ? '재대결 대기 중…' : '상대를 찾는 중…',
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
            const SizedBox(height: 6),
            Text('친구에게 코드를 알려주세요',
                style: TextStyle(color: t.textTertiary, fontSize: 13)),
          ],
          const SizedBox(height: 40),
          TextButton(onPressed: _exit, child: const Text('취소')),
        ],
      ),
    );
  }

  // ── 시작 카운트다운 ──
  Widget _countdown(AppTheme t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('상대를 만났어요!',
              style: TextStyle(
                  color: t.text, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (ctrl.match != null)
            Text('vs ${ctrl.match!.opponentName}',
                style: TextStyle(color: t.textSecondary, fontSize: 15)),
          const SizedBox(height: 24),
          Text('${ctrl.startCountdown}',
              style: TextStyle(
                  color: AppTheme.soloAccent,
                  fontSize: 72,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── 레이스 + 결과 ──
  Widget _race(AppTheme t) {
    final g = ctrl.game;
    final isScore = g.rule == RaceRule.score;
    return Column(
      children: [
        _progressHeader(t, isScore),
        Expanded(child: BoardWidget(game: g, flagMode: flagMode)),
        if (ctrl.flow == RaceFlow.finished)
          _resultBanner(t)
        else
          _controls(t),
      ],
    );
  }

  Widget _progressHeader(AppTheme t, bool isScore) {
    final myName = LocalStore.shared.nickname;
    final oppName = ctrl.match?.opponentName ?? '상대';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          _racerRow(t, oppName, ctrl.opponentBarProgress, AppTheme.oppColor,
              isScore ? ctrl.opponentScore : null),
          const SizedBox(height: 8),
          _racerRow(t, '$myName (나)', ctrl.myBarProgress, AppTheme.meColor,
              isScore ? ctrl.myScore : null),
        ],
      ),
    );
  }

  Widget _racerRow(
      AppTheme t, String name, double progress, Color color, int? score) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: t.fill,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        if (score != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text('$score',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Widget _controls(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Material(
        color: flagMode ? AppTheme.soloAccent : t.fill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => flagMode = !flagMode),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(flagMode ? Icons.flag : Icons.flag_outlined,
                    color: flagMode ? Colors.white : t.text, size: 20),
                const SizedBox(width: 8),
                Text(flagMode ? '깃발 모드 ON' : '깃발 모드',
                    style: TextStyle(
                        color: flagMode ? Colors.white : t.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultBanner(AppTheme t) {
    final r = ctrl.result!;
    final (label, color) = switch (r) {
      RaceResult.win => (ctrl.opponentLeft ? '부전승! 🎉' : '승리! 🎉',
          const Color(0xFF1A801F)),
      RaceResult.lose => ('패배 💥', const Color(0xFFCC0D0D)),
      RaceResult.draw => ('무승부 🤝', t.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _exit,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('나가기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() {
                    flagMode = false;
                    ctrl.rematch();
                  }),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.multiAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('다시하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _failure(AppTheme t, MatchError e) {
    return Center(
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
}
