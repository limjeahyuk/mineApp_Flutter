import 'package:shared_preferences/shared_preferences.dart';

/// 저장값을 미리 채운 채로 시작 — LocalStore는 Swift 키 그대로 쓰려고 prefix를 ''로 두므로,
/// 목 값도 같은 prefix로 넣어야 읽힌다. 시작 코인 지급은 이미 끝난 사용자로 둔다.
void mockSavedPrefs(Map<String, Object> values) {
  try {
    SharedPreferences.setPrefix('');
  } on StateError {
    // 같은 isolate의 앞선 테스트에서 이미 '' — 그대로 쓴다.
  }
  SharedPreferences.setMockInitialValues(
      {'shop.startGranted': true, ...values});
}
