import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_model.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../progression/daily.dart';
import '../ranking/ranking_service.dart';
import 'board_widget.dart';
import 'item_dock.dart';
import '../progression/title.dart';

/// 최고급(가로 허용) 판이면 세로+가로, 아니면 세로 고정 — Swift setAppOrientation 대응.
void setAppOrientationFor(Difficulty? d) {
  SystemChrome.setPreferredOrientations(d?.prefersLandscape == true
      ? const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]
      : const [DeviceOrientation.portraitUp]);
}

/// LED 카운터 색 (1.0, 0.23, 0.19)
const ledRed = Color.fromRGBO(255, 59, 48, 1);
const accentBlue = Color.fromRGBO(51, 115, 217, 1); // (0.20,0.45,0.85)
const flagRed = Color.fromRGBO(230, 77, 61, 1); // (0.90,0.30,0.24)
const flagRedStroke = Color.fromRGBO(255, 140, 115, 1); // (1.0,0.55,0.45)
const zoomStroke = Color.fromRGBO(115, 166, 255, 1); // (0.45,0.65,1.0)
const accentGreen = Color.fromRGBO(51, 140, 102, 1); // (0.20,0.55,0.40)
const popupGold = Color.fromRGBO(242, 199, 77, 1); // (0.95,0.78,0.30)

/// "%03d" (−99…999)
String led3(int v) {
  final c = v.clamp(-99, 999);
  return c < 0 ? '-${(-c).toString().padLeft(2, '0')}' : c.toString().padLeft(3, '0');
}

/// LED 카운터 — Swift ContentView.counter / compactCounter.
Widget ledCounter(AppTheme t, int value, {bool dense = false, bool compact = false}) {
  if (compact) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: rr(5, Colors.black, stroke: t.fillElevated),
      child: Text(led3(value), style: sf(16, weight: W.bold, color: ledRed, mono: true)),
    );
  }
  return Container(
    padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 4 : 6),
    decoration: rr(6, Colors.black, stroke: t.fillElevated),
    child: Text(led3(value),
        style: sf(dense ? 18 : 26, weight: W.bold, color: ledRed, mono: true, height: 1.2)),
  );
}

/// 헤더의 정사각 토글 버튼(확대/깃발) — 켜지면 색 채움 + 밝은 테두리.
Widget toggleSquare(AppTheme t,
    {required IconData icon,
    required bool on,
    required Color onFill,
    required Color onStroke,
    required double w,
    required double h,
    required double iconSize,
    double radius = 10,
    bool glow = false,
    required VoidCallback onTap}) {
  return Tap(
    onTap: () {
      Haptics.tap();
      onTap();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: on ? onFill : t.fillElevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: on ? onStroke : t.border, width: 1.5),
        boxShadow: glow && on
            ? [BoxShadow(color: onFill.withValues(alpha: 0.5), blurRadius: 12)]
            : null,
      ),
      child: Icon(icon, size: iconSize, color: on ? Colors.white : t.textSecondary),
    ),
  );
}

