import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart' hide Title;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../progression/title.dart';

/// 멀티 화면 공용 조각 — Swift MultiplayerView / TreasureMultiplayerView / TouchMultiplayerView의
/// 검색·실패·카운트다운·결과 카드가 모두 같은 모양이라 한곳에 모았다.

const mpMeColor = Color.fromRGBO(51, 140, 242, 1); // (0.20,0.55,0.95)
const mpOppColor = Color.fromRGBO(242, 115, 77, 1); // (0.95,0.45,0.30)
const mpCoopColor = Color.fromRGBO(56, 184, 140, 1); // (0.22,0.72,0.55)
const mpFlagRed = Color.fromRGBO(230, 77, 61, 1);

/// 초대 링크 — Swift InviteLink.webURL.
String inviteWebUrl(String game, String code) =>
    'https://mineapp-aabc8.web.app/j?g=$game&c=$code';

/// 상대 검색 중(스피너 + 제목 + 부가 영역 + 취소).
Widget mpSearching(AppTheme t,
    {required String title, required Widget detail, required VoidCallback onCancel}) {
  return Column(children: [
    const Spacer(),
    Transform.scale(
        scale: 1.6, child: CupertinoActivityIndicator(color: t.textSecondary, radius: 10)),
    const SizedBox(height: 20),
    Text(title, style: sf(18, weight: W.semibold, color: t.text)),
    const SizedBox(height: 20),
    detail,
    const Spacer(),
    Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Tap(
          onTap: onCancel,
          child: Text('취소', style: sf(16, weight: W.medium, color: t.textSecondary))),
    ),
  ]);
}

/// 방 코드 표시 + 복사/공유.
class RoomCodeBlock extends StatelessWidget {
  const RoomCodeBlock(
      {super.key,
      required this.code,
      required this.shareText,
      this.caption = '친구가 이 코드를 입력하면 대결이 시작돼요'});
  final String? code;
  final String shareText;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    if (code == null) {
      return Text('방을 만드는 중…', style: sf(13, color: t.textSecondary));
    }
    return Column(children: [
      Text('방 코드', style: sf(12, weight: W.semibold, color: t.textSecondary)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: rr(14, t.fill),
        child: Text(code!,
            style: sf(34, weight: W.heavy, color: t.text, mono: true)
                .copyWith(letterSpacing: 6)),
      ),
      const SizedBox(height: 12),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Tap(
          onTap: () {
            Clipboard.setData(ClipboardData(text: code!));
            Haptics.tap();
          },
          child: Row(children: [
            Icon(SF.docOnDoc, size: 14, color: t.text),
            const SizedBox(width: 5),
            Text('복사', style: sf(14, weight: W.semibold, color: t.text)),
          ]),
        ),
        const SizedBox(width: 10),
        Tap(
          onTap: () => SharePlus.instance.share(ShareParams(text: shareText)),
          child: Row(children: [
            Icon(SF.shareUp, size: 14, color: t.text),
            const SizedBox(width: 5),
            Text('공유', style: sf(14, weight: W.semibold, color: t.text)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      Text(caption, style: sf(12, color: t.textSecondary)),
    ]);
  }
}

/// 매칭 실패.
Widget mpFailure(AppTheme t, String message, VoidCallback onBack, {Color color = mpMeColor}) {
  return Column(children: [
    const Spacer(),
    const Icon(SF.warningFill, size: 40, color: mpOppColor),
    const SizedBox(height: 16),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(message,
          textAlign: TextAlign.center, style: sf(17, weight: W.semibold, color: t.text)),
    ),
    const Spacer(),
    Padding(
      padding: const EdgeInsets.fromLTRB(36, 0, 36, 24),
      child: Tap(
        onTap: onBack,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: rr(12, color),
          child: Text('돌아가기', style: sf(16, weight: W.semibold, color: Colors.white)),
        ),
      ),
    ),
  ]);
}

/// 매칭 성사 카운트다운.
Widget mpStarting(AppTheme t,
    {required String title,
    required IconData icon,
    required Color iconColor,
    required String name,
    required String titleBadge,
    required int countdown,
    required Color countColor,
    required String caption}) {
  return Column(children: [
    const Spacer(),
    Text(title, style: sf(22, weight: W.bold, color: t.text)),
    const SizedBox(height: 22),
    Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
      child: Icon(icon, size: 30, color: iconColor),
    ),
    const SizedBox(height: 8),
    Text(name, style: sf(18, weight: W.semibold, color: t.text)),
    const SizedBox(height: 8),
    TitleBadge(name: titleBadge, size: 9),
    const SizedBox(height: 22),
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (c, a) =>
          ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
      child: Text('$countdown',
          key: ValueKey(countdown),
          style: sf(64, weight: W.heavy, color: countColor)),
    ),
    const SizedBox(height: 22),
    Text(caption, style: sf(14, color: t.textSecondary)),
    const Spacer(),
  ]);
}

