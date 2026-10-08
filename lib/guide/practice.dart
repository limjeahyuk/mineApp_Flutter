import 'package:flutter/material.dart';

import '../core/game_model.dart';
import '../core/haptics.dart';
import '../core/ui.dart';
import '../core/theme.dart';
import '../game/cell_view.dart';

// 게임별 연습 보드(온보딩) — Swift TutorialPracticeView/GameOnboarding 이식.
// 첫 진입 때 한 번 자동으로, 이후엔 모드 카드/탭의 ? 버튼으로 다시 볼 수 있다.

/// 연습 보드 좌표 (row, col).
typedef PPos = (int, int);

/// 한 단계에서 해야 할 행동 — 이 행동을 해야 다음 단계로 넘어간다.
enum PKind {
  tap, // 칸 열기 (지뢰면 일부러 밟아보기)
  flagMode, // 깃발 모드 켜기
  flag, // 깃발 꽂기
  chord, // 숫자 탭 = 주변 일괄 열기
  info, // 읽고 [다음]
}

class PStep {
  const PStep(this.kind, this.title, this.detail, {this.at, this.hint});
  final PKind kind;
  final String title;
  final String detail;
  final PPos? at; // tap/flag/chord 대상 칸
  final PPos? hint; // 근거가 되는 칸(테두리 표시)
}

/// 모드별 연습 보드 — 고정 보드 + 단계 목록. 규칙 차이(안개·프런티어·보물·파트너)는 옵션으로 켠다.
class PracticeScript {
  const PracticeScript({
    required this.emoji,
    required this.title,
    required this.rows,
    required this.cols,
    required this.mines,
    required this.steps,
    this.startOpen,
    this.treasure,
    this.partnerStart,
    this.partnerFlags = const {},
    this.megaphones = const {},
    this.frontierOnly = false,
    this.fogRadius,
    this.mineResetRadius,
  });
  final String emoji;
  final String title;
  final int rows;
  final int cols;
  final Set<PPos> mines;
  final List<PStep> steps;
  final PPos? startOpen; // 처음부터 열려 있는 내 출발점(보물찾기·닿기)
  final PPos? treasure; // 가운데 보물 — 열면 그 너머로 펼쳐지지 않는다
  final PPos? partnerStart; // 파트너가 이미 열어둔 영역의 출발점
  final Set<PPos> partnerFlags; // 파트너 깃발(주황)
  final Set<PPos> megaphones; // 확성기 칸
  final bool frontierOnly; // 내가 연 칸 옆만 열 수 있음(금색 테두리)
  final int? fogRadius; // 안개 — 내가 연 칸 기준 이 거리까지만 보임
  final int? mineResetRadius; // 지뢰를 밟으면 주변이 도로 닫힘(보물찾기)
}

// MARK: 모드별 스크립트

enum OnboardKind {
  solo,
  mine,
  treasure,
  touch;

