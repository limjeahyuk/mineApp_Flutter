import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../game/board_widget.dart';
import '../game/item_dock.dart';
import '../progression/daily.dart';
import 'firebase_match_service.dart';
import 'multiplayer.dart';
import 'race_controller.dart';

/// 대전(레이스) 화면 — Swift MultiplayerView 이식. 매칭→카운트다운→레이스→결과.
/// 레이스 상단바: X 닫기 · LED 타이머 · 깃발 토글. 진행바는 나(위)·상대(아래) + %.
///
/// ponytail: 자동깃발/레이더 도크, 자리비움 배너, 합동 모드는 미이식.
class VersusScreen extends StatefulWidget {
  const VersusScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

class _VersusScreenState extends State<VersusScreen> {
  late final RaceController ctrl =
      RaceController(FirebaseMatchService(kind: 'mine'));
  // 대전은 시작 시 첫 칸이 열려 있으므로 깃발 모드를 기본으로 둔다(원본과 동일).
  bool flagMode = true;
  bool probing = false; // 자동깃발 발동 대기
  bool _recorded = false; // 이번 판 전적 1회만 기록

  @override
  void initState() {
    super.initState();
    // 인벤토리 배선 — 매칭 후 startSeeded가 티켓을 계산하므로 그 전에 연결.
    final inv = LocalStore.shared;
    ctrl.game.autoFlagSupplier = () => inv.ownedFlags;
    ctrl.game.onConsumeAutoFlag = inv.consumeFlag;
    ctrl.game.radarSupplier = () => inv.ownedRadars;
    ctrl.game.onConsumeRadar = inv.consumeRadar;
    ctrl.game.onGoldenMineFound = () {
      inv.addGoldenMines(1);
      Daily.bump(DailyKind.golden);
    };
    ctrl.addListener(_maybeRecordResult);
    ctrl.start(widget.mode);
  }

  // 대전 종료 시 전적 1회 기록.
  void _maybeRecordResult() {
    if (_recorded) return;
    if (ctrl.flow != RaceFlow.finished || ctrl.result == null) return;
    _recorded = true;
    final inv = LocalStore.shared;
    switch (ctrl.result!) {
      case RaceResult.win:
        inv.recordRaceWin();
        Daily.bump(DailyKind.raceWins);
      case RaceResult.lose:
        inv.recordRaceLoss();
      case RaceResult.draw:
        inv.recordRaceDraw();
    }
  }

  void _onProbe(int r, int c) {
    ctrl.game.useAutoFlag(r, c);
    setState(() => probing = false);
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
                  color: t.text, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
            child: Icon(Icons.person, color: AppTheme.oppColor, size: 30),
          ),
          const SizedBox(height: 8),
          if (ctrl.match != null)
            Text(ctrl.match!.opponentName,
                style: TextStyle(
                    color: t.text, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Text('${ctrl.startCountdown}',
              style: TextStyle(
                  color: AppTheme.meColor,
                  fontSize: 64,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('잠시 후 시작합니다',
              style: TextStyle(color: t.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  // ── 레이스 + 결과 ──
  Widget _race(AppTheme t) {
    final g = ctrl.game;
    final isScore = g.rule == RaceRule.score;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        children: [
          _topBar(t),
          const SizedBox(height: 8),
          _progressRow(t, '나', ctrl.myBarProgress, AppTheme.meColor,
              isScore ? ctrl.myScore : null),
          const SizedBox(height: 6),
          _progressRow(t, ctrl.match?.opponentName ?? '상대',
              ctrl.opponentBarProgress, AppTheme.oppColor,
              isScore ? ctrl.opponentScore : null),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: BoardWidget(
                    game: g,
                    flagMode: flagMode,
                    probing: probing,
                    onProbe: _onProbe,
                  ),
                ),
                if (ctrl.flow == RaceFlow.racing)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: ItemDock(
                      radarTickets: g.radarTickets,
                      autoFlagTickets: g.autoFlagTickets,
                      isPlaying: g.state == GameState.playing,
                      probing: probing,
                      onRadar: () => setState(() {
                        g.useRadar();
                      }),
                      onToggleProbe: () => setState(() => probing = !probing),
                    ),
                  ),
              ],
            ),
          ),
          if (ctrl.flow == RaceFlow.finished) _resultBanner(t),
        ],
      ),
    );
  }

  // 상단바: X 닫기 · LED 타이머 · 깃발 토글
  Widget _topBar(AppTheme t) {
    return Row(
      children: [
        _iconButton(t, Icons.close, _exit),
        const Spacer(),
        _led(ctrl.game.elapsed),
        const Spacer(),
        _iconButton(
          t,
          flagMode ? Icons.flag : Icons.flag_outlined,
          () => setState(() => flagMode = !flagMode),
          highlighted: flagMode,
        ),
      ],
    );
  }

  Widget _iconButton(AppTheme t, IconData icon, VoidCallback onTap,
      {bool highlighted = false}) {
    return Material(
      color: highlighted ? AppTheme.soloAccent : t.fill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 40,
          child: Icon(icon,
              color: highlighted ? Colors.white : t.text, size: 22),
        ),
      ),
    );
  }

  Widget _led(int value) {
    final v = value.clamp(0, 999).toString().padLeft(3, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black, borderRadius: BorderRadius.circular(6)),
      child: Text(v,
          style: const TextStyle(
            color: Color(0xFFFF3B30),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
            letterSpacing: 2,
          )),
    );
  }

  Widget _progressRow(
      AppTheme t, String name, double progress, Color color, int? score) {
    final p = progress.clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
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
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        if (score != null)
          SizedBox(
            width: 30,
            child: Text('$score',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
      ],
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
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
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
                    flagMode = true;
                    _recorded = false;
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
