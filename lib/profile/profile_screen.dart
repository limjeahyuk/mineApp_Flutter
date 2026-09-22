import 'package:flutter/material.dart' hide Title;

import '../core/board.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../progression/title.dart';

/// 내 정보 화면 — 닉네임(변경) + 장착 칭호 + 보유(코인·아이템) + 난이도별 솔로 기록.
/// Swift StartView.ProfileView 이식.
///
/// ponytail: 계정 연동(Apple/Google)·계정 삭제는 플랫폼 연동 미이식이라 생략.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalStore _s = LocalStore.shared;

  Title? get _equippedTitle {
    final id = _s.equippedTitleId;
    for (final t in Title.all) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _s.nickname);
    final t = AppTheme.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('닉네임 변경', style: TextStyle(color: t.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 16,
          style: TextStyle(color: t.text),
          decoration: const InputDecoration(
              hintText: '닉네임', helperText: '랭킹에 표시될 이름이에요 (최대 16자)'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('저장')),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      _s.nickname = trimmed.length > 16 ? trimmed.substring(0, 16) : trimmed;
      setState(() {});
    }
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _profileHeader(t),
                  const SizedBox(height: 22),
                  _walletSection(t),
                  const SizedBox(height: 22),
                  _recordList(t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppTheme t) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
        child: Row(
          children: [
            Material(
              color: t.fill,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.close, color: t.textSecondary, size: 20)),
              ),
            ),
            Expanded(
              child: Text('내 정보',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.text, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 40),
          ],
        ),
      );

  Widget _profileHeader(AppTheme t) {
    final title = _equippedTitle;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
          child: Icon(Icons.person, size: 32, color: t.text),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _editName,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_s.nickname,
                  style: TextStyle(
                      color: t.text, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Icon(Icons.edit, size: 14, color: t.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 7),
        if (title == null || title.id == 'rookie')
          Text('칭호는 업적 탭에서 얻어 장착할 수 있어요',
              style: TextStyle(color: t.textTertiary, fontSize: 11))
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: title.rarity.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(title.rarity.icon, size: 14, color: title.rarity.color),
                const SizedBox(width: 5),
                Text(title.name,
                    style: TextStyle(
                        color: title.rarity.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text('닉네임을 눌러 변경할 수 있어요',
            style: TextStyle(color: t.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _sectionLabel(AppTheme t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(s,
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  Widget _walletSection(AppTheme t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(t, '보유'),
          Row(
            children: [
              _walletChip(t, '🪙', '코인', '${_s.coins}'),
              const SizedBox(width: 10),
              _walletChip(t, '🚩', '자동깃발', '${_s.ownedFlags}'),
              const SizedBox(width: 10),
              _walletChip(t, '📡', '레이더', '${_s.ownedRadars}'),
            ],
          ),
        ],
      );

  Widget _walletChip(AppTheme t, String emoji, String label, String value) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
              color: t.fill, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    Text(label,
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _recordList(AppTheme t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(t, '난이도별 기록'),
          for (final d in Difficulty.values) ...[
            _recordRow(t, d),
            const SizedBox(height: 10),
          ],
        ],
      );

  Widget _recordRow(AppTheme t, Difficulty d) {
    final best = _s.soloBest(d);
    final count = _s.soloClearCount(d);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration:
          BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Text(d.label,
              style: TextStyle(
                  color: t.text, fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(best != null ? '최고 $best초' : '기록 없음',
                  style: TextStyle(
                      color: best != null ? t.text : t.textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Text('클리어 $count회',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
