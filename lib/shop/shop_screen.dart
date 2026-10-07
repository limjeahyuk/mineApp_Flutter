import 'dart:async';

<<<<<<< HEAD
import 'package:flutter/cupertino.dart';
=======
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
<<<<<<< HEAD
import 'rewarded_ads.dart';

/// 상점 안의 두 화면 — 코인을 쓰는 뽑기 / 코인을 채우는 충전.
enum ShopTab {
  gacha('🎰 뽑기'),
  coins('🪙 충전');

  const ShopTab(this.label);
  final String label;
}

/// 코인 상점 시트 — Swift ShopView 이식.
=======
import 'shop_logic.dart';

/// 코인 상점 — Swift ShopView 이식. 잔액 + [🎰 뽑기 | 🪙 충전] 두 탭.
/// 뽑기: 결과 카드(단일 🎰 / ×3 슬롯 3릴) + 뽑기 버튼 + 획득 확률 + 보유 아이템.
/// 충전: 광고 보고 무료 코인(하루 한도). 광고는 시뮬레이션(실제 AdMob 미연동).
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.initialTab = ShopTab.gacha});
  final ShopTab initialTab;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

<<<<<<< HEAD
class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  final store = LocalStore.shared;
  late ShopTab tab = widget.initialTab;
  final _toast = GlobalKey<ToastHostState>();

  GachaItem? lastDrawn;
  late final AnimationController _pop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450), value: 1);
  late final AnimationController _nope = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));

  bool tripleActive = false;
  bool spinning = false;
  List<GachaItem> reelItems = [GachaItem.flag, GachaItem.flag, GachaItem.flag];
  List<bool> reelLanded = [false, false, false];
  TripleDrawResult? tripleResult;
  bool jackpotGlow = false;
  Timer? _spin;

  static const gold = AppTheme.gold;

  @override
  void initState() {
    super.initState();
    store.refreshDailyRewards();
    RewardedAdManager.shared.load(); // 버튼 누를 때쯤 차 있도록
  }

  @override
  void dispose() {
    _spin?.cancel();
    _pop.dispose();
    _nope.dispose();
    super.dispose();
  }

  void _showToast(String m) => _toast.currentState?.show(m);

=======
class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  final LocalStore _s = LocalStore.shared;
  final ShopLogic _shop = ShopLogic();
  final _toast = ToastController();
  late int _tab = widget.initialTab;

  GachaItem? _lastDrawn;
  int _popKey = 0; // 결과가 '팡' 튀는 연출 트리거
  late final AnimationController _nope = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));

  // ×3 슬롯
  bool _tripleActive = false;
  bool _spinning = false;
  List<GachaItem> _reelItems = [GachaItem.flag, GachaItem.flag, GachaItem.flag];
  List<bool> _reelLanded = [false, false, false];
  TripleDrawResult? _tripleResult;
  bool _jackpotGlow = false;
  Timer? _spinTimer;

  static const _gold = AppTheme.gold;

  @override
  void dispose() {
    _spinTimer?.cancel();
    _nope.dispose();
    _toast.dispose();
    super.dispose();
  }

