import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart' hide Title;
import 'package:sign_in_with_apple/sign_in_with_apple.dart' show SignInWithAppleButton, SignInWithAppleButtonStyle;

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

/// 내 정보 — Swift StartView.ProfileView 이식.
/// 프로필(닉네임 변경·칭호 배지) + 보유(코인·자동깃발) + 난이도별 기록 + 계정 연동 + 계정 삭제.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalStore _s = LocalStore.shared;
  bool _linking = false;
  bool _deleting = false;
  String? _linkMessage;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return SheetScaffold(
      title: '내 정보',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(children: [
          _header(t),
          const SizedBox(height: 18),
          _wallet(t),
          const SizedBox(height: 18),
          _records(t),
          const SizedBox(height: 18),
          _account(t),
          const SizedBox(height: 18),
          _danger(t),
        ]),
      ),
    );
  }

  Future<void> _editName() async {
    final v = await showCupertinoTextAlert(context,
        title: '닉네임 변경',
        message: '랭킹에 표시될 이름이에요 (최대 16자)',
        initial: _s.nickname,
        placeholder: '닉네임');
    if (v == null) return;
    final trimmed = v.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _s.nickname = trimmed.length > 16 ? trimmed.substring(0, 16) : trimmed;
      _s.nicknameSetByUser = true;
    });
  }

  Widget _header(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
          child: Icon(SF.personFill, size: 32, color: t.text),
        ),
        const SizedBox(height: 10),
        Tap(
          onTap: _editName,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(_s.nickname,
                  overflow: TextOverflow.ellipsis,
                  style: sf(20, weight: W.bold, color: t.text)),
            ),
            const SizedBox(width: 6),
            Icon(SF.pencil, size: 15, color: t.textSecondary),
          ]),
        ),
        const SizedBox(height: 7),
        _s.equippedTitleName.isEmpty
            ? Text('칭호 미착용 · 업적 탭에서 칭호를 얻어 보세요',
                style: sf(11, color: t.textTertiary))
            : TitleBadge(name: _s.equippedTitleName, size: 12),
        const SizedBox(height: 10),
        Text('닉네임을 눌러 변경할 수 있어요', style: sf(12, color: t.textSecondary)),
      ]),
    );
  }

  Widget _wallet(AppTheme t) {
    Widget chip(String label, String value, Widget icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: rr(12, t.fill),
            child: Row(children: [
              icon,
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: sf(17, weight: W.heavy, color: t.text)),
                const SizedBox(height: 2),
                Text(label, style: sf(11, weight: W.medium, color: t.textSecondary)),
              ]),
            ]),
          ),
        );
    return Column(children: [
      sectionLabel(t, '보유'),
      const SizedBox(height: 10),
      Row(children: [
        chip('코인', fmt(_s.coins), const GoldenMineIcon(size: 24)),
        const SizedBox(width: 10),
        chip('자동깃발', '${_s.ownedFlags}', const Text('🚩', style: TextStyle(fontSize: 22))),
      ]),
    ]);
  }

  Widget _records(AppTheme t) {
    return Column(children: [
      sectionLabel(t, '난이도별 기록'),
      for (final d in Difficulty.values) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: rr(12, t.fill),
          child: Row(children: [
            Text(d.label, style: sf(16, weight: W.bold, color: t.text)),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _s.soloBest(d) != null
                  ? Text('최고 ${_s.soloBest(d)}초',
                      style: sf(14, weight: W.semibold, color: t.text))
                  : Text('기록 없음', style: sf(14, weight: W.medium, color: t.textTertiary)),
              const SizedBox(height: 2),
              Text('클리어 ${_s.soloClearCount(d)}회',
                  style: sf(11, weight: W.medium, color: t.textSecondary)),
            ]),
          ]),
        ),
      ],
    ]);
  }

  // ── 계정 연동 ──
  Widget _account(AppTheme t) {
    final apple = AppleAuth.isLinked;
    final google = GoogleAuth.isLinked;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionLabel(t, '계정 연동'),
      const SizedBox(height: 10),
      if (!apple && !google) ...[
        Text('로그인하면 닉네임·기록·전적이 안전하게 보관되어, 기기를 바꿔도 그대로 복구할 수 있어요.',
            style: sf(12, color: t.textSecondary)),
        const SizedBox(height: 10),
      ],
      if (apple)
        _linkedRow(t, 'Apple 계정 연동됨')
      else if (Platform.isIOS)
        Opacity(
          opacity: _linking ? 0.6 : 1,
          child: SizedBox(
            height: 48,
            child: SignInWithAppleButton(
              text: 'Apple로 로그인',
              height: 48,
              style: t.dark ? SignInWithAppleButtonStyle.white : SignInWithAppleButtonStyle.black,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              onPressed: _linking ? () {} : () => _run(AppleAuth.signIn),
            ),
          ),
        ),
      const SizedBox(height: 10),
      if (google)
        _linkedRow(t, 'Google 계정 연동됨')
      else
        Opacity(
          opacity: _linking ? 0.6 : 1,
          child: Tap(
            onTap: _linking ? null : () => _run(GoogleAuth.signIn),
            child: Container(
              height: 48,
              decoration: rr(12, const Color.fromRGBO(66, 133, 245, 1)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(SF.globe, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text('Google로 계속하기', style: sf(17, weight: W.semibold, color: Colors.white)),
              ]),
            ),
          ),
        ),
      if (_linkMessage != null) ...[
        const SizedBox(height: 10),
        Text(_linkMessage!, style: sf(12, weight: W.medium, color: t.textSecondary)),
      ],
    ]);
  }

  Widget _linkedRow(AppTheme t, String title) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: rr(12, t.fill),
        child: Row(children: [
          const Icon(SF.sealFill, size: 22, color: Colors.green),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: sf(15, weight: W.bold, color: t.text)),
            const SizedBox(height: 2),
            Text('기기를 바꿔도 기록이 복구돼요', style: sf(12, color: t.textSecondary)),
          ]),
        ]),
      );

  Future<void> _run(Future<LinkOutcome> Function() login) async {
    setState(() {
      _linking = true;
      _linkMessage = null;
    });
    final outcome = await login();
    if (!mounted) return;
    switch (outcome) {
      case LinkLinked(:final uid, :final suggestedName):
        if (suggestedName != null && suggestedName.isNotEmpty && !_s.nicknameSetByUser) {
          _s.nickname = suggestedName.length > 16 ? suggestedName.substring(0, 16) : suggestedName;
        }
        await CloudBackup.backup(uid);
        _linkMessage = '연동 완료! 이제 기기를 바꿔도 기록이 복구돼요.';
      case LinkSwitched(:final uid):
        await CloudBackup.restore(uid);
        _linkMessage = '기존 계정의 기록을 불러왔어요.';
      case LinkCancelled():
        break;
      case LinkFailed(:final error):
        _linkMessage = '연동에 실패했어요: $error';
    }
    if (mounted) setState(() => _linking = false);
  }

  // ── 계정 삭제 ──
  Widget _danger(AppTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Divider(height: 1, color: t.border.withValues(alpha: 0.5)),
      ),
      const SizedBox(height: 8),
      Tap(
        onTap: _deleting ? null : _confirmDelete,
        child: Container(
          height: 48,
          decoration: rr(12, Colors.red.withValues(alpha: 0.10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_deleting)
              const CupertinoActivityIndicator(color: Colors.red, radius: 8)
            else
              const Icon(SF.trash, size: 15, color: Colors.red),
            const SizedBox(width: 8),
            Text(_deleting ? '삭제 중…' : '계정 삭제',
                style: sf(15, weight: W.semibold, color: Colors.red)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Text('계정과 모든 기록·전적·코인·아이템이 영구 삭제되며 되돌릴 수 없어요.',
          style: sf(11, color: t.textTertiary)),
    ]);
  }

  Future<void> _confirmDelete() async {
    Haptics.tap();
    final i = await showCupertinoAlert(context,
        title: '계정을 삭제할까요?',
        message: '계정과 모든 데이터(닉네임·기록·전적·코인·아이템)가 영구 삭제됩니다. 이 작업은 되돌릴 수 없어요.',
        actions: const ['삭제', '취소'],
        destructiveIndex: 0,
        cancelIndex: 1);
    if (i != 0 || !mounted) return;
    setState(() => _deleting = true);
    String? error;
    try {
      await AccountDeletion.deleteAccount();
    } on DeletionCancelled {
      error = '본인 확인이 취소되어 삭제하지 않았어요.';
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() => _deleting = false);
    if (error != null) {
      await showCupertinoAlert(context, title: '알림', message: error);
    } else {
      Navigator.of(context).maybePop();
    }
  }
}
