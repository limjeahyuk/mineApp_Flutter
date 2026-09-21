import 'package:flutter/services.dart';

/// Swift `Haptics` 대응 — 로직 코드가 부르는 진동 헬퍼. 실패해도 게임엔 지장 없어 삼켜준다.
class Haptics {
  static void _safe(void Function() f) {
    try {
      f();
    } catch (_) {}
  }

  static void tap() => _safe(HapticFeedback.selectionClick);
  static void flagTap() => _safe(HapticFeedback.lightImpact);
  static void success() => _safe(HapticFeedback.mediumImpact);
  static void warning() => _safe(HapticFeedback.mediumImpact);
  static void error() => _safe(HapticFeedback.heavyImpact);
}
