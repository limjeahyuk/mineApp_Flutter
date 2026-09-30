import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../modes/coop_screen.dart';
import '../modes/treasure_screen.dart';
import '../modes/treasure_solo_screen.dart';
import '../shop/shop_screen.dart';
import 'multiplayer.dart';
import 'versus_screen.dart';

/// 게임 유형 — 지뢰찾기 / 보물찾기 / 너에게 닿기를(협동).
enum GameType { mine, treasure, coop }

extension on GameType {
  String get emoji => switch (this) { GameType.mine => '💣', GameType.treasure => '💎', GameType.coop => '🤝' };
  String get title =>
      switch (this) { GameType.mine => '지뢰찾기', GameType.treasure => '보물찾기', GameType.coop => '너에게 닿기를' };
  Color get accent => switch (this) {
        GameType.mine => const Color.fromRGBO(64, 140, 242, 1),
        GameType.treasure => const Color.fromRGBO(242, 189, 61, 1),
        GameType.coop => const Color.fromRGBO(102, 179, 140, 1),
      };
}

extension RaceRuleTitle on RaceRule {
  String get title => switch (this) { RaceRule.speed => '스피드', RaceRule.score => '지뢰 대결', RaceRule.coop => '합동' };
}

/// 멀티 플레이 페이지 — Swift MultiplayerMenuView 이식(풀스크린).
/// 게임 스위처 → (지뢰찾기: 종류·난이도 카드 + 랜덤/봇/방 만들기/코드 참가)
/// (보물찾기: 온라인 랜덤/방/코드 + 혼자 연습) (너에게 닿기를: 랜덤/방/코드).
class VersusMenuScreen extends StatefulWidget {
  const VersusMenuScreen({super.key});

  @override
  State<VersusMenuScreen> createState() => _VersusMenuScreenState();
}

class _VersusMenuScreenState extends State<VersusMenuScreen> {
  GameType game = GameType.mine;
  RaceRule rule = RaceRule.speed;
  Difficulty difficulty = Difficulty.intermediate;
  final _code = TextEditingController();

  static const ruleAccent = Color.fromRGBO(235, 82, 140, 1); // (0.92,0.32,0.55)
  static const difficultyAccent = Color.fromRGBO(245, 189, 46, 1); // (0.96,0.74,0.18)
  static const difficultyText = Color.fromRGBO(51, 33, 0, 1);
  static const friendAccent = Color.fromRGBO(140, 89, 217, 1); // (0.55,0.35,0.85)
  static const raceColor = Color.fromRGBO(51, 140, 242, 1);
  static const botColor = Color.fromRGBO(51, 158, 128, 1);
  static const gold = Color.fromRGBO(242, 199, 77, 1);

