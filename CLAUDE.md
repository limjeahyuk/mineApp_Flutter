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

## UI 원칙 — 원본 SwiftUI와 픽셀 단위로 맞춤
- 공용 UI 키트 `lib/core/ui.dart`: `SF.*`(SF Symbols 모양 = CupertinoIcons, 없는 것만 둥근 Material), `sf(size, weight:)`(SwiftUI `.font(.system)` 대응), `Tap`(리플 없는 `.buttonStyle(.plain)`), `GoldenMineIcon`(코인 = 황금지뢰 벡터), `showAppSheet`+`SheetScaffold`(원본 `.sheet{NavigationStack{…닫기}}`), `Segmented`, `showCupertinoConfirm/Alert/TextAlert`, `ToastMixin`.
- **Material 아이콘·InkWell·AppBar 쓰지 말 것**(원본과 달라 보임). 수치(패딩·크기·라운드·폰트)는 Swift 파일 값을 그대로 옮긴다.
- 홈에서 여는 화면(상점·랭킹·업적·선물함·공지·가이드·내 정보·설정·솔로 난이도)은 시트, 멀티 메뉴는 풀스크린 — 원본과 동일.
- 색상 테마(스킨) 이식: `ColorThemeDef`(theme.dart) + `colorThemeNotifier`. 표면색만 틴트(`AppTheme._g`), 글자색은 무채색(`_n`).
- 스크린샷 검증: 로컬 전용 `test_shots/`(git 제외, `.git/info/exclude`)에서 한글·이모지 폰트를 로드해 PNG로 렌더 후 원본 코드와 대조.

## 아이템(레이더·자동깃발)
- 로직은 `game_model.dart`(`useRadar`/`useAutoFlag`, 티켓=min(보유, 상한)). 상한: 레이더 `Difficulty.radarCap`(초1·중1·고2·최고3), 자동깃발 솔로 `soloAutoFlagCap`(초3·중3·고5·최고7)·타모드 3.
- 인벤토리 영속화: `LocalStore.ownedFlags/ownedRadars`(시작지급 flag 10·radar 5, `consumeFlag/Radar`·`addFlags/Radars`).
- 배선: 화면(game_screen·versus_screen) initState에서 `game.autoFlagSupplier/onConsumeAutoFlag/radarSupplier/onConsumeRadar`를 LocalStore에 연결(**startSolo/startSeeded 전에** — 거기서 티켓 계산).
- UI: `item_dock.dart` = Swift AutoFlagDock. **초급·중급은 우하단 플로팅, 고급·최고급·보물찾기·협동은 오른쪽 엣지 서랍(손잡이 `<` 탭해서 열기, 위아래 드래그)**. 자동깃발은 탭→probing(보라 강조)→다음 탭을 onProbe로(실패해도 발동 해제). 솔로는 레이더 0개면 버튼 숨김(`hideRadarWhenEmpty`), 손잡이에 남은 수 표시(`soloHandle`).

## 상점(코인·가챠) — 이식됨
- `shop/shop_screen.dart`(뽑기/충전 2탭), `shop/shop_logic.dart`(draw/drawTriple, 균등 1/3, 잭팟=×3 전부 일치 시 전 아이템 3개씩).
- 코인/광고: `LocalStore.coins`(시작 100), `drawCost 30`·`tripleDrawCost 90`, `claimRewardedAd`(+30, 하루 `dailyAdLimit 5`). 광고는 시뮬(즉시 지급) — 실제 AdMob 미이식. 유료 코인팩(IAP)도 미이식("준비 중").
- 홈·대전메뉴 코인 칩은 `LocalStore.coins` 실값 표시. 홈 상점 아이콘/코인 칩 → ShopScreen.

