import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../modes/coop_screen.dart';
import '../modes/treasure_screen.dart';
import 'multiplayer.dart';
import 'versus_screen.dart';

/// 게임 유형 — 지뢰찾기 / 보물찾기 / 너에게 닿기를(협동).
enum GameType { mine, treasure, coop }

/// 대전 메뉴 — Swift MultiplayerMenuView 이식.
/// 게임 유형(지뢰찾기/보물찾기/너에게 닿기를) · 종류(스피드/지뢰대결/합동) ·
/// 난이도 · 대전 방식(랜덤/봇/방만들기) · 코드 참가.
///
/// ponytail: 봇과 대전은 지뢰찾기(스피드·지뢰대결)만 이식. 합동 규칙은 미이식("준비 중").
class VersusMenuScreen extends StatefulWidget {
  const VersusMenuScreen({super.key});

  @override
  State<VersusMenuScreen> createState() => _VersusMenuScreenState();
}

class _VersusMenuScreenState extends State<VersusMenuScreen> {
  RaceRule rule = RaceRule.speed;
  Difficulty difficulty = Difficulty.intermediate;
  GameType gameType = GameType.mine;
  final TextEditingController _codeCtrl = TextEditingController();

  static const _pink = Color(0xFFE85C8B);
  static const _yellow = Color(0xFFEAC23C);
  static const _blueCard = Color(0xFF3E86F5);
  static const _greenCard = Color(0xFF33A07E);
  static const _purpleCard = Color(0xFFA45CE0);

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _soon(String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text('$name — 준비 중이에요'),
          duration: const Duration(seconds: 1)));
  }

  void _launch(RaceMode mode) {
    final Widget screen = switch (gameType) {
      GameType.mine => VersusScreen(mode: mode),
      GameType.treasure => TreasureScreen(mode: mode),
      GameType.coop => CoopScreen(mode: mode),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _joinByCode(String code) {
    if (code.trim().isEmpty) return;
    _launch(RaceMode.join(code.trim()));
  }

  // 봇전은 지뢰찾기(스피드·지뢰대결)만 이식. 보물찾기·너에게 닿기를는 준비 중.
  void _launchBot() {
    if (gameType != GameType.mine) {
      _soon('봇과 대전(${gameType == GameType.treasure ? '보물찾기' : '너에게 닿기를'})');
      return;
    }
    _launch(RaceMode.bot(difficulty, rule));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(t),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _gameTypeSelector(t),
                  const SizedBox(height: 20),
                  _settingsCard(t),
                  const SizedBox(height: 24),
                  _sectionLabel(t, '대전 방식', _blueCard),
                  const SizedBox(height: 10),
                  _bigCard(t, _blueCard, Icons.bolt, '랜덤 매칭',
                      '실시간으로 상대를 찾아 대전',
                      () => _launch(RaceMode.quick(difficulty, rule))),
                  const SizedBox(height: 12),
                  _bigCard(t, _greenCard, Icons.memory, '봇과 대전',
                      '오프라인에서 연습', _launchBot),
                  const SizedBox(height: 12),
                  _bigCard(t, _purpleCard, Icons.person_add_alt, '방 만들기',
                      '이 설정으로 코드를 발급해 초대',
                      () => _launch(RaceMode.host(difficulty, rule))),
                  const SizedBox(height: 16),
                  _codeJoin(t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 헤더: 뒤로 · 제목 · 코인 ──
  Widget _header(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      child: Row(
        children: [
          Material(
            color: t.fill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.chevron_left, color: t.text, size: 24)),
            ),
          ),
          Expanded(
            child: Text('멀티 플레이',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.text, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          _coinPill(t),
        ],
      ),
    );
  }

  Widget _coinPill(AppTheme t) {
    const gold = Color(0xFFF4C13B);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('☀️', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text('${LocalStore.shared.coins}',
              style: TextStyle(
                  color: t.text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 11,
            backgroundColor: gold,
            child: Icon(Icons.add, size: 15, color: Colors.black),
          ),
        ],
      ),
    );
  }

  // ── 게임 유형 3분할 ──
  Widget _gameTypeSelector(AppTheme t) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: t.fill, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _gameTypeTab(t, '💣', '지뢰찾기',
              selected: gameType == GameType.mine,
              onTap: () => setState(() => gameType = GameType.mine)),
          _gameTypeTab(t, '💎', '보물찾기',
              selected: gameType == GameType.treasure,
              onTap: () => setState(() => gameType = GameType.treasure)),
          _gameTypeTab(t, '🤝', '너에게 닿기를',
              selected: gameType == GameType.coop,
              onTap: () => setState(() => gameType = GameType.coop)),
        ],
      ),
    );
  }

  Widget _gameTypeTab(AppTheme t, String emoji, String label,
      {required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? _blueCard : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: selected ? Colors.white : t.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ── 종류 + 난이도 묶음 카드 ──
  Widget _settingsCard(AppTheme t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: t.fill, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(t, '종류', _pink),
          const SizedBox(height: 10),
          Row(
            children: [
              _ruleChip(t, RaceRule.speed, '스피드'),
              const SizedBox(width: 10),
              _ruleChip(t, RaceRule.score, '지뢰 대결'),
              const SizedBox(width: 10),
              Expanded(child: _plainChip(t, '합동', onTap: () => _soon('합동'))),
            ],
          ),
          const SizedBox(height: 18),
          _sectionLabel(t, '난이도', _yellow),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final d in Difficulty.values) ...[
                _diffChip(t, d),
                if (d != Difficulty.values.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(AppTheme t, String s, Color dot) {
    return Row(
      children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(s,
            style: TextStyle(
                color: t.text, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _ruleChip(AppTheme t, RaceRule r, String label) {
    final selected = rule == r;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => rule = r),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _pink : t.fillElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: selected ? Colors.white : t.text,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _plainChip(AppTheme t, String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.fillElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                color: t.text, fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _diffChip(AppTheme t, Difficulty d) {
    final selected = difficulty == d;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => difficulty = d),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _yellow : t.fillElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(d.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: selected ? Colors.black : t.text,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ── 대전 방식 큰 카드 ──
  Widget _bigCard(AppTheme t, Color color, IconData icon, String title,
      String sub, VoidCallback onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _codeJoin(AppTheme t) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: t.text, fontSize: 16),
            decoration: InputDecoration(
              hintText: '코드로 참가 (예: ABC23…)',
              hintStyle: TextStyle(color: t.textTertiary),
              filled: true,
              fillColor: t.fill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: _joinByCode,
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: t.fill,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _joinByCode(_codeCtrl.text),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text('참가',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }
}
