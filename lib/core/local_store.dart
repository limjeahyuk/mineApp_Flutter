import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Swift `RankingStore`의 매칭에 필요한 최소 부분 — 영구 기기 ID·닉네임·장착 칭호.
/// deviceId는 반드시 **안정적**이어야 한다(매칭에서 "방금 나간 내 방"을 남의 방으로 오인하는 걸 막음).
class LocalStore {
  LocalStore._(this._prefs);
  final SharedPreferences _prefs;

  static LocalStore? _instance;
  static LocalStore get shared {
    final i = _instance;
    if (i == null) {
      throw StateError('LocalStore.init()를 main에서 먼저 호출하라.');
    }
    return i;
  }

  static Future<LocalStore> init() async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore._(prefs);
    store._ensureDeviceId();
    return _instance = store;
  }

  static const _kDeviceId = 'device.id';
  static const _kNickname = 'ranking.nickname';
  static const _kEquippedTitle = 'ranking.equippedTitle';

  void _ensureDeviceId() {
    if (_prefs.getString(_kDeviceId) == null) {
      final rng = Random();
      final id = List.generate(
          16, (_) => rng.nextInt(16).toRadixString(16)).join();
      _prefs.setString(_kDeviceId, id);
    }
  }

  String get deviceId => _prefs.getString(_kDeviceId)!;

  String get nickname => _prefs.getString(_kNickname) ?? '플레이어';
  set nickname(String v) => _prefs.setString(_kNickname, v);

  String get equippedTitleName => _prefs.getString(_kEquippedTitle) ?? '';
  set equippedTitleName(String v) => _prefs.setString(_kEquippedTitle, v);
}
