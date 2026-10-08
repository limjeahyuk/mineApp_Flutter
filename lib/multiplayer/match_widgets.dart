import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../progression/title.dart';
import 'multiplayer.dart';

/// 대전·보물·협동 화면이 함께 쓰는 Swift MultiplayerView 계열 UI 조각.

/// 대전 화면 색 — Swift MultiplayerView의 meColor/oppColor/coopColor.
const kRaceMe = Color.fromRGBO(51, 140, 242, 1); // (0.20,0.55,0.95)
const kRaceOpp = Color.fromRGBO(242, 115, 77, 1); // (0.95,0.45,0.30)
const kRaceCoop = Color.fromRGBO(56, 184, 140, 1); // (0.22,0.72,0.55)

/// 초대 링크 — Swift InviteLink.webURL (Firebase Hosting 랜딩 → mineapp:// 로 앱 열기).
class InviteLink {
  static const scheme = 'mineapp';
  static const webBase = 'https://mineapp-aabc8.web.app';

  /// game: mine / treasure / touch
  static String webURL(String game, String code) => '$webBase/j?g=$game&c=$code';

  /// 들어온 URL(커스텀 스킴 또는 https)에서 (게임, 정규화된 방 코드).
  static (String game, String code)? parse(Uri uri) {
    final q = uri.queryParameters;
    final raw = q['c'] ?? q['code'];
    if (raw == null) return null;
    final code = RoomCode.normalize(raw);
    if (code.isEmpty) return null;
    final g = q['g'] ?? q['game'] ?? 'mine';
    return (const ['mine', 'treasure', 'touch'].contains(g) ? g : 'mine', code);
  }
}

/// 원형 아이콘 버튼(✕ 등) — 38×38, fill 바탕.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton(
      {super.key, required this.icon, required this.onTap, this.size = 38});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return PlainButton(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: t.textSecondary),
      ),
    );
  }
}

/// 원형 깃발 모드 토글 — 켜지면 빨강.
class CircleFlagToggle extends StatelessWidget {
  const CircleFlagToggle({super.key, required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return PlainButton(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: on ? AppTheme.dangerRed : t.fill, shape: BoxShape.circle),
        child: Icon(Icons.flag,
            size: 20, color: on ? Colors.white : t.textSecondary),
      ),
    );
  }
}

/// 이름(+칭호 배지) · 진행바 · 퍼센트 · (점수) 한 줄.
class RaceProgressRow extends StatelessWidget {
  const RaceProgressRow({
    super.key,
    required this.label,
    this.title = '',
    required this.value,
    required this.color,
    this.score,
    this.labelWidth = 80,
  });

  final String label;
  final String title;
  final double value;
  final Color color;
  final int? score;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final v = value.clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 2),
                TitleBadge(name: title, size: 8),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: CapsuleProgress(fraction: v, color: color, height: 10)),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text('${(v * 100).round()}%',
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        if (score != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text('$score',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ],
      ],
    );
  }
}

/// 상대 검색 화면(스피너 + 제목 + 하단 설명/방 코드 + 취소).
class MatchSearchingView extends StatelessWidget {
  const MatchSearchingView({
    super.key,
    required this.title,
    required this.detail,
    required this.onCancel,
  });