  PracticeScript get script => switch (this) {
        OnboardKind.solo => PracticeScript(
            emoji: '🙂',
            title: '솔로',
            rows: 6,
            cols: 5,
            mines: _basicMines,
            steps: [
              ..._basicSteps,
              const PStep(PKind.info, '🎉 클리어!',
                  '지뢰가 아닌 칸을 모두 열면 승리예요. 더 많은 공식은 홈의 가이드에 있어요.'),
            ]),
        OnboardKind.mine => PracticeScript(
            emoji: '💣',
            title: '지뢰찾기 대전',
            rows: 6,
            cols: 5,
            mines: _basicMines,
            steps: [
              ..._basicSteps,
              const PStep(
                  PKind.info,
                  '같은 보드, 세 가지 승부',
                  '🏃 스피드: 안전한 칸을 먼저 다 열면 승리\n'
                      '⚔️ 지뢰 대결: 방금처럼 깃발로 맞힌 지뢰 +1, 틀린 깃발 −1\n'
                      '🤝 합동: 둘이 함께 열고, 누구든 지뢰를 밟으면 함께 패배'),
            ]),
        // 7×7 — 왼쪽 위 구석에서 출발해 가운데 💎까지. 지뢰를 일부러 밟아 '도로 닫힘'을 겪어 본다.
        OnboardKind.treasure => const PracticeScript(
            emoji: '💎',
            title: '보물찾기',
            rows: 7,
            cols: 7,
            mines: {(6, 0), (3, 4), (1, 4), (2, 2), (3, 2)},
            startOpen: (0, 0),
            treasure: (3, 3),
            frontierOnly: true,
            mineResetRadius: 2,
            steps: [
              PStep(PKind.tap, '열린 칸 옆만 열 수 있어요',
                  '내 출발 구석(왼쪽 위)은 처음부터 열려 있어요. 금색 테두리 칸(이미 연 칸 옆)만 열 수 있어요. 반짝이는 칸을 열어 길을 이어가세요.',
                  at: (6, 2)),
              PStep(PKind.tap, '지뢰를 밟으면? 일부러 밟아봐요',
                  '반짝이는 칸은 지뢰예요. 밟아도 게임오버는 아니니 눌러보세요!',
                  at: (6, 0)),
              PStep(PKind.tap, '주변이 도로 닫혔어요',
                  '지뢰를 밟으면 주변 5×5 칸이 다시 닫혀서 그만큼 시간을 잃어요. 반짝이는 칸을 열어 길을 다시 뚫으세요.',
                  at: (4, 0)),
              PStep(PKind.tap, '가운데 보물을 열어요',
                  '💎 보물 칸이 금색 테두리 안에 들어왔어요. 먼저 여는 사람이 승리!',
                  at: (3, 3)),
              PStep(PKind.info, '🎉 보물 발견!',
                  '온라인에선 상대가 반대편 구석에서 출발해요. 가운데로 갈수록 지뢰가 빽빽하고, 온라인에선 지뢰를 5번 밟으면 패배예요.'),
            ]),
        // 8×8 — 안개 속에서 오른쪽 위의 파트너 쪽으로 파 들어가, 파트너 칸과 맞닿으면 성공.
        OnboardKind.touch => const PracticeScript(
            emoji: '🤝',
            title: '너에게 닿기를',
            rows: 8,
            cols: 8,
            mines: {
              (1, 3), (2, 6), (3, 2), (4, 0), (4, 5), //
              (5, 4), (6, 6), (6, 7), (7, 2),
            },
            startOpen: (7, 0),
            partnerStart: (0, 7),
            partnerFlags: {(1, 3)},
            megaphones: {(3, 4)},
            frontierOnly: true,
            fogRadius: 2,
            steps: [
              PStep(PKind.tap, '안개 속에서 길 뚫기',
                  '내가 연 칸 주변만 보이고 나머지는 구름이에요. 파트너는 오른쪽 위 어딘가에 있어요. 반짝이는 칸을 열어 다가가세요.',
                  at: (5, 2)),
              PStep(PKind.tap, '숨은 확성기 찾기',
                  "반짝이는 칸을 열어보세요. 확성기 📣 칸을 열면 파트너 화면에 '여기서 울렸어요' 방향 화살표가 떠요.",
                  at: (3, 4)),
              PStep(PKind.tap, '주황색 = 파트너',
                  '안개 안에 파트너가 연 칸과 깃발(주황)이 보여요. 내 칸이 파트너 칸과 위·아래·옆으로 맞닿으면 만나요!',
                  at: (2, 4)),
              PStep(PKind.info, '🎉 만났어요!',
                  '둘 다 성공! 걸린 시간이 협동 랭킹에 올라가요. 지뢰를 밟으면 1.5초 멈추고 파트너 깃발 1개가 빠지니 조심하세요.'),
            ]),
      };

  // 6×5 기본 조작 보드 — (5,0) 탭 → 오른쪽 위만 닫힌 채 남는다.
  // (0,1)의 '1'이 가리키는 닫힌 칸은 (0,2)뿐 → 지뢰. 깃발 후 (1,3)의 '1'을 탭하면 남은 4칸이 열려 클리어.
  static const Set<PPos> _basicMines = {(0, 2), (3, 4)};

  static const List<PStep> _basicSteps = [
    PStep(PKind.tap, '칸을 탭해서 열어보세요',
        '반짝이는 칸을 탭하세요. 첫 칸은 절대 지뢰가 아니라서, 주변 빈 칸이 한꺼번에 열려요.',
        at: (5, 0)),
    PStep(PKind.flagMode, '깃발 모드를 켜보세요',
        "맨 위 '1' 주변에 닫힌 칸은 딱 하나뿐이에요. 그러니 그 칸이 지뢰! 위의 깃발 버튼을 눌러 깃발 모드를 켜세요.",
        hint: (0, 1)),
    PStep(PKind.flag, '지뢰 칸에 깃발을 꽂으세요',
        '반짝이는 칸을 탭하면 깃발이 꽂혀요. (깃발 모드를 끈 상태에선 길게 눌러도 꽂혀요.)',
        at: (0, 2), hint: (0, 1)),
    PStep(PKind.chord, '숫자를 탭해 한꺼번에 열기',
        "이 '1' 주변 지뢰는 이미 깃발로 찾았어요. 숫자를 탭하면 남은 닫힌 칸이 한 번에 열려요.",
        at: (1, 3)),
  ];
}

