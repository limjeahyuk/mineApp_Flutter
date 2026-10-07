import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/account_auth.dart';
import '../core/account_deletion.dart';
import '../core/apple_auth.dart';
import '../core/board.dart';
import '../core/cloud_backup.dart';
import '../core/google_auth.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../progression/title.dart';

/// 내 정보 시트 — Swift StartView.ProfileView 이식.
/// 닉네임(변경) + 장착 칭호 + 보유(코인·자동깃발) + 난이도별 기록 + 계정 연동 + 계정 삭제.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalStore _s = LocalStore.shared;
  bool _linking = false;
  String? _linkMessage;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '내 정보',
      child: ListenableBuilder(
        listenable: _s,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _profileHeader(t),
              const SizedBox(height: 18),
              _walletSection(t),
              const SizedBox(height: 18),
              _recordList(t),
              const SizedBox(height: 18),
              _accountSection(t),
              const SizedBox(height: 18),
              _dangerSection(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(AppTheme t, String text) => Text(text,
      style: TextStyle(
          color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.w600));

  // MARK: 헤더 — 아바타 + 닉네임(탭해서 변경) + 장착 칭호

  Widget _profileHeader(AppTheme t) {
    final titleName = _s.equippedTitleName;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
            child: Icon(Icons.person, size: 36, color: t.text),
          ),
          const SizedBox(height: 10),
          PlainButton(
            onTap: _editName,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(_s.nickname,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit, size: 15, color: t.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 7),
          if (titleName.isEmpty)
            Text('칭호 미착용 · 업적 탭에서 칭호를 얻어 보세요',
                style: TextStyle(color: t.textTertiary, fontSize: 11))
          else
            TitleBadge(name: titleName, size: 12),
          const SizedBox(height: 10),
          Text('닉네임을 눌러 변경할 수 있어요',
              style: TextStyle(color: t.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _s.nickname);
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('닉네임 변경'),
        content: Column(
          children: [
            const Text('랭킹에 표시될 이름이에요 (최대 16자)'),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: ctrl,
              autofocus: true,
              placeholder: '닉네임',
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('저장'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    _s.nickname = trimmed.length > 16 ? trimmed.substring(0, 16) : trimmed;
  }

  // MARK: 보유 — 코인 잔액 + 뽑기로 모은 아이템

  Widget _walletSection(AppTheme t) {
    Widget chip(Widget icon, String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(t, '보유'),
        const SizedBox(height: 10),
        Row(children: [
          chip(const GoldenMineIcon(size: 24), formatNumber(_s.coins), '코인'),
          const SizedBox(width: 10),
          chip(const Text('🚩', style: TextStyle(fontSize: 22)),
              '${_s.ownedFlags}', '자동깃발'),
        ]),
      ],
    );
  }

  // MARK: 난이도별 기록

  Widget _recordList(AppTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(t, '난이도별 기록'),
        for (final d in Difficulty.values) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Text(d.label,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_s.soloBest(d) != null)
                      Text('최고 ${_s.soloBest(d)}초',
                          style: TextStyle(
                              color: t.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600))
                    else
                      Text('기록 없음',
                          style: TextStyle(
                              color: t.textTertiary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('클리어 ${_s.soloClearCount(d)}회',
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // MARK: 계정 연동 (Apple · Google)

  String? _providerEmail(String providerId) {
    User? u;
    try {
      u = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    if (u == null) return null;
    for (final p in u.providerData) {
      if (p.providerId == providerId) return p.email;
    }
    return null;
  }

  Widget _accountSection(AppTheme t) {
    final appleLinked = AppleAuth.isLinked;
    final googleLinked = GoogleAuth.isLinked;
    final showApple = Platform.isIOS || appleLinked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(t, '계정 연동'),
        const SizedBox(height: 10),
        if (!appleLinked && !googleLinked) ...[
          Text('로그인하면 닉네임·기록·전적이 안전하게 보관되어, 기기를 바꿔도 그대로 복구할 수 있어요.',
              style: TextStyle(color: t.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
        ],
        if (showApple) ...[
          if (appleLinked)
            _linkedRow(t, 'Apple 계정 연동됨', _providerEmail('apple.com'))
          else
            Opacity(
              opacity: _linking ? 0.6 : 1,
              child: SignInWithAppleButton(
                text: 'Apple로 로그인',
                height: 48,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                style: t.dark
                    ? SignInWithAppleButtonStyle.white
                    : SignInWithAppleButtonStyle.black,
                onPressed: _linking ? () {} : () => _runLogin(AppleAuth.signIn),
              ),
            ),
          const SizedBox(height: 10),
        ],
        if (googleLinked)
          _linkedRow(t, 'Google 계정 연동됨', _providerEmail('google.com'))
        else
          PlainButton(
            onTap: _linking ? null : () => _runLogin(GoogleAuth.signIn),
            child: Opacity(
              opacity: _linking ? 0.6 : 1,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                    color: const Color.fromRGBO(66, 133, 245, 1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.language, size: 20, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Google로 계속하기',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        if (_linkMessage != null) ...[
          const SizedBox(height: 10),
          Text(_linkMessage!,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }

  Widget _linkedRow(AppTheme t, String title, String? subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration:
          BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.verified, size: 24, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle ?? '기기를 바꿔도 기록이 복구돼요',
                    style: TextStyle(color: t.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 연동 결과(Apple·Google 공통) — 데이터 동기화(머지) + 안내 메시지.
  Future<void> _runLogin(Future<LinkOutcome> Function() login) async {
    setState(() {
      _linking = true;
      _linkMessage = null;
    });
    final outcome = await login();
    String? msg;
    switch (outcome) {
      case LinkLinked(:final uid, :final suggestedName):
        await CloudBackup.syncAfterLink(uid, suggestedName);
        msg = '연동 완료! 이제 기기를 바꿔도 기록이 복구돼요.';
      case LinkSwitched(:final uid, :final suggestedName):
        await CloudBackup.syncAfterLink(uid, suggestedName);
        msg = '기존 계정의 기록을 불러왔어요.';
      case LinkCancelled():
        break;
      case LinkFailed(:final error):
        msg = '연동에 실패했어요: $error';
    }
    if (!mounted) return;
    setState(() {
      _linking = false;
      _linkMessage = msg;
    });
  }

  // MARK: 계정 삭제 (회원탈퇴)

  Widget _dangerSection(AppTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: t.border.withValues(alpha: 0.6), height: 12),
        const SizedBox(height: 8),
        PlainButton(
          onTap: _deleting
              ? null
              : () {
                  Haptics.tap();
                  _confirmDelete();
                },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_deleting)
                  const CupertinoActivityIndicator(color: Colors.red)
                else
                  const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Text(_deleting ? '삭제 중…' : '계정 삭제',
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('계정과 모든 기록·전적·코인·아이템이 영구 삭제되며 되돌릴 수 없어요.',
            style: TextStyle(color: t.textTertiary, fontSize: 11)),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showAppAlert<bool>(
      context,
      title: '계정을 삭제할까요?',
      message: '계정과 모든 데이터(닉네임·기록·전적·코인·아이템)가 영구 삭제됩니다. 이 작업은 되돌릴 수 없어요.',
      actions: const [
        AlertAction('삭제', true, destructive: true),
        AlertAction('취소', false, isCancel: true),
      ],
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await AccountDeletion.deleteAccount();
      selectColorTheme('classic');
      if (!mounted) return;
      setState(() => _deleting = false);
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      await showAppAlert<void>(context,
          title: '알림',
          message: e is DeletionCancelled ? e.toString() : '계정 삭제에 실패했어요: $e',
          actions: const [AlertAction('확인', null, isCancel: true)]);
    }
  }
}