/// 솔로 게임 화면 — Swift ContentView 이식.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.initialDifficulty = Difficulty.beginner, this.debugGame});

  final Difficulty initialDifficulty;

  /// 테스트에서 판을 직접 조작하려고 주입하는 모델(평소엔 null).
  @visibleForTesting
  final GameModel? debugGame;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameModel game = widget.debugGame ?? GameModel();
  final TransformationController _zoom = TransformationController();
  Size _boardViewport = Size.zero;
  bool flagMode = false;
  bool probing = false;
  bool showLossPopup = false;
  bool showWinPopup = false;
  int? winRank;
  bool rankLoading = false;
  String? coinToast;
  GameState _lastState = GameState.ready;
  SoloWinResult? _lastWin;
  Map<String, dynamic>? pendingResume; // 앱 종료 후 복원할 진행 판(이어서/새로 선택 대기)

  static const contentMaxWidth = 460.0;

  bool get _boardZoomed => _zoom.value.getMaxScaleOnAxis() > 1.02;

  @override
  void initState() {
    super.initState();
    final inv = LocalStore.shared;
    game.autoFlagSupplier = () => inv.ownedFlags;
    game.onConsumeAutoFlag = inv.consumeFlag;
    game.radarSupplier = () => inv.ownedRadars;
    game.onConsumeRadar = inv.consumeRadar;
    game.onGoldenMineFound = () {
      inv.awardGoldenMine();
      Daily.bump(DailyKind.golden);
      announceAchievements();
      Haptics.success();
      final msg = '💰 황금지뢰 발견! +${LocalStore.goldenMineReward} 코인';
      setState(() => coinToast = msg);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && coinToast == msg) setState(() => coinToast = null);
      });
    };
    game.onSoloWin = (d, timeSec, noItem) {
      final isBest = inv.recordSolo(d, timeSec);
      inv.awardClearReward(d);
      if (noItem) inv.recordNoItemHardClear(d);
      Daily.bump(DailyKind.clears);
      announceAchievements();
      if (isBest) {
        RankingService().submitBest(ScoreEntry(
          name: inv.nickname,
          difficulty: d.label,
          timeSec: timeSec,
          deviceId: inv.deviceId,
          title: inv.equippedTitleName,
        ));
      }
      game.soloWinResult = SoloWinResult(d, timeSec, isBest);
    };
    game.addListener(_onGameChanged);
    _zoom.addListener(() => setState(() {}));
    WidgetsBinding.instance.addObserver(this);
    // 저장된 진행 판이 있으면 자동 시작하지 않고 이어서/새로 선택을 받는다.
    pendingResume = inv.loadSoloResume();
    game.startSolo(widget.initialDifficulty);
    setAppOrientationFor(widget.initialDifficulty);
  }

  // 백그라운드로 갈 때 진행 중 솔로 판을 저장 → 앱을 완전히 꺼도 복원.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      final snap = game.makeResumeSnapshot();
      if (snap != null) LocalStore.shared.saveSoloResume(snap);
    }
  }

  void _onGameChanged() {
    if (game.state != _lastState) {
      final s = game.state;
      _lastState = s;
      if (s != GameState.playing) probing = false;
      showLossPopup = s == GameState.lost;
      if (s == GameState.won) Haptics.success();
      if (s == GameState.lost) Haptics.error();
      if (s == GameState.won || s == GameState.lost) LocalStore.shared.clearSoloResume();
    }
    final w = game.soloWinResult;
    if (w != null && !identical(w, _lastWin)) {
      _lastWin = w;
      winRank = null;
      rankLoading = true;
      showWinPopup = true;
      final inv = LocalStore.shared;
      final best = inv.soloBest(w.difficulty) ?? w.timeSec;
      RankingService().onlineRank(w.difficulty, best, inv.deviceId).then((r) {
        if (!mounted) return;
        setState(() {
          winRank = r;
          rankLoading = false;
        });
      });
    }
    if (w == null) _lastWin = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    setAppOrientationFor(null);
    game.removeListener(_onGameChanged);
    _zoom.dispose();
    game.dispose();
    super.dispose();
  }

  void _restartGame() {
    setState(() => flagMode = false);
    game.resetCurrentGame();
  }

  void _startNewBoard() {
    setState(() => flagMode = false);
    game.newGame();
  }

  /// 홈으로 나가면 진행 중 판은 버린다(이어하기는 "앱 종료 후 복원"용).
  void _goHome() {
    Haptics.tap();
    LocalStore.shared.clearSoloResume();
    Navigator.of(context).pop();
  }

  void _resumeSaved() {
    final snap = pendingResume;
    if (snap == null) return;
    setState(() {
      flagMode = false;
      pendingResume = null;
    });
    game.restore(snap);
    _lastState = game.state;
    setAppOrientationFor(game.difficulty);
    LocalStore.shared.clearSoloResume();
  }

  void _discardSavedAndStartNew() {
    LocalStore.shared.clearSoloResume();
    setState(() => pendingResume = null);
    game.startSolo(widget.initialDifficulty);
  }

  void _handleProbe(int r, int c) {
    final used = game.useAutoFlag(r, c);
    setState(() => probing = false);
    if (used) {
      Haptics.success();
    } else {
      Haptics.tap();
    }
  }

  void _fireRadar() {
    if (game.useRadar()) Haptics.success();
  }

  void _toggleZoom() => BoardWidget.toggleZoom(_zoom, _boardViewport);

  bool get _itemUsesEdgeDrawer =>
      game.difficulty == Difficulty.expert || game.difficulty == Difficulty.ultimate;
  bool get _anyPopupShowing => showLossPopup || showWinPopup || pendingResume != null;
  bool get _isDense => game.difficulty == Difficulty.expert;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final mq = MediaQuery.of(context);
    final compact = mq.size.height < 500 && mq.size.width > mq.size.height;
    return Scaffold(
      backgroundColor: t.bg,
      body: ListenableBuilder(
        listenable: game,
        builder: (context, _) => Stack(
          children: [
            SafeArea(child: compact ? _compactLayout(t) : _standardLayout(t)),
            if (!_anyPopupShowing)
              Positioned(
                right: 0,
                bottom: _itemUsesEdgeDrawer
                    ? mq.padding.bottom + (compact ? 40 : 96)
                    : mq.padding.bottom,
                child: ItemDock(
                  autoFlagTickets: game.autoFlagTickets,
                  radarTickets: game.radarTickets,
                  hideRadarWhenEmpty: true,
                  soloHandle: true,
                  isPlaying: game.state == GameState.playing,
                  probing: probing,
                  usesEdgeDrawer: _itemUsesEdgeDrawer,
                  onProbingChanged: (v) => setState(() => probing = v),
                  onRadar: _fireRadar,
                ),
              ),
            if (coinToast != null)
              Positioned(
                top: mq.padding.top + 8,
                left: 0,
                right: 0,
                child: Center(child: toastCapsule(coinToast!)),
              ),
            if (showLossPopup) _lossPopup(t),
            if (showWinPopup) _winPopup(t),
            if (pendingResume != null) _resumePopup(t),
          ],
        ),
      ),
    );
  }

  // ── 레이아웃 ──
  Widget _standardLayout(AppTheme t) {
    final dense = _isDense;
    final gap = dense ? 6.0 : 12.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(dense ? 4 : 8, dense ? 4 : 10, dense ? 4 : 8, dense ? 6 : 14),
      child: Column(
        children: [
          _centered(_topBar(t)),
          SizedBox(height: gap),
          _centered(_header(t, dense)),
          SizedBox(height: gap),
          Expanded(child: _boardArea()),
          SizedBox(height: gap),
          _centered(_statusText(t)),
        ],
      ),
    );
  }

  Widget _centered(Widget child) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: contentMaxWidth), child: child));

  Widget _compactLayout(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Column(children: [
        _compactBar(t),
        const SizedBox(height: 5),
        Expanded(child: _boardArea()),
      ]),
    );
  }

  Widget _boardArea() => LayoutBuilder(builder: (context, c) {
        _boardViewport = Size(c.maxWidth, c.maxHeight);
        return BoardWidget(
          game: game,
          flagMode: flagMode,
          controller: _zoom,
          probing: probing,
          onProbe: _handleProbe,
        );
      });

  // ── 상단 바(홈 · 난이도 · ⋯) ──
  Widget _topBar(AppTheme t) {
    return Row(
      children: [
        Tap(
          onTap: _goHome,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 11),
            decoration: rr(9, t.fill),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(SF.chevronLeft, size: 15, color: t.textSecondary),
              const SizedBox(width: 4),
              Text('홈', style: sf(15, weight: W.semibold, color: t.textSecondary)),
            ]),
          ),
        ),
        Expanded(
          child: Text(game.difficulty.label,
              textAlign: TextAlign.center,
              style: sf(14, weight: W.bold, color: t.textSecondary)),
        ),
        Tap(
          onTap: () {
            Haptics.tap();
            _openCodeSheet();
          },
          child: Container(
            width: 38,
            height: 32,
            decoration: rr(9, t.fill),
            child: Icon(SF.ellipsis, size: 16, color: t.textSecondary),
          ),
        ),
      ],
    );
  }

  // ── 헤더(지뢰 카운터 · 얼굴 · 확대 · 깃발 · 타이머) ──
  Widget _header(AppTheme t, bool dense) {
    final gap = dense ? 8.0 : 12.0;
    return Row(
      children: [
        ledCounter(t, game.minesRemaining, dense: dense),
        const Spacer(),
        _faceButton(t, dense),
        SizedBox(width: gap),
        toggleSquare(t,
            icon: _boardZoomed ? SF.zoomOut : SF.zoomIn,
            on: _boardZoomed,
            onFill: accentBlue,
            onStroke: zoomStroke,
            w: dense ? 44 : 50,
            h: dense ? 36 : 50,
            iconSize: dense ? 16 : 20,
            onTap: _toggleZoom),
        SizedBox(width: gap),
        toggleSquare(t,
            icon: SF.flagFill,
            on: flagMode,
            onFill: flagRed,
            onStroke: flagRedStroke,
            w: dense ? 44 : 50,
            h: dense ? 36 : 50,
            iconSize: dense ? 16 : 22,
            glow: true,
            onTap: () => setState(() => flagMode = !flagMode)),
        const Spacer(),
        ledCounter(t, game.elapsed, dense: dense),
      ],
    );
  }

  String get _face => switch (game.state) {
        GameState.won => '😎',
        GameState.lost => '😵',
        _ => '🙂',
      };

  Widget _faceButton(AppTheme t, bool dense) => Tap(
        onTap: () {
          Haptics.tap();
          _restartGame();
        },
        child: Container(
          width: dense ? 44 : 56,
          height: dense ? 36 : 50,
          alignment: Alignment.center,
          decoration: rr(10, t.fillElevated, stroke: t.border),
          child: Text(_face, style: TextStyle(fontSize: dense ? 22 : 30, height: 1.0)),
        ),
      );

  // ── 얇은 헤더바(가로) ──
  Widget _compactBar(AppTheme t) {
    Widget small(IconData icon, VoidCallback onTap) => Tap(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 30,
            decoration: rr(8, t.fill),
            child: Icon(icon, size: 14, color: t.textSecondary),
          ),
        );
    return Row(children: [
      small(SF.chevronLeft, _goHome),
      const SizedBox(width: 7),
      ledCounter(t, game.minesRemaining, compact: true),
      const Spacer(),
      Tap(
        onTap: () {
          Haptics.tap();
          _restartGame();
        },
        child: Container(
          width: 42,
          height: 32,
          alignment: Alignment.center,
          decoration: rr(8, t.fillElevated, stroke: t.border),
          child: Text(_face, style: const TextStyle(fontSize: 20, height: 1.0)),
        ),
      ),
      const SizedBox(width: 7),
      toggleSquare(t,
          icon: SF.flagFill,
          on: flagMode,
          onFill: flagRed,
          onStroke: flagRedStroke,
          w: 40,
          h: 32,
          iconSize: 15,
          radius: 8,
          onTap: () => setState(() => flagMode = !flagMode)),
      const SizedBox(width: 7),
      toggleSquare(t,
          icon: _boardZoomed ? SF.zoomOut : SF.zoomIn,
          on: _boardZoomed,
          onFill: accentBlue,
          onStroke: zoomStroke,
          w: 40,
          h: 32,
          iconSize: 14,
          radius: 8,
          onTap: _toggleZoom),
      const Spacer(),
      ledCounter(t, game.elapsed, compact: true),
      const SizedBox(width: 7),
      small(SF.ellipsis, () {
        Haptics.tap();
        _openCodeSheet();
      }),
    ]);
  }

  // ── 하단 안내문구 ──
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
        style: sf(_isDense ? 11 : 13, weight: W.medium, color: t.textSecondary));
  }

  // ── 판 코드 시트 ──
  void _openCodeSheet() {
    showAppSheet<void>(
      context,
      (ctx) => BoardCodeSheet(
        code: game.boardCode,
        accent: accentBlue,
        onNewBoard: _startNewBoard,
        onLoad: (c) {
          final ok = game.loadCode(c);
          if (ok) {
            setState(() => flagMode = false);
            setAppOrientationFor(game.difficulty);
          }
          return ok;
        },
      ),
      full: false,
    );
  }

  // ── 팝업 ──
  Widget _popupCard(AppTheme t, {required List<Widget> children, Color? stroke, double strokeWidth = 1, List<BoxShadow>? shadow}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(26),
      margin: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stroke ?? t.fillElevated, width: strokeWidth),
        boxShadow: shadow,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _bigButton(String label,
      {IconData? icon, required Color fill, required Color fg, required VoidCallback onTap}) {
    return Tap(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: rr(12, fill),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 17, color: fg), const SizedBox(width: 6)],
          Text(label, style: sf(17, weight: W.semibold, color: fg)),
        ]),
      ),
    );
  }

  Widget _lossPopup(AppTheme t) {
    final canContinue = game.canContinue;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: _popupCard(t, children: [
            const Text('💥', style: TextStyle(fontSize: 54, height: 1.1)),
            const SizedBox(height: 14),
            Text('지뢰를 밟았어요!', style: sf(21, weight: W.bold, color: t.text)),
            const SizedBox(height: 14),
            Text(
                canContinue
                    ? '이어서 계속하거나, 새로운 판으로 다시 시작할 수 있어요.'
                    : '새로운 판으로 다시 시작할까요?',
                textAlign: TextAlign.center,
                style: sf(14, color: t.textSecondary)),
            if (canContinue) ...[
              const SizedBox(height: 20),
              _bigButton('이어하기',
                  icon: SF.uturnBackward,
                  fill: accentGreen,
                  fg: Colors.white, onTap: () {
                setState(() => showLossPopup = false);
                game.continueGame();
              }),
              const SizedBox(height: 14),
              Text('이어한 판은 최고기록·랭킹에 기록되지 않아요.',
                  textAlign: TextAlign.center, style: sf(11, color: t.textTertiary)),
            ],
            SizedBox(height: canContinue ? 14 : 20),
            _bigButton('새 판으로 다시',
                fill: flagRed, fg: Colors.white, onTap: _startNewBoard),
            const SizedBox(height: 14),
            Tap(
              onTap: () => setState(() => showLossPopup = false),
              child: Text('보드 보기',
                  style: sf(14, weight: W.medium, color: t.textSecondary)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _resumePopup(AppTheme t) {
    final snap = pendingResume!;
    final diffName = (snap['difficulty'] as String?) ?? '';
    final secs = (snap['elapsed'] as num?)?.toInt() ?? 0;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: _popupCard(t, children: [
            const Text('⏸️', style: TextStyle(fontSize: 50, height: 1.1)),
            const SizedBox(height: 14),
            Text('이어서 할까요?', style: sf(21, weight: W.bold, color: t.text)),
            const SizedBox(height: 14),
            Text('$diffName · $secs초까지 진행한 판이 있어요.',
                textAlign: TextAlign.center, style: sf(14, color: t.textSecondary)),
            const SizedBox(height: 20),
            _bigButton('이어서 하기',
                icon: SF.uturnBackward, fill: accentGreen, fg: Colors.white, onTap: _resumeSaved),
            const SizedBox(height: 14),
            _bigButton('새로 하기', fill: t.fillElevated, fg: t.text, onTap: _discardSavedAndStartNew),
          ]),
        ),
      ),
    );
  }

  String _winTime(int sec) =>
      sec < 60 ? '$sec초' : '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

  Widget _winPopup(AppTheme t) {
    final result = game.soloWinResult;
    final inv = LocalStore.shared;
    Widget rankRow;
    if (rankLoading) {
      rankRow = Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: popupGold)),
        const SizedBox(width: 7),
        Text('등수 집계 중…', style: sf(14, weight: W.semibold, color: t.textSecondary)),
      ]);
    } else if (winRank != null) {
      rankRow = Text('🏅 전체 $winRank등', style: sf(18, weight: W.heavy, color: popupGold));
    } else {
      rankRow = Text('전체 등수는 온라인 연결 시 표시돼요',
          textAlign: TextAlign.center, style: sf(12, color: t.textTertiary));
    }
    final best = result == null ? null : inv.soloBest(result.difficulty);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Stack(children: [
          const Positioned.fill(child: ConfettiView()),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 550),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Opacity(
                  opacity: v.clamp(0, 1),
                  child: Transform.scale(scale: 0.7 + 0.3 * v, child: child)),
              child: _popupCard(
                t,
                stroke: popupGold.withValues(alpha: 0.5),
                strokeWidth: 1.5,
                shadow: [BoxShadow(color: popupGold.withValues(alpha: 0.35), blurRadius: 52)],
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 54, height: 1.1)),
                  const SizedBox(height: 12),
                  Text('클리어!', style: sf(22, weight: W.heavy, color: t.text)),
                  const SizedBox(height: 12),
                  Text(_winTime(result?.timeSec ?? game.elapsed),
                      style: sf(40, weight: W.heavy, color: t.text, height: 1.1)),
                  const SizedBox(height: 12),
                  if (result?.isBest == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: popupGold,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [BoxShadow(color: popupGold.withValues(alpha: 0.7), blurRadius: 20)],
                      ),
                      child: Text('🏆 최고 기록 경신!',
                          style: sf(13, weight: W.bold, color: Colors.black)),
                    )
                  else if (best != null)
                    Text('내 최고 ${_winTime(best)}',
                        style: sf(13, weight: W.semibold, color: t.textSecondary)),
                  const SizedBox(height: 14),
                  SizedBox(height: 30, child: Center(child: rankRow)),
                  const SizedBox(height: 18),
                  _bigButton('한 번 더',
                      icon: SF.arrowClockwise,
                      fill: accentGreen,
                      fg: Colors.white, onTap: () {
                    setState(() => showWinPopup = false);
                    _startNewBoard();
                  }),
                  const SizedBox(height: 12),
                  _bigButton('홈으로',
                      icon: SF.houseFill,
                      fill: t.fillElevated,
                      fg: t.text, onTap: () {
                    setState(() => showWinPopup = false);
                    Navigator.of(context).pop();
                  }),
                  const SizedBox(height: 14),
                  Tap(
                    onTap: () => setState(() => showWinPopup = false),
                    child: Text('결과 보기',
                        style: sf(14, weight: W.medium, color: t.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 클리어 팝업 뒤로 쏟아지는 색종이 — Swift ConfettiView 이식.
class ConfettiView extends StatefulWidget {
  const ConfettiView({super.key, this.count = 70});
  final int count;

  @override
  State<ConfettiView> createState() => _ConfettiViewState();
}

class _Piece {
  _Piece(math.Random r)
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

class _ConfettiViewState extends State<ConfettiView> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 60))..forward();
  late final List<_Piece> _pieces =
      List.generate(widget.count, (_) => _Piece(math.Random()));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _ConfettiPainter(_pieces, _c.value * 60),
          size: Size.infinite,
        ),
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
      final t0 = time - p.delay;
      if (t0 < 0) continue;
      final phase = (t0 % p.duration) / p.duration;
      final eased = phase * phase; // easeIn
      final x = p.x * size.width + p.drift * eased;
      final y = -50 + (size.height + 100) * eased;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * eased * math.pi / 180);
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
  bool shouldRepaint(covariant _ConfettiPainter old) => old.time != time;
}