// MARK: 보드 규칙 (위젯과 분리 — 테스트 가능)

class PracticeBoard {
  PracticeBoard(this.s) : grid = _makeGrid(s, s.mines) {
    if (s.startOpen != null) flood(s.startOpen!);
    if (s.partnerStart != null) _floodPartner(s.partnerStart!);
  }

  final PracticeScript s;
  List<List<Cell>> grid;
  final Set<PPos> partner = {};

  Cell at(PPos p) => grid[p.$1][p.$2];
  bool inBounds(PPos p) => p.$1 >= 0 && p.$1 < s.rows && p.$2 >= 0 && p.$2 < s.cols;

  List<PPos> neighbors(PPos p) => [
        for (var dr = -1; dr <= 1; dr++)
          for (var dc = -1; dc <= 1; dc++)
            if ((dr != 0 || dc != 0) && inBounds((p.$1 + dr, p.$2 + dc)))
              (p.$1 + dr, p.$2 + dc),
      ];

  /// 내가 연 칸(파트너 칸 제외).
  bool isMine(PPos p) => at(p).isRevealed && !partner.contains(p);

  bool isVisible(PPos p) {
    final f = s.fogRadius;
    if (f == null) return true;
    for (var dr = -f; dr <= f; dr++) {
      for (var dc = -f; dc <= f; dc++) {
        final q = (p.$1 + dr, p.$2 + dc);
        if (inBounds(q) && isMine(q)) return true;
      }
    }
    return false;
  }

  bool isFrontier(PPos p) {
    final d = at(p);
    if (d.isRevealed || d.isFlagged || !isVisible(p)) return false;
    return neighbors(p).any(isMine);
  }

  void flood(PPos p) {
    final stack = [p];
    while (stack.isNotEmpty) {
      final q = stack.removeLast();
      final d = at(q);
      if (d.isRevealed || d.isFlagged || d.isMine) continue;
      d.isRevealed = true;
      if (d.adjacent == 0 && q != s.treasure) stack.addAll(neighbors(q));
    }
  }

  void chord(PPos p) {
    for (final n in neighbors(p)) {
      if (!at(n).isFlagged) flood(n);
    }
  }

  void explode(PPos p) => at(p)
    ..isRevealed = true
    ..exploded = true;

  /// 주변을 닫고 밟은 지뢰는 치운다(실제 게임의 재배치 대신 고정 결과) → 출발점과 끊긴 열린 칸도 닫는다.
  void resetAround(PPos p, int radius) {
    final fresh = _makeGrid(s, {...s.mines}..remove(p));
    final keep = <PPos>{};
    final stack = [s.startOpen ?? p];
    while (stack.isNotEmpty) {
      final q = stack.removeLast();
      final d = at(q);
      final outside = (q.$1 - p.$1).abs() > radius || (q.$2 - p.$2).abs() > radius;
      if (keep.contains(q) || !d.isRevealed || d.isMine || !outside) continue;
      keep.add(q);
      stack.addAll(neighbors(q));
    }
    for (final q in keep) {
      fresh[q.$1][q.$2].isRevealed = true;
    }
    grid = fresh;
  }

  void _floodPartner(PPos p) {
    final stack = [p];
    while (stack.isNotEmpty) {
      final q = stack.removeLast();
      final d = at(q);
      if (d.isRevealed || d.isMine) continue;
      d.isRevealed = true;
      partner.add(q);
      if (d.adjacent == 0) stack.addAll(neighbors(q));
    }
  }

  static List<List<Cell>> _makeGrid(PracticeScript s, Set<PPos> mines) => [
        for (var r = 0; r < s.rows; r++)
          [
            for (var c = 0; c < s.cols; c++)
              Cell(r * s.cols + c)
                ..isMine = mines.contains((r, c))
                ..adjacent = [
                  for (var dr = -1; dr <= 1; dr++)
                    for (var dc = -1; dc <= 1; dc++)
                      if ((dr != 0 || dc != 0) && mines.contains((r + dr, c + dc))) 1
                ].length,
          ],
      ];
}

// MARK: 진입 헬퍼

