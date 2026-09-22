import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/types.dart';
import 'shop_logic.dart';

/// 코인 상점 — 뽑기(코인으로 아이템) + 충전(광고 보고 무료 코인). Swift ShopView 이식.
///
/// ponytail: 실제 AdMob·IAP는 미이식. 무료 코인은 시뮬(즉시 지급, 하루 5회),
/// 유료 코인팩은 "준비 중". x3 슬롯머신 연출은 결과 요약으로 대체.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.initialTab = 0});
  final int initialTab; // 0=뽑기, 1=충전

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab =
      TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  final ShopLogic _shop = ShopLogic();
  final LocalStore _s = LocalStore.shared;

  GachaItem? _lastDrawn;
  bool _jackpot = false;
  List<GachaItem>? _lastReels;

  static const _gold = Color(0xFFF4C13B);
  static const _green = Color(0xFF33A07E);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  void _draw() {
    final item = _shop.draw();
    if (item == null) {
      _toast('코인이 부족해요 (${LocalStore.drawCost}🪙 필요)');
      return;
    }
    setState(() {
      _lastDrawn = item;
      _lastReels = null;
      _jackpot = false;
    });
    _toast('${item.emoji} ${item.itemName} 획득!');
  }

  void _drawTriple() {
    final r = _shop.drawTriple();
    if (r == null) {
      _toast('코인이 부족해요 (${LocalStore.tripleDrawCost}🪙 필요)');
      return;
    }
    setState(() {
      _lastReels = r.reels;
      _lastDrawn = null;
      _jackpot = r.jackpot;
    });
    _toast(r.jackpot ? '🎉 잭팟! 모든 아이템 3개씩!' : '×3 뽑기 완료!');
  }

  void _watchAd() {
    final reward = _s.claimRewardedAd();
    if (reward == null) {
      _toast('오늘 무료 코인을 모두 받았어요');
      return;
    }
    setState(() {});
    _toast('🪙 +$reward 코인 받았어요!');
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
            TabBar(
              controller: _tab,
              indicatorColor: _gold,
              labelColor: t.text,
              unselectedLabelColor: t.textSecondary,
              tabs: const [Tab(text: '🎰 뽑기'), Tab(text: '🪙 충전')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [_gachaTab(t), _coinsTab(t)],
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
            child: Text('상점',
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('☀️', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text('${_s.coins}',
              style: TextStyle(
                  color: t.text, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── 뽑기 탭 ──
  Widget _gachaTab(AppTheme t) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _resultCard(t),
        const SizedBox(height: 20),
        Text('획득 가능 아이템',
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        for (final it in GachaItem.values) ...[
          _poolCard(t, it),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _drawButton(t, '뽑기', LocalStore.drawCost, _draw,
                  color: AppTheme.soloAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _drawButton(
                  t, '×3 뽑기', LocalStore.tripleDrawCost, _drawTriple,
                  color: AppTheme.multiAccent),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultCard(AppTheme t) {
    if (_jackpot && _lastReels != null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFF4C13B), Color(0xFFE85C8B)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_lastReels!.map((e) => e.emoji).join(' '),
                style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            const Text('🎉 잭팟! 모든 아이템 3개씩',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    final String big;
    final String label;
    if (_lastReels != null) {
      big = _lastReels!.map((e) => e.emoji).join(' ');
      label = '×3 뽑기 완료';
    } else if (_lastDrawn != null) {
      big = _lastDrawn!.emoji;
      label = '${_lastDrawn!.itemName} 획득!';
    } else {
      big = '🎁';
      label = '코인으로 아이템을 뽑아보세요';
    }
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: t.fill, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(big, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _poolCard(AppTheme t, GachaItem it) {
    final owned = switch (it) {
      GachaItem.flag => _s.ownedFlags,
      GachaItem.megaphone => _s.ownedMegaphones,
      GachaItem.radar => _s.ownedRadars,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: t.fill, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: t.fillElevated,
                borderRadius: BorderRadius.circular(12)),
            child: Text(it.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(it.itemName,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('보유 $owned',
                        style:
                            TextStyle(color: t.textTertiary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(it.blurb,
                    style: TextStyle(color: t.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${it.drawPercent.round()}%',
              style: TextStyle(
                  color: _gold, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _drawButton(
      AppTheme t, String title, int cost, VoidCallback onTap,
      {required Color color}) {
    final canAfford = _s.coins >= cost;
    return Opacity(
      opacity: canAfford ? 1 : 0.6,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('☀️ $cost',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 충전 탭 ──
  Widget _coinsTab(AppTheme t) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('무료 코인',
            style: TextStyle(
                color: _green, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Material(
          color: _green,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _watchAd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    child: const Icon(Icons.ondemand_video,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('광고 보고 +${LocalStore.adRewardCoins} 코인',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('오늘 남은 횟수 ${_s.remainingRewardedAds}/${LocalStore.dailyAdLimit}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.white, size: 24),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('코인 팩',
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: t.fill, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(Icons.shopping_cart_outlined, color: t.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text('유료 코인 팩은 준비 중이에요',
                    style: TextStyle(color: t.textSecondary, fontSize: 14)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
