import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/theme.dart';
import 'mail.dart';

/// 선물함 — 운영이 보낸 선물을 최신순으로, "받기"로 코인·아이템 지급. Swift MailListView 이식.
class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  final MailService _service = MailService();
  final LocalStore _s = LocalStore.shared;
  List<MailGift>? _gifts; // null = 로딩 중
  static const _accent = Color(0xFFF29E40);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.fetchActive();
      if (mounted) setState(() => _gifts = list);
    } catch (_) {
      if (mounted) setState(() => _gifts = const []);
    }
  }

  void _claim(MailGift g) {
    if (_s.isMailClaimed(g.id)) return;
    _s.grantMailReward(
        coins: g.coins,
        flags: g.flags,
        megaphones: g.megaphones,
        radars: g.radars);
    _s.markMailClaimed(g.id);
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text('${g.rewardSummary} 받았어요!'),
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
            _header(t),
            Expanded(child: _body(t)),
          ],
        ),
      ),
    );
  }

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
            child: Text('선물함',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.text, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _body(AppTheme t) {
    final gifts = _gifts;
    if (gifts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (gifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard, size: 44, color: t.textTertiary),
            const SizedBox(height: 12),
            Text('받을 선물이 없어요',
                style: TextStyle(color: t.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: gifts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _giftCard(t, gifts[i]),
    );
  }

  Widget _giftCard(AppTheme t, MailGift g) {
    final claimed = _s.isMailClaimed(g.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: claimed ? Colors.transparent : _accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: _accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(g.title,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(g.dateText,
              style: TextStyle(color: t.textTertiary, fontSize: 11)),
          if (g.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(g.body,
                style: TextStyle(color: t.textSecondary, fontSize: 14)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(g.rewardSummary,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              _claimButton(t, g, claimed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _claimButton(AppTheme t, MailGift g, bool claimed) {
    return Material(
      color: claimed ? t.fillElevated : _accent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: claimed ? null : () => _claim(g),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(claimed ? Icons.check : Icons.download,
                  size: 14, color: claimed ? t.textTertiary : Colors.white),
              const SizedBox(width: 5),
              Text(claimed ? '받음' : '받기',
                  style: TextStyle(
                      color: claimed ? t.textTertiary : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