  final String title;
  final Widget detail;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Column(
      children: [
        const Spacer(),
        Transform.scale(
            scale: 1.6,
            child: CupertinoActivityIndicator(color: t.textSecondary)),
        const SizedBox(height: 20),
        Text(title,
            style: TextStyle(
                color: t.text, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        detail,
        const Spacer(),
        PlainButton(
          onTap: onCancel,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('취소',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// 검색 화면 아래 한 줄 설명.
class MatchDetailText extends StatelessWidget {
  const MatchDetailText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textSecondary, fontSize: 13)),
    );
  }
}

/// 방 코드 표시 + 복사/공유 — 친구가 [코드로 참가]로 들어온다.
class RoomCodeBlock extends StatelessWidget {
  const RoomCodeBlock({
    super.key,
    required this.code,
    required this.shareText,
    this.footer = '친구가 이 코드를 입력하면 대결이 시작돼요',
  });

  final String? code;
  final String Function(String code) shareText;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final code = this.code;
    if (code == null) {
      return Text('방을 만드는 중…',
          style: TextStyle(color: t.textSecondary, fontSize: 13));
    }
    Widget action(IconData icon, String label, VoidCallback onTap) =>
        PlainButton(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: t.text),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    return Column(
      children: [
        Text('방 코드',
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
              color: t.fill, borderRadius: BorderRadius.circular(14)),
          child: Text(code,
              style: TextStyle(
                  color: t.text,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: const ['Courier', 'monospace'])),
        ),
        const SizedBox(height: 12),
        Row(mainAxisSize: MainAxisSize.min, children: [
          action(Icons.copy, '복사', () {
            Clipboard.setData(ClipboardData(text: code));
            Haptics.tap();
          }),
          const SizedBox(width: 10),
          Builder(
            builder: (ctx) => action(Icons.ios_share, '공유', () {
              final box = ctx.findRenderObject() as RenderBox?;
              SharePlus.instance.share(ShareParams(
                text: shareText(code),
                sharePositionOrigin: box == null
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size,
              ));
            }),
          ),
        ]),
        const SizedBox(height: 12),
        Text(footer,
            style: TextStyle(color: t.textSecondary, fontSize: 12)),
      ],
    );
  }
}

/// 매칭 실패 화면.
class MatchFailedView extends StatelessWidget {
  const MatchFailedView({super.key, required this.error, required this.onClose});
  final MatchError error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Column(
      children: [
        const Spacer(),
        const Icon(Icons.warning_rounded, size: 44, color: kRaceOpp),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(error.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: t.text, fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 0, 36, 24),
          child: PlainButton(
            onTap: onClose,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: kRaceMe, borderRadius: BorderRadius.circular(12)),
              child: const Text('돌아가기',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }
}

/// 매칭 직후 카운트다운 인트로(상대 카드 + 3·2·1).
class MatchStartingView extends StatelessWidget {
  const MatchStartingView({
    super.key,
    required this.headline,
    required this.opponentName,
    required this.opponentTitle,
    required this.countdown,
    required this.footer,
    required this.icon,
    required this.iconColor,
    required this.numberColor,
  });

  final String headline;
  final String opponentName;
  final String opponentTitle;
  final int countdown;
  final String footer;
  final IconData icon;
  final Color iconColor;
  final Color numberColor;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Column(
      children: [
        const Spacer(),
        Text(headline,
            style: TextStyle(
                color: t.text, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 22),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
          child: Icon(icon, size: 30, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(opponentName,
            style: TextStyle(
                color: t.text, fontSize: 18, fontWeight: FontWeight.w600)),
        if (opponentTitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          TitleBadge(name: opponentTitle, size: 9),
        ],
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (c, a) => FadeTransition(
              opacity: a, child: ScaleTransition(scale: a, child: c)),
          child: Text('$countdown',
              key: ValueKey(countdown),
              style: TextStyle(
                  color: numberColor,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        const SizedBox(height: 22),
        Text(footer, style: TextStyle(color: t.textSecondary, fontSize: 14)),
        const Spacer(),
      ],
    );
  }
}

/// 결과 오버레이 카드(이모지·제목·부제·버튼들).
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(36),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.fillElevated),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 54)),
              const SizedBox(height: 12),
              Text(title,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textSecondary, fontSize: 14)),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// 결과 카드용 꽉 찬 버튼.
class FilledWideButton extends StatelessWidget {
  const FilledWideButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.color = kRaceMe,
      this.height = 50});
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => PlainButton(
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(12)),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
        ),
      );
}

/// 결과 카드용 텍스트 버튼(나가기).
class TextLinkButton extends StatelessWidget {
  const TextLinkButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return PlainButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Text(label,
            style: TextStyle(
                color: t.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

/// 자리비움 경고 배너 — 탭하면 계속하기.
class AfkWarningBanner extends StatelessWidget {
  const AfkWarningBanner(
      {super.key, required this.remaining, required this.onStay});
  final int remaining;
  final VoidCallback onStay;

  static String _time(int s) {
    if (s >= 60) {
      final m = s ~/ 60, r = s % 60;
      return r > 0 ? '$m분 $r초' : '$m분';
    }
    return '$s초';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: GestureDetector(
          onTap: () {
            Haptics.tap();
            onStay();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(140, 64, 26, 1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.yellow.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    size: 20, color: Colors.yellow),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('자리를 비우셨나요?',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${_time(remaining)} 후 항복 · 탭하면 계속하기',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
