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
- **`LocalStore`(core/local_store.dart) = Swift `RankingStore` 이식, ChangeNotifier.** 코인·아이템·기록·칭호·통계가 바뀌면 notify(홈 코인칩/뱃지가 구독). 기록은 `ScoreEntry`(core/score_entry.dart) 리스트(난이도별 최근 50). 통계를 바꾸는 메서드(recordSolo/recordRace/awardGoldenMine/recordTouch/뽑기)가 **내부에서 일일 bump + `refreshAchievements()`**까지 처리 — 화면에서 `Daily.bump` 중복 호출 금지(뽑기만 shop_logic이 bump).
- 테마: `lib/core/theme.dart` `AppTheme` — 원본 `Theme.swift` 팔레트(다크 우선 grayscale) 이식. 색상 테마(스킨) `ColorTheme`(클래식+5종, 1000코인)도 이식 — 표면색에만 틴트, 글자는 무채색. `colorThemeNotifier`/`selectColorTheme`. `GoldenMineIcon`(코인 아이콘)도 여기.
- **UI 규약(core/ui.dart)**: SwiftUI 표현을 흉내 — `presentSheet`(=.sheet, CupertinoSheetRoute) + `SheetScaffold`(inline 제목+우상단 "닫기"), `presentFullScreen`(=.fullScreenCover), `presentMediumSheet`(=.presentationDetents medium), `fadeRoute`(홈↔게임 0.25초 크로스페이드), `PlainButton`(=.buttonStyle(.plain), 물결 없음), `ToastController/ToastOverlay`(검은 캡슐 토스트), `showAppAlert`/`showConfirmSheet`(Cupertino alert/action sheet), `SegmentedPicker`, `timeLabel`/`formatNumber`. 새 화면도 이 규약을 따른다.
- 모드: 솔로 `game_screen`, 대전(스피드/점수) `multiplayer/`, 협동 `modes/touch_model`, 보물찾기 `modes/treasure_model`.
- 명령: `flutter run -d <id>`, `flutter test`.

## 솔로 게임 화면(game_screen) — Swift ContentView 이식
- 상단바(홈·난이도·⋯=판 코드 시트) + 헤더(LED 카운터 %03d·얼굴=같은 판 재시작·확대 2.5배·깃발 모드) + 보드 + 상태 문구. 고급은 dense 레이아웃, 가로(최고급)는 얇은 헤더바.
- 패배 팝업(이어하기/새 판/보드 보기), 클리어 팝업(색종이·신기록 배지·전체 등수 조회·한 번 더/홈으로/결과 보기), 이어하기 팝업(앱 종료 후 복원 — `makeResumeSnapshot/restore`, 백그라운드 진입 시 저장).
- 클리어 보상 코인(`LocalStore.clearReward`), 황금지뢰 +10코인 + 상단 토스트. 판 코드별 최고기록은 `LocalStore.bestTimeForCode`.
- 셀 제스처: 탭/길게(0.3초). probing 중엔 **어떤 탭이든** onProbe(실패하면 그냥 해제). 보드 확대는 `BoardWidget(zoomedIn,onZoomChanged)` 버튼↔핀치 동기화.

## 아이템(레이더·자동깃발·확성기)
- 로직은 `game_model.dart`(`useRadar`/`useAutoFlag`, 티켓=min(보유, 상한)). 상한: 레이더 `Difficulty.radarCap`(초1·중1·고2·최고3), 자동깃발 솔로 `soloAutoFlagCap`(초3·중3·고5·최고7)·타모드 3. 확성기는 협동 전용.
- 인벤토리: `LocalStore.ownedFlags/ownedRadars/ownedMegaphones`(시작지급 10/5/5).
- 배선: 솔로는 game_screen, 대전/보물/협동은 각 컨트롤러 생성자에서 LocalStore에 연결(startSolo/startShared 전에 — 거기서 티켓 계산).
- UI: `item_dock.dart` = Swift AutoFlagDock(+솔로 변형 `solo:true`). 초급·중급=우하단 플로팅, 고급·최고급·보물·협동=우측 엣지 서랍(손잡이 드래그 이동). Stack 안에 `Positioned`로 들어간다.

