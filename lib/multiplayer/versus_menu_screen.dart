import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../guide/practice.dart';
import '../modes/coop_screen.dart';
import '../modes/treasure_screen.dart';
import '../modes/treasure_solo_screen.dart';
import '../shop/shop_screen.dart';
import 'multiplayer.dart';
import 'versus_screen.dart';

/// 어떤 게임으로 대전할지 — 상단 스위처.
enum GameType {
  mine('💣', '지뢰찾기', OnboardKind.mine, Color.fromRGBO(64, 140, 242, 1)),
  treasure('💎', '보물찾기', OnboardKind.treasure, Color.fromRGBO(242, 189, 61, 1)),
  coop('🤝', '너에게 닿기를', OnboardKind.touch, Color.fromRGBO(102, 179, 140, 1));

  const GameType(this.emoji, this.title, this.practice, this.accent);
  final String emoji;
  final String title;
  final OnboardKind practice; // 첫 진입 연습 보드 / ? 버튼
  final Color accent;
}

/// 멀티 플레이 전용 페이지 — Swift MultiplayerMenuView 이식(홈에서 풀스크린).
/// 위에서 게임(지뢰찾기·보물찾기·너에게 닿기를)을 고르고, 그 아래에서 설정과 대전 방식을 정한다.
class VersusMenuScreen extends StatefulWidget {
  const VersusMenuScreen({super.key});

  @override
  State<VersusMenuScreen> createState() => _VersusMenuScreenState();
}

class _VersusMenuScreenState extends State<VersusMenuScreen> {
  GameType game = GameType.mine;
  RaceRule rule = RaceRule.speed;
  Difficulty difficulty = Difficulty.intermediate;
  final TextEditingController _codeCtrl = TextEditingController();

  static const _ruleAccent = Color.fromRGBO(235, 82, 140, 1); // 종류 = 핑크
  static const _difficultyAccent = Color.fromRGBO(245, 189, 46, 1); // 난이도 = 노랑
  static const _difficultyText = Color.fromRGBO(51, 33, 0, 1);
  static const _friendAccent = Color.fromRGBO(140, 89, 217, 1); // 방/코드 = 보라
  static const _raceColor = Color.fromRGBO(51, 140, 242, 1); // 레이스 = 파랑
  static const _botColor = Color.fromRGBO(51, 158, 128, 1); // 봇/랜덤 = 초록
  static const _gold = AppTheme.gold;
  static const _contentMaxWidth = 460.0;

