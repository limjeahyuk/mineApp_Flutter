import 'package:flutter/services.dart';

import 'local_store.dart';

/// Swift `Haptics` 대응 — 로직 코드가 부르는 진동 헬퍼. 실패해도 게임엔 지장 없어 삼켜준다.
/// on/off는 환경설정에서 `LocalStore`에 저장(일반 햅틱 `isEnabled`, 깃발 진동 `isFlagEnabled`).
class Haptics {
  static bool get isEnabled => LocalStore.shared.hapticsEnabled;
  static set isEnabled(bool v) => LocalStore.shared.hapticsEnabled = v;
  static bool get isFlagEnabled => LocalStore.shared.flagHapticsEnabled;
  static set isFlagEnabled(bool v) => LocalStore.shared.flagHapticsEnabled = v;

  static void _safe(void Function() f) {
    if (!isEnabled) return;
    try {
      f();
    } catch (_) {}
  }

  static void tap() => _safe(HapticFeedback.selectionClick);
  static void flagTap() {
    if (!isFlagEnabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static void success() => _safe(HapticFeedback.mediumImpact);
  static void warning() => _safe(HapticFeedback.mediumImpact);
  static void error() => _safe(HapticFeedback.heavyImpact);
}