/// 판 코드(시드) 시트 — Swift BoardCodeSheet 이식.
class BoardCodeSheet extends StatefulWidget {
  const BoardCodeSheet(
      {super.key,
      required this.code,
      required this.accent,
      required this.onNewBoard,
      required this.onLoad});
  final String? code;
  final Color accent;
  final VoidCallback onNewBoard;
  final bool Function(String) onLoad;

  @override
  State<BoardCodeSheet> createState() => _BoardCodeSheetState();
}

class _BoardCodeSheetState extends State<BoardCodeSheet> {
  final _input = TextEditingController();
  bool _loadError = false;
  bool _copied = false;
  static const _err = Color.fromRGBO(255, 115, 115, 1);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _load() {
    final trimmed = _input.text.trim();
    if (trimmed.isEmpty) return;
    if (widget.onLoad(trimmed)) {
      Haptics.tap();
      Navigator.of(context).pop();
    } else {
      setState(() => _loadError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: math.max(360, mq.size.height * 0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            // 드래그 인디케이터
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 36,
              height: 5,
              decoration: rr(3, t.border),
            ),
            const SizedBox(height: 14),
            Text('판 코드', style: sf(18, weight: W.bold, color: t.text)),
            const SizedBox(height: 4),
            Text('코드를 공유하면 상대도 같은 판을 풀 수 있어요',
                textAlign: TextAlign.center, style: sf(12, color: t.textSecondary)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: rr(12, t.fill),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('이 판', style: sf(11, weight: W.semibold, color: t.textSecondary)),
                    const SizedBox(height: 2),
                    SelectableText(widget.code ?? '—',
                        style: sf(22, weight: W.bold, color: t.text, mono: true)),
                  ]),
                ),
                const SizedBox(width: 10),
                Tap(
                  onTap: widget.code == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: widget.code!));
                          Haptics.tap();
                          setState(() => _copied = true);
                        },
                  child: Container(
                    width: 44,
                    height: 38,
                    decoration: rr(9, _copied ? const Color.fromRGBO(51, 166, 89, 1) : t.fillElevated),
                    child: Icon(_copied ? SF.checkmark : SF.docOnDoc, size: 15, color: t.text),
                  ),
                ),
                const SizedBox(width: 10),
                Tap(
                  onTap: () {
                    Haptics.tap();
                    widget.onNewBoard();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 58,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: rr(9, widget.accent),
                    child: Text('새 판', style: sf(14, weight: W.semibold, color: Colors.white)),
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
                  decoration: rr(10, t.bg, stroke: _loadError ? _err : t.fillElevated),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: _input,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _load(),
                    onChanged: (_) => setState(() {}),
                    style: sf(15, color: t.text, mono: true),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '코드 입력 (예: I-3F8A2C)',
                      hintStyle: sf(15, color: t.textTertiary, mono: true),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Opacity(
                opacity: _input.text.trim().isEmpty ? 0.4 : 1,
                child: Tap(
                  onTap: _input.text.trim().isEmpty ? null : _load,
                  child: Container(
                    width: 78,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: rr(10, t.fillElevated),
                    child: Text('불러오기', style: sf(14, weight: W.semibold, color: t.text)),
                  ),
                ),
              ),
            ]),
            if (_loadError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('코드를 인식할 수 없어요. 예: I-3F8A2C',
                      style: sf(11, color: _err)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
