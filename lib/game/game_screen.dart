import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_model.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import 'board_widget.dart';
import 'item_dock.dart';

/// 솔로 게임 화면 — Swift ContentView 이식.
/// 상단 바(홈·난이도·⋯) / LED 카운터·얼굴·확대·깃발 / 보드 / 안내문구,
/// 아이템(초·중급 플로팅, 고급+ 엣지 서랍), 패배·클리어·이어하기 팝업, 판 코드 시트.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.initialDifficulty = Difficulty.beginner});
  final Difficulty initialDifficulty;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameModel game = GameModel();
  final store = LocalStore.shared;
  late final AppLifecycleListener _life;

  bool flagMode = false;
  bool boardZoomed = false;
  bool probing = false;
  bool showLossPopup = false;
  bool showWinPopup = false;
  int? winRank;
  bool rankLoading = false;
  Map<String, dynamic>? pendingResume;
  String? coinToast;
  Timer? _toastTimer;
  GameState _lastState = GameState.ready;
  Difficulty _lastDifficulty = Difficulty.beginner;

  static const _contentMaxWidth = 460.0;

  @override
  void initState() {
    super.initState();
    game.onSoloWin = (d, time, noItem) {
      final isBest = store.recordSolo(d, time);
      store.awardClearReward(d);
      if (noItem) store.recordNoItemHardClear(d);
      game.soloWinResult = SoloWinResult(d, time, isBest);
      _onWin(d);
    };
    game.onGoldenMineFound = () {
      store.awardGoldenMine();
      Haptics.success();
      _showCoinToast('💰 황금지뢰 발견! +${LocalStore.goldenMineReward} 코인');
    };
    game.autoFlagSupplier = () => store.ownedFlags;
    game.onConsumeAutoFlag = store.consumeFlag;
    game.radarSupplier = () => store.ownedRadars;
    game.onConsumeRadar = store.consumeRadar;
    game.addListener(_onGameChanged);
    // 저장된 진행 판이 있으면 자동 시작하지 않고 이어/새로 선택을 받는다.
    final snap = store.resumeSnapshotJson;
    Map<String, dynamic>? parsed;
    if (snap != null) {
      try {
        parsed = jsonDecode(snap) as Map<String, dynamic>;
      } catch (_) {}
    }
    if (parsed != null) {
      pendingResume = parsed;
    } else {
      game.startSolo(widget.initialDifficulty);
    }
    _lastDifficulty = game.difficulty;
    // 백그라운드로 갈 때 진행 중 판 저장 → 앱을 완전히 꺼도 복원.
    _life = AppLifecycleListener(onStateChange: (s) {
      if (s == AppLifecycleState.hidden || s == AppLifecycleState.paused) {
        final json = game.makeResumeSnapshot();
        if (json != null) store.resumeSnapshotJson = json;
      }
    });
  }

  @override
  void dispose() {
    _life.dispose();
    _toastTimer?.cancel();
    game.removeListener(_onGameChanged);
    game.dispose();
    setBigBoardOrientation(false);
    super.dispose();
  }

  void _onGameChanged() {
    if (game.state != _lastState) {
      final s = game.state;
      _lastState = s;
      if (s != GameState.playing) probing = false;
      showLossPopup = s == GameState.lost;
      if (s == GameState.won) {
        Haptics.success();
        store.resumeSnapshotJson = null;
      } else if (s == GameState.lost) {
        Haptics.error();
        store.resumeSnapshotJson = null;
      }
    }
    if (game.difficulty != _lastDifficulty) {
      // 코드 불러오기로 난이도가 바뀌면 방향도 맞춘다.
      _lastDifficulty = game.difficulty;
      setBigBoardOrientation(game.difficulty.prefersLandscape);
    }
    if (mounted) setState(() {});
  }

  void _onWin(Difficulty d) {
    winRank = null;
    rankLoading = true;
    showWinPopup = true;
    store.onlineRank(d).then((r) {
      if (!mounted) return;
      setState(() {
        winRank = r;
        rankLoading = false;
      });
    });
  }

  void _showCoinToast(String msg) {
    _toastTimer?.cancel();
    setState(() => coinToast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && coinToast == msg) setState(() => coinToast = null);
    });
  }

  void _restartGame() {
    flagMode = false;
    game.resetCurrentGame();
  }

  void _startNewBoard() {
    flagMode = false;
    game.newGame();
  }

  void _goHome() {
    Haptics.tap();
    store.resumeSnapshotJson = null; // 홈 이탈은 판을 버린다(이어하기는 앱 종료 복원용)
    Navigator.of(context).pop();
  }

  void _handleProbe(int r, int c) {
    final used = game.useAutoFlag(r, c);
    setState(() => probing = false);
    used ? Haptics.success() : Haptics.tap();
  }

  void _fireRadar() {
    if (game.useRadar()) Haptics.success();
  }

  bool get _itemsInDrawer =>
      game.difficulty == Difficulty.expert ||
      game.difficulty == Difficulty.ultimate;
  bool get _dense => game.difficulty == Difficulty.expert;
  bool get _anyPopup => showLossPopup || showWinPopup || pendingResume != null;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final compact = MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).height < 500;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        SafeArea(child: compact ? _compactLayout(t) : _standardLayout(t)),
        if (!_anyPopup && pendingResume == null)
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: ItemDock(
                  solo: true,
                  tickets: game.autoFlagTickets,
                  isPlaying: game.state == GameState.playing,
                  usesEdgeDrawer: _itemsInDrawer,
                  drawerBottomPadding: compact ? 40 : 96,
                  probing: probing,
                  onProbingChanged: (v) => setState(() => probing = v),
                  radarTickets: game.radarTickets,
                  onRadar: _fireRadar,
                ),
              ),
            ),
          ),
        if (showLossPopup) _lossPopup(t),
        if (showWinPopup) _WinPopup(
          result: game.soloWinResult,
          elapsed: game.elapsed,
          rank: winRank,
          rankLoading: rankLoading,
          onAgain: () {
            Haptics.tap();
            setState(() => showWinPopup = false);
            _startNewBoard();
          },
          onHome: () {
            Haptics.tap();
            setState(() => showWinPopup = false);
            Navigator.of(context).pop();
          },
          onResult: () => setState(() => showWinPopup = false),
        ),
        if (pendingResume != null) _resumePopup(t),
        // 황금지뢰 등 코인 획득 안내 — 상단에 잠깐.
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                      position: Tween(begin: const Offset(0, -0.8), end: Offset.zero)
                          .animate(a),
                      child: c)),
              child: coinToast == null
                  ? const SizedBox.shrink()
                  : Center(
                      key: ValueKey(coinToast),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(100)),
                        child: Text(coinToast!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none)),
                      ),
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  // MARK: 레이아웃

  Widget _standardLayout(AppTheme t) {
    final d = _dense;
    return Padding(
      padding: EdgeInsets.fromLTRB(d ? 4 : 8, d ? 4 : 10, d ? 4 : 8, d ? 6 : 14),
      child: Column(children: [
        _centered(_topBar(t)),
        SizedBox(height: d ? 6 : 12),
        _centered(_header(t)),
        SizedBox(height: d ? 6 : 12),
        Expanded(child: _board()),
        SizedBox(height: d ? 6 : 12),
        _centered(_statusText(t)),
      ]),
    );
  }

  Widget _compactLayout(AppTheme t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Column(children: [
          _compactBar(t),
          const SizedBox(height: 5),
          Expanded(child: _board()),
        ]),
      );

  Widget _centered(Widget c) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth), child: c));

  Widget _board() => BoardWidget(
        game: game,
        flagMode: flagMode,
        zoomed: boardZoomed,
        onZoomChanged: (z) => setState(() => boardZoomed = z),
        probing: probing,
        onProbe: _handleProbe,
      );

  // MARK: 상단 바

  Widget _topBar(AppTheme t) {
    return Row(children: [
      Pressable(
        onTap: _goHome,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration:
              BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(CupertinoIcons.chevron_left, size: 15, color: t.textSecondary),
            const SizedBox(width: 4),
            Text('홈',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
      Expanded(
        child: Text(game.difficulty.label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: t.textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      Pressable(
        haptic: true,
        onTap: _openCodeSheet,
        child: Container(
          width: 38,
          height: 32,
          decoration:
              BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(9)),
          child: Icon(CupertinoIcons.ellipsis, size: 17, color: t.textSecondary),
        ),
      ),
    ]);
  }

  // MARK: 헤더 — 지뢰 카운터 / 얼굴·확대·깃발 / 타이머

  Widget _header(AppTheme t) {
    final d = _dense;
    return Row(children: [
      _counter(game.minesRemaining, d),
      const Spacer(),
      _faceButton(t, d),
      SizedBox(width: d ? 8 : 12),
      _toggle(
          t,
          boardZoomed ? CupertinoIcons.zoom_out : CupertinoIcons.zoom_in,
          boardZoomed,
          AppTheme.zoomBlue,
          AppTheme.zoomBlueStroke,
          () => setState(() => boardZoomed = !boardZoomed),
          w: d ? 44 : 50,
          h: d ? 36 : 50,
          iconSize: d ? 17 : 21),
      SizedBox(width: d ? 8 : 12),
      _toggle(t, CupertinoIcons.flag_fill, flagMode, AppTheme.flagRed,
          AppTheme.flagRedStroke, () => setState(() => flagMode = !flagMode),
          w: d ? 44 : 50, h: d ? 36 : 50, iconSize: d ? 17 : 23, glow: true),
      const Spacer(),
      _counter(game.elapsed, d),
    ]);
  }

  String get _face => switch (game.state) {
        GameState.won => '😎',
        GameState.lost => '😵',
        _ => '🙂',
      };

  Widget _faceButton(AppTheme t, bool d) => Pressable(
        haptic: true,
        onTap: _restartGame,
        child: Container(
          width: d ? 44 : 56,
          height: d ? 36 : 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.fillElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.border),
          ),
          child: Text(_face, style: TextStyle(fontSize: d ? 22 : 30)),
        ),
      );

  Widget _toggle(AppTheme t, IconData icon, bool on, Color onColor,
      Color onStroke, VoidCallback onTap,
      {required double w,
      required double h,
      required double iconSize,
      bool glow = false,
      double radius = 10}) {
    return Pressable(
      haptic: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: on ? onColor : t.fillElevated,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: on ? onStroke : t.border, width: 1.5),
          boxShadow: glow && on
              ? [BoxShadow(color: onColor.withValues(alpha: 0.5), blurRadius: 6)]
              : null,
        ),
        child: Icon(icon, size: iconSize, color: on ? Colors.white : t.textSecondary),
      ),
    );
  }

  static String _fmt3(int v) {
    final x = min(999, max(-99, v));
    return x < 0 ? '-${(-x).toString().padLeft(2, '0')}' : x.toString().padLeft(3, '0');
  }

  Widget _counter(int v, bool dense) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 12, vertical: dense ? 4 : 6),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.of(context).fillElevated),
        ),
        child: Text(_fmt3(v),
            style: TextStyle(
              color: AppTheme.ledRed,
              fontSize: dense ? 18 : 26,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier',
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
      );

  // MARK: 가로(컴팩트) 바

  Widget _compactBar(AppTheme t) {
    Widget smallBtn(IconData icon, VoidCallback onTap) => Pressable(
          haptic: true,
          onTap: onTap,
          child: Container(
            width: 34,
            height: 30,
            decoration:
                BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: t.textSecondary),
          ),
        );
    Widget counter(int v) => Container(
          height: 30,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: t.fillElevated),
          ),
          child: Text(_fmt3(v),
              style: const TextStyle(
                  color: AppTheme.ledRed,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier')),
        );
    return Row(children: [
      smallBtn(CupertinoIcons.chevron_left, _goHome),
      const SizedBox(width: 7),
      counter(game.minesRemaining),
      const Spacer(),
      Pressable(
        haptic: true,
        onTap: _restartGame,
        child: Container(
          width: 42,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.fillElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Text(_face, style: const TextStyle(fontSize: 20)),
        ),
      ),
      const SizedBox(width: 7),
      _toggle(t, CupertinoIcons.flag_fill, flagMode, AppTheme.flagRed,
          AppTheme.flagRedStroke, () => setState(() => flagMode = !flagMode),
          w: 40, h: 32, iconSize: 15, radius: 8),
      const SizedBox(width: 7),
      _toggle(
          t,
          boardZoomed ? CupertinoIcons.zoom_out : CupertinoIcons.zoom_in,
          boardZoomed,
          AppTheme.zoomBlue,
          AppTheme.zoomBlueStroke,
          () => setState(() => boardZoomed = !boardZoomed),
          w: 40,
          h: 32,
          iconSize: 15,
          radius: 8),
      const Spacer(),
      counter(game.elapsed),
      const SizedBox(width: 7),
      smallBtn(CupertinoIcons.ellipsis, _openCodeSheet),
    ]);
  }

  // MARK: 안내문구

  Widget _statusText(AppTheme t) {
    String text;
    switch (game.state) {
      case GameState.won:
        final code = game.boardCode;
        if (code != null) {
          final best = game.bestTime(code) ?? game.elapsed;
          text = '🎉 ${game.elapsed}초 클리어!  (이 판 최고 $best초)';
        } else {
          text = '🎉 클리어! 새 게임을 시작하려면 얼굴을 누르세요.';
        }
      case GameState.lost:
        text = '💥 지뢰를 밟았어요. 얼굴을 눌러 다시 도전!';
      default:
        if (probing) {
          text = '🚩 자동깃발 · 숫자칸을 선택하면 주변 지뢰에 깃발을 꽂아요';
        } else if (flagMode) {
          text = '🚩 깃발 모드 · 탭: 깃발 꽂기 · 길게 누르기: 칸 열기';
        } else {
          text = '탭: 칸 열기 · 길게 누르기: 깃발 · 숫자 탭: 주변 일괄 열기';
        }
    }
    return Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: t.textSecondary,
            fontSize: _dense ? 11 : 13,
            fontWeight: FontWeight.w500));
  }

  // MARK: 판 코드 시트

  void _openCodeSheet() {
    final t = AppTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: _BoardCodeSheet(
            code: game.boardCode,
            onNewBoard: _startNewBoard,
            onLoad: (c) {
              flagMode = false;
              return game.loadCode(c);
            },
          ),
        ),
      ),
    );
  }

  // MARK: 이어하기 팝업

  Widget _resumePopup(AppTheme t) {
    final snap = pendingResume!;
    final diffName = Difficulty.fromLabel(snap['difficulty'] as String? ?? '')?.label ?? '';
    final secs = (snap['elapsed'] as num?)?.toInt() ?? 0;
    return PopupCard(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('⏸️', style: TextStyle(fontSize: 50)),
        const SizedBox(height: 14),
        Text('이어서 할까요?',
            style: TextStyle(color: t.text, fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Text('$diffName · $secs초까지 진행한 판이 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary, fontSize: 14)),
        const SizedBox(height: 20),
        BigButton(
          label: '이어서 하기',
          icon: CupertinoIcons.arrow_uturn_left,
          color: AppTheme.successGreen,
          onTap: () {
            Haptics.tap();
            flagMode = false;
            game.restore(snap);
            setBigBoardOrientation(game.difficulty.prefersLandscape);
            store.resumeSnapshotJson = null;
            setState(() => pendingResume = null);
          },
        ),
        const SizedBox(height: 14),
        BigButton(
          label: '새로 하기',
          color: t.fillElevated,
          textColor: t.text,
          onTap: () {
            Haptics.tap();
            store.resumeSnapshotJson = null;
            setState(() => pendingResume = null);
            game.startSolo(widget.initialDifficulty);
          },
        ),
      ]),
    );
  }

  // MARK: 패배 팝업

  Widget _lossPopup(AppTheme t) {
    final canContinue = game.canContinue;
    return PopupCard(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('💥', style: TextStyle(fontSize: 54)),
        const SizedBox(height: 14),
        Text('지뢰를 밟았어요!',
            style: TextStyle(color: t.text, fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Text(
            canContinue
                ? '이어서 계속하거나, 새로운 판으로 다시 시작할 수 있어요.'
                : '새로운 판으로 다시 시작할까요?',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary, fontSize: 14)),
        const SizedBox(height: 20),
        if (canContinue) ...[
          BigButton(
            label: '이어하기',
            icon: CupertinoIcons.arrow_uturn_left,
            color: AppTheme.successGreen,
            onTap: () {
              Haptics.tap();
              setState(() => showLossPopup = false);
              game.continueGame();
            },
          ),
          const SizedBox(height: 14),
          Text('이어한 판은 최고기록·랭킹에 기록되지 않아요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textTertiary, fontSize: 11)),
          const SizedBox(height: 14),
        ],
        BigButton(
          label: '새 판으로 다시',
          color: AppTheme.flagRed,
          onTap: () {
            Haptics.tap();
            _startNewBoard();
          },
        ),
        const SizedBox(height: 14),
        TextLink('보드 보기', onTap: () => setState(() => showLossPopup = false)),
      ]),
    );
  }
}