  String get _normalizedCode => RoomCode.normalize(_codeCtrl.text);

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(() {
      final n = RoomCode.normalize(_codeCtrl.text);
      if (n != _codeCtrl.text) {
        _codeCtrl.value = TextEditingValue(
            text: n, selection: TextSelection.collapsed(offset: n.length));
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  LinearGradient _grad(Color c) => LinearGradient(
        colors: [c, c.withValues(alpha: 0.80)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// 메뉴를 게임으로 바꿔 넣는다(닫으면 홈으로). 이 게임 첫 진입이면 연습 보드를 먼저 보여준다.
  void _open(Widget screen) =>
      pushGameWithOnboarding(context, game.practice, () => screen,
          replace: true);

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _navBar(t),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _contentMaxWidth),
                    child: Column(
                      children: [
                        _gameSwitcher(t),
                        const SizedBox(height: 22),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: KeyedSubtree(
                            key: ValueKey(game),
                            child: switch (game) {
                              GameType.mine => _mineSection(t),
                              GameType.treasure => _treasureSection(t),
                              GameType.coop => _touchSection(t),
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: 상단 바 — 뒤로 / 제목 / 코인

  Widget _navBar(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('멀티 플레이',
              style: TextStyle(
                  color: t.text, fontSize: 17, fontWeight: FontWeight.bold)),
          Row(
            children: [
              PlainButton(
                onTap: () {
                  Haptics.tap();
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: t.fill, shape: BoxShape.circle),
                  child: Icon(Icons.chevron_left,
                      size: 22, color: t.textSecondary),
                ),
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: LocalStore.shared,
                builder: (_, _) => PlainButton(
                  onTap: () {
                    Haptics.tap();
                    presentSheet(context, (_) => const ShopScreen(initialTab: 1));
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
                    decoration: BoxDecoration(
                      color: t.fill,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: _gold.withValues(alpha: 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const GoldenMineIcon(size: 16),
                      const SizedBox(width: 6),
                      Text(formatNumber(LocalStore.shared.coins),
                          style: TextStyle(
                              color: t.text,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Icon(Icons.add_circle, size: 17, color: _gold),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // MARK: 게임 스위처

  Widget _gameSwitcher(AppTheme t) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration:
          BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (final g in GameType.values) ...[
            if (g != GameType.mine) const SizedBox(width: 6),
            Expanded(
              child: Stack(children: [
                SizedBox(width: double.infinity, child: _gameTab(t, g)),
                Positioned(
                  top: 0,
                  right: 0,
                  child: PracticeHelpButton(
                      onTap: () => openPractice(context, g.practice)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gameTab(AppTheme t, GameType g) {
    final selected = g == game;
    return PlainButton(
      onTap: () {
        Haptics.tap();
        setState(() => game = g);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 62,
        decoration: BoxDecoration(
          gradient: selected ? _grad(g.accent) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: g.accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(g.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(g.title,
                  maxLines: 1,
                  style: TextStyle(
                      color: selected ? Colors.white : t.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: 지뢰찾기

  Widget _mineSection(AppTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _setupCard(t),
        const SizedBox(height: 18),
        _sectionLabel(t, '대전 방식', GameType.mine.accent),
        const SizedBox(height: 10),
        _actionRow(t,
            icon: Icons.bolt,
            title: '랜덤 매칭',
            subtitle: '실시간으로 상대를 찾아 대전',
            color: _raceColor,
            onTap: () => _open(VersusScreen(mode: RaceMode.quick(difficulty, rule)))),
        const SizedBox(height: 10),
        _actionRow(t,
            icon: Icons.memory,
            title: '봇과 대전',
            subtitle: '오프라인에서 연습',
            color: _botColor,
            onTap: () => _open(VersusScreen(mode: RaceMode.bot(difficulty, rule)))),
        const SizedBox(height: 10),
        _actionRow(t,
            icon: Icons.person_add_alt_1,
            title: '방 만들기',
            subtitle: '이 설정으로 코드를 발급해 초대',
            color: _friendAccent,
            onTap: () => _open(VersusScreen(mode: RaceMode.host(difficulty, rule)))),
        const SizedBox(height: 10),
        _joinRow(t,
            onJoin: () =>
                _open(VersusScreen(mode: RaceMode.join(_normalizedCode)))),
      ],
    );
  }

  Widget _setupCard(AppTheme t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(t, '종류', _ruleAccent),
          const SizedBox(height: 9),
          Row(
            children: [
              for (final r in RaceRule.values) ...[
                if (r != RaceRule.speed) const SizedBox(width: 8),
                Expanded(
                  child: _chip(t,
                      label: r.title,
                      selected: rule == r,
                      fill: _ruleAccent,
                      onTap: () => setState(() {
                            rule = r;
                            // 합동으로 바꾸면 허용되지 않는 난이도는 고급으로 보정한다.
                            if (!r.allowedDifficulties.contains(difficulty)) {
                              difficulty = r.allowedDifficulties.first;
                            }
                          })),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: _difficultyAccent, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text('난이도',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            if (rule == RaceRule.coop) ...[
              const SizedBox(width: 7),
              Text('· 합동은 고급·최고급만',
                  style: TextStyle(
                      color: t.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ]),
          const SizedBox(height: 9),
          Row(
            children: [
              for (final d in rule.allowedDifficulties) ...[
                if (d != rule.allowedDifficulties.first)
                  const SizedBox(width: 8),
                Expanded(
                  child: _chip(t,
                      label: d.label,
                      selected: difficulty == d,
                      fill: _difficultyAccent,
                      selectedText: _difficultyText,
                      onTap: () => setState(() => difficulty = d)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(AppTheme t,
      {required String label,
      required bool selected,
      required Color fill,
      Color selectedText = Colors.white,
      required VoidCallback onTap}) {
    return PlainButton(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? null : t.fill,
          gradient: selected ? _grad(fill) : null,
          borderRadius: BorderRadius.circular(11),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              maxLines: 1,
              style: TextStyle(
                  color: selected ? selectedText : t.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // MARK: 보물찾기

  Widget _treasureSection(AppTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _blurb(t, '💎', '지뢰밭을 헤치고 같은 보드의 가운데 보물까지 먼저 도달하면 승리해요.'),
        const SizedBox(height: 18),
        _sectionLabel(t, '대전 방식', GameType.treasure.accent),
        const SizedBox(height: 10),
        _actionRow(t,
            icon: Icons.bolt,
            title: '온라인 랜덤 매칭',
            subtitle: '같은 보드에서 먼저 보물 찾기',
            color: _botColor,
            onTap: () => _open(TreasureScreen(
                mode: RaceMode.quick(Difficulty.intermediate, RaceRule.speed)))),
        const SizedBox(height: 10),
        _actionRow(t,
            icon: Icons.person_add_alt_1,
            title: '친구와 방 만들기',
            subtitle: '코드를 발급해 초대',
            color: _friendAccent,
            onTap: () => _open(TreasureScreen(
                mode: RaceMode.host(Difficulty.intermediate, RaceRule.speed)))),
        const SizedBox(height: 10),
        _joinRow(t,
            onJoin: () =>
                _open(TreasureScreen(mode: RaceMode.join(_normalizedCode)))),
        const SizedBox(height: 18),
        _sectionLabel(t, '혼자', t.textTertiary),
        const SizedBox(height: 10),
        _actionRow(t,
            icon: Icons.person,
            title: '혼자 연습',
            subtitle: '가운데 보물까지 길 뚫기',
            color: GameType.treasure.accent,
            filled: false,
            onTap: () => _open(const TreasureSoloScreen())),
      ],
    );
  }

  // MARK: 너에게 닿기를

  Widget _touchSection(AppTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _blurb(t, '🤝',
            '80×80 보드 양 끝에서 시작해, 안개를 헤치고 길을 뚫어 서로 만나면 둘 다 성공! 걸린 시간이 협동 랭킹에 올라가요.'),
        const SizedBox(height: 18),
        _sectionLabel(t, '함께하기', GameType.coop.accent),
        const SizedBox(height: 10),
        _actionRow(t,
            icon: Icons.bolt,
            title: '온라인 랜덤 매칭',
            subtitle: '길을 뚫어 서로 만나기',
            color: _botColor,
            onTap: () => _open(CoopScreen(
                mode: RaceMode.quick(Difficulty.intermediate, RaceRule.coop)))),
        const SizedBox(height: 10),
        _actionRow(t,
            icon: Icons.person_add_alt_1,
            title: '친구와 방 만들기',
            subtitle: '코드를 발급해 초대',
            color: _friendAccent,
            onTap: () => _open(CoopScreen(
                mode: RaceMode.host(Difficulty.intermediate, RaceRule.coop)))),
        const SizedBox(height: 10),
        _joinRow(t,
            onJoin: () =>
                _open(CoopScreen(mode: RaceMode.join(_normalizedCode)))),
      ],
    );
  }

  // MARK: 공용 컴포넌트

  Widget _blurb(AppTheme t, String emoji, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(AppTheme t, String text, Color accent) {
    return Row(children: [
      Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
      const SizedBox(width: 7),
      Text(text,
          style: TextStyle(
              color: t.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _actionRow(AppTheme t,
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      bool filled = true,
      required VoidCallback onTap}) {
    return PlainButton(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: filled ? _grad(color) : null,
          color: filled ? null : t.fill,
          borderRadius: BorderRadius.circular(16),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: filled
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: filled
                    ? Colors.white.withValues(alpha: 0.22)
                    : color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: filled ? Colors.white : color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: filled ? Colors.white : t.text,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: filled
                              ? Colors.white.withValues(alpha: 0.9)
                              : t.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18,
                color: filled
                    ? Colors.white.withValues(alpha: 0.9)
                    : t.textTertiary),
          ],
        ),
      ),
    );
  }

  /// 코드 입력 + 참가 버튼(세 게임 공용).
  Widget _joinRow(AppTheme t, {required VoidCallback onJoin}) {
    final enabled = _normalizedCode.length >= 4;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(14)),
            child: TextField(
              controller: _codeCtrl,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                  color: t.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: const ['Courier', 'monospace']),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '코드로 참가 (예: ABC234)',
                hintStyle: TextStyle(
                    color: t.textTertiary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PlainButton(
          onTap: enabled
              ? () {
                  Haptics.tap();
                  onJoin();
                }
              : null,
          child: Container(
            width: 74,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? null : t.fillElevated,
              gradient: enabled ? _grad(_friendAccent) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('참가',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
