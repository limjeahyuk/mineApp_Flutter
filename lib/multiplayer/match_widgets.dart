import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../progression/title.dart';
import 'multiplayer.dart';

/// 대전·보물·닿기 화면이 함께 쓰는 원본(MultiplayerView/TreasureMultiplayerView/TouchMultiplayerView) 조각들.

/// 상대 검색 중 — 스피너 + 제목 + (재대결 문구 | 방 코드 | 설명) + 하단 취소.
class SearchingView extends StatelessWidget {
  const SearchingView({
    super.key,
    required this.title,
    required this.onCancel,
    this.rematchText,
    this.roomCode,
    this.isHost = false,
    this.description,
    this.shareText,
    this.codeHint = '친구가 이 코드를 입력하면 대결이 시작돼요',
  });
  final String title;
  final VoidCallback onCancel;
  final String? rematchText; // 재대결 대기 중이면 문구
  final String? roomCode;
  final bool isHost;
  final String? description;
  final String Function(String code)? shareText;
  final String codeHint;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    Widget middle;
    if (rematchText != null) {
      middle = Text(rematchText!,
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textSecondary, fontSize: 13));
    } else if (isHost) {
      middle = RoomCodeBlock(code: roomCode, shareText: shareText, hint: codeHint);
    } else {
      middle = Text(description ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textSecondary, fontSize: 13));
    }
    return Column(children: [
      const Spacer(),
      Transform.scale(
        scale: 1.6,
        child: CupertinoActivityIndicator(color: t.textSecondary),
      ),
      const SizedBox(height: 20),
      Text(title,
          style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: middle),
      const Spacer(),
      TextLink('취소', onTap: onCancel, fontSize: 16),
      const SizedBox(height: 24),
    ]);
  }
}

/// 방 코드 표시 + 복사/공유.
class RoomCodeBlock extends StatelessWidget {
  const RoomCodeBlock({super.key, required this.code, this.shareText, required this.hint});
  final String? code;
  final String Function(String code)? shareText;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final c = code;
    if (c == null) {
      return Text('방을 만드는 중…',
          style: TextStyle(color: t.textSecondary, fontSize: 13));
    }
    Widget action(IconData icon, String label, VoidCallback onTap) => Pressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: AppTheme.iosBlue),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.iosBlue, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    return Column(children: [
      Text('방 코드',
          style: TextStyle(
              color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration:
            BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(14)),
        child: Text(c,
            style: TextStyle(
                color: t.text,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                fontFamily: 'Courier',
                letterSpacing: 6)),
      ),
      const SizedBox(height: 12),
      Row(mainAxisSize: MainAxisSize.min, children: [
        action(CupertinoIcons.doc_on_doc, '복사', () {
          Clipboard.setData(ClipboardData(text: c));
          Haptics.tap();
        }),
        const SizedBox(width: 10),
        if (shareText != null)
          action(CupertinoIcons.square_arrow_up, '공유', () {
            SharePlus.instance.share(ShareParams(text: shareText!(c)));
          }),
      ]),
      const SizedBox(height: 12),
      Text(hint, style: TextStyle(color: t.textSecondary, fontSize: 12)),
    ]);
  }
}

/// 매칭 실패 — 경고 아이콘 + 사유 + 돌아가기.
class MatchFailedView extends StatelessWidget {
  const MatchFailedView({super.key, required this.error, required this.onClose});
  final MatchError error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Column(children: [
      const Spacer(),
      const Icon(CupertinoIcons.exclamationmark_triangle_fill,
          size: 40, color: AppTheme.raceOpp),
      const SizedBox(height: 16),
      Text(error.message,
          textAlign: TextAlign.center,
          style: TextStyle(color: t.text, fontSize: 17, fontWeight: FontWeight.w600)),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.fromLTRB(36, 0, 36, 24),
        child: BigButton(label: '돌아가기', color: AppTheme.raceMe, onTap: onClose, fontSize: 16),
      ),
    ]);
  }
}

/// 원형 아이콘 버튼(38) — 닫기 등.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
        child: Icon(icon, size: 17, color: t.textSecondary),
      ),
    );
  }
}

/// 원형 깃발 모드 토글(38) — 켜지면 빨강.
class FlagToggle extends StatelessWidget {
  const FlagToggle({super.key, required this.on, required this.onChanged});
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Pressable(
      onTap: () {
        Haptics.tap();
        onChanged(!on);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: on ? AppTheme.flagRed : t.fill, shape: BoxShape.circle),
        child: Icon(CupertinoIcons.flag_fill,
            size: 18, color: on ? Colors.white : t.textSecondary),
      ),
    );
  }
}

/// 진행바 한 줄 — 이름(+칭호 배지) · 바 · % · (점수).
class ProgressRow extends StatelessWidget {
  const ProgressRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.title = '',
    this.score,
    this.labelWidth = 80,
  });
  final String label;
  final double value;
  final Color color;
  final String title;
  final int? score;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final v = value.clamp(0.0, 1.0);
    return Row(children: [
      SizedBox(
        width: labelWidth,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 2),
            TitleBadge(name: title, size: 8),
          ],
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: LayoutBuilder(
          builder: (_, box) => Stack(children: [
            Container(
                height: 10,
                decoration: BoxDecoration(
                    color: t.fill, borderRadius: BorderRadius.circular(100))),
            AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 10,
                width: v * box.maxWidth,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(100))),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 40,
        child: Text('${(v * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ),
      if (score != null)
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
    ]);
  }
}

/// 결과 오버레이 공통 — 이모지·제목·부제 + 버튼들.
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.children,
    this.titleSize = 24,
  });
  final String emoji, title, subtitle;
  final List<Widget> children;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return PopupCard(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 54)),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: t.text, fontSize: titleSize, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary, fontSize: 14)),
        const SizedBox(height: 18),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ]),
    );
  }
}

/// 복기 중 하단 "결과 보기" 캡슐.
class ReviewBar extends StatelessWidget {
  const ReviewBar(
      {super.key,
      required this.color,
      required this.onTap,
      this.textColor = Colors.white,
      this.bottom = 34});
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final double bottom;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom + MediaQuery.paddingOf(context).bottom),
          child: Pressable(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.rosette, size: 16, color: textColor),
                const SizedBox(width: 6),
                Text('결과 보기',
                    style: TextStyle(
                        color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}

/// 상단 빨간 배너(지뢰를 밟아 잠깐 멈춤).
class StunBanner extends StatelessWidget {
  const StunBanner({super.key, required this.text, this.fontSize = 14});
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 10 + MediaQuery.paddingOf(context).top),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('💥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(text,
                  style: TextStyle(
                      color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      );
}
