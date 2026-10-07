import 'package:flutter/material.dart';

import 'local_store.dart';

/// 앱 전역 화면 테마(시스템/라이트/다크). 환경설정에서 바꾸면 즉시 반영되고
/// `LocalStore`에 저장된다. `main`이 `MaterialApp.themeMode`를 여기에 연결.
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(_parseThemeMode(LocalStore.shared.themeMode));

ThemeMode _parseThemeMode(String s) => switch (s) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

String themeModeName(ThemeMode m) => switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

/// 테마를 바꾸고 저장 + 알림.
void setThemeMode(ThemeMode m) {
  LocalStore.shared.themeMode = themeModeName(m);
  themeModeNotifier.value = m;
}

/// 코인으로 구매하는 색상 테마(스킨) — Swift `ColorTheme`. 무채색 표면(배경·카드·보드 칸)에
/// 대표색을 옅게 섞어 분위기를 바꾼다. 글자색은 가독성을 위해 테마와 무관하게 무채색.
class ColorTheme {
  const ColorTheme(this.id, this.name, this.r, this.g, this.b, this.tinted);
  final String id;
  final String name;
  final double r, g, b;
  final bool tinted;

  Color get accent => Color.fromRGBO(
      (r * 255).round(), (g * 255).round(), (b * 255).round(), 1);

  /// 무채색(white) 표면에 대표색을 옅게 섞는다. 다크는 조금 더 진하게.
  Color tintedSurface(double v, bool dark) {
    int c(double x) => (x * 255).round().clamp(0, 255);
    if (!tinted) return Color.fromARGB(255, c(v), c(v), c(v));
    final mix = dark ? 0.18 : 0.14;
    return Color.fromARGB(255, c(v * (1 - mix) + r * mix),
        c(v * (1 - mix) + g * mix), c(v * (1 - mix) + b * mix));
  }

  static const classic = ColorTheme('classic', '클래식', 0.5, 0.5, 0.5, false);

  static const all = <ColorTheme>[
    classic,
    ColorTheme('ocean', '오션', 0.20, 0.55, 0.90, true),
    ColorTheme('forest', '포레스트', 0.18, 0.62, 0.50, true),
    ColorTheme('sunset', '선셋', 0.95, 0.55, 0.30, true),
    ColorTheme('lavender', '라벤더', 0.60, 0.50, 0.90, true),
    ColorTheme('rose', '로즈', 0.92, 0.45, 0.62, true),
  ];

  static ColorTheme named(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => classic);

  /// 지금 적용 중인 테마.
  static ColorTheme get active => named(colorThemeNotifier.value);
}

/// 적용 중인 색상 테마 id. 바꾸면 앱 전체가 다시 그려진다(main이 구독).
final ValueNotifier<String> colorThemeNotifier =
    ValueNotifier(LocalStore.shared.colorThemeId);

/// 보유한 테마로 전환한다(보유 확인은 호출부에서).
void selectColorTheme(String id) {
  LocalStore.shared.colorThemeId = id;
  colorThemeNotifier.value = id;
}

/// Swift `Theme`(Core/Theme.swift) 이식 — 다크 우선 + 라이트 적응, 무채색(회색조) 기반.
/// 색상 테마(틴트 스킨)는 클래식(무채색)만 이식(원본 기본값). 글자색은 항상 무채색.
class AppTheme {
  AppTheme(this.dark);
  final bool dark;

  static AppTheme of(BuildContext c) =>
      AppTheme(Theme.of(c).brightness == Brightness.dark);

  static Color _white(double v) {
    final n = (v * 255).round().clamp(0, 255);
    return Color.fromARGB(255, n, n, n);
  }

  /// 표면용(색상 테마 틴트 적용).
  Color _g(double d, double l) =>
      ColorTheme.active.tintedSurface(dark ? d : l, dark);

  /// 글자용(항상 무채색).
  Color _n(double d, double l) => _white(dark ? d : l);

  // 배경 / 표면
  Color get bg => _g(0.085, 0.96);
  Color get surface => _g(0.115, 1.0);
  Color get fill => _g(0.16, 0.90);
  Color get fillElevated => _g(0.24, 0.84);
  Color get border => _g(0.34, 0.80);

  // 텍스트 (무채색)
  Color get text => _n(0.96, 0.12);
  Color get textSecondary => _n(0.60, 0.40);
  Color get textTertiary => _n(0.45, 0.55);