>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '상점',
<<<<<<< HEAD
      child: ToastHost(
        key: _toast,
        child: ListenableBuilder(
          listenable: store,
          builder: (_, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(children: [
              _balanceCard(t),
              const SizedBox(height: 18),
              _tabPicker(t),
              const SizedBox(height: 18),
              if (tab == ShopTab.gacha) ...[
                _resultCard(t),
                const SizedBox(height: 18),
                _drawButtons(t),
                const SizedBox(height: 18),
                _odds(t),
                const SizedBox(height: 18),
                _inventory(t),
                const SizedBox(height: 18),
                _earnHint(t),
              ] else ...[
                _freeCoins(t),
                const SizedBox(height: 18),
                Text('코인은 계정 연동 시 클라우드에 안전하게 보관돼요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.textTertiary, fontSize: 11)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // MARK: 잔액 카드

  Widget _balanceCard(AppTheme t) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: gold.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6))
          ],
        ),
        child: Column(children: [
          Text('내 코인',
              style: TextStyle(
                  color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const GoldenMineIcon(size: 38),
            const SizedBox(width: 10),
            Text(fmt(store.coins),
                style: TextStyle(color: t.text, fontSize: 40, fontWeight: FontWeight.w900)),
          ]),
        ]),
      );

  Widget _tabPicker(AppTheme t) => SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<ShopTab>(
          groupValue: tab,
          children: {
            for (final s in ShopTab.values)
              s: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(s.label,
                    style: TextStyle(
                        color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
          },
          onValueChanged: (v) => setState(() => tab = v ?? tab),
        ),
      );

  // MARK: 무료 코인 — 광고 보상

  Widget _freeCoins(AppTheme t) {
    final remaining = store.remainingRewardedAds;
    final soldOut = remaining <= 0;
    const g1 = Color.fromRGBO(51, 168, 133, 1), g2 = Color.fromRGBO(41, 133, 107, 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionLabel('무료 코인', accent: AppTheme.multiAccent),
      const SizedBox(height: 10),
      Opacity(
        opacity: soldOut ? 0.7 : 1,
        child: Pressable(
          enabled: !soldOut,
          onTap: _watchAd,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: soldOut
                      ? [Colors.grey.withValues(alpha: 0.55), Colors.grey.withValues(alpha: 0.4)]
                      : const [g1, g2]),
              boxShadow: soldOut
                  ? null
                  : [
                      BoxShadow(
                          color: g2.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ],
            ),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.play_rectangle_fill,
                    size: 21, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('광고 보고 코인 받기',
                      style: TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(
                      soldOut
                          ? '오늘은 모두 받았어요 · 내일 다시!'
                          : '30초 광고 시청 시 +${LocalStore.adRewardCoins} 코인',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
              Column(children: [
                Text('$remaining/${LocalStore.dailyAdLimit}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('오늘 남음',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ]),
            ]),
          ),
        ),
=======
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: _s,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _balanceCard(t),
                  const SizedBox(height: 18),
                  SegmentedPicker<int>(
                    value: _tab,
                    items: const {0: '🎰 뽑기', 1: '🪙 충전'},
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                  const SizedBox(height: 18),
                  if (_tab == 0) ...[
                    _resultCard(t),
                    const SizedBox(height: 18),
                    _drawButtons(t),
                    const SizedBox(height: 18),
                    _oddsSection(t),
                    const SizedBox(height: 18),
                    _inventory(t),
                    const SizedBox(height: 18),
                    _earnHint(t),
                  ] else ...[
                    _freeCoinsSection(t),
                    const SizedBox(height: 18),
                    Text('코인은 계정 연동 시 클라우드에 안전하게 보관돼요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.textTertiary, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ),
          ToastOverlay(
              controller: _toast,
              padding: const EdgeInsets.only(bottom: 30),
              fontSize: 14),
        ],
      ),
    );
  }

  // MARK: 잔액 카드

  Widget _balanceCard(AppTheme t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _gold.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          Text('내 코인',
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GoldenMineIcon(size: 38),
              const SizedBox(width: 10),
              Text(formatNumber(_s.coins),
                  style: TextStyle(
                      color: t.text,
                      fontSize: 40,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ],
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
      ),
      const SizedBox(height: 10),
      Text('하루 ${LocalStore.dailyAdLimit}번까지 광고를 보고 코인을 받을 수 있어요.',
          style: TextStyle(color: t.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }

  void _watchAd() {
    Haptics.tap();
    void reward() {
      final r = store.claimRewardedAd();
      if (r != null) _showToast('🪙 +$r 코인 받았어요!');
    }

    final presented = RewardedAdManager.shared.present(reward);
    if (!presented) {
      // 광고 미준비(개발/오프라인) → 시뮬레이션 폴백.
      Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        fullscreenDialog: true,
        pageBuilder: (ctx, _, _) => _SimulatedAd(onReward: () {
          Navigator.of(ctx).pop();
          reward();
        }),
      ));
    }
  }

  // MARK: 결과 카드

  Widget _resultCard(AppTheme t) {
    return AnimatedBuilder(
      animation: _nope,
      builder: (_, c) => Transform.rotate(angle: _nope.value * 4 * 3.14159 / 180, child: c),
      child: tripleActive ? _tripleCard(t) : _singleCard(t),
    );
  }

<<<<<<< HEAD
  Widget _cardFrame({required Widget child, bool glow = false}) => Container(
        height: 196,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [gold.withValues(alpha: glow ? 0.45 : 0.22), gold.withValues(alpha: 0.06)]),
          border: Border.all(
              color: gold.withValues(alpha: glow ? 0.95 : 0.45), width: glow ? 2.5 : 1.5),
          boxShadow: [
            BoxShadow(
                color: gold.withValues(alpha: glow ? 0.5 : 0.25),
                blurRadius: glow ? 26 : 18,
                offset: const Offset(0, 6))
          ],
        ),
        child: child,
      );

  Widget _singleCard(AppTheme t) {
    final it = lastDrawn;
    return Column(children: [
      _cardFrame(
        child: Center(
          child: ScaleTransition(
            scale: Tween(begin: 0.7, end: 1.0)
                .animate(CurvedAnimation(parent: _pop, curve: Curves.elasticOut)),
            child: Text(it?.emoji ?? '🎰', style: const TextStyle(fontSize: 88)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(it?.itemName ?? '무엇이 나올까?',
          style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Text(it?.blurb ?? '코인을 써서 아이템을 뽑아보세요',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }

  String get _tripleHeadline {
    if (spinning) return '두근두근…';
    final r = tripleResult;
    if (r == null) return '×3 뽑기';
    return r.jackpot ? '잭팟! 🎉' : '획득 완료!';
  }

  String get _tripleBlurb {
    if (spinning) return '슬롯 3개가 모두 같으면 잭팟!';
    final r = tripleResult;
    if (r == null) return '';
    if (r.jackpot) return '모든 아이템을 3개씩 받았어요!';
    return '${r.reels.map((e) => '${e.emoji} ${e.itemName}').join(' · ')} 획득!';
  }

  Widget _tripleCard(AppTheme t) {
    return Column(children: [
      _cardFrame(
        glow: jackpotGlow,
        child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _reel(t, i),
            ],
          ]),
          if (jackpotGlow)
            Positioned(
              top: -14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                        color: gold.withValues(alpha: 0.6),
                        blurRadius: 12,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: const Text('✨ 잭팟 ✨',
                    style: TextStyle(
                        color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Text(_tripleHeadline,
          style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Text(_tripleBlurb,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: jackpotGlow ? gold : t.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _reel(AppTheme t, int i) {
    final landed = reelLanded[i];
    return AnimatedScale(
      duration: const Duration(milliseconds: 250),
      curve: Curves.elasticOut,
      scale: landed ? 1.0 : 0.9,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: landed ? 1 : 0.8,
        child: Container(
          width: 78,
          height: 108,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: landed ? gold : t.border.withValues(alpha: 0.4),
                width: landed ? 2.5 : 1),
          ),
          child: Text(reelItems[i].emoji, style: const TextStyle(fontSize: 50)),
        ),
      ),
    );
  }

  // MARK: 뽑기 버튼

  Widget _drawButtons(AppTheme t) => Opacity(
        opacity: spinning ? 0.6 : 1,
        child: Row(children: [
          Expanded(
              child: _drawButton(t, '뽑기', LocalStore.drawCost, store.canDraw, false,
                  _performDraw)),
          const SizedBox(width: 12),
          Expanded(
              child: _drawButton(t, '×3 뽑기', LocalStore.tripleDrawCost,
                  store.canDrawTriple, true, _performTripleDraw)),
        ]),
      );

  Widget _drawButton(AppTheme t, String title, int cost, bool enabled, bool primary,
      VoidCallback onTap) {
    return Pressable(
      enabled: enabled && !spinning,
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: enabled ? null : t.fill,
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: primary
                        ? const [gold, Color.fromRGBO(237, 153, 41, 1)]
                        : [gold, gold.withValues(alpha: 0.82)])
                : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                        color: gold.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ]
                : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title,
                style: TextStyle(
                    color: enabled ? Colors.white : t.textTertiary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const GoldenMineIcon(size: 13),
              const SizedBox(width: 4),
              Text('$cost',
                  style: TextStyle(
                      color: (enabled ? Colors.white : t.textTertiary)
                          .withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        if (primary)
          Positioned(
            top: -7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 2,
                      offset: const Offset(0, 1))
=======
  Widget _sectionLabel(AppTheme t, String text, Color accent) => Row(children: [
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

  // MARK: 무료 코인 — 광고 보상

  Widget _freeCoinsSection(AppTheme t) {
    final remaining = _s.remainingRewardedAds;
    final soldOut = remaining <= 0;
    const green1 = Color.fromRGBO(51, 168, 133, 1);
    const green2 = Color.fromRGBO(41, 133, 107, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(t, '무료 코인', AppTheme.multiAccent),
        const SizedBox(height: 10),
        PlainButton(
          onTap: soldOut ? null : _watchRewardedAd,
          child: Opacity(
            opacity: soldOut ? 0.7 : 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: soldOut
                      ? [
                          Colors.grey.withValues(alpha: 0.55),
                          Colors.grey.withValues(alpha: 0.4)
                        ]
                      : const [green1, green2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: soldOut
                    ? null
                    : [
                        BoxShadow(
                            color: green2.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.smart_display,
                        size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('광고 보고 코인 받기',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(
                            soldOut
                                ? '오늘은 모두 받았어요 · 내일 다시!'
                                : '30초 광고 시청 시 +${LocalStore.adRewardCoins} 코인',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text('$remaining/${LocalStore.dailyAdLimit}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text('오늘 남음',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
                ],
              ),
              child: const Text('잭팟 찬스',
                  style: TextStyle(
                      color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
            ),
          ),
<<<<<<< HEAD
      ]),
    );
  }

  // MARK: 획득 확률

  static String _pct(double p) =>
      p == p.roundToDouble() ? '${p.toInt()}%' : '${p.toStringAsFixed(1)}%';

  Widget _odds(AppTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('획득 확률', accent: gold),
        const SizedBox(height: 8),
        for (final it in GachaItem.values) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration:
                BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Text(it.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(it.itemName,
                  style: TextStyle(
                      color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_pct(it.drawPercent),
                  style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        Text('아이템은 위 확률에 따라 무작위로 지급돼요.',
            style: TextStyle(color: t.textTertiary, fontSize: 11)),
        const SizedBox(height: 8),
        const Text('×3 뽑기는 위 확률로 3번 뽑아요. 슬롯 3개가 모두 같으면 잭팟! 모든 아이템을 3개씩 드려요.',
            style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w600)),
      ]);

  int _owned(GachaItem it) => switch (it) {
        GachaItem.flag => store.ownedFlags,
        GachaItem.megaphone => store.ownedMegaphones,
        GachaItem.radar => store.ownedRadars,
      };

  Widget _inventory(AppTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('보유 아이템', accent: gold),
        const SizedBox(height: 10),
        for (final it in GachaItem.values) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration:
                BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Text(it.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.itemName,
                      style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(it.blurb,
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                ]),
              ),
              Text('×${_owned(it)}',
                  style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ]);

  Widget _earnHint(AppTheme t) => Column(children: [
        if (!store.canDraw) ...[
          const Text('코인이 부족해요 · 충전 탭에서 채울 수 있어요',
              style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
        ],
        Text(
            '코인은 솔로 클리어(초급 1·중급 5·고급 10·최고급 20)와\n황금지뢰 발견(+${LocalStore.goldenMineReward})으로도 모을 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
      ]);

  // MARK: 동작

  void _performDraw() {
    if (spinning) return;
    final it = store.draw();
    if (it == null) {
      _coinShort();
      return;
    }
    Haptics.success();
    setState(() {
      tripleActive = false;
      lastDrawn = it;
    });
    _pop.forward(from: 0);
    _showToast('${it.emoji} ${it.itemName} 획득!');
  }

  void _performTripleDraw() {
    if (spinning) return;
    final r = store.drawTriple();
    if (r == null) {
      _coinShort();
      return;
    }
    Haptics.tap();
    const all = GachaItem.values;
    setState(() {
      tripleActive = true;
      tripleResult = r;
      jackpotGlow = false;
      reelLanded = [false, false, false];
      reelItems = [for (var i = 0; i < 3; i++) all[i % all.length]];
      spinning = true;
    });
    // 0.08초마다 굴리다 0.9 / 1.4 / 1.9초에 왼쪽부터 멈춘다.
    final landAt = [900, 1400, 1900];
    final started = DateTime.now();
    _spin?.cancel();
    _spin = Timer.periodic(const Duration(milliseconds: 80), (tm) {
      if (!mounted) return tm.cancel();
      final el = DateTime.now().difference(started).inMilliseconds;
      setState(() {
        for (var i = 0; i < 3; i++) {
          if (reelLanded[i]) continue;
          if (el >= landAt[i]) {
            reelLanded[i] = true;
            reelItems[i] = r.reels[i];
            Haptics.tap();
          } else {
            reelItems[i] = all[(all.indexOf(reelItems[i]) + 1) % all.length];
          }
        }
      });
      if (!reelLanded.contains(false)) {
        tm.cancel();
        _finishTriple(r);
      }
    });
  }

  void _finishTriple(TripleDrawResult r) {
    setState(() => spinning = false);
    Haptics.success();
    if (r.jackpot) {
      setState(() => jackpotGlow = true);
      _showToast('🎉 잭팟! 모든 아이템 3개씩 획득!');
    } else {
      _showToast('${r.reels.map((e) => e.emoji).join(' ')} 획득!');
    }
  }

  void _coinShort() {
    Haptics.tap();
    _nope.forward(from: 0).then((_) => _nope.reverse()).then((_) => _nope.forward()).then((_) => _nope.reverse());
  }
}

/// 보상형 광고 시뮬레이션 — 실제 광고가 준비 안 됐을 때 폴백(4초 카운트다운 → 자동 지급).
class _SimulatedAd extends StatefulWidget {
  const _SimulatedAd({required this.onReward});
  final VoidCallback onReward;

  @override
  State<_SimulatedAd> createState() => _SimulatedAdState();
}

class _SimulatedAdState extends State<_SimulatedAd> {
  static const duration = 4;
  int secondsLeft = duration;
  bool finished = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft <= 1) {
        t.cancel();
        setState(() {
          secondsLeft = 0;
          finished = true;
        });
        widget.onReward();
        return;
      }
      setState(() => secondsLeft--);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.yellow, borderRadius: BorderRadius.circular(5)),
                child: const Text('AD',
                    style: TextStyle(
                        color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              if (!finished)
                Text('$secondsLeft초',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
            ]),
            const Spacer(),
            const Text('💣', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 14),
            const Text('지뢰 마스터',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Text('광고 미리보기',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            LinearProgressIndicator(
              value: (duration - secondsLeft) / duration,
              color: AppTheme.gold,
              backgroundColor: Colors.white24,
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (finished) ...[
                const Icon(CupertinoIcons.checkmark_circle_fill, size: 14, color: AppTheme.gold),
                const SizedBox(width: 6),
              ],
              Text(
                  finished
                      ? '+${LocalStore.adRewardCoins} 코인을 지급했어요!'
                      : '광고를 끝까지 보면 코인을 받아요',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 12),
            Text('실제 광고는 출시 버전에서 표시됩니다',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
=======
        ),
        const SizedBox(height: 10),
        Text('하루 ${LocalStore.dailyAdLimit}번까지 광고를 보고 코인을 받을 수 있어요.',
            style: TextStyle(
                color: t.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    );
  }

  Future<void> _watchRewardedAd() async {
    Haptics.tap();
    await Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      fullscreenDialog: true,
      pageBuilder: (ctx, _, _) => _RewardedAdView(onReward: () {
        Navigator.of(ctx).pop();
        final reward = _s.claimRewardedAd();
        if (reward != null) _toast.show('🪙 +$reward 코인 받았어요!');
      }),
    ));
  }

  // MARK: 결과 카드

  Widget _resultCard(AppTheme t) {
    return AnimatedBuilder(
      animation: _nope,
      builder: (_, child) => Transform.rotate(
          angle: (_nope.value < 0.5 ? _nope.value : 1 - _nope.value) *
              2 *
              0.07,
          child: child),
      child: _tripleActive ? _tripleResultCard(t) : _singleResultCard(t),
    );
  }

  BoxDecoration _cardDeco({bool glow = false}) => BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _gold.withValues(alpha: glow ? 0.45 : 0.22),
            _gold.withValues(alpha: 0.06)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: _gold.withValues(alpha: glow ? 0.95 : 0.45),
            width: glow ? 2.5 : 1.5),
        boxShadow: [
          BoxShadow(
              color: _gold.withValues(alpha: glow ? 0.5 : 0.25),
              blurRadius: glow ? 26 : 18,
              offset: const Offset(0, 6))
        ],
      );

  Widget _singleResultCard(AppTheme t) {
    final item = _lastDrawn;
    return Column(
      children: [
        Container(
          height: 196,
          alignment: Alignment.center,
          decoration: _cardDeco(),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_popKey),
            tween: Tween(begin: _popKey == 0 ? 1.0 : 0.7, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Text(item?.emoji ?? '🎰',
                style: const TextStyle(fontSize: 88, height: 1.1)),
          ),
        ),
        const SizedBox(height: 12),
        Text(item?.itemName ?? '무엇이 나올까?',
            style: TextStyle(
                color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(item?.blurb ?? '코인을 써서 아이템을 뽑아보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _tripleResultCard(AppTheme t) {
    return Column(
      children: [
        SizedBox(
          height: 196,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: _cardDeco(glow: _jackpotGlow),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      _reelCell(t, i),
                    ],
                  ],
                ),
              ),
              if (_jackpotGlow)
                Positioned(
                  top: 98 - 74 - 18,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: _gold,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                              color: _gold.withValues(alpha: 0.6),
                              blurRadius: 12,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: const Text('✨ 잭팟 ✨',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(_tripleHeadline,
            style: TextStyle(
                color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(_tripleBlurb,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _jackpotGlow ? _gold : t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _reelCell(AppTheme t, int i) {
    final landed = _reelLanded[i];
    return AnimatedScale(
      scale: landed ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 250),
      curve: Curves.elasticOut,
      child: Opacity(
        opacity: landed ? 1 : 0.8,
        child: Container(
          width: 78,
          height: 108,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: landed ? _gold : t.border.withValues(alpha: 0.4),
                width: landed ? 2.5 : 1),
          ),
          child: Text(_reelItems[i].emoji, style: const TextStyle(fontSize: 50)),
        ),
      ),
    );
  }

  String get _tripleHeadline {
    if (_spinning) return '두근두근…';
    final r = _tripleResult;
    if (r == null) return '×3 뽑기';
    return r.jackpot ? '잭팟! 🎉' : '획득 완료!';
  }

  String get _tripleBlurb {
    if (_spinning) return '슬롯 3개가 모두 같으면 잭팟!';
    final r = _tripleResult;
    if (r == null) return '';
    if (r.jackpot) return '모든 아이템을 3개씩 받았어요!';
    return '${r.reels.map((e) => '${e.emoji} ${e.itemName}').join(' · ')} 획득!';
  }

  // MARK: 뽑기 버튼

  Widget _drawButtons(AppTheme t) {
    return Opacity(
      opacity: _spinning ? 0.6 : 1,
      child: Row(
        children: [
          Expanded(
            child: _drawButton(t,
                title: '뽑기',
                cost: LocalStore.drawCost,
                enabled: _s.coins >= LocalStore.drawCost,
                primary: false,
                onTap: _performDraw),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _drawButton(t,
                title: '×3 뽑기',
                cost: LocalStore.tripleDrawCost,
                enabled: _s.coins >= LocalStore.tripleDrawCost,
                primary: true,
                onTap: _performTripleDraw),
          ),
        ],
      ),
    );
  }

  Widget _drawButton(AppTheme t,
      {required String title,
      required int cost,
      required bool enabled,
      required bool primary,
      required VoidCallback onTap}) {
    final fg = enabled ? Colors.white : t.textTertiary;
    return PlainButton(
      onTap: (!enabled || _spinning) ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: enabled ? null : t.fill,
              gradient: enabled
                  ? LinearGradient(
                      colors: primary
                          ? const [_gold, Color.fromRGBO(237, 153, 41, 1)]
                          : [_gold, _gold.withValues(alpha: 0.82)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                          color: _gold.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: TextStyle(
                        color: fg, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GoldenMineIcon(size: 13),
                    const SizedBox(width: 4),
                    Text('$cost',
                        style: TextStyle(
                            color: fg.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          if (primary)
            Positioned(
              top: -7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 2,
                        offset: const Offset(0, 1))
                  ],
                ),
                child: const Text('잭팟 찬스',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }

  // MARK: 획득 확률 (루트박스 확률 공개)

  static String _formatPercent(double p) => p == p.roundToDouble()
      ? '${p.toInt()}%'
      : '${p.toStringAsFixed(1)}%';

  Widget _oddsSection(AppTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(t, '획득 확률', _gold),
        for (final item in GachaItem.values) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Text(item.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(item.itemName,
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_formatPercent(item.drawPercent),
                  style: TextStyle(
                      color: t.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Text('아이템은 위 확률에 따라 무작위로 지급돼요.',
            style: TextStyle(color: t.textTertiary, fontSize: 11)),
        const SizedBox(height: 8),
        const Text('×3 뽑기는 위 확률로 3번 뽑아요. 슬롯 3개가 모두 같으면 잭팟! 모든 아이템을 3개씩 드려요.',
            style: TextStyle(
                color: _gold, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // MARK: 보유 아이템

  int _owned(GachaItem item) => switch (item) {
        GachaItem.flag => _s.ownedFlags,
        GachaItem.megaphone => _s.ownedMegaphones,
        GachaItem.radar => _s.ownedRadars,
      };

  Widget _inventory(AppTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(t, '보유 아이템', _gold),
        for (final item in GachaItem.values) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Text(item.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(item.blurb,
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Text('×${_owned(item)}',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _earnHint(AppTheme t) {
    return Column(
      children: [
        if (_s.coins < LocalStore.drawCost) ...[
          const Text('코인이 부족해요 · 충전 탭에서 채울 수 있어요',
              style: TextStyle(
                  color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
        ],
        Text(
            '코인은 솔로 클리어(초급 1·중급 5·고급 10·최고급 20)와\n황금지뢰 발견(+${LocalStore.goldenMineReward})으로도 모을 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: t.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // MARK: 동작

  void _performDraw() {
    if (_spinning) return;
    final item = _shop.draw();
    if (item == null) {
      _coinShortFeedback();
      return;
    }
    Haptics.success();
    setState(() {
      _tripleActive = false;
      _lastDrawn = item;
      _popKey++;
    });
    _toast.show('${item.emoji} ${item.itemName} 획득!');
  }

  void _performTripleDraw() {
    if (_spinning) return;
    final result = _shop.drawTriple();
    if (result == null) {
      _coinShortFeedback();
      return;
    }
    Haptics.tap();
    const all = GachaItem.values;
    setState(() {
      _tripleActive = true;
      _tripleResult = result;
      _jackpotGlow = false;
      _reelLanded = [false, false, false];
      _reelItems = [for (var i = 0; i < 3; i++) all[i % all.length]];
      _spinning = true;
    });
    // 슬롯 3릴을 빠르게 굴리다 0.9 / 1.4 / 1.9초에 왼쪽부터 순차로 멈춘다.
    const landAt = [0.9, 1.4, 1.9];
    final startedAt = DateTime.now();
    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final elapsed =
          DateTime.now().difference(startedAt).inMilliseconds / 1000;
      setState(() {
        for (var i = 0; i < 3; i++) {
          if (_reelLanded[i]) continue;
          if (elapsed >= landAt[i]) {
            _reelLanded[i] = true;
            _reelItems[i] = result.reels[i];
            Haptics.tap();
          } else {
            final idx = all.indexOf(_reelItems[i]);
            _reelItems[i] = all[(idx + 1) % all.length];
          }
        }
      });
      if (!_reelLanded.contains(false)) {
        timer.cancel();
        _finishTriple(result);
      }
    });
  }

  void _finishTriple(TripleDrawResult result) {
    Haptics.success();
    setState(() {
      _spinning = false;
      if (result.jackpot) _jackpotGlow = true;
    });
    _toast.show(result.jackpot
        ? '🎉 잭팟! 모든 아이템 3개씩 획득!'
        : '${result.reels.map((e) => e.emoji).join(' ')} 획득!');
  }

  void _coinShortFeedback() {
    Haptics.tap();
    _nope.forward(from: 0);
  }
}

/// 보상형 광고(시뮬레이션) — 짧은 카운트다운 후 자동으로 보상 지급. Swift RewardedAdView 이식.
class _RewardedAdView extends StatefulWidget {
  const _RewardedAdView({required this.onReward});
  final VoidCallback onReward;

  @override
  State<_RewardedAdView> createState() => _RewardedAdViewState();
}

class _RewardedAdViewState extends State<_RewardedAdView> {
  static const _duration = 4;
  int _secondsLeft = _duration;
  bool _finished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) {
        t.cancel();
        setState(() => _finished = true);
        widget.onReward(); // 끝까지 봤으니 곧바로 보상 지급 + 닫기
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 끝나기 전엔 닫기 불가 → 보상 보장
      child: Material(
        color: Colors.black.withValues(alpha: 0.94),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.yellow,
                        borderRadius: BorderRadius.circular(5)),
                    child: const Text('AD',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
                  const Spacer(),
                  if (!_finished)
                    Text('$_secondsLeft초',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                ]),
                const Spacer(),
                const Text('💣', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 14),
                const Text('지뢰 마스터',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Text('광고 미리보기',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_duration - _secondsLeft) / _duration,
                    color: AppTheme.gold,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_finished) ...[
                    const Icon(Icons.check_circle,
                        size: 14, color: AppTheme.gold),
                    const SizedBox(width: 6),
                  ],
                  Text(
                      _finished
                          ? '+${LocalStore.adRewardCoins} 코인을 지급했어요!'
                          : '광고를 끝까지 보면 코인을 받아요',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 12),
                Text('실제 광고는 출시 버전에서 표시됩니다',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
