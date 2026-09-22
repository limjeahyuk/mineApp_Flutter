# MineAppFlutter — 지뢰찾기 아레나 (Flutter 포팅)

원본 Swift/SwiftUI 앱(`../MineApp`, App Store 출시됨)을 Google Play + iOS 재출시용으로 Flutter 전면 재작성한 프로젝트. 원본은 **읽기 전용 참고**만 하고 절대 수정하지 않는다. 한국어 단일 언어.

## 핵심 제약: 결정성(Determinism)

크로스플레이(iOS↔Android)는 같은 시드로 **양쪽이 동일한 보드**를 생성하는 데 의존한다. RTDB엔 보드 전체가 아니라 `seed`(정수 하나)만 오가고, 양쪽이 각자 `lib/core/seeded_random.dart`로 같은 보드를 만든다.

- 내부는 `dart:math`의 `Random(seed)` — 플랫폼 무관 결정적이라 iOS/Android 둘 다 Flutter면 같은 seed → 같은 수열. 별도 구현 불필요.
- 난수 **소비 순서**(어떤 메서드를 몇 번 부르는지)는 여전히 보드 생성 로직에서 지켜야 한다(양쪽이 같은 코드를 도니 자동으로 맞음).
- 변경 시 `test/seeded_random_test.dart`(같은 seed → 같은 결과 재현성)로 검증.
- 참고: 예전엔 App Store의 옛 Swift 앱과도 매칭하려고 Swift stdlib 난수(SplitMix64+Lemire)를 비트단위 복제했으나, Flutter가 Swift를 완전 대체하기로 하여 걷어냄. 옛 Swift 앱과의 크로스버전 매칭은 포기(유저 거의 없음).

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

## 아이템(레이더·자동깃발)
- 로직은 `game_model.dart`(`useRadar`/`useAutoFlag`, 티켓=min(보유, 상한)). 상한: 레이더 `Difficulty.radarCap`(초1·중1·고2·최고3), 자동깃발 솔로 `soloAutoFlagCap`(초3·중3·고5·최고7)·타모드 3.
- 인벤토리 영속화: `LocalStore.ownedFlags/ownedRadars`(시작지급 flag 10·radar 5, `consumeFlag/Radar`·`addFlags/Radars`).
- 배선: 화면(game_screen·versus_screen) initState에서 `game.autoFlagSupplier/onConsumeAutoFlag/radarSupplier/onConsumeRadar`를 LocalStore에 연결(**startSolo/startSeeded 전에** — 거기서 티켓 계산).
- UI: `item_dock.dart`(우하단 플로팅). 자동깃발은 탭→probing(보라 강조)→숫자칸 탭으로 발동(BoardWidget/CellView의 `probing`/`onProbe`).

## 상점(코인·가챠) — 이식됨
- `shop/shop_screen.dart`(뽑기/충전 2탭), `shop/shop_logic.dart`(draw/drawTriple, 균등 1/3, 잭팟=×3 전부 일치 시 전 아이템 3개씩).
- 코인/광고: `LocalStore.coins`(시작 100), `drawCost 30`·`tripleDrawCost 90`, `claimRewardedAd`(+30, 하루 `dailyAdLimit 5`). 광고는 시뮬(즉시 지급) — 실제 AdMob 미이식. 유료 코인팩(IAP)도 미이식("준비 중").
- 홈·대전메뉴 코인 칩은 `LocalStore.coins` 실값 표시. 홈 상점 아이콘/코인 칩 → ShopScreen.

## 랭킹 — 이식됨
- `ranking/ranking_screen.dart`(솔로/대전·협동 2탭), `ranking/ranking_service.dart`(Firestore `scores`, named DB `mineappdatabase`, docId `deviceId_난이도`, difficulty=`Difficulty.label`, timeSec 클라 정렬).
- 로컬 기록: `LocalStore.soloBest/soloClearCount/recordSolo`(난이도별 최고·클리어수), 대전 전적 `raceWins/Losses/Draws/recordRace*`.
- 배선: 솔로 승리 → `game.onSoloWin`에서 `recordSolo` + 신기록이면 `RankingService.submitBest`(game_screen). 대전 종료 → versus_screen 리스너가 `recordRace*` 1회. 홈 랭킹 버튼 → RankingScreen.
- **기존 Swift 앱과 같은 `scores` 컬렉션 → 크로스플랫폼 랭킹 공유**(실측 확인). 협동 랭킹(`touchScores`)은 모드 미이식이라 "준비 중".

## 우편함 · 업적/칭호 — 이식됨
- 우편함: `mail/mail.dart`(MailGift + Firestore `mailGifts` 읽기, named DB) + `mail/mail_screen.dart`. "받기" → `LocalStore.grantMailReward` + `markMailClaimed`(1회). 홈 선물 아이콘 → MailScreen.
- 업적/칭호: `progression/title.dart`(칭호 23종 카탈로그 + Goal 평가 + `refreshAchievements`) + `progression/achievements_screen.dart`(도전과제 진행/칭호 장착·구매 2탭). 홈 업적 → AchievementsScreen.
- 통계(LocalStore): `gachaDraws/gachaJackpots`(ShopLogic 배선), `goldenMinesFound`(game.onGoldenMineFound 배선), `bestWinStreak`(recordRaceWin/Loss), `noItemExpert/UltimateClears`(onSoloWin noItem). 칭호 보유 `ownedTitleIds`+장착 `equippedTitleId`.
- 미이식 목표(항상 잠금): 협동(touchClears/touchUnder)·테마(themesOwned) — `UnportedGoal`. 일일 도전과제(DailyChallenge)도 미이식.

