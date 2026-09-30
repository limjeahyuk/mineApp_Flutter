import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../game/game_screen.dart';
import '../guide/guide_screen.dart';
import '../mail/mail.dart';
import '../mail/mail_screen.dart';
import '../multiplayer/versus_menu_screen.dart';
import '../notice/notice.dart';
import '../notice/notice_popup.dart';
import '../notice/notice_screen.dart';
import '../profile/profile_screen.dart';
import '../progression/achievements_screen.dart';
import '../progression/daily.dart';
import '../ranking/ranking_screen.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';

/// 시작 페이지 — Swift StartView 이식.
/// 상단(공지 종·선물함 | 코인 칩·상점) + 타이틀 + 솔로/멀티 카드 + 아이콘 행(가이드·랭킹·업적·내 정보·설정).
/// 각 화면은 원본처럼 시트로, 멀티 메뉴는 전체 화면으로 연다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _noticeDot = false;
  bool _mailDot = false;

  static const contentMaxWidth = 460.0;
  static const gold = Color.fromRGBO(242, 199, 77, 1); // (0.95,0.78,0.30)

  @override
  void initState() {
    super.initState();
    _checkNotices();
    _checkMail();
  }

  Future<void> _checkNotices() async {
    try {
      final list = await NoticeService().fetchActive();
      if (!mounted) return;
      final last = LocalStore.shared.noticeLastSeen;
      setState(() => _noticeDot = list.any((n) => n.date.isAfter(last)));
      for (final n in list) {
        if (n.showPopup && !LocalStore.shared.isNoticeDismissedToday(n.id)) {
          await showNoticePopup(context, n);
          break;
        }
      }
    } catch (_) {/* 오프라인 — 점만 안 뜸 */}
  }

  Future<void> _checkMail() async {
    try {
      final list = await MailService().fetchActive();
      if (!mounted) return;
      setState(() => _mailDot =
          list.any((m) => !LocalStore.shared.isMailClaimed(m.id)));
    } catch (_) {}
  }

  Future<void> _sheet(Widget page) async {
    Haptics.tap();
    await showAppSheet<void>(context, (_) => page);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(t),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Center(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: contentMaxWidth),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _titleBlock(t),
                            const SizedBox(height: 24 + 16),
                            _modeCard(t,
                                emoji: '🎯',
                                title: '솔로 플레이',
                                subtitle: '초급 · 중급 · 고급 난이도 도전',
                                color: AppTheme.soloAccent,
                                onTap: _pickSolo),
                            const SizedBox(height: 12),
                            _modeCard(t,
                                emoji: '🏁',
                                title: '멀티 플레이',
                                subtitle: '지뢰찾기 · 보물찾기 온라인 대전',
                                color: AppTheme.multiAccent, onTap: () async {
                              await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      fullscreenDialog: true,
                                      builder: (_) =>
                                          const VersusMenuScreen()));
                              if (mounted) setState(() {});
                            }),
                            const SizedBox(height: 16 + 4),
                            _iconRow(t),
                          ],
                        ),
                      ),
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

  // ── 상단 바 ──
  Widget _topBar(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          _roundChip(t, SF.bellFill, badge: _noticeDot, onTap: () async {
            await _sheet(const NoticeScreen());
            if (mounted) setState(() => _noticeDot = false);
          }),
          const SizedBox(width: 8),
          _roundChip(t, SF.giftFill, badge: _mailDot, onTap: () async {
            await _sheet(const MailScreen());
            _checkMail();
          }),
          const Spacer(),
          _coinChip(t),
          const SizedBox(width: 8),
          _roundChip(t, SF.bagFill,
              onTap: () => _sheet(const ShopScreen(initialTab: 0))),
        ],
      ),
    );
  }

  Widget _badgeDot(AppTheme t, double size, double stroke) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30),
          shape: BoxShape.circle,
          border: Border.all(color: t.bg, width: stroke),
        ),
      );

  Widget _roundChip(AppTheme t, IconData icon,
      {bool badge = false, required VoidCallback onTap}) {
    return Tap(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: t.text),
          ),
          if (badge)
            Positioned(right: -1, top: -1, child: _badgeDot(t, 9, 1.5)),
        ],
      ),
    );
  }

  Widget _coinChip(AppTheme t) {
    return Tap(
      onTap: () => _sheet(const ShopScreen(initialTab: 1)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoldenMineIcon(size: 17),
            const SizedBox(width: 7),
            Text(fmt(LocalStore.shared.coins),
                style: sf(15, weight: W.bold, color: t.text)),
            const SizedBox(width: 7),
            const Icon(SF.plusCircleFill, size: 17, color: gold),
          ],
        ),
      ),
    );
  }

  // ── 타이틀 ──
  Widget _titleBlock(AppTheme t) {
    return Column(
      children: [
        const Text('💣', style: TextStyle(fontSize: 52, height: 1.15)),
        const SizedBox(height: 8),
        Text('지뢰 찾기', style: sf(30, weight: W.heavy, color: t.text)),
        const SizedBox(height: 8),
        Text('플레이 모드를 선택하세요',
            style: sf(14, weight: W.medium, color: t.textSecondary)),
      ],
    );
  }

  Widget _modeCard(AppTheme t,
      {required String emoji,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return Tap(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: rr(16, color.withValues(alpha: 0.20)),
              child: Text(emoji, style: const TextStyle(fontSize: 30, height: 1.1)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: sf(20, weight: W.bold, color: t.text)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: sf(13, weight: W.medium, color: t.textSecondary)),
                ],
              ),
            ),
            Icon(SF.chevronRight, size: 15, color: t.textTertiary),
          ],
        ),
      ),
    );
  }

  // ── 아이콘 행 ──
  Widget _iconRow(AppTheme t) {
    return Row(
      children: [
        _iconButton(t, SF.bookFill, '가이드', () => _sheet(const GuideScreen())),
        const SizedBox(width: 12),
        _iconButton(t, SF.trophyFill, '랭킹', () => _sheet(const RankingScreen())),
        const SizedBox(width: 12),
        _iconButton(t, SF.rosette, '업적', () => _sheet(const AchievementsScreen()),
            badge: Daily.claimableCount() > 0),
        const SizedBox(width: 12),
        _iconButton(t, SF.personFill, '내 정보', () => _sheet(const ProfileScreen())),
        const SizedBox(width: 12),
        _iconButton(t, SF.gearFill, '설정', () => _sheet(const SettingsScreen())),
      ],
    );
  }

  Widget _iconButton(AppTheme t, IconData icon, String label, VoidCallback onTap,
      {bool badge = false}) {
    return Expanded(
      child: Tap(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
                  child: Icon(icon, size: 19, color: t.textSecondary),
                ),
                if (badge)
                  Positioned(right: -1, top: -1, child: _badgeDot(t, 11, 2)),
              ],
            ),
            const SizedBox(height: 6),
            Text(label, style: sf(11, weight: W.medium, color: t.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── 솔로 난이도 선택 시트 ──
  void _pickSolo() {
    showAppSheet<void>(
      context,
      full: false,
      (ctx) {
        final t = AppTheme.of(ctx);
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.5,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 36,
                height: 5,
                decoration: rr(3, t.border),
              ),
              const SizedBox(height: 16),
              Text('솔로 플레이', style: sf(18, weight: W.bold, color: t.text)),
              const SizedBox(height: 4),
              Text('난이도를 선택하세요', style: sf(13, color: t.textSecondary)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final d in Difficulty.values) ...[
                        Tap(
                          onTap: () {
                            Haptics.tap();
                            Navigator.pop(ctx);
                            Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (_) => GameScreen(initialDifficulty: d)))
                                .then((_) {
                              if (mounted) setState(() {});
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                            decoration: rr(12, t.fill),
                            child: Row(
                              children: [
                                Text(d.label,
                                    style: sf(17, weight: W.bold, color: t.text)),
                                const Spacer(),
                                Text('${d.rows}×${d.cols} · 지뢰 ${d.mineCount}',
                                    style: sf(13,
                                        weight: W.medium, color: t.textSecondary)),
                                const SizedBox(width: 4 + 4),
                                Icon(SF.chevronRight,
                                    size: 13, color: t.textTertiary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
