import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../game/item_dock.dart';
import '../multiplayer/firebase_match_service.dart';
import '../multiplayer/match_widgets.dart';
import '../multiplayer/multiplayer.dart';
import '../progression/title.dart' show TitleBadge;
import 'coop_controller.dart';
import 'touch_board.dart';

/// "너에게 닿기를" 협동 화면 — Swift TouchMultiplayerView 이식.
/// 상대 검색 → 함께 길 뚫기(안개 보드) → 두 사람이 닿으면 둘 다 성공 → 결과.
class CoopScreen extends StatefulWidget {
  const CoopScreen({super.key, required this.mode});
  final RaceMode mode;

  @override
  State<CoopScreen> createState() => _CoopScreenState();
}

class _CoopScreenState extends State<CoopScreen> {
  late final CoopController vm =
      CoopController(FirebaseMatchService(kind: 'touch'));
  bool flagMode = true; // 기본 깃발 모드 — 탭=깃발, 길게=칸 열기
  bool probing = false;
  bool reviewing = false;
  CoopFlow _lastFlow = CoopFlow.searching;
  bool _lastStunned = false;
  bool _closed = false;

  static const _accent = Color.fromRGBO(102, 179, 140, 1); // (0.40,0.70,0.55)

  @override
  void initState() {
    super.initState();
    vm.addListener(_onVm);
    vm.start(widget.mode);
  }

  @override
  void dispose() {
    vm.removeListener(_onVm);
    vm.leave();
    vm.dispose();
    super.dispose();
  }

  void _onVm() {
    if (vm.flow != _lastFlow) {
      _lastFlow = vm.flow;
      if (vm.flow != CoopFlow.racing) probing = false;
      if (vm.flow == CoopFlow.racing) reviewing = false;
    }
    if (vm.game.stunned != _lastStunned) {
      _lastStunned = vm.game.stunned;
      if (_lastStunned) probing = false;
    }
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            final g = vm.game;
            return Stack(
              fit: StackFit.expand,
              children: [
                SafeArea(
                  child: vm.flow == CoopFlow.searching
                      ? _searchingView(t)
                      : _raceView(t),
                ),
                if (vm.flow == CoopFlow.racing)
                  SafeArea(
                    child: Stack(children: [
                      ItemDock(
                        tickets: g.autoFlagTickets,
                        isPlaying:
                            g.state == GameState.playing && !g.stunned,
                        probing: probing,
                        onProbingChanged: (v) => setState(() => probing = v),
                        drawerBottomPadding: 40,
                        megaphoneTickets: g.megaphoneTickets,
                        onMegaphone: g.useMegaphone,
                      ),
                    ]),
                  ),
                if (vm.flow == CoopFlow.finished &&
                    vm.result != null &&
                    !reviewing)
                  _resultOverlay(t, vm.result!),
                if (vm.flow == CoopFlow.finished && reviewing) _reviewBar(),
                if (vm.flow == CoopFlow.racing && g.stunned)
                  SafeArea(child: _stunBanner()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stunBanner() => Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('💥', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text('지뢰! 잠깐 멈춤… (파트너 깃발 1개 떨어짐)',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  // MARK: 검색 중

  Widget _searchingView(AppTheme t) {
    final failure = vm.failure;
    if (failure != null) return MatchFailedView(error: failure, onClose: _close);
    final Widget detail;
    if (vm.rematching) {
      detail = const MatchDetailText('같은 파트너와 다시 시작할게요');
    } else if (widget.mode.kind == RaceModeKind.host) {
      detail = RoomCodeBlock(
        code: vm.roomCode,
        shareText: (code) =>
            '‘너에게 닿기를’ 같이 해요! 방 코드: $code\n${InviteLink.webURL('touch', code)}',
        footer: '친구가 이 코드를 입력하면 함께 시작돼요',
      );
    } else {
      detail = const MatchDetailText('서로 길을 뚫어 만나면 둘 다 성공이에요');
    }
    final title = vm.rematching
        ? '파트너를 기다리는 중…'
        : switch (widget.mode.kind) {
            RaceModeKind.host => '파트너 입장을 기다리는 중…',
            RaceModeKind.join => '방에 입장 중…',
            _ => '함께할 사람을 찾는 중…',
          };
    return MatchSearchingView(title: title, detail: detail, onCancel: _close);
  }

  // MARK: 플레이

  Widget _raceView(AppTheme t) {
    final g = vm.game;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              CircleIconButton(icon: Icons.close, onTap: _close),
              const Spacer(),
              ValueListenableBuilder<int>(
                valueListenable: g.tick,
                builder: (_, _, _) => Text(timeLabel(g.elapsed),
                    style: TextStyle(
                        color: t.text,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Menlo',
                        fontFamilyFallback: const ['Courier', 'monospace'])),
              ),
              const Spacer(),
              CircleFlagToggle(
                  on: flagMode,
                  onTap: () => setState(() => flagMode = !flagMode)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('🤝', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Flexible(
                child: Text('${vm.opponentName}와 길을 뚫어 만나기',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              if (vm.opponentTitle.isNotEmpty) ...[
                const SizedBox(width: 6),
                TitleBadge(name: vm.opponentTitle, size: 8),
              ],
              const Spacer(),
              if (g.minesHit > 0)
                Text('💣 ${g.minesHit}',
                    style: const TextStyle(
                        color: kRaceOpp,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TouchBoard(
              game: g,
              flagMode: flagMode,
              pings: List.of(vm.pings),
              probing: probing,
              onProbe: (r, c) {
                g.useAutoFlag(r, c);
                setState(() => probing = false);
              },
              reveal: reviewing,
            ),
          ),
        ],
      ),
    );
  }

  // MARK: 결과

  Widget _resultOverlay(AppTheme t, RaceResult r) {
    final win = r == RaceResult.win;
    final best = LocalStore.shared.touchBest;
    return ResultOverlay(
      emoji: win ? '🤝' : '🌫️',
      title: win ? '서로에게 닿았어요!' : '아쉽게 끝났어요',
      subtitle: vm.opponentLeft
          ? '상대가 나가서 함께 도달하지 못했어요'
          : (win ? '둘이 길을 이어 만났어요 🎉' : '다시 도전해 보세요'),
      children: [
        if (win) ...[
          Text('걸린 시간 ${timeLabel(vm.game.elapsed)}',
              style: const TextStyle(
                  color: _accent, fontSize: 16, fontWeight: FontWeight.bold)),
          if (best != null) ...[
            const SizedBox(height: 3),
            Text('최고 기록 ${timeLabel(best)}',
                style: TextStyle(color: t.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          PlainButton(
            onTap: () => setState(() => reviewing = true),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _accent.withValues(alpha: 0.6), width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 17, color: _accent),
                  SizedBox(width: 6),
                  Text('보드 보기',
                      style: TextStyle(
                          color: _accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledWideButton(
            label: '다시 하기',
            color: _accent,
            onTap: () {
              setState(() => flagMode = true);
              vm.rematch();
            }),
        TextLinkButton(label: '나가기', onTap: _close),
      ],
    );
  }

  Widget _reviewBar() => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 34),
          child: PlainButton(
            onTap: () => setState(() => reviewing = false),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.workspace_premium, size: 17, color: Colors.white),
                SizedBox(width: 6),
                Text('결과 보기',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}
