import 'dart:async';

import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import '../core/ui.dart';
import 'shop_logic.dart';

/// 코인 상점 — Swift ShopView 이식. 잔액 카드 + (뽑기 | 충전) 세그먼트.
/// 광고는 시뮬레이션(RewardedAdView) — 실제 AdMob 미이식.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.initialTab = 0});
  final int initialTab; // 0=뽑기, 1=충전

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with ToastMixin {
  late int tab = widget.initialTab;
  final _logic = ShopLogic();

  GachaItem? lastDrawn;
  bool pop = false;
  bool nope = false;

  bool tripleActive = false;
  bool spinning = false;
  List<GachaItem> reelItems = [GachaItem.flag, GachaItem.flag, GachaItem.flag];
  List<bool> reelLanded = [false, false, false];
  TripleDrawResult? tripleResult;
  bool jackpotGlow = false;
  Timer? _spin;

  static const gold = Color.fromRGBO(242, 199, 77, 1);
  static const orange = Color.fromRGBO(237, 153, 41, 1); // (0.93,0.60,0.16)

  LocalStore get store => LocalStore.shared;

  @override
  void dispose() {
    _spin?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '상점',
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _balanceCard(t),
                const SizedBox(height: 18),
                Segmented(
                    labels: const ['🎰 뽑기', '🪙 충전'],
                    index: tab,
                    onChanged: (i) => setState(() => tab = i)),
                const SizedBox(height: 18),
                if (tab == 0) ...[
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
                      style: sf(11, color: t.textTertiary)),
                ],
              ],
            ),
          ),
          toastOverlay(),
        ],
      ),
    );
  }

  Widget _balanceCard(AppTheme t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: gold.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(children: [
        Text('내 코인', style: sf(13, weight: W.semibold, color: t.textSecondary)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const GoldenMineIcon(size: 38),
          const SizedBox(width: 10),
          Text(fmt(store.coins), style: sf(40, weight: W.heavy, color: t.text, height: 1.1)),
        ]),
      ]),
    );
  }

  // ── 충전 ──
  Widget _freeCoinsSection(AppTheme t) {
    final remaining = store.remainingRewardedAds;
    final soldOut = remaining <= 0;
    const g1 = Color.fromRGBO(51, 168, 133, 1), g2 = Color.fromRGBO(41, 133, 107, 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      dotLabel(t, '무료 코인', AppTheme.multiAccent),
      const SizedBox(height: 10),
      Opacity(
        opacity: soldOut ? 0.7 : 1,
        child: Tap(
          onTap: soldOut ? null : _watchAd,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: soldOut
                    ? [Colors.grey.withValues(alpha: 0.55), Colors.grey.withValues(alpha: 0.4)]
                    : const [g1, g2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: soldOut
                  ? null
                  : [BoxShadow(color: g2.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 5))],
            ),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                child: const Icon(SF.playRectFill, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('광고 보고 코인 받기',
                      style: sf(16, weight: W.bold, color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(
                      soldOut
                          ? '오늘은 모두 받았어요 · 내일 다시!'
                          : '30초 광고 시청 시 +${LocalStore.adRewardCoins} 코인',
                      style: sf(12,
                          weight: W.medium,
                          color: Colors.white.withValues(alpha: 0.9))),
                ]),
              ),
              Column(children: [
                Text('$remaining/${LocalStore.dailyAdLimit}',
                    style: sf(16, weight: W.heavy, color: Colors.white)),
                const SizedBox(height: 2),
                Text('오늘 남음',
                    style: sf(10,
                        weight: W.medium,
                        color: Colors.white.withValues(alpha: 0.85))),
              ]),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text('하루 ${LocalStore.dailyAdLimit}번까지 광고를 보고 코인을 받을 수 있어요.',
          style: sf(11, weight: W.medium, color: t.textTertiary)),
    ]);
  }

  Future<void> _watchAd() async {
    Haptics.tap();
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      fullscreenDialog: true,
      pageBuilder: (_, _, _) => RewardedAdView(onReward: () {
        Navigator.of(context).pop();
        final r = store.claimRewardedAd();
        if (r != null) showToast('🪙 +$r 코인 받았어요!');
      }),
    ));
    if (mounted) setState(() {});
  }

  // ── 뽑기 ──
  Widget _goldCard({required Widget child, bool glow = false}) => Container(
        height: 196,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [gold.withValues(alpha: glow ? 0.45 : 0.22), gold.withValues(alpha: 0.06)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
              color: gold.withValues(alpha: glow ? 0.95 : 0.45), width: glow ? 2.5 : 1.5),
          boxShadow: [
            BoxShadow(
                color: gold.withValues(alpha: glow ? 0.5 : 0.25),
                blurRadius: glow ? 52 : 36,
                offset: const Offset(0, 6))
          ],
        ),
        child: child,
      );

  Widget _resultCard(AppTheme t) {
    final card = tripleActive ? _tripleCard(t) : _singleCard(t);
    return AnimatedRotation(
        turns: nope ? 4 / 360 : 0,
        duration: const Duration(milliseconds: 80),
        child: card);
  }

  Widget _singleCard(AppTheme t) {
    return Column(children: [
      _goldCard(
        child: Center(
          child: AnimatedScale(
            scale: pop ? 1 : 0.7,
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            child: Text(lastDrawn?.emoji ?? '🎰',
                style: const TextStyle(fontSize: 88, height: 1.1)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(lastDrawn?.itemName ?? '무엇이 나올까?',
          style: sf(18, weight: W.bold, color: t.text)),
      const SizedBox(height: 12),
      Text(lastDrawn?.blurb ?? '코인을 써서 아이템을 뽑아보세요',
          textAlign: TextAlign.center,
          style: sf(13, weight: W.medium, color: t.textSecondary)),
    ]);
  }

  Widget _tripleCard(AppTheme t) {
    String headline, blurb;
    final r = tripleResult;
    if (spinning) {
      headline = '두근두근…';
      blurb = '슬롯 3개가 모두 같으면 잭팟!';
    } else if (r == null) {
      headline = '×3 뽑기';
      blurb = '';
    } else {
      headline = r.jackpot ? '잭팟! 🎉' : '획득 완료!';
      blurb = r.jackpot
          ? '모든 아이템을 3개씩 받았어요!'
          : '${r.reels.map((e) => '${e.emoji} ${e.itemName}').join(' · ')} 획득!';
    }
    return Column(children: [
      _goldCard(
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
              top: 98 - 74 - 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.6), blurRadius: 24, offset: const Offset(0, 3))],
                ),
                child: Text('✨ 잭팟 ✨', style: sf(22, weight: W.heavy, color: Colors.black)),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Text(headline, style: sf(18, weight: W.bold, color: t.text)),
      const SizedBox(height: 12),
      Text(blurb,
          textAlign: TextAlign.center,
          style: sf(13, weight: W.medium, color: jackpotGlow ? gold : t.textSecondary)),
    ]);
  }

  Widget _reel(AppTheme t, int i) {
    final landed = reelLanded[i];
    return AnimatedScale(
      scale: landed ? 1 : 0.9,
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
                color: landed ? gold : t.border.withValues(alpha: 0.4),
                width: landed ? 2.5 : 1),
          ),
          child: Text(reelItems[i].emoji, style: const TextStyle(fontSize: 50, height: 1.1)),
        ),
      ),
    );
  }

  Widget _drawButtons(AppTheme t) {
    return Opacity(
      opacity: spinning ? 0.6 : 1,
      child: Row(children: [
        Expanded(
            child: _drawButton(t, '뽑기', LocalStore.drawCost,
                store.coins >= LocalStore.drawCost, false, _performDraw)),
        const SizedBox(width: 12),
        Expanded(
            child: _drawButton(t, '×3 뽑기', LocalStore.tripleDrawCost,
                store.coins >= LocalStore.tripleDrawCost, true, _performTriple)),
      ]),
    );
  }

  Widget _drawButton(AppTheme t, String title, int cost, bool enabled, bool primary,
      VoidCallback action) {
    final fg = enabled ? Colors.white : t.textTertiary;
    return Tap(
      onTap: (!enabled || spinning) ? null : action,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: enabled ? null : t.fill,
            gradient: enabled
                ? LinearGradient(
                    colors: primary ? const [gold, orange] : [gold, gold.withValues(alpha: 0.82)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)
                : null,
            boxShadow: enabled
                ? [BoxShadow(color: gold.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 5))]
                : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, style: sf(17, weight: W.heavy, color: fg)),
            const SizedBox(height: 3),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const GoldenMineIcon(size: 13),
              const SizedBox(width: 4),
              Text('$cost', style: sf(13, weight: W.semibold, color: fg.withValues(alpha: fg.a * 0.95))),
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
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Text('잭팟 찬스', style: sf(9, weight: W.heavy, color: Colors.black)),
            ),
          ),
      ]),
    );
  }

  String _pct(double p) => p == p.roundToDouble() ? '${p.toInt()}%' : '${p.toStringAsFixed(1)}%';

  Widget _oddsSection(AppTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      dotLabel(t, '획득 확률', gold),
      for (final item in GachaItem.values) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: rr(10, t.fill),
          child: Row(children: [
            Text(item.emoji, style: const TextStyle(fontSize: 18, height: 1.2)),
            const SizedBox(width: 10),
            Text(item.itemName, style: sf(13, weight: W.semibold, color: t.textSecondary)),
            const Spacer(),
            Text(_pct(item.drawPercent), style: sf(13, weight: W.heavy, color: t.text)),
          ]),
        ),
      ],
      const SizedBox(height: 8),
      Text('아이템은 위 확률에 따라 무작위로 지급돼요.', style: sf(11, color: t.textTertiary)),
      const SizedBox(height: 8),
      Text('×3 뽑기는 위 확률로 3번 뽑아요. 슬롯 3개가 모두 같으면 잭팟! 모든 아이템을 3개씩 드려요.',
          style: sf(11, weight: W.semibold, color: gold)),
    ]);
  }

  int _owned(GachaItem i) => switch (i) {
        GachaItem.flag => store.ownedFlags,
        GachaItem.megaphone => store.ownedMegaphones,
        GachaItem.radar => store.ownedRadars,
      };

  Widget _inventory(AppTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      dotLabel(t, '보유 아이템', gold),
      for (final item in GachaItem.values) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: rr(12, t.fill),
          child: Row(children: [
            Text(item.emoji, style: const TextStyle(fontSize: 26, height: 1.2)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.itemName, style: sf(15, weight: W.bold, color: t.text)),
                const SizedBox(height: 2),
                Text(item.blurb, style: sf(11, weight: W.medium, color: t.textSecondary)),
              ]),
            ),
            Text('×${_owned(item)}', style: sf(18, weight: W.heavy, color: t.text)),
          ]),
        ),
      ],
    ]);
  }

  Widget _earnHint(AppTheme t) {
    return Column(children: [
      if (store.coins < LocalStore.drawCost) ...[
        Text('코인이 부족해요 · 충전 탭에서 채울 수 있어요',
            style: sf(12, weight: W.bold, color: gold)),
        const SizedBox(height: 4),
      ],
      Text(
          '코인은 솔로 클리어(초급 1·중급 5·고급 10·최고급 20)와\n황금지뢰 발견(+${LocalStore.goldenMineReward})으로도 모을 수 있어요',
          textAlign: TextAlign.center,
          style: sf(11, weight: W.medium, color: t.textTertiary)),
    ]);
  }

  // ── 동작 ──
  void _coinShort() {
    Haptics.tap();
    setState(() => nope = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => nope = false);
    });
  }

  void _performDraw() {
    if (spinning) return;
    final item = _logic.draw();
    if (item == null) return _coinShort();
    Haptics.success();
    setState(() {
      tripleActive = false;
      lastDrawn = item;
      pop = false;
    });
    Future.microtask(() {
      if (mounted) setState(() => pop = true);
    });
    showToast('${item.emoji} ${item.itemName} 획득!');
  }

  void _performTriple() {
    if (spinning) return;
    final result = _logic.drawTriple();
    if (result == null) return _coinShort();
    Haptics.tap();
    final all = GachaItem.values;
    setState(() {
      tripleActive = true;
      tripleResult = result;
      jackpotGlow = false;
      reelLanded = [false, false, false];
      reelItems = [for (var i = 0; i < 3; i++) all[i % all.length]];
      spinning = true;
    });
    const landAt = [900, 1400, 1900];
    var ticks = 0;
    _spin?.cancel();
    _spin = Timer.periodic(const Duration(milliseconds: 80), (tm) {
      if (!mounted) return tm.cancel();
      final elapsed = ++ticks * 80;
      setState(() {
        for (var i = 0; i < 3; i++) {
          if (reelLanded[i]) continue;
          if (elapsed >= landAt[i]) {
            reelLanded[i] = true;
            reelItems[i] = result.reels[i];
            Haptics.tap();
          } else {
            reelItems[i] = all[(all.indexOf(reelItems[i]) + 1) % all.length];
          }
        }
      });
      if (!reelLanded.contains(false)) {
        tm.cancel();
        setState(() => spinning = false);
        Haptics.success();
        if (result.jackpot) {
          setState(() => jackpotGlow = true);
          showToast('🎉 잭팟! 모든 아이템 3개씩 획득!');
        } else {
          showToast('${result.reels.map((e) => e.emoji).join(' ')} 획득!');
        }
      }
    });
  }
}

