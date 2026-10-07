import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../game/game_screen.dart';
import '../guide/guide_screen.dart';
import '../guide/practice.dart';
import '../mail/mail.dart';
import '../mail/mail_screen.dart';
import '../modes/coop_screen.dart';
import '../modes/treasure_screen.dart';
import '../multiplayer/match_widgets.dart' show InviteLink;
import '../multiplayer/multiplayer.dart';
import '../multiplayer/versus_menu_screen.dart';
import '../multiplayer/versus_screen.dart';
import '../notice/notice.dart';
import '../notice/notice_popup.dart';
import '../notice/notice_screen.dart';
import '../profile/profile_screen.dart';
import '../progression/achievements_screen.dart';
import '../progression/daily.dart';
import '../ranking/ranking_screen.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';

/// 시작 페이지 — Swift StartView 이식. 솔로 / 멀티 두 갈래 + 아이콘 행(가이드·랭킹·업적·내 정보·설정).
/// 상단 바: 왼쪽 공지 종 + 선물함, 오른쪽 코인 칩 + 상점.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocalStore _s = LocalStore.shared;
  List<Notice> _notices = [];
  List<MailGift> _gifts = [];

  static const _contentMaxWidth = 460.0;
  static const _gold = AppTheme.gold;

  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _loadNotices();
    _reloadMail();
    _listenDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  /// 방 초대 딥링크(mineapp://join?g=…&c=…) — 콜드/웜 런치 모두 해당 방으로 바로 들어간다.
  /// (Swift DeepLinkRouter: 다른 화면에 있었다면 그 화면을 닫고 새 방으로 전환)
  void _listenDeepLinks() {
    try {
      final links = AppLinks();
      _linkSub = links.uriLinkStream.listen(_openInvite, onError: (_) {});
    } catch (_) {/* 플랫폼 미지원(테스트 등) */}
  }

  void _openInvite(Uri uri) {
    if (uri.scheme.toLowerCase() != InviteLink.scheme || !mounted) return;
    final parsed = InviteLink.parse(uri);
    if (parsed == null) return;
    final (game, code) = parsed;
    final mode = RaceMode.join(code);
    final Widget screen = switch (game) {
      'treasure' => TreasureScreen(mode: mode),
      'touch' => CoopScreen(mode: mode),
      _ => VersusScreen(mode: mode),
    };
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    nav.push(fadeRoute((_) => screen));
  }

  /// 시작 시 한 번 공지를 불러와 오늘 아직 안 막은 첫 팝업 공지를 띄운다.
  Future<void> _loadNotices() async {
    try {
      final list = await NoticeService().fetchActive();
      if (!mounted) return;
      setState(() => _notices = list);
      for (final n in list) {
        if (n.showPopup && !_s.isNoticeDismissedToday(n.id)) {
          await showNoticePopup(context, n);
          break;
        }
      }
    } catch (_) {/* 조용히 무시 — 종 점만 안 뜸 */}
  }

  /// 홈 진입 시 선물함을 불러와 안 받은 선물 뱃지를 띄운다.
  Future<void> _reloadMail() async {
    try {
      final list = await MailService().fetchActive();
      if (mounted) setState(() => _gifts = list);
    } catch (_) {}
  }

  bool get _hasUnreadNotice {
    final last = _s.noticeLastSeen;
    return _notices.any((n) => n.date.isAfter(last));
  }

  bool get _hasUnclaimedMail => _gifts.any((g) => !_s.isMailClaimed(g.id));

  Future<void> _openShop(int tab) =>
      presentSheet(context, (_) => ShopScreen(initialTab: tab));

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: ListenableBuilder(
        listenable: _s,
        builder: (context, _) => SafeArea(
          child: Column(
            children: [
              _topBar(t),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: _contentMaxWidth),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 24),
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
    );
  }

  // MARK: 상단 바

  Widget _topBar(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          _circleChip(t, Icons.notifications, badge: _hasUnreadNotice,
              onTap: () async {
            await presentSheet(context, (_) => const NoticeScreen());
            if (mounted) setState(() {});
          }),
          const SizedBox(width: 8),
          _circleChip(t, Icons.card_giftcard, badge: _hasUnclaimedMail,
              onTap: () async {
            await presentSheet(context, (_) => const MailScreen());
            if (mounted) setState(() {});
          }),
          const Spacer(),
          _coinChip(t),
          const SizedBox(width: 8),
          _circleChip(t, Icons.shopping_bag, onTap: () => _openShop(0)),
        ],
      ),
    );
  }

  Widget _badgeDot(AppTheme t, double size, double stroke) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: t.bg, width: stroke),
        ),
      );

  Widget _circleChip(AppTheme t, IconData icon,
      {bool badge = false, required VoidCallback onTap}) {
    return PlainButton(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: t.text),
          ),
          if (badge)
            Positioned(right: -1, top: -1, child: _badgeDot(t, 9, 1.5)),
        ],
      ),
    );
  }

  /// 코인 칩 — 잔액을 보여주고, 누르면 충전 탭이 열린다.
  Widget _coinChip(AppTheme t) {
    return PlainButton(
      onTap: () {
        Haptics.tap();
        _openShop(1);
      },
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
            Text(formatNumber(_s.coins),
                style: TextStyle(
                    color: t.text, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(width: 7),
            const Icon(Icons.add_circle, size: 18, color: _gold),
          ],
        ),
      ),
    );
  }

  // MARK: 타이틀

  Widget _titleBlock(AppTheme t) {
    return Column(
      children: [
        const Text('💣', style: TextStyle(fontSize: 52, height: 1.15)),
        const SizedBox(height: 8),
        Text('지뢰 찾기',
            style: TextStyle(
                color: t.text, fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('플레이 모드를 선택하세요',
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // MARK: 솔로 / 멀티 카드

  Widget _modeCards(AppTheme t) => Column(
        children: [
          Stack(children: [
            _modeCard(t,
                emoji: '🎯',
                title: '솔로 플레이',
                subtitle: '초급 · 중급 · 고급 난이도 도전',
                color: AppTheme.soloAccent,
                onTap: _pickSolo),
            Positioned(
              top: 0,
              right: 0,
              child: PracticeHelpButton(
                  onTap: () => openPractice(context, OnboardKind.solo)),
            ),
          ]),
          const SizedBox(height: 12),
          _modeCard(t,
              emoji: '🏁',
              title: '멀티 플레이',
              subtitle: '지뢰찾기 · 보물찾기 온라인 대전',
              color: AppTheme.multiAccent,
              onTap: () =>
                  presentFullScreen(context, (_) => const VersusMenuScreen())),
        ],
      );

  Widget _modeCard(AppTheme t,
      {required String emoji,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return PlainButton(
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
                  Text(title,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  // MARK: 아이콘 행 — 가이드 / 랭킹 / 업적 / 내 정보 / 설정

  Widget _iconRow(AppTheme t) {
    return Row(
      children: [
        _iconButton(t, Icons.menu_book, '가이드',
            () => presentSheet(context, (_) => const GuideScreen())),
        const SizedBox(width: 12),
        _iconButton(t, Icons.emoji_events, '랭킹',
            () => presentSheet(context, (_) => const RankingScreen())),
        const SizedBox(width: 12),
        _iconButton(t, Icons.workspace_premium, '업적',
            () => presentSheet(context, (_) => const AchievementsScreen()),
            badge: Daily.claimableCount > 0),
        const SizedBox(width: 12),
        _iconButton(t, Icons.person, '내 정보',
            () => presentSheet(context, (_) => const ProfileScreen())),
        const SizedBox(width: 12),
        _iconButton(t, Icons.settings, '설정',
            () => presentSheet(context, (_) => const SettingsScreen())),
      ],
    );
  }

  Widget _iconButton(AppTheme t, IconData icon, String label,
      VoidCallback onTap,
      {bool badge = false}) {
    return Expanded(
      child: PlainButton(
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                      BoxDecoration(color: t.fill, shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: t.textSecondary),
                ),
                if (badge)
                  Positioned(right: -1, top: -1, child: _badgeDot(t, 11, 2)),
              ],
            ),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // MARK: 솔로 난이도 선택 시트

  void _pickSolo() {
    presentMediumSheet<void>(
      context,
      (ctx) {
        final t = AppTheme.of(ctx);
        return SingleChildScrollView(
          child: Column(
            children: [
              Text('솔로 플레이',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('난이도를 선택하세요',
                  style: TextStyle(color: t.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final d in Difficulty.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PlainButton(
                          onTap: () {
                            Haptics.tap();
                            Navigator.pop(ctx);
                            pushGameWithOnboarding(context, OnboardKind.solo,
                                () => GameScreen(initialDifficulty: d),
                                landscape: d.prefersLandscape);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                            decoration: BoxDecoration(
                                color: t.fill,
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Text(d.label,
                                    style: TextStyle(
                                        color: t.text,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text('${d.rows}×${d.cols} · 지뢰 ${d.mineCount}',
                                    style: TextStyle(
                                        color: t.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right,
                                    color: t.textTertiary, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