## 랭킹 — 이식됨
- `ranking/ranking_screen.dart`(솔로/대전·협동 2탭), `ranking/ranking_service.dart`(Firestore `scores`, named DB `mineappdatabase`, docId `deviceId_난이도`, difficulty=`Difficulty.label`, timeSec 클라 정렬).
- 로컬 기록: `LocalStore.soloBest/soloClearCount/recordSolo`(난이도별 최고·클리어수), 대전 전적 `raceWins/Losses/Draws/recordRace*`.
- 배선: 솔로 승리 → `game.onSoloWin`에서 `recordSolo` + 신기록이면 `RankingService.submitBest`(game_screen). 대전 종료 → versus_screen 리스너가 `recordRace*` 1회. 홈 랭킹 버튼 → RankingScreen.
- **기존 Swift 앱과 같은 `scores` 컬렉션 → 크로스플랫폼 랭킹 공유**(실측 확인). 협동 랭킹 `touchScores`(docId=deviceId)도 이식 — 협동 성공 시 `recordTouch` + 신기록이면 제출, 랭킹 대전·협동 탭에 최고 기록·전체 등수.
- 솔로 클리어 코인 보상(초급1·중급5·고급10·최고급20)·황금지뢰 +10(`LocalStore.awardClearReward/awardGoldenMine`), 클리어 팝업의 전체 등수(`RankingService.onlineRank`).

## 우편함 · 업적/칭호 — 이식됨
- 우편함: `mail/mail.dart`(MailGift + Firestore `mailGifts` 읽기, named DB) + `mail/mail_screen.dart`. "받기" → `LocalStore.grantMailReward` + `markMailClaimed`(1회). 홈 선물 아이콘 → MailScreen.
- 업적/칭호: `progression/title.dart`(칭호 23종 카탈로그 + Goal 평가 + `refreshAchievements`) + `progression/achievements_screen.dart`(도전과제 진행/칭호 장착·구매 2탭). 홈 업적 → AchievementsScreen.
- 통계(LocalStore): `gachaDraws/gachaJackpots`(ShopLogic 배선), `goldenMinesFound`(game.onGoldenMineFound 배선), `bestWinStreak`(recordRaceWin/Loss), `noItemExpert/UltimateClears`(onSoloWin noItem). 칭호 보유 `ownedTitleIds`+장착 `equippedTitleId`.
- 협동(touchClears/touchUnder)·테마(themesOwned) 목표도 이식(`LocalStore.touchBest/touchClears/ownedThemeIds`).

## 협동·보물찾기 모드 — 이식됨
- 모델은 기존 `modes/touch_model.dart`(협동 안개 공유보드)·`modes/treasure_model.dart`(중앙 보물 경쟁). 컨트롤러/화면 신규:
  - 협동: `modes/coop_controller.dart` + `coop_screen.dart`(`FirebaseMatchService(kind:'touch')`, 안개 렌더 = `isVisible` 밖은 어둡게, 만나면 공동 승리). **보드 80×80(원본과 동일, 크로스플레이 정합)** — 화면보다 크므로 `InteractiveViewer(constrained:false)` 팬/줌 + 판 시작 시 내 시작점 자동 센터링(고정 셀 28px). `TouchModel` 타이머는 매초 rebuild 방지 위해 elapsed만 증가(알림 X). 2 시뮬 실측 검증됨.
  - 보물: `modes/treasure_controller.dart` + `treasure_screen.dart`(`kind:'treasure'`, 중앙 💎 먼저 열면 승리, 나·상대 진행바).
- 대전 메뉴 게임유형 탭(`GameType.mine/treasure/coop`)이 실제 라우팅 — 랜덤/방만들기/코드참가가 선택 유형의 화면을 연다.
- 협동: 확성기 핑(방향 화살표 배너)·지뢰 페널티(파트너 깃발 1개 드롭)·기절 배너·만난 지점 복기 마커까지 이식(`coop_controller.dart`, `touch_board.dart`).
- 보물찾기 멀티 보드는 **51×51**(원본 동일 — 예전 15×15는 버그였음). 게스트는 180° 뒤집어 그림, 카운트다운 없이 바로 시작(원본 동일). 큰 보드는 CustomPaint 한 장(`treasure_board.dart`/`touch_board.dart`)으로 그려 성능 확보.
- 대전: 자리비움 경고(30초)/항복(120초)(`RaceController`), 방 코드 복사·공유(share_plus).