/// 게임 시작. 연습 보드는 자동으로 띄우지 않고 ? 버튼(openPractice)으로만 연다.
/// 원본 RootView.start: 큰 판(최고급)은 세로 기본 + 가로 허용. 게임 화면은 닫힐 때 세로로 되돌린다.
void pushGame(
  BuildContext context,
  Widget Function() game, {
  bool landscape = false,
  bool replace = false,
}) {
  final nav = Navigator.of(context);
  setAppOrientation(allowLandscape: landscape);
  // replace: 멀티 메뉴처럼 현재 화면을 게임으로 바꿔 넣는 경우(닫으면 홈으로).
  (replace ? nav.pushReplacement : nav.push)(fadeRoute((_) => game()));
}

/// ? 버튼 — 연습 보드만 풀스크린으로 열고, 끝나면 닫는다.
void openPractice(BuildContext context, OnboardKind kind) {
  presentFullScreen<void>(
      context,
      (ctx) => PracticeScreen(
            script: kind.script,
            finishTitle: '닫기',
            onFinish: () => Navigator.of(ctx).pop(),
          ));
}

/// 모드 카드/탭 모서리의 작은 ? 버튼.
class PracticeHelpButton extends StatelessWidget {
  const PracticeHelpButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Semantics(
      button: true,
      label: '연습해 보기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(5), // 누르기 쉽게 터치 영역을 넓힌다
          child: Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.fillElevated,
              shape: BoxShape.circle,
              border: Border.all(color: t.border),
            ),
            child: Text('?',
                style: TextStyle(
                    color: t.text, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}

// MARK: 연습 보드 화면

/// 연습 보드에서 단계별로 반짝이는 칸/버튼만 눌러보며 규칙을 익힌다.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.script,
    required this.finishTitle,
    required this.onFinish,
  });
  final PracticeScript script;

  /// 마지막 단계 버튼 문구 — 첫 진입이면 "실전 시작하기", ? 버튼이면 "닫기".
  final String finishTitle;
  final VoidCallback onFinish;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  late final PracticeBoard board = PracticeBoard(widget.script);
  late final AnimationController pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);
  int stepIndex = 0;
  bool flagMode = false;
  bool busy = false; // 지뢰 폭발 연출 중 입력 막기

  static const _gold = Color(0xFFF2C74D);
  static const _flagRed = Color(0xFFE64D3D);
  static const _fog = Color(0xFF94A1B8);

  PracticeScript get s => widget.script;
  PStep get step => s.steps[stepIndex];
  bool get isLast => stepIndex == s.steps.length - 1;
  bool get usesFlags => s.steps.any((x) => x.kind == PKind.flagMode);
  double get cellSize => (340 / s.cols).clamp(0, 50).toDouble();

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  void next() {
    if (isLast) {
      widget.onFinish();
    } else {
      setState(() => stepIndex++);
    }
  }

  void onReveal(PPos p) {
    if (busy || step.at != p) return;
    if (step.kind == PKind.tap) {
      Haptics.tap();
      if (board.at(p).isMine) {
        stepOnMine(p);
      } else {
        board.flood(p);
        next();
      }
    } else if (step.kind == PKind.chord) {
      Haptics.tap();
      board.chord(p);
      next();
    }
  }

  void onFlag(PPos p) {
    if (busy || step.kind != PKind.flag || step.at != p) return;
    Haptics.flagTap();
    board.at(p).isFlagged = true;
    next();
  }

  /// 일부러 밟아보기 — 터진 뒤, 보물찾기면 주변이 도로 닫힌다.
  void stepOnMine(PPos p) {
    Haptics.error();
    setState(() => board.explode(p));
    final radius = s.mineResetRadius;
    if (radius == null) {
      next();
      return;
    }
    busy = true;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        board.resetAround(p, radius);
        busy = false;
      });
      next();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('${s.emoji} ${s.title} 연습',
                          style: TextStyle(
                              color: t.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    ),
                    if (!isLast)
                      TextButton(
                        onPressed: widget.onFinish,
                        child: Text('건너뛰기',
                            style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  _instructionCard(t),
                  const SizedBox(height: 18),
                  if (usesFlags) ...[
                    _flagButton(t),
                    const SizedBox(height: 18),
                  ],
                  _board(t),
                  if (step.kind == PKind.info) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: next,
                        child: Text(isLast ? widget.finishTitle : '다음',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _instructionCard(AppTheme t) {
    return Container(
      width: double.infinity,
      // 안내 길이(2~4줄)가 달라도 보드가 위아래로 밀리지 않게 높이를 고정한다.
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: t.fill, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
          child: Text(isLast ? '✓' : '${stepIndex + 1}',
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step.title,
                style: TextStyle(
                    color: t.text, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(step.detail,
                style: TextStyle(color: t.textSecondary, fontSize: 14)),
          ]),
        ),
      ]),
    );
  }

  Widget _flagButton(AppTheme t) {
    return Semantics(
      button: true,
      label: flagMode ? '깃발 모드 켜짐' : '깃발 모드 꺼짐',
      child: GestureDetector(
        onTap: () {
          if (step.kind != PKind.flagMode && step.kind != PKind.flag) return;
          Haptics.tap();
          setState(() => flagMode = !flagMode);
          if (step.kind == PKind.flagMode && flagMode) next();
        },
        child: Stack(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: flagMode ? _flagRed : t.fillElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.flag,
                size: 26, color: flagMode ? Colors.white : t.textSecondary),
          ),
          if (step.kind == PKind.flagMode)
            Positioned.fill(child: _ring(12)),
        ]),
      ),
    );
  }

  Widget _board(AppTheme t) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: t.boardFrame, borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < s.rows; r++)
            Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < s.cols; c++)
                    Padding(
                      padding: EdgeInsets.only(left: c == 0 ? 0 : 2),
                      child: _cell(t, (r, c)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(AppTheme t, PPos p) {
    final d = board.at(p);
    final size = cellSize;
    final vis = board.isVisible(p);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        CellView(
          cell: d,
          gameEnded: false,
          flagMode: flagMode,
          size: size,
          onReveal: () => onReveal(p),
          onFlag: () => onFlag(p),
        ),
        Positioned.fill(child: IgnorePointer(child: _decoration(t, p, d))),
        // 안개 — 구름 너머는 보이지도, 만져지지도 않는다(탭을 막는다).
        if (!vis)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                  color: _fog, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        if (vis && step.at == p && step.kind != PKind.info)
          Positioned.fill(child: _ring(4)),
        if (step.hint == p)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  // ponytail: Flutter엔 점선 테두리가 없어 반투명 실선으로 대신한다.
                  border: Border.all(color: _gold.withValues(alpha: 0.8), width: 2),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  /// 모드별 칸 표시 — 보물·파트너 칸·확성기·파트너 깃발·프런티어(실제 게임과 같은 색).
  Widget _decoration(AppTheme t, PPos p, Cell d) {
    final unit = cellSize;
    final r = BorderRadius.circular(3);
    final layers = <Widget>[];
    if (p == s.treasure) {
      layers.addAll([
        Container(
            decoration: BoxDecoration(
                color: d.isRevealed ? t.cellRevealed : t.cellClosedTop,
                borderRadius: r)),
        Container(
            decoration: BoxDecoration(
                color: _gold.withValues(alpha: d.isRevealed ? 0.32 : 0.18),
                borderRadius: r)),
        Center(
            child: Opacity(
                opacity: d.isRevealed ? 1 : 0.5,
                child: Text('💎', style: TextStyle(fontSize: unit * 0.5)))),
      ]);
    } else if (d.isRevealed && s.megaphones.contains(p)) {
      layers.addAll([
        Container(
            decoration:
                BoxDecoration(color: t.cellRevealed, borderRadius: r)),
        Container(
            decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.30), borderRadius: r)),
        Center(child: Text('📣', style: TextStyle(fontSize: unit * 0.55))),
      ]);
    } else if (board.partner.contains(p)) {
      layers.add(Container(
          decoration: BoxDecoration(
              color: AppTheme.oppColor.withValues(alpha: 0.32),
              borderRadius: r)));
    } else if (!d.isRevealed && s.partnerFlags.contains(p)) {
      layers.add(Center(
          child: Icon(Icons.flag, size: unit * 0.55, color: AppTheme.oppColor)));
    }
    if (s.frontierOnly && !isLast && board.isFrontier(p)) {
      layers.add(Container(
          decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(
                  color: _gold.withValues(alpha: 0.9), width: 1.6))));
    }
    return Stack(fit: StackFit.expand, children: layers);
  }

  /// 지금 해야 할 칸/버튼 — 흰 테두리 + 금빛 채움이 숨 쉬듯 반짝인다(금색 프런티어 테두리와 구분).
  Widget _ring(double radius) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, _) => Container(
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.08 + 0.27 * pulse.value),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              // outer — 반투명 채움 아래로 그림자가 비쳐 칸이 금색으로 꽉 차 보이지 않게.
              BoxShadow(
                  color: _gold,
                  blurRadius: 3 + 7 * pulse.value,
                  blurStyle: BlurStyle.outer),
            ],
          ),
        ),
      ),
    );
  }
}