/// 보상형 광고(시뮬레이션) — Swift RewardedAdView 이식. 4초 카운트다운 후 자동 지급.
class RewardedAdView extends StatefulWidget {
  const RewardedAdView({super.key, required this.onReward});
  final VoidCallback onReward;

  @override
  State<RewardedAdView> createState() => _RewardedAdViewState();
}

class _RewardedAdViewState extends State<RewardedAdView> {
  static const duration = 4;
  int secondsLeft = duration;
  bool finished = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (!mounted) return tm.cancel();
      setState(() => secondsLeft--);
      if (secondsLeft <= 0) {
        tm.cancel();
        setState(() => finished = true);
        widget.onReward();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color.fromRGBO(242, 199, 77, 1);
    final white = Colors.white;
    return Material(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: rr(5, Colors.yellow),
                child: Text('AD', style: sf(12, weight: W.heavy, color: Colors.black)),
              ),
              const Spacer(),
              if (!finished)
                Text('$secondsLeft초',
                    style: sf(13, weight: W.semibold, color: white.withValues(alpha: 0.7))),
            ]),
            const Spacer(),
            const Text('💣', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 14),
            Text('지뢰 마스터', style: sf(24, weight: W.heavy, color: white)),
            const SizedBox(height: 14),
            Text('광고 미리보기',
                style: sf(13, weight: W.medium, color: white.withValues(alpha: 0.55))),
            const Spacer(),
            LinearProgressIndicator(
              value: (duration - secondsLeft) / duration,
              color: gold,
              backgroundColor: white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (finished) ...[
                const Icon(SF.checkCircleFill, color: gold, size: 14),
                const SizedBox(width: 6),
              ],
              Text(
                  finished
                      ? '+${LocalStore.adRewardCoins} 코인을 지급했어요!'
                      : '광고를 끝까지 보면 코인을 받아요',
                  style: sf(12, weight: W.medium, color: white.withValues(alpha: 0.7))),
            ]),
            const SizedBox(height: 12),
            Text('실제 광고는 출시 버전에서 표시됩니다',
                style: sf(10, weight: W.medium, color: white.withValues(alpha: 0.4))),
          ]),
        ),
      ),
    );
  }
}
