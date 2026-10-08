import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_model.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import '../ranking/ranking_service.dart';
import 'board_widget.dart';
import 'confetti.dart';
import 'item_dock.dart';

/// 솔로 게임 화면 — Swift ContentView 이식.
/// 상단 바(홈·난이도·⋯) + 헤더(지뢰 카운터·얼굴·타이머) + 보드 + 안내문구 + 떠 있는 깃발 버튼.
/// 가로(최고급)면 얇은 헤더바 한 줄 + 꽉 찬 보드. 패배/클리어/이어하기 팝업, 판 코드 시트.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.initialDifficulty = Difficulty.beginner});

  final Difficulty initialDifficulty;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final GameModel game = GameModel();
  final LocalStore _s = LocalStore.shared;
  final _coinToast = ToastController();

  bool flagMode = false; // 깃발 모드: 탭=깃발, 길게=칸 열기
  Offset? _flagPos; // 떠 있는 깃발 버튼 위치(드래그로 이동, null=기본 우하단)
  bool _flagDocked = false; // 오른쪽 가장자리 손잡이로 접힘
  bool _flagDragging = false; // 드래그 중엔 위치 애니메이션 끔
  Offset _flagDrag = Offset.zero; // 이번 드래그 누적 이동량(오른쪽 스와이프 판정)
  bool probing = false; // 자동깃발 발동 대기
  bool showLossPopup = false;
  bool showWinPopup = false;
  int? winRank; // 클리어 시 전체 등수(로딩 중·오프라인이면 null)
  bool rankLoading = false;
  Map<String, dynamic>? pendingResume; // 이어하기 제안 대기(앱 종료 후 복원)

  GameState _lastState = GameState.ready;
  SoloWinResult? _lastWin;
  Difficulty _lastDifficulty = Difficulty.beginner;

  static const _contentMaxWidth = 460.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game.onSoloWin = (d, time, noItem) {
      final isBest = _s.recordSolo(d, time);
      if (isBest) {
        RankingService().submitBest(ScoreEntry(
          name: _s.nickname,
          difficulty: d.label,
          timeSec: time,
          deviceId: _s.deviceId,
          title: _s.equippedTitleName,
        ));
      }
      _s.awardClearReward(d); // 솔로 클리어 코인 보상
      // 아이템을 하나도 안 쓰고 고급·최고급을 깼으면 '무결점' 칭호 판정.
      if (noItem) _s.recordNoItemHardClear(d);
      game.soloWinResult = SoloWinResult(d, time, isBest);
    };
    // 황금지뢰를 깃발로 발견하면 코인을 지급하고 상단에 잠깐 안내한다.
    game.onGoldenMineFound = () {
      _s.awardGoldenMine();
      Haptics.success();
      _coinToast.show('💰 황금지뢰 발견! +${LocalStore.goldenMineReward} 코인');
    };
    // 자동깃발·레이더: 보유 인벤토리에서 채우고, 쓸 때마다 인벤토리에서 영구 차감한다.
    // (startSolo가 티켓을 계산하므로 그 전에 연결)
    game.autoFlagSupplier = () => _s.ownedFlags;
    game.onConsumeAutoFlag = () => _s.consumeFlag();
    game.radarSupplier = () => _s.ownedRadars;
    game.onConsumeRadar = () => _s.consumeRadar();
    game.addListener(_onGameChanged);

    // 저장된 진행 판이 있으면 자동 시작하지 않고 이어/새로 선택을 받는다.
    final snapJson = _s.soloResumeJson;
    Map<String, dynamic>? snap;
    if (snapJson != null) {
      try {
        snap = jsonDecode(snapJson) as Map<String, dynamic>;
      } catch (_) {}
    }
    if (snap != null) {
      pendingResume = snap;
    } else {
      game.startSolo(widget.initialDifficulty);
    }
    _lastState = game.state;
    _lastDifficulty = game.difficulty;
    setAppOrientation(allowLandscape: game.difficulty.prefersLandscape);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.removeListener(_onGameChanged);
    game.dispose();
    _coinToast.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드로 갈 때 진행 중 솔로 판을 저장 → 앱을 완전히 꺼도 복원 가능.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final snap = game.makeResumeSnapshot();
      if (snap != null) _s.saveSoloResume(jsonEncode(snap));
    }
  }

  void _onGameChanged() {
    final st = game.state;
    if (st != _lastState) {
      _lastState = st;
      if (st != GameState.playing) probing = false; // 끝/리셋되면 아이템 발동 해제
      showLossPopup = st == GameState.lost;
      if (st == GameState.won) {
        Haptics.success();
        _s.clearSoloResume();
      } else if (st == GameState.lost) {
        Haptics.error();
        _s.clearSoloResume();
      }
    }
    final win = game.soloWinResult;
    if (win != null && !identical(win, _lastWin)) {
      _lastWin = win;
      // 기록되는 솔로 클리어에서만 채워진다 → 결과 팝업 + 등수 조회.
      winRank = null;
      rankLoading = true;
      showWinPopup = true;
      RankingService().onlineRank(win.difficulty).then((rank) {
        if (!mounted) return;
        setState(() {
          winRank = rank;
          rankLoading = false;
        });
      });
    } else if (win == null) {
      _lastWin = null;
    }
    if (game.difficulty != _lastDifficulty) {
      // 코드 불러오기로 난이도가 바뀌면 방향도 맞춘다.
      _lastDifficulty = game.difficulty;
      setAppOrientation(allowLandscape: game.difficulty.prefersLandscape);
    }
  }

  /// 같은 판 재시작 — 깃발 모드는 꺼진 상태로.
  void _restartGame() {
    setState(() => flagMode = false);
    game.resetCurrentGame();
  }

  /// 새 판 생성 — 깃발 모드를 끈 상태로.
  void _startNewBoard() {
    setState(() => flagMode = false);
    game.newGame();
  }

  /// 홈으로 — 진행 중 판은 버린다(이어하기는 앱 종료 후 복원용).
  void _goHome() {
    Haptics.tap();
    _s.clearSoloResume();
    setAppOrientation();
    Navigator.of(context).pop();
  }

  bool get _anyPopupShowing =>
      showLossPopup || showWinPopup || pendingResume != null;

  bool _isCompact(BuildContext c) {
    final size = MediaQuery.of(c).size;
    return size.width > size.height && size.height < 500;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            final compact = _isCompact(context);
            return Stack(
              fit: StackFit.expand,
              children: [
                SafeArea(
                  child: compact ? _compactLayout(t) : _standardLayout(t),
                ),
                if (!_anyPopupShowing)
                  SafeArea(
                    child: Stack(
                      children: [
                        _floatingFlag(t),
                        ItemDock(
                          solo: true,
                          tickets: game.autoFlagTickets,
                          isPlaying: game.state == GameState.playing,
                          drawerBottomPadding: compact
                              ? 130
                              : 150, // 아래 깃발 버튼(기본 우하단)과 안 겹치게
                          probing: probing,
                          onProbingChanged: (v) => setState(() => probing = v),
                          radarTickets: game.radarTickets,
                          onRadar: _fireRadar,
                        ),
                      ],
                    ),
                  ),
                if (showLossPopup) _lossPopup(t),
                if (showWinPopup) _winPopup(t),
                if (pendingResume != null) _resumePopup(t),
                ToastOverlay(
                  controller: _coinToast,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 8),
                  fontSize: 14,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // MARK: 레이아웃

  bool get _dense => game.difficulty == Difficulty.expert;

  Widget _standardLayout(AppTheme t) {
    final dense = _dense;
    final gap = dense ? 6.0 : 12.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          dense ? 4 : 8, dense ? 4 : 10, dense ? 4 : 8, dense ? 6 : 14),
      child: Column(
        children: [
          _constrained(_topBar(t)),
          SizedBox(height: gap),
          _constrained(_header(t)),
          SizedBox(height: gap),
          Expanded(child: _boardArea()),
          SizedBox(height: gap),
          _constrained(_statusText(t)),
        ],
      ),
    );
  }

  Widget _constrained(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: child,
        ),
      );

  Widget _compactLayout(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Column(
        children: [
          _compactBar(t),
          const SizedBox(height: 5),
          Expanded(child: _boardArea()),
        ],
      ),
    );
  }

  Widget _boardArea() => BoardWidget(
    game: game,
    flagMode: flagMode,
    probing: probing,
    onProbe: _handleProbe,
  );

  // MARK: 상단 바 (홈 버튼 + 난이도 + ⋯ 메뉴)

  Widget _topBar(AppTheme t) {
    return Row(
      children: [
        PlainButton(
          onTap: _goHome,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(9)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chevron_left, size: 18, color: t.textSecondary),
              Text('홈',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const Spacer(),
        Text(game.difficulty.label,
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const Spacer(),
        PlainButton(
          onTap: () {
            Haptics.tap();
            _openCodeSheet();
          },
          child: Container(
            width: 38,
            height: 32,
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(9)),
            child: Icon(Icons.more_horiz, size: 20, color: t.textSecondary),
          ),
        ),
      ],
    );
  }

  // MARK: 헤더 (지뢰 카운터 / 얼굴 / 타이머)

  Widget _header(AppTheme t) {
    final dense = _dense;
    return Row(
      children: [
        _counter(t, game.minesRemaining, dense: dense),
        const Spacer(),
        _faceButton(t, dense: dense),
        const Spacer(),
        _counter(t, game.elapsed, dense: dense, timer: true),
      ],
    );
  }

  String get _face => switch (game.state) {
        GameState.won => '😎',
        GameState.lost => '😵',
        _ => '🙂',
      };

  static String _fmt3(int v) {
    final n = v.clamp(-99, 999);
    return n < 0
        ? '-${(-n).toString().padLeft(2, '0')}'
        : n.toString().padLeft(3, '0');
  }

  Widget _counter(
    AppTheme t,
    int value, {
    bool dense = false,
    bool timer = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 12, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.fillElevated),
      ),
      child: Text(
        timer ? game.difficulty.formatTimer(value) : _fmt3(value),
        style: TextStyle(
          color: AppTheme.ledRed,
          fontSize: dense ? 18 : 26,
          fontWeight: FontWeight.bold,
          fontFamily: 'Menlo',
          fontFamilyFallback: const ['Courier', 'monospace'],
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _faceButton(AppTheme t, {bool dense = false}) {
    return PlainButton(
      onTap: () {
        Haptics.tap();
        _restartGame();
      },
      child: Container(
        width: dense ? 44 : 56,
        height: dense ? 36 : 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.fillElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.border),
        ),
        child: Text(_face, style: TextStyle(fontSize: dense ? 20 : 27)),
      ),
    );
  }

  static const _flagOnStroke = Color.fromRGBO(255, 140, 115, 1);
  static const _flagSize = 56.0;

  /// 떠 있는 원형 깃발 버튼 — 탭=깃발 모드 토글, 드래그=위치 이동.
  /// 오른쪽으로 끌면 오른쪽 가장자리 손잡이로 쏙 들어가고(색=깃발 모드 상태), 손잡이를 탭하면 다시 나온다.
  Widget _floatingFlag(AppTheme t) {
    const handleW = 26.0;
    return LayoutBuilder(
      builder: (context, box) {
        final max = Offset(box.maxWidth - _flagSize, box.maxHeight - _flagSize);
        final pos = _flagPos ?? Offset(max.dx - 16, max.dy - 60);
        final y = pos.dy.clamp(0, max.dy).toDouble();
        final onFill = flagMode ? AppTheme.dangerRed : t.fillElevated;
        final onBorder = flagMode ? _flagOnStroke : t.border;
        final onIcon = flagMode ? Colors.white : t.textSecondary;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: _flagDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: _flagDocked ? box.maxWidth - handleW : pos.dx,
              top: y,
              child: _flagDocked
                  ? GestureDetector(
                      onTap: () {
                        Haptics.tap();
                        setState(() {
                          _flagDocked = false;
                          _flagPos = Offset(max.dx - 16, y);
                        });
                      },
                      onVerticalDragUpdate: (d) => setState(
                        () => _flagPos = Offset(
                          pos.dx,
                          (y + d.delta.dy).clamp(0, max.dy),
                        ),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: handleW,
                        height: _flagSize,
                        decoration: BoxDecoration(
                          color: onFill,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(12),
                          ),
                          border: Border.all(color: onBorder, width: 1.5),
                        ),
                        child: Icon(Icons.flag, size: 15, color: onIcon),
                      ),
                    )
                  // 기본 드래그 시작 거리(36pt)는 짧은 스와이프를 놓쳐서 줄인다.
                  : MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        gestureSettings: const DeviceGestureSettings(
                          touchSlop: 6,
                        ),
                      ),
                      child: GestureDetector(
                        onPanStart: (_) => setState(() {
                          _flagDragging = true;
                          _flagDrag = Offset.zero;
                        }),
                        onPanUpdate: (d) => setState(() {
                          _flagDrag += d.delta;
                          final p = pos + d.delta;
                          _flagPos = Offset(
                            p.dx.clamp(0, max.dx).toDouble(),
                            p.dy.clamp(0, max.dy).toDouble(),
                          );
                        }),
                        // 오른쪽으로 끈 드래그(가로 우세)면 손잡이로 접는다.
                        onPanEnd: (d) => setState(() {
                          _flagDragging = false;
                          if (_flagDrag.dx > 24 &&
                              _flagDrag.dx > _flagDrag.dy.abs()) {
                            _flagDocked = true;
                          }
                        }),
                        child: PlainButton(
                          onTap: () {
                            Haptics.tap();
                            setState(() => flagMode = !flagMode);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: _flagSize,
                            height: _flagSize,
                            decoration: BoxDecoration(
                              color: onFill,
                              shape: BoxShape.circle,
                              border: Border.all(color: onBorder, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (flagMode
                                              ? AppTheme.dangerRed
                                              : Colors.black)
                                          .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(Icons.flag, size: 27, color: onIcon),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // MARK: 얇은 헤더바 (가로 전용)

  Widget _compactBar(AppTheme t) {
    Widget smallCounter(int v, {bool timer = false}) => Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: t.fillElevated),
      ),
      child: Text(
        timer ? game.difficulty.formatTimer(v) : _fmt3(v),
        style: const TextStyle(
          color: AppTheme.ledRed,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Menlo',
          fontFamilyFallback: ['Courier', 'monospace'],
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
    Widget square(IconData icon, VoidCallback onTap) => PlainButton(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 30,
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: t.textSecondary),
          ),
        );
    return Row(
      children: [
        square(Icons.chevron_left, _goHome),
        const SizedBox(width: 7),
        smallCounter(game.minesRemaining),
        const Spacer(),
        PlainButton(
          onTap: () {
            Haptics.tap();
            _restartGame();
          },
          child: Container(
            width: 42,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.fillElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border),
            ),
            child: Text(_face, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const Spacer(),
        smallCounter(game.elapsed, timer: true),
        const SizedBox(width: 7),
        square(Icons.more_horiz, () {
          Haptics.tap();
          _openCodeSheet();
        }),
      ],
    );
  }

  // MARK: 안내 문구

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

  // MARK: 아이템

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

  // MARK: 판 코드 시트

  void _openCodeSheet() {
    presentMediumSheet<void>(
      context,
      (ctx) => _BoardCodeSheet(
        code: game.boardCode,
        onNewBoard: _startNewBoard,
        onLoad: (code) {
          final ok = game.loadCode(code);
          if (ok) setState(() => flagMode = false);
          return ok;
        },
      ),
    );
  }

  // MARK: 팝업 공통

  Widget _popupFrame(AppTheme t,
      {required Widget child, Color? stroke, double strokeWidth = 1, List<BoxShadow>? shadow}) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(36),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: t.fill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: stroke ?? t.fillElevated, width: strokeWidth),
              boxShadow: shadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _bigButton(AppTheme t,
      {required String label,
      IconData? icon,
      required Color fill,
      Color fg = Colors.white,
      required VoidCallback onTap}) {
    return PlainButton(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Container(
        height: 50,
        decoration:
            BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    color: fg, fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _textLink(AppTheme t, String label, VoidCallback onTap) => PlainButton(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(label,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ),
      );

  // MARK: 이어하기 팝업 (앱 종료 후 복원)

  Widget _resumePopup(AppTheme t) {
    final snap = pendingResume!;
    final diffName =
        Difficulty.fromLabel((snap['difficulty'] as String?) ?? '')?.label ??
            '';
    final secs = (snap['elapsed'] as num?)?.toInt() ?? 0;
    return _popupFrame(
      t,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⏸️', style: TextStyle(fontSize: 50)),
          const SizedBox(height: 14),
          Text('이어서 할까요?',
              style: TextStyle(
                  color: t.text, fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Text('$diffName · $secs초까지 진행한 판이 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          _bigButton(t,
              label: '이어서 하기',
              icon: Icons.undo,
              fill: AppTheme.accentGreen, onTap: () {
            setState(() => flagMode = false);
            game.restore(snap);
            setAppOrientation(
                allowLandscape: game.difficulty.prefersLandscape);
            _s.clearSoloResume(); // 복원으로 소비 — 다음 백그라운드에서 다시 저장된다
            setState(() => pendingResume = null);
          }),
          const SizedBox(height: 14),
          _bigButton(t,
              label: '새로 하기',
              fill: t.fillElevated,
              fg: t.text, onTap: () {
            _s.clearSoloResume();
            setState(() => pendingResume = null);
            game.startSolo(widget.initialDifficulty);
          }),
        ],
      ),
    );
  }

  // MARK: 패배 팝업 (재시도)

  Widget _lossPopup(AppTheme t) {
    final canContinue = game.canContinue;
    return _popupFrame(
      t,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💥', style: TextStyle(fontSize: 54)),
          const SizedBox(height: 14),
          Text('지뢰를 밟았어요!',
              style: TextStyle(
                  color: t.text, fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Text(
              canContinue
                  ? '이어서 계속하거나, 새로운 판으로 다시 시작할 수 있어요.'
                  : '새로운 판으로 다시 시작할까요?',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          if (canContinue) ...[
            _bigButton(t,
                label: '이어하기',
                icon: Icons.undo,
                fill: AppTheme.accentGreen, onTap: () {
              setState(() => showLossPopup = false);
              game.continueGame();
            }),
            const SizedBox(height: 14),
            Text('이어한 판은 최고기록·랭킹에 기록되지 않아요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textTertiary, fontSize: 11)),
            const SizedBox(height: 14),
          ],
          _bigButton(t,
              label: '새 판으로 다시',
              fill: AppTheme.dangerRed,
              onTap: _startNewBoard),
          const SizedBox(height: 14),
          _textLink(t, '보드 보기', () => setState(() => showLossPopup = false)),
        ],
      ),
    );
  }

  // MARK: 클리어 팝업 (기록 + 등수 + 다시하기/홈)

  Widget _winPopup(AppTheme t) {
    final result = game.soloWinResult;
    const gold = AppTheme.gold;
    final best =
        result == null ? null : _s.soloBest(result.difficulty);
    return Stack(
      children: [
        Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.6))),
        const Positioned.fill(child: ConfettiView()),
        Positioned.fill(
          child: _WinCardAnimator(
            child: _popupFrameNoDim(
              t,
              stroke: gold.withValues(alpha: 0.5),
              strokeWidth: 1.5,
              shadow: [
                BoxShadow(color: gold.withValues(alpha: 0.35), blurRadius: 26)
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BounceEmoji('🎉'),
                  const SizedBox(height: 12),
                  Text('클리어!',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text(timeLabel(result?.timeSec ?? game.elapsed),
                      style: TextStyle(
                          color: t.text,
                          fontSize: 40,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  if (result?.isBest == true)
                    const _PulsingBestBadge()
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
                      child: rankLoading
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: gold)),
                              const SizedBox(width: 7),
                              Text('등수 집계 중…',
                                  style: TextStyle(
                                      color: t.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ])
                          : winRank != null
                              ? Text('🏅 전체 $winRank등',
                                  style: const TextStyle(
                                      color: gold,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900))
                              : Text('전체 등수는 온라인 연결 시 표시돼요',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: t.textTertiary, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _bigButton(t,
                      label: '한 번 더',
                      icon: Icons.refresh,
                      fill: AppTheme.accentGreen, onTap: () {
                    setState(() => showWinPopup = false);
                    _startNewBoard();
                  }),
                  const SizedBox(height: 12),
                  _bigButton(t,
                      label: '홈으로',
                      icon: Icons.home,
                      fill: t.fillElevated,
                      fg: t.text, onTap: () {
                    showWinPopup = false;
                    _s.clearSoloResume();
                    setAppOrientation();
                    Navigator.of(context).pop();
                  }),
                  const SizedBox(height: 14),
                  _textLink(t, '결과 보기',
                      () => setState(() => showWinPopup = false)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _popupFrameNoDim(AppTheme t,
      {required Widget child,
      Color? stroke,
      double strokeWidth = 1,
      List<BoxShadow>? shadow}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: t.fill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: stroke ?? t.fillElevated, width: strokeWidth),
                boxShadow: shadow,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 카드가 통통 튀며 등장(0.7 → 1 스프링 오버슈트 + 페이드).
class _WinCardAnimator extends StatefulWidget {
  const _WinCardAnimator({required this.child});
  final Widget child;

  @override
  State<_WinCardAnimator> createState() => _WinCardAnimatorState();
}

class _WinCardAnimatorState extends State<_WinCardAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut));
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: const Interval(0, 0.4)),
      child: ScaleTransition(scale: scale, child: widget.child),
    );
  }
}

/// 이모지는 카드보다 살짝 늦게 통통 튀어 오른다.
class _BounceEmoji extends StatefulWidget {
  const _BounceEmoji(this.emoji);
  final String emoji;

  @override
  State<_BounceEmoji> createState() => _BounceEmojiState();
}

class _BounceEmojiState extends State<_BounceEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    return AnimatedBuilder(
      animation: a,
      builder: (_, child) => Transform.rotate(
        angle: (1 - a.value) * -0.52,
        child: Transform.scale(scale: 0.2 + 0.8 * a.value, child: child),
      ),
      child: Text(widget.emoji, style: const TextStyle(fontSize: 54)),
    );
  }
}

/// "🏆 최고 기록 경신!" — 금색 캡슐이 은은하게 숨 쉰다.
class _PulsingBestBadge extends StatefulWidget {
  const _PulsingBestBadge();

  @override
  State<_PulsingBestBadge> createState() => _PulsingBestBadgeState();
}

class _PulsingBestBadgeState extends State<_PulsingBestBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = AppTheme.gold;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final v = Curves.easeInOut.transform(_c.value);
        return Transform.scale(
          scale: 0.9 + 0.1 * v,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(color: gold.withValues(alpha: 0.7 * v), blurRadius: 10)
              ],
            ),
            child: const Text('🏆 최고 기록 경신!',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}

/// 판 코드(시드) 시트 — 현재 판 코드를 복사하거나, 코드를 입력해 같은 판을 불러온다.
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
  bool _loadError = false;
  bool _copied = false;

  static const _errorColor = Color.fromRGBO(255, 115, 115, 1);

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _copy() {
    final code = widget.code;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    Haptics.tap();
    setState(() => _copied = true);
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
    final empty = _input.text.trim().isEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text('판 코드',
              style: TextStyle(
                  color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('코드를 공유하면 상대도 같은 판을 풀 수 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, fontSize: 12)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              fontFamily: 'Menlo',
                              fontFamilyFallback: const ['Courier', 'monospace'])),
                    ],
                  ),
                ),
                PlainButton(
                  onTap: widget.code == null ? null : _copy,
                  child: Container(
                    width: 44,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _copied
                          ? const Color.fromRGBO(51, 166, 89, 1)
                          : t.fillElevated,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(_copied ? Icons.check : Icons.copy,
                        size: 17, color: t.text),
                  ),
                ),
                const SizedBox(width: 10),
                PlainButton(
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
                        color: AppTheme.accentBlue,
                        borderRadius: BorderRadius.circular(9)),
                    child: const Text('새 판',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _input,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _load(),
                    style: TextStyle(
                        color: t.text,
                        fontSize: 15,
                        fontFamily: 'Menlo',
                        fontFamilyFallback: const ['Courier', 'monospace']),
                    decoration: InputDecoration(
                      hintText: '코드 입력 (예: I-3F8A2C)',
                      hintStyle: TextStyle(color: t.textTertiary),
                      filled: true,
                      fillColor: t.bg,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: _loadError ? _errorColor : t.fillElevated),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: _loadError ? _errorColor : t.fillElevated),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PlainButton(
                onTap: empty ? null : _load,
                child: Opacity(
                  opacity: empty ? 0.5 : 1,
                  child: Container(
                    width: 78,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: t.fillElevated,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('불러오기',
                        style: TextStyle(
                            color: t.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
          if (_loadError)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('코드를 인식할 수 없어요. 예: I-3F8A2C',
                    style: const TextStyle(color: _errorColor, fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }
}