## 협동·보물찾기 모드 — 이식됨
- 모델은 기존 `modes/touch_model.dart`(협동 안개 공유보드)·`modes/treasure_model.dart`(중앙 보물 경쟁). 컨트롤러/화면 신규:
  - 협동: `modes/coop_controller.dart` + `coop_screen.dart`(`FirebaseMatchService(kind:'touch')`, 안개 렌더 = `isVisible` 밖은 어둡게, 만나면 공동 승리).
  - 보물: `modes/treasure_controller.dart` + `treasure_screen.dart`(`kind:'treasure'`, 중앙 💎 먼저 열면 승리, 나·상대 진행바).
- 대전 메뉴 게임유형 탭(`GameType.mine/treasure/coop`)이 실제 라우팅 — 랜덤/방만들기/코드참가가 선택 유형의 화면을 연다.
- ponytail 미이식: 협동 지뢰 페널티 상대 동기화·확성기 브로드캐스트·stun 전파(핵심 reveal/flag/보드 동기화만), 보물 깃발 동기화(TreasureModel엔 onPushFlag 없음).

## 환경설정 · 내 정보 — 이식됨
- 환경설정: `settings/settings_screen.dart` — 화면 테마(시스템/라이트/다크) + 게임 햅틱 2종 on/off. 테마는 전역 `themeModeNotifier`(theme.dart)+`setThemeMode`로 즉시 반영, `main.dart`의 `MaterialApp.themeMode`가 구독. 저장은 `LocalStore.themeMode`. 햅틱은 `Haptics.isEnabled/isFlagEnabled`(LocalStore 백업)로 게이트. 색상 테마(스킨) 갤러리는 미이식(클래식 무채색만).
- 내 정보: `profile/profile_screen.dart` — 닉네임 변경(다이얼로그, 최대 16자) + 장착 칭호 배지(`equippedTitleId`→Title.all 조회, rarity 색) + 보유(코인·자동깃발·레이더) + 난이도별 솔로 기록(soloBest/soloClearCount). 계정 연동(Apple/Google)·계정 삭제는 플랫폼 연동 미이식이라 생략.
- 홈 하단 내비 내 정보→ProfileScreen, 설정→SettingsScreen.

## 가이드 — 이식됨
- `guide/guide_screen.dart` — Swift TutorialView 이식. 상단 탭 3개(튜토리얼/공략/멀티) + PageView 스와이프. 순수 정적 콘텐츠(로직 없음), 텍스트는 원본 그대로.
- 튜토리얼: 게임 목표 카드 + 기본 조작 + 화면 버튼·표시. 공략: 색 범례(지뢰=빨강·안전=초록) + 패턴 6종(①②③·1-2-1·1-2-2-1·1-1), 각 카드에 미니보드 일러스트(`_TutoBoard`, 숫자색은 `minesweeperNumberColor` 재사용). 멀티: 시작 방법 3종 + 게임별 규칙 카드 3종(지뢰찾기/보물찾기/너에게 닿기를).
- 홈 하단 내비 가이드→GuideScreen.

## 알림(공지) — 이식됨
- `notice/notice.dart`(Notice + NoticeService, Firestore `notices` 읽기, named DB, isActive==true + 클라 정렬=고정 먼저·최신순) + `notice/notice_screen.dart`(목록·고정 배지·빈 상태). Swift NoticeView/Notice 이식.
- 홈 종(bell)→NoticeScreen. 안 읽음 점: 홈 initState에서 공지 조회 후 `LocalStore.noticeLastSeen`보다 새 공지가 있으면 표시, 목록 열면 최신 시각 저장(markNoticesSeen)+점 끔.
- 미이식: 콜드런치 공지 팝업(NoticePopupView)·"오늘은 그만 보기"(목록만 이식).

## 일일 도전과제 — 이식됨
- 카탈로그: `progression/daily.dart`(DailyChallenge 풀 5종 + 결정적 `forDay`=날짜+kind FNV-1a 해시로 하루 3개, `Daily.bump/state/claim`). Swift DailyChallenge 이식.
- 저장: `LocalStore`(daily.day/progress(JSON)/claimed, 자정 롤오버 `_rollOverDailyIfNeeded`, `todayKey()` 공개=공지와 공용). 보상 수령=`addCoins`.
- 노출: 업적 화면 도전과제 탭 **상단** "오늘의 도전과제"(진행바·받기 버튼). 아래는 기존 장기 업적.
- 이벤트 배선(오늘 뽑힌 kind만 누적): 솔로 클리어→clears, 대전 승→raceWins, 황금지뢰→golden, 뽑기→draws(단일1·×3은 3), 협동 성공→touch. game_screen/versus_screen/shop_logic/coop_controller에서 `Daily.bump`.
- 테스트: `test/daily_test.dart`(forDay 결정성·회전, bump 가드, claim 1회).

## 원본에서 아직 미이식(로드맵)

봇과 대전(오프라인 연습), 실제 AdMob·IAP 코인팩, AFK 자동몰수, Apple/Google 로그인·계정 삭제, bestTime/재개 스냅샷의 shared_preferences 연동, 익명 uid 데이터 이관, 아이템/코인/칭호 클라우드 백업, 색상 테마(스킨), Game Center, 협동 랭킹(touchScores).
