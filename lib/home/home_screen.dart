import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/deep_link.dart';
import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../game/game_screen.dart';
import '../guide/guide_screen.dart';
import '../guide/practice.dart';
import '../mail/mail.dart';
import '../mail/mail_screen.dart';
import '../multiplayer/versus_menu_screen.dart';
import '../notice/notice.dart';
import '../notice/notice_popup.dart';
import '../notice/notice_screen.dart';
import '../profile/profile_screen.dart';
import '../progression/achievements_screen.dart';
import '../ranking/ranking_screen.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';

/// 홈 — Swift StartView 이식. 상단(공지·선물 | 코인·상점) + 타이틀 + 솔로/멀티 카드 + 아이콘 행.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _gold = AppTheme.gold;
  final store = LocalStore.shared;

  @override
  void initState() {
    super.initState();
    // 홈 진입 시 선물함을 한 번 불러와 안 받은 선물 뱃지를 띄운다.
    MailStore.shared.reload();
    // 방 초대 딥링크 — 콜드 런치(이미 도착)·웜 런치(나중 도착) 모두 소비한다.
    DeepLinkRouter.shared.addListener(_consumeDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeDeepLink());
  }

  @override
  void dispose() {
    DeepLinkRouter.shared.removeListener(_consumeDeepLink);
    super.dispose();
  }

  void _consumeDeepLink() {
    if (!mounted || DeepLinkRouter.shared.value == null) return;
    final p = DeepLinkRouter.shared.take()!;
    // 다른 화면 위에 있으면 홈까지 닫고 방으로 들어간다(원본: 화면 정체성을 바꿔 새 매칭).
    Navigator.of(context).popUntil((r) => r.isFirst);
    launchJoin(context, p.$1, p.$2);
  }

  void _openShop(ShopTab tab) =>
      presentSheet(context, (_) => ShopScreen(initialTab: tab));

  void _sheet(Widget Function() page) => presentSheet(context, (_) => page());

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: t.bg,
          body: ListenableBuilder(
            listenable: Listenable.merge([
              store,
              NoticeStore.shared,
              MailStore.shared,
            ]),
            builder: (context, _) => SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _topBar(t),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _titleBlock(t),
                                    const SizedBox(height: 24 + 16),
                                    _modeCards(t),
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
                  ),
                ],
              ),
            ),
          ),
        ),
        // 시작 공지 팝업 — 홈에서만(게임 중엔 가린다).
        ListenableBuilder(
          listenable: NoticeStore.shared,
          builder: (_, _) {
            final n = NoticeStore.shared.popup;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: n == null
                  ? const SizedBox.shrink()
                  : NoticePopup(notice: n),
            );
          },
        ),
      ],
    );
  }

  // MARK: 메인 — 솔로 / 멀티 카드

  Widget _modeCards(AppTheme t) {
    return Column(
      children: [
        Stack(
          children: [
            _modeCard(
              t,
              emoji: '🎯',
              title: '솔로 플레이',
              subtitle: '초급 · 중급 · 고급 난이도 도전',
              color: AppTheme.soloAccent,
              onTap: _pickSolo,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PracticeHelpButton(
                onTap: () => openPractice(context, OnboardKind.solo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _modeCard(
          t,
          emoji: '🏁',
          title: '멀티 플레이',
          subtitle: '지뢰찾기 · 보물찾기 온라인 대전',
          color: AppTheme.multiAccent,
          onTap: () =>
              Navigator.of(context).push(coverRoute(const VersusMenuScreen())),
        ),
      ],
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
    return Pressable(
      haptic: true,
      onTap: onTap,
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
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: t.text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 15, color: t.textTertiary),
          ],
        ),
      ),
    );
  }

  // MARK: 아이콘 행 — 가이드 / 랭킹 / 업적 / 내 정보 / 설정

  Widget _iconRow(AppTheme t) {
    return Row(
      children: [
        _iconButton(
          t,
          CupertinoIcons.book_fill,
          '가이드',
          () => _sheet(() => const GuideScreen()),
        ),
        const SizedBox(width: 12),
        _iconButton(
          t,
          Icons.emoji_events,
          '랭킹',
          () => _sheet(() => const RankingScreen()),
        ),
        const SizedBox(width: 12),
        _iconButton(
          t,
          CupertinoIcons.rosette,
          '업적',
          () => _sheet(() => const AchievementsScreen()),
          badge: store.dailyClaimableCount > 0,
        ),
        const SizedBox(width: 12),
        _iconButton(
          t,
          CupertinoIcons.person_fill,
          '내 정보',
          () => _sheet(() => const ProfileScreen()),
        ),
        const SizedBox(width: 12),
        _iconButton(
          t,
          CupertinoIcons.gear_alt_fill,
          '설정',
          () => _sheet(() => const SettingsScreen()),
        ),
      ],
    );
  }

  Widget _iconButton(
    AppTheme t,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool badge = false,
  }) {
    return Expanded(
      child: Pressable(
        haptic: true,
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: t.fill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 19, color: t.textSecondary),
                ),
                if (badge)
                  Positioned(top: -1, right: -1, child: _dot(t, 11, 2)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(AppTheme t, double size, double stroke) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.red,
      shape: BoxShape.circle,
      border: Border.all(color: t.bg, width: stroke),
    ),
  );

  // MARK: 상단 바 — 공지·선물 | 코인·상점

  Widget _topBar(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          _circleButton(t, CupertinoIcons.bell_fill, () {
            _sheet(() => const NoticeScreen());
          }, badge: NoticeStore.shared.hasUnread),
          const SizedBox(width: 8),
          _circleButton(t, CupertinoIcons.gift_fill, () {
            _sheet(() => const MailScreen());
          }, badge: MailStore.shared.hasUnclaimed),
          const Spacer(),
          _coinChip(t),
          const SizedBox(width: 8),
          _circleButton(
            t,
            CupertinoIcons.bag_fill,
            () => _openShop(ShopTab.gacha),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
    AppTheme t,
    IconData icon,
    VoidCallback onTap, {
    bool badge = false,
  }) {
    return Pressable(
      haptic: true,
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
          if (badge) Positioned(top: -1, right: -1, child: _dot(t, 9, 1.5)),
        ],
      ),
    );
  }

  Widget _coinChip(AppTheme t) {
    return Pressable(
      haptic: true,
      onTap: () => _openShop(ShopTab.coins),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoldenMineIcon(size: 17),
            const SizedBox(width: 7),
            Text(
              fmt(store.coins),
              style: TextStyle(
                color: t.text,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 7),
            const Icon(CupertinoIcons.plus_circle_fill, size: 17, color: _gold),
          ],
        ),
      ),
    );
  }

  // MARK: 타이틀

  Widget _titleBlock(AppTheme t) {
    return Column(
      children: [
        const Text('💣', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 8),
        Text(
          '지뢰 찾기',
          style: TextStyle(
            color: t.text,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '플레이 모드를 선택하세요',
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // MARK: 솔로 난이도 선택(하프 시트)

  void _pickSolo() {
    final t = AppTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => DifficultyPicker(
        title: '솔로 플레이',
        onPick: (d) {
          Navigator.pop(ctx);
          pushGameWithOnboarding(
            context,
            OnboardKind.solo,
            () => GameScreen(initialDifficulty: d),
            landscape: d.prefersLandscape,
          );
        },
      ),
    );
  }
}

/// 솔로 플레이 시작 전 난이도 선택 시트(원본 DifficultyPicker).
class DifficultyPicker extends StatelessWidget {
  const DifficultyPicker({
    super.key,
    required this.title,
    required this.onPick,
  });
  final String title;
  final void Function(Difficulty) onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: t.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '난이도를 선택하세요',
            style: TextStyle(color: t.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (final d in Difficulty.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: () {
                  Haptics.tap();
                  onPick(d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: t.fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        d.label,
                        style: TextStyle(
                          color: t.text,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${d.rows}×${d.cols} · 지뢰 ${d.mineCount}',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 13,
                        color: t.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
