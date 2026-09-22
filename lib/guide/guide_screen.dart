import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme.dart';

/// 가이드 화면 — Swift TutorialView 이식. 상단 탭 3개:
/// 튜토리얼(기초 조작·화면 버튼) / 공략(자주 나오는 패턴) / 멀티(대전·협동 규칙).
/// 순수 정적 콘텐츠(로직 없음). 스와이프로도 탭 전환.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _page = PageController();
  int _tab = 0;
  static const _tabs = ['튜토리얼', '공략', '멀티'];
  static const _accent = Color(0xFF408CF2); // (0.25,0.55,0.95)
  static const _mineRed = Color(0xFFEB5757); // (0.92,0.34,0.34)
  static const _safeGreen = Color(0xFF4DC77A); // (0.30,0.78,0.48)
  static const _gold = Color(0xFFF2C74D); // (0.95,0.78,0.30)

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _goTab(int i) {
    Haptics.tap();
    setState(() => _tab = i);
    _page.animateToPage(i,
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(t),
            _tabBar(t),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _tab = i),
                children: [
                  _tabPage(_basicsTab(t)),
                  _tabPage(_patternsTab(t)),
                  _tabPage(_multiTab(t)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppTheme t) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
        child: Row(
          children: [
            Material(
              color: t.fill,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.close, color: t.textSecondary, size: 20)),
              ),
            ),
            Expanded(
              child: Text('가이드',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.text, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 40),
          ],
        ),
      );

  Widget _tabBar(AppTheme t) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _goTab(i),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: _tab == i ? _accent : t.fill,
                        borderRadius: BorderRadius.circular(11)),
                    child: Text(_tabs[i],
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _tab == i ? Colors.white : t.textSecondary)),
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _tabPage(Widget content) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: content,
      );

  // ── 튜토리얼 탭 ──

  Widget _basicsTab(AppTheme t) => Column(
        children: [
          _objectiveCard(t),
          const SizedBox(height: 14),
          _sectionHeader(t, '🕹️ 기본 조작'),
          for (final g in _controls) ...[
            const SizedBox(height: 14),
            _guideRow(t, g, t.fill)
          ],
          const SizedBox(height: 14),
          _sectionHeader(t, '🔘 화면 버튼·표시'),
          for (final g in _buttons) ...[
            const SizedBox(height: 14),
            _guideRow(t, g, t.fill)
          ],
        ],
      );

  Widget _objectiveCard(AppTheme t) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('게임 목표',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      '지뢰가 숨은 칸을 피해, 지뢰가 없는 칸을 모두 열면 승리예요. 지뢰를 열면 그 판은 끝나요. '
                      '숫자를 단서로 지뢰 위치를 추리하는 게 핵심이에요.',
                      style: TextStyle(color: t.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );

  // ── 공략 탭 ──

  Widget _patternsTab(AppTheme t) => Column(
        children: [
          _centerIntro(t, '🧠 지뢰찾기 공식', '자주 나오는 패턴을 익히면 찍지 않고도 풀 수 있어요.'),
          const SizedBox(height: 14),
          _legend(t),
          for (final l in _lessons) ...[
            const SizedBox(height: 14),
            _lessonCard(t, l)
          ],
        ],
      );

  Widget _centerIntro(AppTheme t, String title, String sub) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(
                    color: t.text, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSecondary, fontSize: 13)),
          ],
        ),
      );

  Widget _legend(AppTheme t) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: t.fill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem(t, _mineRed, '지뢰 확정'),
            const SizedBox(width: 16),
            _legendItem(t, _safeGreen, '안전 확정'),
          ],
        ),
      );

  Widget _legendItem(AppTheme t, Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color, width: 1.5)),
          ),
          const SizedBox(width: 7),
          Text(text,
              style: TextStyle(
                  color: t.text, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _lessonCard(AppTheme t, _Lesson l) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: t.fill, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: _gold, borderRadius: BorderRadius.circular(20)),
                  child: Text(l.badge,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 10),
                Text(l.title,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(l.detail,
                style: TextStyle(color: t.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Center(child: _TutoBoard(board: l.board, dark: t.dark)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: t.bg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb, size: 14, color: _gold),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(l.conclusion,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── 멀티 탭 ──

  Widget _multiTab(AppTheme t) => Column(
        children: [
          _centerIntro(t, '🏁 멀티 플레이',
              '세 가지 게임을 친구나 랜덤 상대와 함께 즐겨요. 같은 방에 들어가면 똑같은 보드에서 겨뤄요.'),
          const SizedBox(height: 14),
          _sectionHeader(t, '🚀 시작 방법'),
          for (final g in _startMethods) ...[
            const SizedBox(height: 14),
            _guideRow(t, g, t.fill)
          ],
          const SizedBox(height: 14),
          _sectionHeader(t, '🎮 게임별 규칙'),
          for (final g in _games) ...[
            const SizedBox(height: 14),
            _multiGameCard(t, g)
          ],
        ],
      );

  Widget _multiGameCard(AppTheme t, _MultiGame game) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: t.fill, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: game.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle),
                  child: Text(game.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.title,
                          style: TextStyle(
                              color: t.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      Text(game.tagline,
                          style: TextStyle(
                              color: game.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: game.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.emoji_events, size: 13, color: game.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(game.goal,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final r in game.rules) ...[
              _guideRow(t, r, t.bg),
              if (r != game.rules.last) const SizedBox(height: 8),
            ],
          ],
        ),
      );

  // ── 공용 ──

  Widget _sectionHeader(AppTheme t, String text) => Row(
        children: [
          Text(text,
              style: TextStyle(
                  color: t.text, fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      );

  Widget _guideRow(AppTheme t, _GuideItem item, Color bg) => Container(
        padding: const EdgeInsets.all(13),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _guideBadge(t, item.icon),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(item.detail,
                      style: TextStyle(color: t.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _guideBadge(AppTheme t, _GuideIcon icon) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: t.fillElevated, borderRadius: BorderRadius.circular(11)),
        child: icon.emoji != null
            ? Text(icon.emoji!, style: const TextStyle(fontSize: 22))
            : Icon(icon.iconData, size: 19, color: icon.color),
      );
}

// ── 미니보드 렌더러 ──

enum _Kind { hidden, empty, number, flag, mine, safe, wall }

class _TC {
  const _TC(this.kind, [this.n = 0]);
  final _Kind kind;
  final int n;
  static const hidden = _TC(_Kind.hidden);
  static const empty = _TC(_Kind.empty);
  static const flag = _TC(_Kind.flag);
  static const mine = _TC(_Kind.mine);
  static const safe = _TC(_Kind.safe);
  static const wall = _TC(_Kind.wall);
  static _TC num(int n) => _TC(_Kind.number, n);
}

class _TutoBoard extends StatelessWidget {
  const _TutoBoard({required this.board, required this.dark});
  final List<List<_TC>> board;
  final bool dark;

  static const _cell = 38.0;
  static const _mineRed = Color(0xFFEB5757);
  static const _safeGreen = Color(0xFF4DC77A);

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < board.length; r++) ...[
          if (r > 0) const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var c = 0; c < board[r].length; c++) ...[
                if (c > 0) const SizedBox(width: 4),
                _cellView(t, board[r][c]),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _cellView(AppTheme t, _TC cell) {
    return SizedBox(
      width: _cell,
      height: _cell,
      child: DecoratedBox(
        decoration: _bg(t, cell),
        child: Center(child: _content(t, cell)),
      ),
    );
  }

  BoxDecoration _bg(AppTheme t, _TC cell) {
    switch (cell.kind) {
      case _Kind.wall:
        return const BoxDecoration();
      case _Kind.empty:
      case _Kind.number:
        return BoxDecoration(
            color: t.cellRevealed,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.cellRevealedStroke, width: 0.5));
      case _Kind.mine:
        return BoxDecoration(
            color: _mineRed.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _mineRed, width: 1.5));
      case _Kind.safe:
        return BoxDecoration(
            color: _safeGreen.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _safeGreen, width: 1.5));
      case _Kind.hidden:
      case _Kind.flag:
        return BoxDecoration(
            gradient: LinearGradient(
                colors: [t.cellClosedTop, t.cellClosedBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.cellClosedStroke, width: 0.5));
    }
  }

  Widget? _content(AppTheme t, _TC cell) {
    switch (cell.kind) {
      case _Kind.number:
        return Text('${cell.n}',
            style: TextStyle(
                fontSize: _cell * 0.55,
                fontWeight: FontWeight.w900,
                color: minesweeperNumberColor(cell.n, dark)));
      case _Kind.flag:
        return Text('🚩', style: TextStyle(fontSize: _cell * 0.46));
      case _Kind.mine:
        return Text('💣', style: TextStyle(fontSize: _cell * 0.46));
      case _Kind.safe:
        return Icon(Icons.check, size: _cell * 0.4, color: _safeGreen);
      case _Kind.empty:
      case _Kind.hidden:
      case _Kind.wall:
        return null;
    }
  }
}

// ── 콘텐츠 데이터 (Swift TutorialView 콘텐츠 그대로) ──

class _GuideIcon {
  const _GuideIcon.emoji(this.emoji)
      : iconData = null,
        color = null;
  const _GuideIcon.symbol(this.iconData, this.color) : emoji = null;
  final String? emoji;
  final IconData? iconData;
  final Color? color;
}

class _GuideItem {
  const _GuideItem(this.icon, this.title, this.detail);
  final _GuideIcon icon;
  final String title;
  final String detail;
}

class _Lesson {
  const _Lesson(this.badge, this.title, this.detail, this.board, this.conclusion);
  final String badge;
  final String title;
  final String detail;
  final List<List<_TC>> board;
  final String conclusion;
}

class _MultiGame {
  const _MultiGame(this.emoji, this.title, this.tagline, this.accent, this.goal,
      this.rules);
  final String emoji;
  final String title;
  final String tagline;
  final Color accent;
  final String goal;
  final List<_GuideItem> rules;
}

const _flagRed = Color(0xFFE64C3D); // (0.90,0.30,0.24)
const _zoomBlue = Color(0xFF3373D9); // (0.20,0.45,0.85)
const _itemPurple = Color(0xFF946BF5); // (0.58,0.42,0.96)
const _mineBlue = Color(0xFF408CF2); // (0.25,0.55,0.95)
const _treasureGold = Color(0xFFF2BD3D); // (0.95,0.74,0.24)
const _touchGreen = Color(0xFF66B38C); // (0.40,0.70,0.55)

const _controls = <_GuideItem>[
  _GuideItem(_GuideIcon.emoji('👆'), '칸 열기 — 탭',
      '닫힌 칸을 가볍게 탭하면 열려요. 첫 탭은 그 칸과 둘레까지 절대 지뢰가 아니니, 안심하고 아무 데나 시작하세요.'),
  _GuideItem(_GuideIcon.emoji('🚩'), '깃발 꽂기 — 길게 누르기',
      '지뢰라고 생각되는 칸을 길게 누르면 깃발이 꽂혀요. 실수로 열지 않게 표시해 두는 용도이고, 다시 길게 누르면 빠져요.'),
  _GuideItem(_GuideIcon.emoji('🔢'), '숫자의 뜻',
      "열린 숫자는 그 칸과 맞닿은 8칸 안에 숨은 지뢰의 개수예요. '3'이면 둘레에 지뢰가 정확히 3개라는 뜻이에요."),
  _GuideItem(_GuideIcon.symbol(Icons.touch_app, _itemPurple), '숫자 탭 = 주변 한꺼번에 열기',
      '숫자 둘레에 그 숫자만큼 깃발을 다 꽂았다면, 그 숫자를 한 번 더 탭해 남은 칸을 한꺼번에 열 수 있어요. 빠르게 푸는 핵심이에요. 단, 깃발이 틀렸으면 지뢰가 열려 지니 깃발이 확실할 때만 쓰세요.'),
];

const _buttons = <_GuideItem>[
  _GuideItem(_GuideIcon.emoji('🙂'), '얼굴 버튼 — 다시 시작',
      '가운데 표정을 누르면 같은 판을 처음부터 다시 시작해요. 진행 중엔 🙂, 이기면 😎, 지면 😵 로 표정이 바뀌어요.'),
  _GuideItem(_GuideIcon.symbol(Icons.flag, _flagRed), '깃발 모드 버튼',
      '켜면 탭만으로 깃발을 꽂아요(탭=깃발, 길게=칸 열기로 반대가 돼요). 깃발을 많이 꽂을 때 편해요.'),
  _GuideItem(_GuideIcon.symbol(Icons.zoom_in, _zoomBlue), '확대 버튼',
      '보드를 크게 키워서 보고 드래그로 움직일 수 있어요. 칸이 작은 고급·최고급에서 특히 유용해요.'),
  _GuideItem(_GuideIcon.emoji('💣'), '왼쪽 숫자판 — 남은 지뢰',
      '전체 지뢰 수에서 꽂은 깃발 수를 뺀 값이에요. 깃발을 꽂을수록 줄어들어, 0이 되면 깃발을 다 꽂은 거예요.'),
  _GuideItem(_GuideIcon.emoji('⏱️'), '오른쪽 숫자판 — 시간',
      '시작부터 흐른 시간(초)이에요. 최고 기록과 랭킹은 이 시간으로 매겨져요.'),
  _GuideItem(_GuideIcon.symbol(Icons.auto_fix_high, _itemPurple), '자동깃발 아이템',
      '확실한 지뢰 칸에 깃발을 자동으로 꽂아주는 도우미예요. 아이템을 켜고 숫자칸을 고르면 그 둘레 지뢰에 깃발이 꽂혀요. (초급·중급은 우측 하단, 고급·최고급은 우측 가장자리 손잡이)'),
  _GuideItem(_GuideIcon.symbol(Icons.more_horiz, Color(0xFF999999)), '⋯ 메뉴 — 판 코드',
      '지금 판의 코드를 복사·공유할 수 있어요. 친구가 같은 코드를 입력하면 똑같은 판으로 대결할 수 있어요.'),
];

final _lessons = <_Lesson>[
  _Lesson(
    '①',
    '숫자의 의미',
    "열린 숫자는 그 칸과 맞닿은 8칸 안에 있는 지뢰의 개수예요. 아래 '2'는 주변 닫힌 칸 중 정확히 2개가 지뢰라는 뜻이에요.",
    [
      [_TC.hidden, _TC.hidden, _TC.hidden],
      [_TC.hidden, _TC.num(2), _TC.hidden],
      [_TC.empty, _TC.empty, _TC.empty],
    ],
    '숫자 = 인접한 8칸 속 지뢰 수',
  ),
  _Lesson(
    '②',
    '전부 지뢰일 때',
    "숫자와 맞닿은 '닫힌 칸 수'가 그 숫자와 같다면, 그 닫힌 칸은 모두 지뢰예요. 여기 '3'에 닫힌 칸이 딱 3개뿐이라, 셋 다 지뢰로 확정돼요.",
    [
      [_TC.mine, _TC.mine, _TC.mine],
      [_TC.empty, _TC.num(3), _TC.empty],
      [_TC.empty, _TC.empty, _TC.empty],
    ],
    '닫힌 칸 수 = 숫자 → 전부 지뢰(깃발)',
  ),
  _Lesson(
    '③',
    '전부 안전할 때',
    "이미 꽂은 깃발 수가 숫자와 같다면, 그 숫자 주변의 남은 닫힌 칸은 모두 안전해요. '1' 옆 깃발이 1개라 나머지 칸은 안심하고 열 수 있어요.",
    [
      [_TC.flag, _TC.safe, _TC.safe],
      [_TC.empty, _TC.num(1), _TC.safe],
      [_TC.empty, _TC.empty, _TC.safe],
    ],
    '깃발 수 = 숫자 → 나머지는 모두 안전',
  ),
  _Lesson(
    '1·2·1',
    '1-2-1 패턴',
    '한 줄로 1-2-1이 나오고 한쪽이 트여 있으면, 양쪽 1 끝의 칸이 지뢰, 가운데 2 위의 칸은 안전이에요. 가장 자주 나오는 공식이에요.',
    [
      [_TC.mine, _TC.safe, _TC.mine],
      [_TC.num(1), _TC.num(2), _TC.num(1)],
      [_TC.empty, _TC.empty, _TC.empty],
    ],
    '양 끝(1) = 지뢰, 가운데(2) = 안전',
  ),
  _Lesson(
    '1·2·2·1',
    '1-2-2-1 패턴',
    '1-2-2-1이 한 줄로 늘어서면 가운데 두 칸(2 위)이 지뢰, 양 끝(1 위)이 안전이에요. 1-2-1과 짝꿍처럼 외워두면 좋아요.',
    [
      [_TC.safe, _TC.mine, _TC.mine, _TC.safe],
      [_TC.num(1), _TC.num(2), _TC.num(2), _TC.num(1)],
      [_TC.empty, _TC.empty, _TC.empty, _TC.empty],
    ],
    '가운데 둘(2·2) = 지뢰, 양 끝(1·1) = 안전',
  ),
  _Lesson(
    '1·1',
    '1-1 패턴',
    '벽을 따라 1-1이 이어질 때, 왼쪽 1이 보는 칸이 오른쪽 1이 보는 칸에 포함되면 그 바깥쪽 칸은 안전해요. 지뢰 위치는 아직 몰라도 안전칸부터 열 수 있어요.',
    [
      [_TC.hidden, _TC.hidden, _TC.safe],
      [_TC.num(1), _TC.num(1), _TC.empty],
      [_TC.wall, _TC.wall, _TC.empty],
    ],
    '겹치는 칸 바깥(▢)은 안전 — 먼저 열기',
  ),
];

const _startMethods = <_GuideItem>[
  _GuideItem(_GuideIcon.emoji('🎲'), '랜덤 매칭',
      '비슷한 때 접속한 다른 사람과 자동으로 짝지어 같은 보드에서 시작해요. 혼자 눌러도 상대를 찾아줘요.'),
  _GuideItem(_GuideIcon.emoji('🔑'), '방 만들기 · 코드로 참가',
      '방을 만들면 6자리 코드가 나와요. 친구가 그 코드를 입력하면 둘이 같은 방, 똑같은 보드에서 대결해요. (지뢰찾기는 방을 만든 사람이 종류·난이도를 정해요.)'),
  _GuideItem(_GuideIcon.emoji('🤖'), '봇과 대전 · 혼자 연습',
      '인터넷 없이도 연습할 수 있어요. 지뢰찾기는 봇과 대전, 보물찾기는 혼자 연습으로 들어가요.'),
];

const _games = <_MultiGame>[
  _MultiGame('💣', '지뢰찾기', '같은 보드, 세 가지 승부', _mineBlue,
      '같은 지뢰판을 두 사람이 함께 풀어요. 고른 종류에 따라 이기는 방법이 달라져요.', [
    _GuideItem(_GuideIcon.emoji('🏃'), '스피드',
        '같은 보드를 각자 풀어, 안전한 칸을 먼저 다 연 사람이 승리해요. 상대 진행도가 화면 위에 막대로 보여요.'),
    _GuideItem(_GuideIcon.emoji('⚔️'), '지뢰 대결',
        '한 보드를 실시간으로 함께 봐요. 보드가 끝났을 때 깃발로 지뢰를 더 많이 맞힌 사람이 승리예요(맞힌 깃발 +1, 틀린 깃발 −1). 밟아 터진 지뢰는 누구의 점수도 아니에요.'),
    _GuideItem(_GuideIcon.emoji('🤝'), '합동',
        '한 보드를 둘이 함께 풀어 안전한 칸을 모두 열면 같이 승리해요. 단, 둘 중 누구든 지뢰를 밟으면 함께 패배하니 호흡이 중요해요.'),
    _GuideItem(_GuideIcon.symbol(Icons.tune, _mineBlue), '난이도·상대 고르기',
        '초급부터 최고급까지 난이도를 고르고, 실시간 매칭·봇·친구 방 중에서 상대를 정할 수 있어요.'),
  ]),
  _MultiGame('💎', '보물찾기', '가운데 보물까지 먼저!', _treasureGold,
      '같은 보드에서 각자 구석에서 출발해, 가운데 보물 칸을 먼저 연 사람이 승리해요.', [
    _GuideItem(_GuideIcon.emoji('🧭'), '반대편 구석에서 출발',
        '방을 만든 사람은 왼쪽 위, 참가한 사람은 오른쪽 아래에서 시작해요. 둘 다 가운데를 향해 길을 뚫어요.'),
    _GuideItem(_GuideIcon.emoji('🧱'), '길 이어 파기',
        '이미 연 칸 근처만 열 수 있어요. 출발 구석에서 중앙까지 한 칸씩 길을 이어 나가야 해요.'),
    _GuideItem(_GuideIcon.emoji('💥'), '지뢰는 함정 (안 죽어요)',
        '밟아도 게임오버는 아니에요. 대신 주변 5×5 칸이 도로 닫히고 잠깐 멈춰요(그 안 지뢰도 다시 섞여요). 그만큼 시간을 잃죠.'),
    _GuideItem(_GuideIcon.emoji('🌶️'), '중앙일수록 빽빽',
        '가운데로 갈수록 지뢰가 촘촘해져요. 보물 코앞이 가장 어려운 구간이에요.'),
    _GuideItem(_GuideIcon.symbol(Icons.person, _treasureGold), '혼자 연습',
        '상대 없이 같은 규칙으로 길 뚫기를 연습할 수 있어요.'),
  ]),
  _MultiGame('🤝', '너에게 닿기를', '길 뚫어 서로 만나기 · 협동', _touchGreen,
      '80×80 큰 보드 양 끝에서 시작한 두 사람이 서로를 향해 길을 파, 두 사람이 연 칸이 맞닿으면 둘 다 성공! 만나기까지 걸린 시간이 협동 랭킹에 올라가요.', [
    _GuideItem(_GuideIcon.emoji('🌫️'), '안개 — 내 주변만 보여요',
        "내가 연 칸 둘레 3칸까지만 보여요. 상대가 가까이 오면 상대 칸·깃발이 내 안개 안에 나타나 '근처에 왔다'를 알 수 있어요."),
    _GuideItem(_GuideIcon.emoji('🧱'), '길 이어 파기',
        '지뢰찾기처럼 이미 연 칸 옆만 열 수 있어요. 상대가 있을 방향으로 한 줄씩 길을 이어가세요.'),
    _GuideItem(_GuideIcon.emoji('💣'), '지뢰 밟으면 둘 다 손해',
        '1.5초 동안 멈추고, 게다가 파트너가 꽂아둔 깃발 1개가 무작위로 빠져요. 협동이라 내 실수가 파트너에게도 영향을 줘요.'),
    _GuideItem(_GuideIcon.emoji('📣'), '확성기 5개',
        "보드에 숨은 확성기 칸을 열면 파트너 화면에 '여기서 울렸어요' 방향 화살표가 잠깐 떠요. 만날 방향을 잡는 데 도움이 돼요."),
    _GuideItem(_GuideIcon.symbol(Icons.flag, _touchGreen), '깃발은 서로의 신호',
        "꽂은 깃발은 파트너 안개에도 보여서 '여기 지뢰 있어'라고 알려주는 신호가 돼요."),
  ]),
];