// MARK: - 클리어 팝업(색종이 + 기록 + 등수)

class _WinPopup extends StatefulWidget {
  const _WinPopup({
    required this.result,
    required this.elapsed,
    required this.rank,
    required this.rankLoading,
    required this.onAgain,
    required this.onHome,
    required this.onResult,
  });
  final SoloWinResult? result;
  final int elapsed;
  final int? rank;
  final bool rankLoading;
  final VoidCallback onAgain, onHome, onResult;

  @override
  State<_WinPopup> createState() => _WinPopupState();
}

class _WinPopupState extends State<_WinPopup> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550))
    ..forward();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  static const _gold = AppTheme.gold;

  @override
  void dispose() {
    _in.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final r = widget.result;
    final card = CurvedAnimation(parent: _in, curve: Curves.elasticOut);
    final emoji = CurvedAnimation(
        parent: _in, curve: const Interval(0.2, 1, curve: Curves.elasticOut));
    final best = r == null ? null : LocalStore.shared.bestLocal(r.difficulty);
    return Stack(children: [
      Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.6))),
      const Positioned.fill(child: IgnorePointer(child: _Confetti())),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: ScaleTransition(
            scale: Tween(begin: 0.7, end: 1.0).animate(card),
            child: FadeTransition(
              opacity: _in,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: t.fill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 26)
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedBuilder(
                        animation: emoji,
                        builder: (_, c) => Transform.rotate(
                            angle: (1 - emoji.value) * -30 * pi / 180,
                            child: Transform.scale(
                                scale: 0.2 + 0.8 * emoji.value, child: c)),
                        child: const Text('🎉', style: TextStyle(fontSize: 54)),
                      ),
                      const SizedBox(height: 12),
                      Text('클리어!',
                          style: TextStyle(
                              color: t.text, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Text(timeLabel(r?.timeSec ?? widget.elapsed),
                          style: TextStyle(
                              color: t.text, fontSize: 40, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      if (r?.isBest == true)
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, c) => Transform.scale(
                            scale: 0.9 + 0.1 * _pulse.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: _gold,
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                      color: _gold.withValues(alpha: 0.7 * _pulse.value),
                                      blurRadius: 10)
                                ],
                              ),
                              child: c,
                            ),
                          ),
                          child: const Text('🏆 최고 기록 경신!',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        )
                      else if (best != null)
                        Text('내 최고 ${timeLabel(best)}',
                            style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 30,
                        child: Center(
                          child: widget.rankLoading
                              ? Row(mainAxisSize: MainAxisSize.min, children: [
                                  const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: _gold)),
                                  const SizedBox(width: 7),
                                  Text('등수 집계 중…',
                                      style: TextStyle(
                                          color: t.textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ])
                              : widget.rank != null
                                  ? Text('🏅 전체 ${widget.rank}등',
                                      style: const TextStyle(
                                          color: _gold,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900))
                                  : Text('전체 등수는 온라인 연결 시 표시돼요',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: t.textTertiary, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      BigButton(
                          label: '한 번 더',
                          icon: CupertinoIcons.arrow_clockwise,
                          color: AppTheme.successGreen,
                          onTap: widget.onAgain),
                      const SizedBox(height: 12),
                      BigButton(
                          label: '홈으로',
                          icon: CupertinoIcons.house_fill,
                          color: t.fillElevated,
                          textColor: t.text,
                          onTap: widget.onHome),
                      const SizedBox(height: 14),
                      TextLink('결과 보기', onTap: widget.onResult),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// 축하 색종이 — 화면 위에서 무작위 색·크기·속도·회전으로 쏟아진다(반복).
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _Piece {
  _Piece(Random r)
      : x = r.nextDouble(),
        color = _palette[r.nextInt(_palette.length)],
        size = 7 + r.nextDouble() * 6,
        delay = r.nextDouble() * 1.4,
        duration = 2.2 + r.nextDouble() * 1.6,
        spin = (240 + r.nextDouble() * 660) * (r.nextBool() ? 1 : -1),
        drift = -45 + r.nextDouble() * 90,
        isRect = r.nextBool();
  final double x, size, delay, duration, spin, drift;
  final Color color;
  final bool isRect;

  static const _palette = [
    Color.fromRGBO(242, 77, 102, 1),
    Color.fromRGBO(250, 199, 77, 1),
    Color.fromRGBO(77, 191, 140, 1),
    Color.fromRGBO(77, 140, 242, 1),
    Color.fromRGBO(179, 115, 242, 1),
    Color.fromRGBO(250, 140, 191, 1),
  ];
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final List<_Piece> pieces = List.generate(70, (_) => _Piece(Random()));
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(days: 1))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        painter: _ConfettiPainter(
            pieces, (_c.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.time);
  final List<_Piece> pieces;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final t = time - p.delay;
      if (t < 0) continue;
      final f = (t % p.duration) / p.duration;
      final e = f * f; // easeIn
      final x = p.x * size.width + p.drift * e;
      final y = -50 + (size.height + 100) * e;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * e * pi / 180);
      final paint = Paint()..color = p.color;
      if (p.isRect) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.45),
                const Radius.circular(1.5)),
            paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

// MARK: - 판 코드 시트

class _BoardCodeSheet extends StatefulWidget {
  const _BoardCodeSheet(
      {required this.code, required this.onNewBoard, required this.onLoad});
  final String? code;
  final VoidCallback onNewBoard;
  final bool Function(String) onLoad;

  @override
  State<_BoardCodeSheet> createState() => _BoardCodeSheetState();
}

class _BoardCodeSheetState extends State<_BoardCodeSheet> {
  final _input = TextEditingController();
  bool loadError = false;
  bool copied = false;

  static const _errorRed = Color.fromRGBO(255, 115, 115, 1);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _load() {
    final s = _input.text.trim();
    if (s.isEmpty) return;
    if (widget.onLoad(s)) {
      Haptics.tap();
      Navigator.of(context).pop();
    } else {
      setState(() => loadError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        Text('판 코드',
            style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('코드를 공유하면 상대도 같은 판을 풀 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary, fontSize: 12)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration:
              BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('이 판',
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                SelectableText(widget.code ?? '—',
                    style: TextStyle(
                        color: t.text,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier')),
              ]),
            ),
            Pressable(
              enabled: widget.code != null,
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.code!));
                Haptics.tap();
                setState(() => copied = true);
              },
              child: Container(
                width: 44,
                height: 38,
                decoration: BoxDecoration(
                  color: copied
                      ? const Color.fromRGBO(51, 166, 89, 1)
                      : t.fillElevated,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                    copied ? CupertinoIcons.checkmark : CupertinoIcons.doc_on_doc,
                    size: 16,
                    color: t.text),
              ),
            ),
            const SizedBox(width: 10),
            Pressable(
              onTap: () {
                Haptics.tap();
                widget.onNewBoard();
                Navigator.of(context).pop();
              },
              child: Container(
                width: 58,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppTheme.zoomBlue,
                    borderRadius: BorderRadius.circular(9)),
                child: const Text('새 판',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: loadError ? _errorRed : t.fillElevated),
              ),
              child: TextField(
                controller: _input,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _load(),
                style: TextStyle(color: t.text, fontSize: 15, fontFamily: 'Courier'),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '코드 입력 (예: I-3F8A2C)',
                  hintStyle: TextStyle(color: t.textTertiary, fontSize: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            enabled: _input.text.trim().isNotEmpty,
            onTap: _load,
            child: Container(
              width: 78,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: t.fillElevated, borderRadius: BorderRadius.circular(10)),
              child: Text('불러오기',
                  style: TextStyle(
                      color: t.text, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        if (loadError)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('코드를 인식할 수 없어요. 예: I-3F8A2C',
                  style: TextStyle(color: _errorRed, fontSize: 11)),
            ),
          ),
      ]),
    );
  }
}