## 상점(코인·가챠) — 이식됨
- `shop/shop_screen.dart`(뽑기/충전 2탭, initialTab 0=뽑기 1=충전 — 홈 코인칩=충전, 가방=뽑기), `shop/shop_logic.dart`(draw/drawTriple, 균등 1/3, 잭팟=×3 전부 일치 시 전 아이템 3개씩). ×3은 슬롯 3릴 순차 정지 연출.
- 코인/광고: `LocalStore.coins`(시작 100), `drawCost 30`·`tripleDrawCost 90`, `claimRewardedAd`(+30, 하루 `dailyAdLimit 5`). 광고는 Swift 폴백과 같은 4초 시뮬 화면(`_RewardedAdView`) — 실제 AdMob 미이식.
- 홈·대전메뉴 코인 칩은 `LocalStore.coins` 실값 표시. 홈 상점 아이콘/코인 칩 → ShopScreen.

## 랭킹 — 이식됨
- `ranking/ranking_screen.dart`(솔로/대전·협동 2탭), `ranking/ranking_service.dart`(Firestore `scores`, named DB `mineappdatabase`, docId `deviceId_난이도`, difficulty=`Difficulty.label`, timeSec 클라 정렬).
- 로컬 기록: `LocalStore.soloBest/soloClearCount/recordSolo`(난이도별 최고·클리어수), 대전 전적 `raceWins/Losses/Draws/recordRace*`.
- 배선: 솔로 승리 → `game.onSoloWin`에서 `recordSolo` + 신기록이면 `RankingService.submitBest`(game_screen). 대전 종료 → versus_screen 리스너가 `recordRace*` 1회. 홈 랭킹 버튼 → RankingScreen.
- **기존 Swift 앱과 같은 `scores` 컬렉션 → 크로스플랫폼 랭킹 공유**(실측 확인). 협동 랭킹 `touchScores`(docId=deviceId)도 제출/조회(`submitTouchBest/topTouch/touchOnlineRank`). 랭킹 화면 대전·협동 탭에 협동 최고·전체 등수.

## 우편함 · 업적/칭호 — 이식됨
- 우편함: `mail/mail.dart`(MailGift + Firestore `mailGifts` 읽기, named DB) + `mail/mail_screen.dart`. "받기" → `LocalStore.grantMailReward` + `markMailClaimed`(1회). 홈 선물 아이콘 → MailScreen.
- 업적/칭호: `progression/title.dart`(칭호 23종 카탈로그 + Goal 평가 + `refreshAchievements`) + `progression/achievements_screen.dart`(도전과제 진행/칭호 장착·구매 2탭). 홈 업적 → AchievementsScreen.
- 통계(LocalStore): `gachaDraws/gachaJackpots`(ShopLogic 배선), `goldenMinesFound`(game.onGoldenMineFound 배선), `bestWinStreak`(recordRaceWin/Loss), `noItemExpert/UltimateClears`(onSoloWin noItem). 칭호 보유 `ownedTitleIds`+장착 `equippedTitleId`.
- 모든 업적 목표 이식(협동 touchClears/touchUnder, 테마 themesOwned 포함). 해금 시 미착용이면 자동 장착 + 앱 상단 "새 칭호 획득!" 배너(`LocalStore.pendingUnlockToast`, main.dart의 `_UnlockBannerHost`). 칭호 배지 위젯 `TitleBadge`(title.dart).

## 협동·보물찾기 모드 — 이식됨
- 모델: `modes/touch_model.dart`(협동 안개 공유보드)·`modes/treasure_model.dart`(중앙 보물 경쟁). 둘 다 매초 시계는 `tick`(ValueNotifier)으로만 알림 — 보드 전체 rebuild 방지.
  - 협동: `coop_controller.dart`(Swift TouchRaceViewModel: 카운트다운 없음, 확성기 핑·지뢰 페널티(파트너 깃발 1개 떨어뜨림) 동기화, 성공 시 `recordTouch`+`submitTouchBest`) + `coop_screen.dart` + `touch_board.dart`(**80×80을 CustomPaint 한 장**으로 그림, 30px 셀, 2축 스크롤, 시작점 센터링, 핑 배너, 복기 시 만난 지점 마커).
  - 보물: `treasure_controller.dart`(**보드 51×51 — 원본과 동일**, 카운트다운 없음, 상대 자멸=승) + `treasure_screen.dart` + `treasure_board.dart`(30px 셀·프런티어 금테·게스트 180° 뒤집기·폭발·흔들림) + `treasure_solo_screen.dart`(혼자 연습).
