import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../game/game_screen.dart';
import '../mail/mail_screen.dart';
import '../multiplayer/versus_menu_screen.dart';
import '../profile/profile_screen.dart';
import '../progression/achievements_screen.dart';
import '../ranking/ranking_screen.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';

/// 홈 화면 — Swift StartView 이식. 상단바(알림·선물·코인·상점) + 타이틀 +
/// 솔로/멀티 카드 + 하단 내비(가이드·랭킹·업적·내정보·설정).
///
/// ponytail: 가이드만 아직 미이식(탭 시 "준비 중"). 우편/랭킹/업적/내정보/설정/상점은 이식됨.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _openShop(int tab) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShopScreen(initialTab: tab)));
    if (mounted) setState(() {}); // 코인 잔액 갱신
  }

  void _soon(BuildContext c, String name) {
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text('$name — 준비 중이에요'),
          duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context, t),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _titleBlock(t),
                        const SizedBox(height: 36),
                        _modeCard(
                          t,
                          emoji: '🎯',
                          title: '솔로 플레이',
                          subtitle: '초급 · 중급 · 고급 난이도 도전',
                          color: AppTheme.soloAccent,
                          onTap: () => _pickSolo(context),
                        ),
                        const SizedBox(height: 12),
                        _modeCard(
                          t,
                          emoji: '🏁',
                          title: '멀티 플레이',
                          subtitle: '지뢰찾기 · 보물찾기 온라인 대전',
                          color: AppTheme.multiAccent,
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const VersusMenuScreen())),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _bottomNav(context, t),
          ],
        ),
      ),
    );
  }

  // ── 상단바 ──
  Widget _topBar(BuildContext c, AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _circleBtn(t, Icons.notifications_none, () => _soon(c, '알림')),
          const SizedBox(width: 10),
          _circleBtn(t, Icons.redeem, () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MailScreen()))
                .then((_) {
              if (mounted) setState(() {}); // 코인/아이템 수령 반영
            });
          }, badge: true),
          const Spacer(),
          _coinPill(c, t),
          const SizedBox(width: 10),
          _circleBtn(t, Icons.shopping_bag_outlined, () => _openShop(0)),
        ],
      ),
    );
  }

  Widget _circleBtn(AppTheme t, IconData icon, VoidCallback onTap,
      {bool badge = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: t.fill,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
                width: 44, height: 44, child: Icon(icon, color: t.text, size: 22)),
          ),
        ),
        if (badge)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30), shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }

  Widget _coinPill(BuildContext c, AppTheme t) {
    const gold = Color(0xFFF4C13B);
    return Material(
      color: t.fill,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openShop(1),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          decoration: BoxDecoration(
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
        ),
      ),
    );
  }

  // ── 하단 내비 ──
  Widget _bottomNav(BuildContext c, AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(t, Icons.menu_book, '가이드', () => _soon(c, '가이드')),
          _navItem(t, Icons.emoji_events, '랭킹', () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RankingScreen()));
          }),
          _navItem(t, Icons.workspace_premium, '업적', () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AchievementsScreen()));
          }),
          _navItem(t, Icons.person, '내 정보', () async {
            await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()));
            if (mounted) setState(() {}); // 닉네임·잔액 변동 반영
          }),
          _navItem(t, Icons.settings, '설정', () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
        ],
      ),
    );
  }

  Widget _navItem(AppTheme t, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
              child: Icon(icon, color: t.textSecondary, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(color: t.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _titleBlock(AppTheme t) {
    return Column(
      children: [
        const Text('💣', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 10),
        Text('지뢰 찾기',
            style: TextStyle(
                color: t.text, fontSize: 34, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('플레이 모드를 선택하세요',
            style: TextStyle(color: t.textSecondary, fontSize: 15)),
      ],
    );
  }

  void _pickSolo(BuildContext context) {
    final t = AppTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Text('솔로 플레이',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.text, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('난이도를 선택하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textSecondary, fontSize: 14)),
              const SizedBox(height: 16),
              for (final d in Difficulty.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: t.fill,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => GameScreen(initialDifficulty: d)));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 18),
                        child: Row(
                          children: [
                            Text(d.label,
                                style: TextStyle(
                                    color: t.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text('${d.rows}×${d.cols} · 지뢰 ${d.mineCount}',
                                style: TextStyle(
                                    color: t.textSecondary, fontSize: 15)),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right,
                                color: t.textTertiary, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeCard(
    AppTheme t, {
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: t.fill,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.textTertiary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