  // 게임 보드
  Color get boardFrame => _g(0.16, 0.78);
  Color get cellRevealed => _g(0.13, 0.88);
  Color get cellRevealedStroke => _g(0.22, 0.74);
  Color get cellClosedTop => _g(0.34, 0.82);
  Color get cellClosedBottom => _g(0.22, 0.70);
  Color get cellClosedStroke => _g(0.45, 0.62);
  Color get cellExploded => dark
      ? const Color.fromRGBO(140, 31, 31, 1) // (0.55,0.12,0.12)
      : const Color.fromRGBO(245, 158, 148, 1); // (0.96,0.62,0.58)

  // 강조색 (모드 카드 등, 라이트/다크 공통 — 원본과 동일 RGB)
  static const soloAccent = Color.fromRGBO(64, 140, 242, 1); // (0.25,0.55,0.95)
  static const multiAccent = Color.fromRGBO(51, 158, 128, 1); // (0.20,0.62,0.50)
  static const meColor = Color.fromRGBO(77, 166, 255, 1); // (0.30,0.65,1.00)
  static const oppColor = Color.fromRGBO(250, 128, 82, 1); // (0.98,0.50,0.32)
  static const gold = Color.fromRGBO(242, 199, 77, 1); // (0.95,0.78,0.30)
  static const accentBlue = Color.fromRGBO(51, 115, 217, 1); // (0.20,0.45,0.85)
  static const accentGreen = Color.fromRGBO(51, 140, 102, 1); // (0.20,0.55,0.40)
  static const dangerRed = Color.fromRGBO(230, 77, 61, 1); // (0.90,0.30,0.24)
  static const itemPurple = Color.fromRGBO(148, 107, 245, 1); // (0.58,0.42,0.96)
  static const radarSky = Color.fromRGBO(51, 173, 219, 1); // (0.20,0.68,0.86)
  static const ledRed = Color.fromRGBO(255, 59, 48, 1); // (1.0,0.23,0.19)
}

/// 코드로 그린 '황금 지뢰' 아이콘 — 코인(통화) 표시. Swift `GoldenMineIcon` 이식.
/// 금색 구 + 바깥으로 뻗는 스파이크 8개 + 좌상단 하이라이트.
class GoldenMineIcon extends StatelessWidget {
  const GoldenMineIcon({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size, height: size, child: CustomPaint(painter: _GoldenMinePainter()));
}

class _GoldenMinePainter extends CustomPainter {
  static const highlight = Color.fromRGBO(255, 237, 148, 1);
  static const goldMid = Color.fromRGBO(245, 194, 61, 1);
  static const goldDeep = Color.fromRGBO(179, 117, 15, 1);

  @override
  void paint(Canvas canvas, Size sz) {
    final s = sz.width;
    final c = Offset(s / 2, s / 2);
    // 스파이크 8개(캡슐) — 구 뒤에서 45°씩.
    final spike = Paint()
      ..shader = const LinearGradient(
              colors: [goldMid, goldDeep],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter)
          .createShader(Rect.fromLTWH(0, 0, s, s));
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * 3.141592653589793 / 4);
      final w = s * 0.11, h = s * 0.26;
      final rect = Rect.fromCenter(center: Offset(0, -s * 0.36), width: w, height: h);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(w / 2)), spike);
      canvas.restore();
    }
    // 본체 구.
    final r = s * 0.35;
    final body = Paint()
      ..shader = RadialGradient(
        colors: const [highlight, goldMid, goldDeep],
        center: const Alignment(-0.32, -0.40),
        radius: 0.40 / 0.70, // endRadius(size*0.40) / 구 지름(size*0.70)
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, body);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02 < 0.5 ? 0.5 : s * 0.02
          ..color = goldDeep.withValues(alpha: 0.55));
    // 반짝임.
    canvas.drawCircle(
        c + Offset(-s * 0.12, -s * 0.13),
        s * 0.075,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.015 + 0.01));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 숫자(주변 지뢰 수) 색 — Swift CellView.numberColor의 dark/light 값 그대로.
Color minesweeperNumberColor(int n, bool dark) {
  switch (n) {
    case 1:
      return dark ? const Color(0xFF66B3FF) : const Color(0xFF1933D9);
    case 2:
      return dark ? const Color(0xFF66D973) : const Color(0xFF1A801F);
    case 3:
      return dark ? const Color(0xFFFF7373) : const Color(0xFFCC0D0D);
    case 4:
      return dark ? const Color(0xFFB394FF) : const Color(0xFF4D1A8C);
    case 5:
      return dark ? const Color(0xFFFFB852) : const Color(0xFF8C330D);
    case 6:
      return dark ? const Color(0xFF59D9D9) : const Color(0xFF0D7380);
    case 7:
      return dark ? const Color(0xFFEBEBEB) : const Color(0xFF1A1A1A);
    default:
      return dark ? const Color(0xFF9E9E9E) : const Color(0xFF666666);
  }
}