- 대전 메뉴(`versus_menu_screen.dart`)는 Swift MultiplayerMenuView 그대로 — 지뢰찾기(스피드/지뢰 대결/합동 × 난이도, 랜덤/봇/방/코드), 보물찾기(랜덤/방/코드 + 혼자 연습), 너에게 닿기를(랜덤/방/코드). 게임 화면은 메뉴를 `pushReplacement`(닫으면 홈으로 — Swift와 동일).
- 대전·보물·협동 공용 UI 조각: `multiplayer/match_widgets.dart`(검색/방코드+공유/실패/카운트다운/결과/자리비움 배너/진행바, `InviteLink`).

## 환경설정 · 내 정보 — 이식됨
- 환경설정: `settings/settings_screen.dart` — 화면 테마(시스템/라이트/다크) + 색상 테마 갤러리(구매/적용) + 게임 햅틱 2종 on/off(깃발 진동 기본 꺼짐). 테마는 `themeModeNotifier`/`colorThemeNotifier`를 `main.dart`가 구독.
- 내 정보: `profile/profile_screen.dart` — 닉네임 변경(Cupertino 알럿, 최대 16자) + 장착 칭호 배지 + 보유(코인·자동깃발) + 난이도별 솔로 기록 + **계정 섹션**(아래 참고).
- 홈 하단 내비 내 정보→ProfileScreen, 설정→SettingsScreen.

## 계정(Apple/Google 로그인) · 계정 삭제 — 이식됨
- 코드: `core/account_auth.dart`(LinkOutcome sealed + `firebaseLinkOrSignIn`=익명이면 link 승격, `credential-already-in-use`면 signIn 전환), `core/apple_auth.dart`(sign_in_with_apple, crypto nonce), `core/google_auth.dart`(google_sign_in **v7** API: `instance.initialize/authenticate`, idToken-only), `core/account_deletion.dart`(재인증+Apple revoke → 클라우드 삭제 → user.delete → 로컬 wipe → 재익명), `core/cloud_backup.dart`(users/{uid} 백업/복원). Swift Auth/* 이식.
- 백업 데이터: **Swift `UserBackupService`와 같은 users/{uid} 스키마**(`LocalStore.exportBackup/mergeBackup`) — iOS 구버전 백업도 그대로 복원. 연동/전환 모두 `CloudBackup.syncAfterLink`(머지: 기록 합집합, 같은 기기면 max·다른 기기면 합산, 칭호/테마 합집합) 후 재백업. 연동 계정이면 값 변경 시 1초 디바운스 자동 백업(`LocalStore.backupHook`). `wipeLocalData()`는 Swift처럼 **새 deviceId 발급**(설정만 유지).
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
- 콜드런치 공지 팝업(`notice_popup.dart`, "오늘은 그만 보기") 이식됨 — 홈 initState에서 1회.

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
  - 합동: 봇 파트너가 확정 안전칸만 열고 확정 지뢰엔 깃발(추측 안 함).
- 배선: `RaceMode.bot(difficulty, rule)` → versus_screen이 BotMatchService 사용. race_controller 재대결 규칙은 Swift와 동일(host/join=같은 상대 핸드셰이크, quick/bot=leave 후 새로 find). 봇 칭호(`randomBotTitle`) 표시.
- race_controller에 Swift 자리비움(AFK) 항복 이식: 30초 무조작 경고 배너, 120초면 패배 기록 후 나감. 백그라운드 시간은 제외. 대전 전적·황금지뢰 보상은 컨트롤러가 기록.

## 초대 딥링크
- `mineapp://join?g=mine|treasure|touch&c=코드` (iOS CFBundleURLSchemes·Android intent-filter 등록, `app_links`). 홈이 받아 해당 방 참가 화면으로 이동. 공유 문구/링크는 `InviteLink.webURL`(Firebase Hosting `/j` 랜딩, Swift와 동일) + `share_plus`.

## 원본에서 아직 미이식(로드맵)

실제 AdMob(시뮬레이션만), Game Center(iOS 전용), ATT. 구버전 Swift 앱의 기기 로컬(UserDefaults) 데이터 자동 이전은 안 됨(클라우드 연동 계정은 머지로 복원됨).

코드는 됐고 **콘솔/수동만 남은 것**: Firebase 규칙 실제 게시(위 dry-run 통과), 릴리스 키스토어 생성, Firebase Auth provider 활성화 + Apple capability/프로비저닝 + Android SHA-1 등록.