  String get _normalized => RoomCode.normalize(_code.text);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  LinearGradient _grad(Color c) => LinearGradient(
      colors: [c, c.withValues(alpha: 0.80)], begin: Alignment.topLeft, end: Alignment.bottomRight);

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          _navBar(t),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _switcher(t),
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
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _navBar(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Stack(alignment: Alignment.center, children: [
        Text('멀티 플레이', style: sf(17, weight: W.bold, color: t.text)),
        Row(children: [
          Tap(
            onTap: () {
              Haptics.tap();
              Navigator.of(context).pop();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
              child: Icon(SF.chevronLeft, size: 16, color: t.textSecondary),
            ),
          ),
          const Spacer(),
          Tap(
            onTap: () async {
              Haptics.tap();
              await showAppSheet<void>(context, (_) => const ShopScreen(initialTab: 1));
              if (mounted) setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
              decoration: BoxDecoration(
                color: t.fill,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: gold.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const GoldenMineIcon(size: 16),
                const SizedBox(width: 6),
                Text(fmt(LocalStore.shared.coins), style: sf(14, weight: W.bold, color: t.text)),
                const SizedBox(width: 6),
                const Icon(SF.plusCircleFill, size: 16, color: gold),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _switcher(AppTheme t) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: rr(16, t.fill),
      child: Row(children: [
        for (final g in GameType.values) ...[
          if (g != GameType.mine) const SizedBox(width: 6),
          Expanded(
            child: Tap(
              onTap: () {
                Haptics.tap();
                setState(() => game = g);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: g == game ? _grad(g.accent) : null,
                  boxShadow: g == game
                      ? [BoxShadow(color: g.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(g.emoji, style: const TextStyle(fontSize: 22, height: 1.15)),
                  const SizedBox(height: 5),
                  FittedBox(
                    child: Text(g.title,
                        style: sf(12.5,
                            weight: W.bold, color: g == game ? Colors.white : t.textSecondary)),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  // ── 지뢰찾기 ──
  Widget _mineSection(AppTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _setupCard(t),
      const SizedBox(height: 18),
      dotLabel(t, '대전 방식', GameType.mine.accent),
      const SizedBox(height: 10),
      _action(t, SF.bolt, '랜덤 매칭', '실시간으로 상대를 찾아 대전', raceColor,
          () => _push(VersusScreen(mode: RaceMode.quick(difficulty, rule)))),
      const SizedBox(height: 10),
      _action(t, Icons.memory_rounded, '봇과 대전', '오프라인에서 연습', botColor,
          () => _push(VersusScreen(mode: RaceMode.bot(difficulty, rule)))),
      const SizedBox(height: 10),
      _action(t, CupertinoIcons.person_badge_plus, '방 만들기', '이 설정으로 코드를 발급해 초대', friendAccent,
          () => _push(VersusScreen(mode: RaceMode.host(difficulty, rule)))),
      const SizedBox(height: 10),
      _joinRow(t, () => _push(VersusScreen(mode: RaceMode.join(_normalized)))),
    ]);
  }

  Widget _setupCard(AppTheme t) {
    Widget chip(String label, bool sel, LinearGradient g, Color selText, VoidCallback onTap) => Expanded(
          child: Tap(
            onTap: () {
              Haptics.tap();
              onTap();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: sel ? null : t.fill,
                gradient: sel ? g : null,
              ),
              child: FittedBox(
                child: Text(label,
                    style: sf(14, weight: W.bold, color: sel ? selText : t.textSecondary)),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: rr(16, t.surface, stroke: t.border.withValues(alpha: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        dotLabel(t, '종류', ruleAccent),
        const SizedBox(height: 9),
        Row(children: [
          for (final r in RaceRule.values) ...[
            if (r != RaceRule.speed) const SizedBox(width: 8),
            chip(r.title, rule == r, _grad(ruleAccent), Colors.white, () {
              setState(() {
                rule = r;
                if (!r.allowedDifficulties.contains(difficulty)) {
                  difficulty = r.allowedDifficulties.first;
                }
              });
            }),
          ],
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: difficultyAccent, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text('난이도', style: sf(13, weight: W.bold, color: t.textSecondary)),
          if (rule == RaceRule.coop) ...[
            const SizedBox(width: 7),
            Text('· 합동은 고급·최고급만', style: sf(11, weight: W.medium, color: t.textTertiary)),
          ],
        ]),
        const SizedBox(height: 9),
        Row(children: [
          for (final d in rule.allowedDifficulties) ...[
            if (d != rule.allowedDifficulties.first) const SizedBox(width: 8),
            chip(d.label, difficulty == d, _grad(difficultyAccent), difficultyText,
                () => setState(() => difficulty = d)),
          ],
        ]),
      ]),
    );
  }

  // ── 보물찾기 ──
  Widget _treasureSection(AppTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _blurb(t, '💎', '지뢰밭을 헤치고 같은 보드의 가운데 보물까지 먼저 도달하면 승리해요.'),
      const SizedBox(height: 18),
      dotLabel(t, '대전 방식', GameType.treasure.accent),
      const SizedBox(height: 10),
      _action(t, SF.bolt, '온라인 랜덤 매칭', '같은 보드에서 먼저 보물 찾기', botColor,
          () => _push(TreasureScreen(mode: RaceMode.quick(Difficulty.intermediate, RaceRule.speed)))),
      const SizedBox(height: 10),
      _action(t, CupertinoIcons.person_badge_plus, '친구와 방 만들기', '코드를 발급해 초대', friendAccent,
          () => _push(TreasureScreen(mode: RaceMode.host(Difficulty.intermediate, RaceRule.speed)))),
      const SizedBox(height: 10),
      _joinRow(t, () => _push(TreasureScreen(mode: RaceMode.join(_normalized)))),
      const SizedBox(height: 18),
      dotLabel(t, '혼자', t.textTertiary),
      const SizedBox(height: 10),
      _action(t, SF.personFill, '혼자 연습', '가운데 보물까지 길 뚫기', GameType.treasure.accent,
          () => _push(const TreasureSoloScreen()),
          filled: false),
    ]);
  }

  // ── 너에게 닿기를 ──
  Widget _touchSection(AppTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _blurb(t, '🤝',
          '80×80 보드 양 끝에서 시작해, 안개를 헤치고 길을 뚫어 서로 만나면 둘 다 성공! 걸린 시간이 협동 랭킹에 올라가요.'),
      const SizedBox(height: 18),
      dotLabel(t, '함께하기', GameType.coop.accent),
      const SizedBox(height: 10),
      _action(t, SF.bolt, '온라인 랜덤 매칭', '길을 뚫어 서로 만나기', botColor,
          () => _push(CoopScreen(mode: RaceMode.quick(Difficulty.intermediate, RaceRule.speed)))),
      const SizedBox(height: 10),
      _action(t, CupertinoIcons.person_badge_plus, '친구와 방 만들기', '코드를 발급해 초대', friendAccent,
          () => _push(CoopScreen(mode: RaceMode.host(Difficulty.intermediate, RaceRule.speed)))),
      const SizedBox(height: 10),
      _joinRow(t, () => _push(CoopScreen(mode: RaceMode.join(_normalized)))),
    ]);
  }

  // ── 공용 ──
  Widget _blurb(AppTheme t, String emoji, String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: rr(14, t.fill),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 11),
          Expanded(child: Text(text, style: sf(12, weight: W.medium, color: t.textSecondary))),
        ]),
      );

  Widget _action(AppTheme t, IconData icon, String title, String subtitle, Color color,
      VoidCallback onTap,
      {bool filled = true}) {
    return Tap(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: filled ? null : t.fill,
          gradient: filled ? _grad(color) : null,
          border: filled ? null : Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: filled
              ? [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: filled ? Colors.white.withValues(alpha: 0.22) : color.withValues(alpha: 0.16),
                shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: filled ? Colors.white : color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: sf(15, weight: W.bold, color: filled ? Colors.white : t.text)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: sf(11,
                      weight: W.medium,
                      color: filled ? Colors.white.withValues(alpha: 0.9) : t.textSecondary)),
            ]),
          ),
          Icon(SF.chevronRight,
              size: 13, color: filled ? Colors.white.withValues(alpha: 0.9) : t.textTertiary),
        ]),
      ),
    );
  }

  Widget _joinRow(AppTheme t, VoidCallback onJoin) {
    final ok = _normalized.length >= 4;
    return Row(children: [
      Expanded(
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: rr(14, t.fill),
          child: TextField(
            controller: _code,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) {
              final n = RoomCode.normalize(v);
              if (n != v) {
                _code.value = TextEditingValue(
                    text: n, selection: TextSelection.collapsed(offset: n.length));
              }
              setState(() {});
            },
            style: sf(16, weight: W.bold, color: t.text, mono: true).copyWith(letterSpacing: 3),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: '코드로 참가 (예: ABC234)',
              hintStyle: sf(16, color: t.textTertiary),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Tap(
        onTap: ok
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
            borderRadius: BorderRadius.circular(14),
            color: ok ? null : t.fillElevated,
            gradient: ok ? _grad(friendAccent) : null,
          ),
          child: Text('참가', style: sf(15, weight: W.semibold, color: Colors.white)),
        ),
      ),
    ]);
  }
}