## 환경설정 · 내 정보 — 이식됨
- 환경설정: `settings/settings_screen.dart` — 화면 테마(시스템/라이트/다크) + 게임 햅틱 2종 on/off. 테마는 전역 `themeModeNotifier`(theme.dart)+`setThemeMode`로 즉시 반영, `main.dart`의 `MaterialApp.themeMode`가 구독. 저장은 `LocalStore.themeMode`. 햅틱은 `Haptics.isEnabled/isFlagEnabled`(LocalStore 백업)로 게이트. 색상 테마(스킨) 갤러리는 미이식(클래식 무채색만).
- 내 정보: `profile/profile_screen.dart` — 닉네임 변경(다이얼로그, 최대 16자) + 장착 칭호 배지(`equippedTitleId`→Title.all 조회, rarity 색) + 보유(코인·자동깃발·레이더) + 난이도별 솔로 기록(soloBest/soloClearCount) + **계정 섹션**(아래 참고).
- 홈 하단 내비 내 정보→ProfileScreen, 설정→SettingsScreen.

## 계정(Apple/Google 로그인) · 계정 삭제 — 이식됨
- 코드: `core/account_auth.dart`(LinkOutcome sealed + `firebaseLinkOrSignIn`=익명이면 link 승격, `credential-already-in-use`면 signIn 전환), `core/apple_auth.dart`(sign_in_with_apple, crypto nonce), `core/google_auth.dart`(google_sign_in **v7** API: `instance.initialize/authenticate`, idToken-only), `core/account_deletion.dart`(재인증+Apple revoke → 클라우드 삭제 → user.delete → 로컬 wipe → 재익명), `core/cloud_backup.dart`(users/{uid} 백업/복원). Swift Auth/* 이식.
- 백업 데이터: `LocalStore.exportBackup/restoreBackup`(닉네임·재화·아이템·칭호·기록·전적; 일일/공지/광고일자 제외). linked→backup, switched→restore. `wipeLocalData()`는 deviceId만 남기고 clear. **ponytail: 전환 시 클라우드 값으로 덮어쓴다(기기 병합 미이식).**
- UI: ProfileScreen 계정 섹션 — 미연동이면 Apple(iOS만)·Google 버튼, 항상 "계정 삭제(회원탈퇴)"(확인 다이얼로그). 결과 토스트.
- iOS 설정: `Runner.entitlements`에 `com.apple.developer.applesignin`(Default), `Info.plist`에 Google REVERSED_CLIENT_ID URL scheme 추가. 웹 클라이언트 id는 `google_auth.dart` 상수(공개 OAuth id).
- **콘솔/수동 필요(미완)**: Firebase Auth에서 Apple·Google provider 활성화, Apple Developer의 App ID에 Sign in with Apple capability + 프로비저닝, **Android Google 로그인은 Firebase 콘솔에 릴리스/디버그 SHA-1 등록 필요**(현 google-services.json엔 type1 클라이언트 없음). iOS 번들 id 불일치 주의: firebase_options=`com.imjaehyeog.MineApp` vs Xcode=`com.imjaehyeog.mineApp`.
- 테스트: `test/backup_test.dart`(export→restore 왕복 보존).

## Firebase 보안 규칙 — 코드화(rules-as-code)
- `firestore.rules` + `firebase.json`(named DB `mineappdatabase` 타깃) + `.firebaserc`(mineapp-aabc8). 정책 A=로그인(익명 포함)만. 컬렉션: scores/touchScores/matches(+하위)/mailGifts=로그인 읽기·쓰기, users/{uid}=본인만, notices=로그인 읽기·쓰기 금지(콘솔만).
- 배포: `firebase deploy --only firestore:rules`(named DB로 나감). `--dry-run` 컴파일 확인됨. **실제 게시는 프로덕션 영향이라 사용자 확인 후 실행.** RTDB(`boards`) 규칙은 별도(미포함).

## Android 릴리스 서명 — 플러밍 이식
- `android/app/build.gradle.kts`: `key.properties`(gitignore됨) 있으면 릴리스 키, 없으면 디버그 폴백. `android/key.properties.example` 템플릿 + keytool 명령 포함. **키스토어 생성/비밀번호는 사용자 수동.**

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

## 봇과 대전 — 이식됨(지뢰찾기: 스피드·지뢰 대결·합동)
- `multiplayer/bot_match_service.dart`(MatchService 구현). Swift BotMatchService 이식.
  - 스피드: 시간 기반 상대 시뮬(난이도별 목표 시각 speedFinishSeconds에 완료, 초급≈35초·최고급≈14분).
  - 지뢰 대결: 봇이 같은 시드 보드의 미러(GameModel)를 직접 플레이 — 열린 숫자만으로 추론(deductions), 확정 지뢰는 flagBias 확률로 차지, 막히면 frontier 안전칸 확장. onRemoteBoard로 사람 화면 공유 보드에 반영, 사람 동작은 pushReveal/pushFlag로 봇 미러에 반영. turnInterval+paceMultiplier(후반 감속)로 난이도 조절.
- 배선: `RaceMode.bot(difficulty, rule)`(multiplayer.dart) → versus_screen이 mode.kind==bot이면 BotMatchService 사용, 아니면 FirebaseMatchService. race_controller: bot은 find로 매칭·rematch로 같은 봇 새 판. 대전 메뉴 '봇과 대전' 카드(지뢰찾기만; 보물/협동은 "준비 중").
  - 합동: 봇 파트너가 같은 보드를 함께 — 확정 안전칸만 열고 확정 지뢰엔 깃발(추측 없음, 막히면 사람을 기다림). `test/bot_test.dart`.
- 봇 칭호(opponentTitle) 랜덤 부여. 원본에도 보물찾기/너에게 닿기를 봇은 없다(보물찾기는 '혼자 연습' = `modes/treasure_solo_screen.dart`).

## 이어하기 · 딥링크 · 칭호 배너 — 이식됨
- 솔로 이어하기: 백그라운드 전환 시 `GameModel.makeResumeSnapshot` → `LocalStore.saveSoloResume`, 다음 진입 때 "이어서 할까요?"(홈으로 나가거나 판이 끝나면 폐기). `test/resume_test.dart`.
- 초대 딥링크 `mineapp://…?g=mine|treasure|touch&c=CODE`(app_links, `core/deep_link.dart`) — iOS URL scheme·Android intent-filter.
- 새 칭호 배너: 통계 변동 지점에서 `announceAchievements()` → main의 오버레이가 2.8초 표시.

## 출시 설정
- `Info.plist`의 `ITSAppUsesNonExemptEncryption=false`(표준 HTTPS만 사용 → TestFlight 수출 규정 질문 생략).
- 스플래시 배경 = 아이콘 보라 배경 `#5C5FC5`(iOS LaunchScreen, Android launch_background + values-v31 SplashScreen API).

## 원본에서 아직 미이식(로드맵)

실제 AdMob 보상형 광고(현재 시뮬 — Android용 AdMob 앱 ID 필요), IAP 코인팩, Game Center(iOS 전용), bestTime(판 코드별 최고)의 영구 저장.
이 컨테이너에선 Android SDK 다운로드(dl.google.com)가 막혀 있어 APK 빌드는 로컬에서 확인해야 한다.

코드는 됐고 **콘솔/수동만 남은 것**: Firebase 규칙 실제 게시(위 dry-run 통과), 릴리스 키스토어 생성, Firebase Auth provider 활성화 + Apple capability/프로비저닝 + Android SHA-1 등록.