/// 원형 아이콘 버튼(38×38) — 레이스 상단바 X.
Widget mpCircleButton(AppTheme t, IconData icon, VoidCallback onTap,
        {double size = 38, double iconSize = 16}) =>
    Tap(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
        child: Icon(icon, size: iconSize, color: t.textSecondary),
      ),
    );

/// 원형 깃발 모드 토글.
Widget mpFlagToggle(AppTheme t, bool on, VoidCallback onTap) => Tap(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: on ? mpFlagRed : t.fill, shape: BoxShape.circle),
        child: Icon(SF.flagFill, size: 18, color: on ? Colors.white : t.textSecondary),
      ),
    );

/// 진행바 한 줄(이름·칭호 | 막대 | % | 점수).
Widget mpProgressRow(AppTheme t,
    {required String label,
    String title = '',
    required double value,
    required Color color,
    int? score}) {
  final v = value.clamp(0.0, 1.0);
  return Row(children: [
    SizedBox(
      width: 80,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: sf(12, weight: W.semibold, color: t.textSecondary)),
        if (title.isNotEmpty) ...[
          const SizedBox(height: 2),
          TitleBadge(name: title, size: 8),
        ],
      ]),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: SizedBox(
        height: 10,
        child: LayoutBuilder(
          builder: (_, c) => Stack(children: [
            Container(decoration: BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(5))),
            Container(
                width: v * c.maxWidth,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
          ]),
        ),
      ),
    ),
    const SizedBox(width: 8),
    SizedBox(
      width: 40,
      child: Text('${(v * 100).round()}%',
          textAlign: TextAlign.right, style: sf(13, weight: W.bold, color: color)),
    ),
    if (score != null) ...[
      const SizedBox(width: 8),
      SizedBox(
        width: 30,
        child: Text('$score',
            textAlign: TextAlign.right, style: sf(14, weight: W.bold, color: color)),
      ),
    ],
  ]);
}

/// 결과 카드 오버레이.
Widget mpResultOverlay(AppTheme t,
    {required String emoji,
    required String title,
    required String subtitle,
    required String primary,
    required VoidCallback onPrimary,
    required VoidCallback onExit,
    Color primaryColor = mpMeColor}) {
  return Positioned.fill(
    child: ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.all(36),
          padding: const EdgeInsets.all(26),
          decoration: rr(20, t.fill, stroke: t.fillElevated),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 54, height: 1.1)),
            const SizedBox(height: 12),
            Text(title, style: sf(24, weight: W.bold, color: t.text)),
            const SizedBox(height: 12),
            Text(subtitle, textAlign: TextAlign.center, style: sf(14, color: t.textSecondary)),
            const SizedBox(height: 18),
            Tap(
              onTap: onPrimary,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: rr(12, primaryColor),
                child: Text(primary, style: sf(17, weight: W.semibold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            Tap(
                onTap: onExit,
                child: Text('나가기', style: sf(14, weight: W.medium, color: t.textSecondary))),
          ]),
        ),
      ),
    ),
  );
}

/// 자리비움 경고 배너.
Widget mpAfkBanner(int remaining, VoidCallback onTap) {
  String text(int s) {
    if (s >= 60) {
      final m = s ~/ 60, r = s % 60;
      return r > 0 ? '$m분 $r초' : '$m분';
    }
    return '$s초';
  }

  return Positioned(
    left: 16,
    right: 16,
    top: 8,
    child: SafeArea(
      child: Tap(
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: rr(14, const Color.fromRGBO(140, 64, 26, 1),
              stroke: Colors.yellow.withValues(alpha: 0.6)),
          child: Row(children: [
            const Icon(SF.warningFill, size: 18, color: Colors.yellow),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('자리를 비우셨나요?', style: sf(14, weight: W.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text('${text(remaining)} 후 항복 · 탭하면 계속하기',
                    style: sf(12, color: Colors.white.withValues(alpha: 0.9))),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}
