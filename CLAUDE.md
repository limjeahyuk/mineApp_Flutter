# MineAppFlutter — 지뢰찾기 아레나 (Flutter 포팅)

원본 Swift/SwiftUI 앱(`../MineApp`, App Store 출시됨)을 Google Play + iOS 재출시용으로 Flutter 전면 재작성한 프로젝트. 원본은 **읽기 전용 참고**만 하고 절대 수정하지 않는다. 한국어 단일 언어.

## 핵심 제약: 결정성(Determinism)

크로스플레이(iOS↔Android)는 같은 시드로 **양쪽이 비트 단위로 동일한 보드**를 생성하는 데 의존한다. `lib/core/seeded_random.dart`는 Swift `SeededGenerator`(SplitMix64) + Swift stdlib의 난수 소비 방식을 그대로 재현한 것이다. 여기 손대면 크로스플레이가 깨진다.

- `nextBounded`: Swift `next(upperBound:)` = Lemire(`multipliedFullWidth`→high), BigInt로 128비트 곱.
- `doubleInRange`: Swift `Double.random`은 Lemire가 **아님** — `next() & (2^53-1) / 2^53`(하위 53비트 마스크).
- `nextBool`: `(next()>>>17)&1==0`. Dart 정수는 2^64 wrap, 논리 시프트는 `>>>` 사용.
- 변경 시 반드시 `test/seeded_random_test.dart`(Swift 실측 golden vector)로 검증.

## Firebase

- 프로젝트 `mineapp-aabc8`. 익명 인증, named Firestore `mineappdatabase`, RTDB `boards/<id>/r<round>`.
- 매칭 스키마는 원본 `FirebaseMatchService.swift`와 정확히 일치해야 함(같은 백엔드 공유 가능).
- **비밀키 파일은 git 제외** (`.gitignore`): `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`. 커밋 금지 — 과거 키 노출 이력 있음. 클론 시 `firebase_options.dart.example` 복사 또는 `flutterfire configure`.

## iOS 빌드 함정

- **SPM 금지**: Xcode 16.2는 firebase-ios-sdk SPM 해석 불가 → `flutter config --no-enable-swift-package-manager`, CocoaPods 사용. pod 오류 시 `cd ios && pod repo update`.
- **Firebase Auth엔 Keychain Sharing 필수**: `ios/Runner/Runner.entitlements`(keychain-access-groups) + pbxproj `CODE_SIGN_ENTITLEMENTS`. deployment target 15.0.
- 익명 인증/매칭은 `flutter run`으로만 동작(entitlement 임베드됨). `simctl install`한 빌드는 keychain 막혀 인증 전부 실패.

## Android

- `adb: Operation not permitted`(macOS 샌드박스) → APK를 `/tmp`로 복사 후 `adb install -r /tmp/app-debug.apk`.

## 아키텍처

- 상태관리: `ChangeNotifier` + `ListenableBuilder`(파라미터명 `listenable:`). provider 패키지 안 씀.
- 테마: `lib/core/theme.dart` `AppTheme` — 원본 `Theme.swift` 팔레트(다크 우선 grayscale) 이식. 색상/톤은 원본과 동일 유지.
- 모드: 솔로 `game_screen`, 대전(스피드/점수) `multiplayer/`, 협동 `modes/touch_model`, 보물찾기 `modes/treasure_model`.
- 명령: `flutter run -d <id>`, `flutter test`.

## 원본에서 아직 미이식(로드맵)

협동/보물찾기 화면, 샵/랭킹/우편, 아이템 버튼(자동깃발·레이더), AFK 자동몰수, Apple/Google 로그인, bestTime/재개 스냅샷의 shared_preferences 연동, 익명 uid 데이터 이관.
