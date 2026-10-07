import 'dart:convert';
import 'dart:math';

<<<<<<< HEAD
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../progression/daily.dart';
import '../progression/title.dart';
import '../ranking/ranking_service.dart';
import 'board.dart';
import 'cloud_backup.dart';
import 'types.dart';

/// Swift `RankingStore` 이식 — 닉네임·기록·전적·코인·아이템·테마·칭호·업적 통계·일일 도전과제.
///
/// **저장 키는 원본 Swift 앱의 UserDefaults 키와 동일**하다. 이 Flutter 앱은 App Store의
/// 기존 Swift 앱(같은 번들 ID)을 대체하므로, 업데이트한 사용자의 진행이 그대로 이어진다
/// (`main`에서 prefix를 ''로 두고, Data/Date/Dictionary 같은 비호환 타입은 iOS AppDelegate가
/// 첫 실행 때 `*.json`/`*Ms` 키로 변환해 둔다).
=======
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../progression/title.dart';
import '../multiplayer/multiplayer.dart' show RaceResult;
import 'board.dart';
import 'score_entry.dart';

/// Swift `RankingStore` 이식 — 로컬 개인 기록·닉네임·재화·아이템·칭호·통계·일일 도전과제 보관.
/// 값이 바뀌면 `notifyListeners`로 알린다(홈 코인 칩·뱃지 등이 구독).
/// deviceId는 반드시 **안정적**이어야 한다(매칭에서 "방금 나간 내 방"을 남의 방으로 오인하는 걸 막음).
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
class LocalStore extends ChangeNotifier {
  LocalStore._(this._prefs);
  final SharedPreferences _prefs;

  static LocalStore? _instance;
  /// 초기화돼 있으면 인스턴스(테스트 등 미초기화면 null).
  static LocalStore? get maybe => _instance;

  static LocalStore get shared {
    final i = _instance;
    if (i == null) throw StateError('LocalStore.init()를 main에서 먼저 호출하라.');
    return i;
  }

  /// 초기화 전이면 null(테스트에서 GameModel만 쓸 때).
  static LocalStore? get maybeShared => _instance;

  static Future<LocalStore> init() async {
    // 원본 Swift 앱과 같은 키를 쓰려고 'flutter.' 접두사를 뗀다(getInstance 전에만 가능).
    try {
      SharedPreferences.setPrefix('');
    } on StateError {
      // 이미 초기화됨(테스트 재진입 등) — 그대로 쓴다.
    }
    final prefs = await SharedPreferences.getInstance();
<<<<<<< HEAD
    final s = LocalStore._(prefs);
    s._load();
    return _instance = s;
  }

  // ── 상수 (Swift와 동일) ──
  static const dailyAdLimit = 5;
  static const adRewardCoins = 30;
=======
    final store = LocalStore._(prefs);
    _instance = store;
    store._load();
    return store;
  }

  /// 연동 계정이면 클라우드 백업을 요청하는 훅(main에서 CloudBackup에 연결). 테스트에선 null.
  static void Function()? backupHook;

  /// 갓 해금한 칭호(축하 배너용). 앱 루트가 구독해 잠깐 띄우고 null로 되돌린다.
  final ValueNotifier<Title?> pendingUnlockToast = ValueNotifier(null);

  // ── 키 ──
  static const _kDeviceId = 'device.id';
  static const _kNickname = 'ranking.nickname';
  static const _kNicknameSetByUser = 'ranking.nicknameSetByUser';
  static const _kLastSyncedDeviceId = 'ranking.lastSyncedDeviceId';
  static const _kRecords = 'ranking.localRecords'; // JSON [ScoreEntry]
  static const _kEquippedTitleName = 'ranking.equippedTitle'; // (구버전) 이름 캐시
  static const _kOwnedFlags = 'inv.ownedFlags';
  static const _kOwnedRadars = 'inv.ownedRadars';
  static const _kOwnedMegaphones = 'inv.ownedMegaphones';
  static const _kStarterMegaphones = 'inv.starterMegaphonesGranted';
  static const _kCoins = 'shop.coins';
  static const _kAdRewardDay = 'shop.adRewardDay';
  static const _kAdsWatchedToday = 'shop.adsWatchedToday';
  static const _kOwnedThemes = 'shop.ownedThemes';
  static const _kThemeMode = 'settings.themeMode';
  static const _kColorTheme = 'settings.colorTheme';
  static const _kHaptics = 'settings.haptics';
  static const _kFlagHaptics = 'settings.flagHaptics';
  static const _kNoticeLastSeen = 'notice.lastSeenMs';
  static const _kDailyDay = 'daily.day';
  static const _kDailyProgress = 'daily.progress'; // JSON {kind:int}
  static const _kDailyClaimed = 'daily.claimed'; // 콤마로 이은 kind들
  static const _kRaceWins = 'rank.raceWins';
  static const _kRaceLosses = 'rank.raceLosses';
  static const _kRaceDraws = 'rank.raceDraws';
  static const _kTouchBest = 'rank.touchBest';
  static const _kCurStreak = 'stat.curStreak';
  static const _kBestStreak = 'stat.bestStreak';
  static const _kGachaDraws = 'stat.gachaDraws';
  static const _kJackpots = 'stat.jackpots';
  static const _kGoldenMines = 'stat.goldenMines';
  static const _kNoItemExpert = 'stat.noItemExpert';
  static const _kNoItemUltimate = 'stat.noItemUltimate';
  static const _kTouchClears = 'stat.touchClears';
  static const _kOwnedTitles = 'title.owned';
  static const _kEquippedTitleId = 'title.equippedId';
  static const _kBestPrefix = 'best_'; // 판 코드별 최고 기록

  /// 첫 실행 시작 지급 — Swift와 동일(코인 100, 자동깃발 10, 확성기 5, 레이더 5).
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  static const startingCoins = 100;
  static const startingFlags = 10;
  static const startingMegaphones = 5;
  static const startingRadars = 5;
<<<<<<< HEAD
  static const drawCost = 30;
  static const tripleDrawCost = drawCost * 3;
  static const goldenMineReward = 10;
  static const themeCost = 1000;

  // ── 키 (Swift Keys와 동일) ──
  static const _kNickname = 'ranking.nickname';
  static const _kDeviceId = 'ranking.deviceId';
  static const _kRecords = 'ranking.localRecords.json'; // Swift Data → AppDelegate가 JSON 문자열로 변환
  static const _kWins = 'ranking.raceWins';
  static const _kLosses = 'ranking.raceLosses';
  static const _kDraws = 'ranking.raceDraws';
  static const _kTouchBest = 'ranking.touchBest';
  static const _kNicknameSetByUser = 'ranking.nicknameSetByUser';
  static const _kLastSyncedDeviceId = 'ranking.lastSyncedDeviceId';
  static const _kCoins = 'shop.coins';
  static const _kAdsWatchedToday = 'shop.adsWatchedToday';
  static const _kAdRewardDay = 'shop.adRewardDay';
  static const _kStartGranted = 'shop.startGranted';
  static const _kOwnedFlags = 'shop.ownedFlags';
  static const _kStarterFlags = 'shop.starterFlagsGranted';
  static const _kOwnedMegaphones = 'shop.ownedMegaphones';
  static const _kStarterMegaphones = 'shop.starterMegaphonesGranted';
  static const _kOwnedRadars = 'shop.ownedRadars';
  static const _kStarterRadars = 'shop.starterRadarsGranted';
  static const _kOwnedThemes = 'shop.ownedThemes';
  static const _kUnlockedTitles = 'titles.unlocked';
  static const _kEquippedTitle = 'titles.equipped';
  static const _kGoldenMines = 'stats.goldenMinesFound';
  static const _kGachaDraws = 'stats.gachaDraws';
  static const _kGachaJackpots = 'stats.gachaJackpots';
  static const _kBestWinStreak = 'stats.bestWinStreak';
  static const _kCurWinStreak = 'stats.currentWinStreak';
  static const _kTouchClears = 'stats.touchClears';
  static const _kNoItemExpert = 'stats.noItemExpertClears';
  static const _kNoItemUltimate = 'stats.noItemUltimateClears';
  static const _kDailyDay = 'daily.day';
  static const _kDailyProgress = 'daily.progress.json'; // Swift Dictionary → JSON 문자열
  static const _kDailyClaimed = 'daily.claimed';
  // 기타 화면 상태
  static const _kThemeMode = 'settings.themeMode';
  static const _kColorTheme = 'settings.colorTheme';
  static const _kHaptics = 'settings.haptics';
  static const _kFlagHaptics = 'settings.flagHaptics';
  static const _kNoticeLastSeen = 'notice.lastSeenMs'; // Swift Date → epoch ms
  static const _kResume = 'solo.resume.snapshot.json';

  // ── 상태 ──
  late String deviceId;
  late String _nickname;
  List<ScoreEntry> localRecords = [];
  int raceWins = 0, raceLosses = 0, raceDraws = 0;
  int? touchBest;
  int coins = 0;
  int adsWatchedToday = 0;
  int ownedFlags = 0, ownedMegaphones = 0, ownedRadars = 0;
  Set<String> ownedThemeIds = {'classic'};
  Set<String> unlockedTitleIds = {...Title.starterIds};
  String? equippedTitleId;
  int goldenMinesFound = 0, gachaDraws = 0, gachaJackpots = 0;
  int bestWinStreak = 0, touchClears = 0;
  int noItemExpertClears = 0, noItemUltimateClears = 0;
  int _currentWinStreak = 0;
  String _dailyDay = '';
  Map<String, int> dailyProgress = {};
  Set<String> dailyClaimed = {};
  bool nicknameSetByUser = false;
  String _lastSyncedDeviceId = '';
  String _adRewardDay = '';
  bool _isRestoring = false;

  /// 갓 해금한 칭호(축하 배너용). 루트가 잠깐 띄우고 null로 되돌린다.
  Title? pendingUnlockToast;

  int _int(String k) => _prefs.getInt(k) ?? 0;
  bool _bool(String k) => _prefs.getBool(k) ?? false;
  void _setInt(String k, int v) => _prefs.setInt(k, v);
  void _setBool(String k, bool v) => _prefs.setBool(k, v);

  void _load() {
    final id = _prefs.getString(_kDeviceId);
    if (id != null) {
      deviceId = id;
    } else {
      deviceId = _uuid();
      _prefs.setString(_kDeviceId, deviceId);
    }
    _nickname = _prefs.getString(_kNickname) ?? randomName();
    final recJson = _prefs.getString(_kRecords);
    if (recJson != null) {
      try {
        localRecords = (jsonDecode(recJson) as List)
            .map((e) => ScoreEntry.fromLocalJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    raceWins = _int(_kWins);
    raceLosses = _int(_kLosses);
    raceDraws = _int(_kDraws);
    final t = _int(_kTouchBest);
    touchBest = t > 0 ? t : null;
    nicknameSetByUser = _bool(_kNicknameSetByUser);
    _lastSyncedDeviceId = _prefs.getString(_kLastSyncedDeviceId) ?? '';
    // 코인: 첫 실행이면 시작 코인 1회 지급.
    if (_bool(_kStartGranted)) {
      coins = _int(_kCoins);
    } else {
      coins = startingCoins;
      _setInt(_kCoins, coins);
      _setBool(_kStartGranted, true);
    }
    ownedFlags = _int(_kOwnedFlags);
    if (!_bool(_kStarterFlags)) {
      ownedFlags += startingFlags;
      _setInt(_kOwnedFlags, ownedFlags);
      _setBool(_kStarterFlags, true);
    }
    ownedMegaphones = _int(_kOwnedMegaphones);
    if (!_bool(_kStarterMegaphones)) {
      ownedMegaphones += startingMegaphones;
      _setInt(_kOwnedMegaphones, ownedMegaphones);
      _setBool(_kStarterMegaphones, true);
    }
    ownedRadars = _int(_kOwnedRadars);
    if (!_bool(_kStarterRadars)) {
      ownedRadars += startingRadars;
      _setInt(_kOwnedRadars, ownedRadars);
      _setBool(_kStarterRadars, true);
    }
    ownedThemeIds = {...?_prefs.getStringList(_kOwnedThemes), 'classic'};
    unlockedTitleIds = {
      ...?_prefs.getStringList(_kUnlockedTitles),
      ...Title.starterIds
    };
    final eq = _prefs.getString(_kEquippedTitle) ?? '';
    equippedTitleId = eq.isEmpty ? null : eq;
    goldenMinesFound = _int(_kGoldenMines);
    gachaDraws = _int(_kGachaDraws);
    gachaJackpots = _int(_kGachaJackpots);
    bestWinStreak = _int(_kBestWinStreak);
    _currentWinStreak = _int(_kCurWinStreak);
    touchClears = _int(_kTouchClears);
    noItemExpertClears = _int(_kNoItemExpert);
    noItemUltimateClears = _int(_kNoItemUltimate);
    adsWatchedToday = _int(_kAdsWatchedToday);
    _adRewardDay = _prefs.getString(_kAdRewardDay) ?? '';
    _rollOverAdDayIfNeeded();
    _dailyDay = _prefs.getString(_kDailyDay) ?? '';
    final dp = _prefs.getString(_kDailyProgress);
    if (dp != null) {
      try {
        dailyProgress = (jsonDecode(dp) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }
    dailyClaimed = {...?_prefs.getStringList(_kDailyClaimed)};
    _rollOverDailyIfNeeded();
=======

  /// 상점 상수(Swift RankingStore와 동일).
  static const drawCost = 30;
  static const tripleDrawCost = drawCost * 3;
  static const adRewardCoins = 30;
  static const dailyAdLimit = 5;
  static const goldenMineReward = 10;
  static const themeCost = 1000;

  List<ScoreEntry> _records = [];

  void _load() {
    if (_prefs.getString(_kDeviceId) == null) {
      _prefs.setString(_kDeviceId, _newDeviceId());
    }
    if (_prefs.getString(_kNickname) == null) {
      _prefs.setString(_kNickname, randomName());
    }
    // 시작 재화 1회 지급(키가 없으면 첫 실행).
    if (_prefs.getInt(_kCoins) == null) _prefs.setInt(_kCoins, startingCoins);
    if (_prefs.getInt(_kOwnedFlags) == null) {
      _prefs.setInt(_kOwnedFlags, startingFlags);
    }
    if (_prefs.getInt(_kOwnedRadars) == null) {
      _prefs.setInt(_kOwnedRadars, startingRadars);
    }
    // 확성기: 도입 후 첫 실행이면 시작 지급을 1회 더해 준다(Swift와 동일 패턴).
    if (!(_prefs.getBool(_kStarterMegaphones) ?? false)) {
      _prefs.setInt(_kOwnedMegaphones,
          (_prefs.getInt(_kOwnedMegaphones) ?? 0) + startingMegaphones);
      _prefs.setBool(_kStarterMegaphones, true);
    }
    _records = _decodeRecords(_prefs.getString(_kRecords));
    _migrateLegacySoloRecords();
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
    // 기존 통계로 이미 충족된 업적을 조용히 해금(배너 없이).
    refreshAchievements(announce: false);
  }

<<<<<<< HEAD
  static String _uuid() {
    final r = Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${hex(4)}-${hex(12)}'.toUpperCase();
  }

  static String randomName() {
    const base = ['지뢰왕', '폭탄해체가', '깃발장인', '마인스위퍼', '스피드러너', '9초컷'];
    final r = Random();
    return '${base[r.nextInt(base.length)]}${10 + r.nextInt(90)}';
  }

  // ── 닉네임 ──
  String get nickname => _nickname;
  set nickname(String v) {
    _nickname = v;
    if (_isRestoring) return;
    _prefs.setString(_kNickname, v);
    nicknameSetByUser = true;
    _setBool(_kNicknameSetByUser, true);
    _backupIfLinked();
    notifyListeners();
  }

  // ── 대전 전적 ──
  int get raceTotal => raceWins + raceLosses + raceDraws;
  int get raceWinRate {
    final decided = raceWins + raceLosses;
    if (decided <= 0) return 0;
    return (raceWins / decided * 100).round();
  }

  void recordRace(RaceResult r) {
    switch (r) {
      case RaceResult.win:
        raceWins++;
        _setInt(_kWins, raceWins);
        _currentWinStreak++;
        if (_currentWinStreak > bestWinStreak) {
          bestWinStreak = _currentWinStreak;
          _setInt(_kBestWinStreak, bestWinStreak);
        }
        _setInt(_kCurWinStreak, _currentWinStreak);
        bumpDaily(DailyKind.raceWins);
      case RaceResult.lose:
        raceLosses++;
        _setInt(_kLosses, raceLosses);
        _currentWinStreak = 0;
        _setInt(_kCurWinStreak, 0);
      case RaceResult.draw:
        raceDraws++;
        _setInt(_kDraws, raceDraws); // 무승부는 연승을 끊지 않는다
    }
    refreshAchievements();
    _backupIfLinked();
    notifyListeners();
  }

  // ── 코인 / 광고 보상 ──
  int get remainingRewardedAds => max(0, dailyAdLimit - adsWatchedToday);

  void addCoins(int amount) {
    if (amount <= 0) return;
    coins += amount;
    _setInt(_kCoins, coins);
    _backupIfLinked();
    notifyListeners();
  }

  void grantMailReward(
      {int coins = 0, int flags = 0, int megaphones = 0, int radars = 0}) {
    var changed = false;
    if (coins > 0) {
      this.coins += coins;
      _setInt(_kCoins, this.coins);
      changed = true;
    }
    if (flags > 0) {
      ownedFlags += flags;
      _setInt(_kOwnedFlags, ownedFlags);
      changed = true;
    }
    if (megaphones > 0) {
      ownedMegaphones += megaphones;
      _setInt(_kOwnedMegaphones, ownedMegaphones);
      changed = true;
    }
    if (radars > 0) {
      ownedRadars += radars;
      _setInt(_kOwnedRadars, ownedRadars);
      changed = true;
    }
    if (changed) {
      _backupIfLinked();
      notifyListeners();
    }
  }

  bool spendCoins(int amount) {
    if (amount <= 0 || coins < amount) return false;
    coins -= amount;
    _setInt(_kCoins, coins);
    _backupIfLinked();
    notifyListeners();
    return true;
  }

  /// 상점/업적 진입 시 — 날짜가 바뀌었으면 광고 횟수·일일 도전과제를 리셋.
  void refreshDailyRewards() {
    _rollOverAdDayIfNeeded();
    _rollOverDailyIfNeeded();
    notifyListeners();
  }

  int? claimRewardedAd() {
    _rollOverAdDayIfNeeded();
    if (adsWatchedToday >= dailyAdLimit) return null;
    adsWatchedToday++;
    _setInt(_kAdsWatchedToday, adsWatchedToday);
    addCoins(adRewardCoins);
    return adRewardCoins;
  }

  static int clearReward(Difficulty d) => switch (d) {
        Difficulty.beginner => 1,
        Difficulty.intermediate => 5,
        Difficulty.expert => 10,
        Difficulty.ultimate => 20,
      };

  int awardClearReward(Difficulty d) {
    final r = clearReward(d);
    addCoins(r);
    return r;
  }

  void awardGoldenMine() {
    addCoins(goldenMineReward);
    goldenMinesFound++;
    _setInt(_kGoldenMines, goldenMinesFound);
    bumpDaily(DailyKind.golden);
    refreshAchievements();
    notifyListeners();
  }

  // ── 뽑기 ──
  bool get canDraw => coins >= drawCost;
  bool get canDrawTriple => coins >= tripleDrawCost;

  GachaItem? draw([Random? rng]) {
    if (!spendCoins(drawCost)) return null;
    final item = GachaItem.weightedRandom(rng);
    _grant(item);
    gachaDraws++;
    _setInt(_kGachaDraws, gachaDraws);
    bumpDaily(DailyKind.draws);
    refreshAchievements();
    _backupIfLinked();
    notifyListeners();
    return item;
  }

  TripleDrawResult? drawTriple([Random? rng]) {
    if (!spendCoins(tripleDrawCost)) return null;
    final reels = [
      GachaItem.weightedRandom(rng),
      GachaItem.weightedRandom(rng),
      GachaItem.weightedRandom(rng),
    ];
    final jackpot = reels.every((e) => e == reels.first);
    if (jackpot) {
      for (final it in GachaItem.values) {
        _grant(it, 3); // 히든: 모든 아이템 3개씩
      }
      gachaJackpots++;
      _setInt(_kGachaJackpots, gachaJackpots);
    } else {
      for (final it in reels) {
        _grant(it);
      }
    }
    gachaDraws += 3;
    _setInt(_kGachaDraws, gachaDraws);
    bumpDaily(DailyKind.draws, by: 3);
    refreshAchievements();
    _backupIfLinked();
    notifyListeners();
    return TripleDrawResult(reels, jackpot);
  }

  void _grant(GachaItem item, [int count = 1]) {
    switch (item) {
      case GachaItem.flag:
        ownedFlags += count;
        _setInt(_kOwnedFlags, ownedFlags);
      case GachaItem.megaphone:
        ownedMegaphones += count;
        _setInt(_kOwnedMegaphones, ownedMegaphones);
      case GachaItem.radar:
        ownedRadars += count;
        _setInt(_kOwnedRadars, ownedRadars);
    }
  }

  bool consumeFlag() {
    if (ownedFlags <= 0) return false;
    ownedFlags--;
    _setInt(_kOwnedFlags, ownedFlags);
    _backupIfLinked();
    notifyListeners();
    return true;
  }

  bool consumeMegaphone() {
    if (ownedMegaphones <= 0) return false;
    ownedMegaphones--;
    _setInt(_kOwnedMegaphones, ownedMegaphones);
    _backupIfLinked();
    notifyListeners();
    return true;
  }

  bool consumeRadar() {
    if (ownedRadars <= 0) return false;
    ownedRadars--;
    _setInt(_kOwnedRadars, ownedRadars);
    _backupIfLinked();
    notifyListeners();
    return true;
  }

  // ── 색상 테마(스킨) ──
  bool ownsTheme(String id) => ownedThemeIds.contains(id);

  bool purchaseTheme(String id) {
    if (ownedThemeIds.contains(id)) return false;
    if (!spendCoins(themeCost)) return false;
    ownedThemeIds.add(id);
    _prefs.setStringList(_kOwnedThemes, ownedThemeIds.toList());
    refreshAchievements(); // 수집가(테마 3개)
    _backupIfLinked();
    notifyListeners();
    return true;
  }

  String get colorThemeId => _prefs.getString(_kColorTheme) ?? 'classic';
  set colorThemeId(String v) => _prefs.setString(_kColorTheme, v);

  // ── 칭호 / 업적 ──
  bool owns(String titleId) => unlockedTitleIds.contains(titleId);

  Title? get equippedTitle {
    final id = equippedTitleId;
    if (id == null || !unlockedTitleIds.contains(id)) return null;
    return Title.byId(id);
  }

  /// 멀티/랭킹으로 전송할 장착 칭호 이름. 미착용이면 "".
  String get equippedTitleName => equippedTitle?.name ?? '';

  void equip(String? id) {
    if (id != null) {
      if (!unlockedTitleIds.contains(id)) return;
      equippedTitleId = id;
    } else {
      equippedTitleId = null;
    }
    _prefs.setString(_kEquippedTitle, equippedTitleId ?? '');
    _backupIfLinked();
    notifyListeners();
  }

  bool purchaseTitle(String id) {
    final t = Title.byId(id);
    final cost = t?.purchaseCost;
    if (t == null || cost == null) return false;
    if (unlockedTitleIds.contains(id)) return false;
    if (!spendCoins(cost)) return false;
    unlockedTitleIds.add(id);
    _persistTitles();
    equip(id);
    return true;
  }

  void _persistTitles() =>
      _prefs.setStringList(_kUnlockedTitles, unlockedTitleIds.toList());

  int _totalClears() =>
      Difficulty.values.fold(0, (a, d) => a + countLocal(d));

  ({int current, int target, bool done}) goalProgress(Goal g) {
    ({int current, int target, bool done}) count(int c, int n) =>
        (current: min(c, n), target: n, done: c >= n);
    switch (g) {
      case ClearsGoal(:final d, :final n):
        return count(countLocal(d), n);
      case TotalClearsGoal(:final n):
        return count(_totalClears(), n);
      case BestUnderGoal(:final d, :final sec):
        final b = bestLocal(d);
        final done = b != null && b <= sec;
        return (current: done ? sec : 0, target: sec, done: done);
      case RaceWinsGoal(:final n):
        return count(raceWins, n);
      case WinStreakGoal(:final n):
        return count(bestWinStreak, n);
      case TouchClearsGoal(:final n):
        return count(touchClears, n);
      case NoItemClearGoal(:final d, :final n):
        return count(
            d == Difficulty.ultimate ? noItemUltimateClears : noItemExpertClears,
            n);
      case TouchUnderGoal(:final sec):
        final b = touchBest;
        final done = b != null && b <= sec;
        return (current: done ? sec : 0, target: sec, done: done);
      case GoldenMinesGoal(:final n):
        return count(goldenMinesFound, n);
      case DrawsGoal(:final n):
        return count(gachaDraws, n);
      case JackpotGoal(:final n):
        return count(gachaJackpots, n);
      case ThemesOwnedGoal(:final n):
        return count(ownedThemeIds.length, n);
      case CoinsAtLeastGoal(:final n):
        return count(coins, n);
    }
  }

  String goalDisplay(Goal g) {
    switch (g) {
      case BestUnderGoal(:final d, :final sec):
        final b = bestLocal(d);
        return b != null ? '최고 $b초 · 목표 $sec초 이내' : '기록 없음 · 목표 $sec초 이내';
      case TouchUnderGoal(:final sec):
        final b = touchBest;
        return b != null ? '최고 $b초 · 목표 $sec초 이내' : '기록 없음 · 목표 $sec초 이내';
      default:
        final p = goalProgress(g);
        return '${p.current} / ${p.target}';
    }
  }

  TitleState titleState(Title t) {
    if (equippedTitleId == t.id && unlockedTitleIds.contains(t.id)) {
      return const TitleEquipped();
    }
    if (unlockedTitleIds.contains(t.id)) return const TitleOwned();
    final cost = t.purchaseCost;
    if (cost != null) return TitlePurchasable(cost, coins >= cost);
    return const TitleLocked();
  }

  /// 업적형 칭호를 전부 재평가해 새로 충족된 것을 해금한다. announce면 축하 배너.
  List<Title> refreshAchievements({bool announce = true}) {
    final newly = <Title>[];
    for (final t in Title.achievements) {
      if (unlockedTitleIds.contains(t.id)) continue;
      final g = t.goal;
      if (g != null && goalProgress(g).done) {
        unlockedTitleIds.add(t.id);
        newly.add(t);
      }
    }
    if (newly.isEmpty) return const [];
    _persistTitles();
    // 미착용 상태면 갓 얻은 칭호를 자동 장착(첫 보람).
    if (equippedTitleId == null) {
      equippedTitleId = newly.first.id;
      _prefs.setString(_kEquippedTitle, newly.first.id);
    }
    if (announce) {
      pendingUnlockToast = newly.reduce(
          (a, b) => b.rarity.index > a.rarity.index ? b : a);
    }
    _backupIfLinked();
    notifyListeners();
    return newly;
  }

  void clearUnlockToast(Title t) {
    if (pendingUnlockToast?.id != t.id) return;
    pendingUnlockToast = null;
    notifyListeners();
  }

  // ── 일일 도전과제 ──
  List<DailyChallenge> todaysChallenges() => DailyChallenge.forDay(todayKey());

  ({int current, int target, bool done, bool claimed}) dailyState(
      DailyKind kind) {
    final target = DailyChallenge.named(kind).goal;
    final cur = min(dailyProgress[kind.name] ?? 0, target);
    return (
      current: cur,
      target: target,
      done: target > 0 && cur >= target,
      claimed: dailyClaimed.contains(kind.name),
    );
  }

  int get dailyClaimableCount => todaysChallenges().where((c) {
        final s = dailyState(c.kind);
        return s.done && !s.claimed;
      }).length;

  /// 오늘 뽑힌 미션에 그 kind가 있을 때만 누적.
  void bumpDaily(DailyKind kind, {int by = 1}) {
    _rollOverDailyIfNeeded();
    if (by <= 0 || !todaysChallenges().any((c) => c.kind == kind)) return;
    dailyProgress[kind.name] = (dailyProgress[kind.name] ?? 0) + by;
    _prefs.setString(_kDailyProgress, jsonEncode(dailyProgress));
    notifyListeners();
  }

  int? claimDaily(DailyKind kind) {
    _rollOverDailyIfNeeded();
    final s = dailyState(kind);
    if (!s.done || s.claimed) return null;
    dailyClaimed.add(kind.name);
    _prefs.setStringList(_kDailyClaimed, dailyClaimed.toList());
    final reward = DailyChallenge.named(kind).reward;
    addCoins(reward);
    return reward;
  }

  void _rollOverDailyIfNeeded() {
    final today = todayKey();
    if (_dailyDay == today) return;
    _dailyDay = today;
    dailyProgress = {};
    dailyClaimed = {};
    _prefs.setString(_kDailyDay, today);
    _prefs.setString(_kDailyProgress, '{}');
    _prefs.setStringList(_kDailyClaimed, const []);
  }

  void _rollOverAdDayIfNeeded() {
    final today = todayKey();
    if (_adRewardDay == today) return;
    _adRewardDay = today;
    adsWatchedToday = 0;
    _prefs.setString(_kAdRewardDay, today);
    _setInt(_kAdsWatchedToday, 0);
  }

  /// 기기 로컬 시간 기준 오늘 날짜 키("yyyy-MM-dd").
  static String todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── 조회 ──
  int? bestLocal(Difficulty d) {
    int? best;
    for (final e in localRecords) {
      if (e.difficulty == d.label && (best == null || e.timeSec < best)) {
        best = e.timeSec;
      }
    }
    return best;
  }

  int countLocal(Difficulty d) =>
      localRecords.where((e) => e.difficulty == d.label).length;

  List<ScoreEntry> recentLocal(Difficulty d, {int limit = 10}) {
    final l = localRecords.where((e) => e.difficulty == d.label).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return l.take(limit).toList();
  }

  // ── 기록 ──
  /// 솔로 클리어 1건 — 로컬 저장 + (신기록이면) 온라인 갱신. 새 개인 최고면 true.
  bool recordSolo(Difficulty d, int timeSec) {
    final prev = bestLocal(d);
    final isBest = prev == null || timeSec < prev;
    final entry = ScoreEntry(
      name: nickname,
      difficulty: d.label,
      timeSec: timeSec,
      deviceId: deviceId,
      title: equippedTitleName,
    );
    localRecords.add(entry);
    _trim();
    _persistRecords();
    _backupIfLinked();
    if (isBest) RankingService().submitBest(entry);
    bumpDaily(DailyKind.clears);
    refreshAchievements();
    notifyListeners();
    return isBest;
  }

  void recordNoItemHardClear(Difficulty d) {
    switch (d) {
      case Difficulty.expert:
        noItemExpertClears++;
        _setInt(_kNoItemExpert, noItemExpertClears);
      case Difficulty.ultimate:
        noItemUltimateClears++;
        _setInt(_kNoItemUltimate, noItemUltimateClears);
      case Difficulty.beginner:
      case Difficulty.intermediate:
        return;
    }
    refreshAchievements();
    _backupIfLinked();
    notifyListeners();
  }

  /// 협동("너에게 닿기를") 성공 — 로컬 최고 갱신 + (신기록이면) 온라인. 새 최고면 true.
  bool recordTouch(int timeSec) {
    if (timeSec <= 0) return false;
    touchClears++;
    _setInt(_kTouchClears, touchClears);
    bumpDaily(DailyKind.touch);
    final isBest = touchBest == null || timeSec < touchBest!;
    if (isBest) {
      touchBest = timeSec;
      _setInt(_kTouchBest, timeSec);
      RankingService().submitTouchBest(
          name: nickname,
          timeSec: timeSec,
          deviceId: deviceId,
          title: equippedTitleName);
    }
    refreshAchievements();
    _backupIfLinked();
    notifyListeners();
    return isBest;
  }

  /// 온라인 전체에서 내 최고 기록의 등수(나보다 빠른 다른 기기 수 + 1). 오프라인이면 null.
  Future<int?> onlineRank(Difficulty d) async {
    final my = bestLocal(d);
    if (my == null) return null;
    try {
      final list = await RankingService().top(d, limit: 300);
      if (list.isEmpty) return null;
      return list.where((e) => e.deviceId != deviceId && e.timeSec < my).length +
          1;
    } catch (_) {
      return null;
    }
  }

  Future<int?> touchOnlineRank() async {
    final my = touchBest;
    if (my == null) return null;
    try {
      final list = await RankingService().topTouch(limit: 300);
      if (list.isEmpty) return null;
      return list.where((e) => e.deviceId != deviceId && e.timeSec < my).length +
          1;
    } catch (_) {
      return null;
    }
  }

  void _trim() {
    final kept = <ScoreEntry>[];
    for (final d in Difficulty.values) {
      final l = localRecords.where((e) => e.difficulty == d.label).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      kept.addAll(l.take(50));
    }
    localRecords = kept;
  }

  void _persistRecords() => _prefs.setString(
      _kRecords, jsonEncode(localRecords.map((e) => e.toLocalJson()).toList()));

  // ── 클라우드 백업/복원 ──
  static bool get _isLinked {
    try {
      final u = FirebaseAuth.instance.currentUser;
      return u != null &&
          u.providerData.any(
              (p) => p.providerId == 'apple.com' || p.providerId == 'google.com');
    } catch (_) {
      return false; // Firebase 미초기화(테스트)
    }
  }

  void _backupIfLinked() {
    if (_isRestoring || !_isLinked) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    backupToCloud(uid);
  }

  UserBackupData snapshot() => UserBackupData(
        nickname: nickname,
        nicknameSetByUser: nicknameSetByUser,
        records: localRecords,
        raceWins: raceWins,
        raceLosses: raceLosses,
        raceDraws: raceDraws,
        coins: coins,
        ownedFlags: ownedFlags,
        ownedMegaphones: ownedMegaphones,
        ownedRadars: ownedRadars,
        ownedThemeIds: ownedThemeIds.toList(),
        touchBest: touchBest,
        unlockedTitleIds: unlockedTitleIds.toList(),
        equippedTitleId: equippedTitleId,
        goldenMinesFound: goldenMinesFound,
        gachaDraws: gachaDraws,
        gachaJackpots: gachaJackpots,
        bestWinStreak: bestWinStreak,
        touchClears: touchClears,
        noItemExpertClears: noItemExpertClears,
        noItemUltimateClears: noItemUltimateClears,
        lastSyncedDeviceId: deviceId,
      );

  Future<void> backupToCloud(String uid) async {
    _lastSyncedDeviceId = deviceId;
    _prefs.setString(_kLastSyncedDeviceId, deviceId);
    await UserBackupService.save(uid, snapshot());
  }

  /// 연동/계정 전환 직후 — 클라우드와 로컬을 머지하고 최신본을 다시 백업.
  Future<void> syncAfterLink(String uid, String? suggestedName) async {
    final remote = await UserBackupService.load(uid);
    if (remote != null) merge(remote);
    if (suggestedName != null && !nicknameSetByUser) {
      _isRestoring = true;
      _nickname = suggestedName.length > 16
          ? suggestedName.substring(0, 16)
          : suggestedName;
      _isRestoring = false;
      nicknameSetByUser = true;
      _setBool(_kNicknameSetByUser, true);
      _prefs.setString(_kNickname, _nickname);
    }
    refreshAchievements(announce: false);
    await backupToCloud(uid);
    notifyListeners();
  }

  /// 클라우드 백업과 로컬을 머지(어느 기록도 잃지 않는 방향). Swift merge와 동일 정책.
  @visibleForTesting
  void merge(UserBackupData remote) {
    _isRestoring = true;
    try {
      final seen = <String>{};
      String key(ScoreEntry e) =>
          '${e.difficulty}|${e.timeSec}|${e.date.millisecondsSinceEpoch ~/ 1000}';
      final union = <ScoreEntry>[];
      for (final e in [...localRecords, ...remote.records]) {
        if (seen.add(key(e))) union.add(e);
      }
      localRecords = union;
      _trim();
      _persistRecords();

      // 전적·코인·아이템: 같은 기기 재로그인이면 max, 다른 기기면 합산.
      final same = remote.lastSyncedDeviceId == deviceId;
      int m(int a, int b) => same ? max(a, b) : a + b;
      raceWins = m(raceWins, remote.raceWins);
      raceLosses = m(raceLosses, remote.raceLosses);
      raceDraws = m(raceDraws, remote.raceDraws);
      coins = m(coins, remote.coins);
      ownedFlags = m(ownedFlags, remote.ownedFlags);
      ownedMegaphones = m(ownedMegaphones, remote.ownedMegaphones);
      ownedRadars = m(ownedRadars, remote.ownedRadars);
      _setInt(_kWins, raceWins);
      _setInt(_kLosses, raceLosses);
      _setInt(_kDraws, raceDraws);
      _setInt(_kCoins, coins);
      _setInt(_kOwnedFlags, ownedFlags);
      _setInt(_kOwnedMegaphones, ownedMegaphones);
      _setInt(_kOwnedRadars, ownedRadars);

      ownedThemeIds = {...ownedThemeIds, ...remote.ownedThemeIds, 'classic'};
      _prefs.setStringList(_kOwnedThemes, ownedThemeIds.toList());

      unlockedTitleIds = {
        ...unlockedTitleIds,
        ...remote.unlockedTitleIds,
        ...Title.starterIds
      };
      _persistTitles();
      final rid = remote.equippedTitleId;
      if (equippedTitleId == null &&
          rid != null &&
          unlockedTitleIds.contains(rid)) {
        equippedTitleId = rid;
        _prefs.setString(_kEquippedTitle, rid);
      }

      goldenMinesFound = m(goldenMinesFound, remote.goldenMinesFound);
      gachaDraws = m(gachaDraws, remote.gachaDraws);
      gachaJackpots = m(gachaJackpots, remote.gachaJackpots);
      touchClears = m(touchClears, remote.touchClears);
      noItemExpertClears = m(noItemExpertClears, remote.noItemExpertClears);
      noItemUltimateClears =
          m(noItemUltimateClears, remote.noItemUltimateClears);
      bestWinStreak = max(bestWinStreak, remote.bestWinStreak);
      _setInt(_kGoldenMines, goldenMinesFound);
      _setInt(_kGachaDraws, gachaDraws);
      _setInt(_kGachaJackpots, gachaJackpots);
      _setInt(_kBestWinStreak, bestWinStreak);
      _setInt(_kTouchClears, touchClears);
      _setInt(_kNoItemExpert, noItemExpertClears);
      _setInt(_kNoItemUltimate, noItemUltimateClears);

      final rt = remote.touchBest;
      if (rt != null) {
        touchBest = min(touchBest ?? rt, rt);
        _setInt(_kTouchBest, touchBest!);
      }

      if (!nicknameSetByUser &&
          remote.nicknameSetByUser &&
          remote.nickname.isNotEmpty) {
        _nickname = remote.nickname;
        nicknameSetByUser = true;
        _setBool(_kNicknameSetByUser, true);
        _prefs.setString(_kNickname, _nickname);
      }
    } finally {
      _isRestoring = false;
    }
    notifyListeners();
  }

  // ── 계정 삭제 ──
  /// 로컬 개인 데이터를 지우고 첫 실행(새 사용자) 상태로 — 새 기기 ID로 이전 랭킹과 분리.
  void wipeLocalData() {
    _isRestoring = true;
    try {
      deviceId = _uuid();
      _prefs.setString(_kDeviceId, deviceId);
      _nickname = randomName();
      nicknameSetByUser = false;
      _prefs.setString(_kNickname, _nickname);
      _setBool(_kNicknameSetByUser, false);
      localRecords = [];
      _persistRecords();
      raceWins = raceLosses = raceDraws = 0;
      _setInt(_kWins, 0);
      _setInt(_kLosses, 0);
      _setInt(_kDraws, 0);
      touchBest = null;
      _setInt(_kTouchBest, 0);
      coins = startingCoins;
      _setInt(_kCoins, coins);
      _setBool(_kStartGranted, true);
      ownedFlags = startingFlags;
      _setInt(_kOwnedFlags, ownedFlags);
      _setBool(_kStarterFlags, true);
      ownedMegaphones = startingMegaphones;
      _setInt(_kOwnedMegaphones, ownedMegaphones);
      _setBool(_kStarterMegaphones, true);
      ownedRadars = startingRadars;
      _setInt(_kOwnedRadars, ownedRadars);
      _setBool(_kStarterRadars, true);
      ownedThemeIds = {'classic'};
      _prefs.setStringList(_kOwnedThemes, ownedThemeIds.toList());
      colorThemeId = 'classic';
      unlockedTitleIds = {...Title.starterIds};
      _persistTitles();
      equippedTitleId = null;
      _prefs.setString(_kEquippedTitle, '');
      goldenMinesFound = gachaDraws = gachaJackpots = 0;
      bestWinStreak = _currentWinStreak = touchClears = 0;
      noItemExpertClears = noItemUltimateClears = 0;
      for (final k in [
        _kGoldenMines, _kGachaDraws, _kGachaJackpots, _kBestWinStreak,
        _kCurWinStreak, _kTouchClears, _kNoItemExpert, _kNoItemUltimate,
      ]) {
        _setInt(k, 0);
      }
      _dailyDay = '';
      _rollOverDailyIfNeeded();
      adsWatchedToday = 0;
      _setInt(_kAdsWatchedToday, 0);
      _lastSyncedDeviceId = '';
      _prefs.setString(_kLastSyncedDeviceId, '');
    } finally {
      _isRestoring = false;
    }
    notifyListeners();
  }

  // ── 기타 화면 상태(UserDefaults 직접 사용하던 것들) ──
=======
  /// (구버전) 난이도별 최고/횟수만 저장하던 기록을 기록 리스트로 옮긴다.
  void _migrateLegacySoloRecords() {
    var changed = false;
    for (final d in Difficulty.values) {
      final bestKey = 'rank.best.${d.code}', countKey = 'rank.count.${d.code}';
      final best = _prefs.getInt(bestKey);
      final count = _prefs.getInt(countKey) ?? 0;
      if (best == null && count == 0) continue;
      if (!_records.any((e) => e.difficulty == d.label) && best != null) {
        for (var i = 0; i < max(1, count); i++) {
          _records.add(ScoreEntry(
              name: nickname,
              difficulty: d.label,
              timeSec: best,
              deviceId: deviceId));
        }
        changed = true;
      }
      _prefs.remove(bestKey);
      _prefs.remove(countKey);
    }
    if (changed) {
      _trim();
      _persistRecords();
    }
  }

  static String _newDeviceId() {
    final r = Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}'.toUpperCase();
  }

  static String randomName() {
    const bases = ['지뢰왕', '폭탄해체가', '깃발장인', '마인스위퍼', '스피드러너', '9초컷'];
    final r = Random();
    return '${bases[r.nextInt(bases.length)]}${10 + r.nextInt(90)}';
  }

  void _changed({bool backup = true}) {
    if (backup) backupHook?.call();
    notifyListeners();
  }

  // ── 기기·닉네임 ──
  String get deviceId => _prefs.getString(_kDeviceId)!;

  String get nickname => _prefs.getString(_kNickname) ?? '';
  set nickname(String v) {
    _prefs.setString(_kNickname, v);
    _prefs.setBool(_kNicknameSetByUser, true);
    _changed();
  }

  bool get nicknameSetByUser => _prefs.getBool(_kNicknameSetByUser) ?? false;
  String get lastSyncedDeviceId => _prefs.getString(_kLastSyncedDeviceId) ?? '';
  set lastSyncedDeviceId(String v) => _prefs.setString(_kLastSyncedDeviceId, v);

  // ── 환경설정 ──
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  set themeMode(String v) => _prefs.setString(_kThemeMode, v);

  /// 적용 중인 색상 테마(스킨) id. 기본 classic.
  String get colorThemeId => _prefs.getString(_kColorTheme) ?? 'classic';
  set colorThemeId(String v) => _prefs.setString(_kColorTheme, v);

  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? true;
  set hapticsEnabled(bool v) => _prefs.setBool(_kHaptics, v);

<<<<<<< HEAD
  /// 깃발 진동 — 원본 기본값 꺼짐.
  bool get flagHapticsEnabled => _prefs.getBool(_kFlagHaptics) ?? false;
  set flagHapticsEnabled(bool v) => _prefs.setBool(_kFlagHaptics, v);

  bool onboarded(String kind) => _prefs.getBool('onboarded.$kind') ?? false;
  void markOnboarded(String kind) => _prefs.setBool('onboarded.$kind', true);

  DateTime get noticeLastSeen =>
      DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_kNoticeLastSeen) ?? 0);
  void markNoticesSeen(DateTime newest) {
    _prefs.setInt(_kNoticeLastSeen, newest.millisecondsSinceEpoch);
    notifyListeners();
=======
  /// 깃발 진동은 기본 꺼짐(Swift와 동일).
  bool get flagHapticsEnabled => _prefs.getBool(_kFlagHaptics) ?? false;
  set flagHapticsEnabled(bool v) => _prefs.setBool(_kFlagHaptics, v);

  // ── 공지 ──
  DateTime get noticeLastSeen =>
      DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_kNoticeLastSeen) ?? 0);
  void markNoticesSeen(DateTime newest) =>
      _prefs.setInt(_kNoticeLastSeen, newest.millisecondsSinceEpoch);

  /// 기기 로컬 시간 기준 오늘 날짜 키("yyyy-MM-dd"). 공지·일일·광고 롤오버 공용.
  static String todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  }

  bool isNoticeDismissedToday(String id) =>
      _prefs.getString('notice.dismissedToday.$id') == todayKey();
  void dismissNoticeForToday(String id) =>
      _prefs.setString('notice.dismissedToday.$id', todayKey());

<<<<<<< HEAD
=======
  // ── 일일 도전과제(저장만; 카탈로그는 progression/daily.dart) ──
  void _rollOverDailyIfNeeded() {
    if (_prefs.getString(_kDailyDay) == todayKey()) return;
    _prefs.setString(_kDailyDay, todayKey());
    _prefs.remove(_kDailyProgress);
    _prefs.remove(_kDailyClaimed);
  }

  Map<String, int> _dailyProgressMap() {
    final s = _prefs.getString(_kDailyProgress);
    if (s == null || s.isEmpty) return {};
    final m = jsonDecode(s) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  int dailyProgress(String kind) {
    _rollOverDailyIfNeeded();
    return _dailyProgressMap()[kind] ?? 0;
  }

  void bumpDaily(String kind, int amount) {
    _rollOverDailyIfNeeded();
    final m = _dailyProgressMap();
    m[kind] = (m[kind] ?? 0) + amount;
    _prefs.setString(_kDailyProgress, jsonEncode(m));
    _changed(backup: false);
  }

  Set<String> _dailyClaimedSet() {
    final s = _prefs.getString(_kDailyClaimed);
    if (s == null || s.isEmpty) return {};
    return s.split(',').toSet();
  }

  bool isDailyClaimed(String kind) {
    _rollOverDailyIfNeeded();
    return _dailyClaimedSet().contains(kind);
  }

  void markDailyClaimed(String kind) {
    _rollOverDailyIfNeeded();
    final set = _dailyClaimedSet()..add(kind);
    _prefs.setString(_kDailyClaimed, set.join(','));
    _changed(backup: false);
  }

  // ── 아이템 인벤토리 ──
  int get ownedFlags => _prefs.getInt(_kOwnedFlags) ?? 0;
  int get ownedRadars => _prefs.getInt(_kOwnedRadars) ?? 0;
  int get ownedMegaphones => _prefs.getInt(_kOwnedMegaphones) ?? 0;

  bool _consume(String key) {
    final v = _prefs.getInt(key) ?? 0;
    if (v <= 0) return false;
    _prefs.setInt(key, v - 1);
    _changed();
    return true;
  }

  bool consumeFlag() => _consume(_kOwnedFlags);
  bool consumeRadar() => _consume(_kOwnedRadars);
  bool consumeMegaphone() => _consume(_kOwnedMegaphones);

  void _add(String key, int n, {bool notify = true}) {
    if (n <= 0) return;
    _prefs.setInt(key, (_prefs.getInt(key) ?? 0) + n);
    if (notify) _changed();
  }

  void addFlags(int n) => _add(_kOwnedFlags, n);
  void addRadars(int n) => _add(_kOwnedRadars, n);
  void addMegaphones(int n) => _add(_kOwnedMegaphones, n);

  // ── 코인 ──
  int get coins => _prefs.getInt(_kCoins) ?? 0;

  /// 코인을 쓴다. 잔액 부족이면 false(차감 안 함).
  bool spendCoins(int amount) {
    if (amount <= 0 || coins < amount) return false;
    _prefs.setInt(_kCoins, coins - amount);
    _changed();
    return true;
  }

  void addCoins(int amount) {
    if (amount <= 0) return;
    _prefs.setInt(_kCoins, coins + amount);
    _changed();
  }

  /// 솔로 클리어 보상(난이도별 코인).
  static int clearReward(Difficulty d) => switch (d) {
        Difficulty.beginner => 1,
        Difficulty.intermediate => 5,
        Difficulty.expert => 10,
        Difficulty.ultimate => 20,
      };

  /// 솔로 클리어 보상 지급 — 지급한 코인 수를 돌려준다.
  int awardClearReward(Difficulty d) {
    final reward = clearReward(d);
    addCoins(reward);
    return reward;
  }

  /// 황금지뢰 1개 발견 보상 지급(+ 누적 카운터·일일·업적 갱신).
  void awardGoldenMine() {
    _prefs.setInt(_kCoins, coins + goldenMineReward);
    _prefs.setInt(_kGoldenMines, goldenMinesFound + 1);
    _bumpDailyKind('golden');
    refreshAchievements();
    _changed();
  }

  // ── 광고 보상(하루 한도) ──
  int get adsWatchedToday {
    if (_prefs.getString(_kAdRewardDay) != todayKey()) return 0;
    return _prefs.getInt(_kAdsWatchedToday) ?? 0;
  }

  int get remainingRewardedAds => max(0, dailyAdLimit - adsWatchedToday);

  /// 보상형 광고 1회 시청분 지급. 한도 소진이면 null.
  int? claimRewardedAd() {
    final watched = adsWatchedToday; // 날짜 리셋 반영된 값
    if (watched >= dailyAdLimit) return null;
    _prefs.setString(_kAdRewardDay, todayKey());
    _prefs.setInt(_kAdsWatchedToday, watched + 1);
    addCoins(adRewardCoins);
    return adRewardCoins;
  }

  // ── 솔로 기록(난이도별 최근 50개) ──
  List<ScoreEntry> get localRecords => List.unmodifiable(_records);

  static List<ScoreEntry> _decodeRecords(String? s) {
    if (s == null || s.isEmpty) return [];
    try {
      final list = jsonDecode(s) as List;
      return [
        for (final m in list)
          if (m is Map<String, dynamic>) ?ScoreEntry.fromJson(m),
      ];
    } catch (_) {
      return [];
    }
  }

  void _persistRecords() => _prefs.setString(
      _kRecords, jsonEncode([for (final e in _records) e.toJson()]));

  void _trim() {
    final kept = <ScoreEntry>[];
    for (final d in Difficulty.values) {
      final list = _records.where((e) => e.difficulty == d.label).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      kept.addAll(list.take(50));
    }
    _records = kept;
  }

  /// 난이도별 내 최고 기록(초). 없으면 null.
  int? soloBest(Difficulty d) {
    int? best;
    for (final e in _records) {
      if (e.difficulty == d.label && (best == null || e.timeSec < best)) {
        best = e.timeSec;
      }
    }
    return best;
  }

  /// 난이도별 내 클리어 횟수.
  int soloClearCount(Difficulty d) =>
      _records.where((e) => e.difficulty == d.label).length;

  /// 난이도별 내 최근 기록(최신순).
  List<ScoreEntry> recentLocal(Difficulty d, {int limit = 10}) {
    final list = _records.where((e) => e.difficulty == d.label).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list.take(limit).toList();
  }

  /// 솔로 클리어 1건 기록. 개인 신기록이면 true.
  /// (온라인 제출은 호출부에서 신기록일 때만 — RankingService 의존을 피하려고 분리)
  bool recordSolo(Difficulty d, int timeSec) {
    final prev = soloBest(d);
    final isBest = prev == null || timeSec < prev;
    _records.add(ScoreEntry(
        name: nickname,
        difficulty: d.label,
        timeSec: timeSec,
        deviceId: deviceId,
        title: equippedTitleName));
    _trim();
    _persistRecords();
    _bumpDailyKind('clears');
    refreshAchievements();
    _changed();
    return isBest;
  }

  /// 아이템 없이 고급/최고급 솔로 클리어 — 무결점 칭호 판정용 카운터.
  void recordNoItemHardClear(Difficulty d) {
    if (d == Difficulty.expert) {
      _prefs.setInt(_kNoItemExpert, noItemExpertClears + 1);
    } else if (d == Difficulty.ultimate) {
      _prefs.setInt(_kNoItemUltimate, noItemUltimateClears + 1);
    } else {
      return;
    }
    refreshAchievements();
    _changed();
  }

  // ── 판 코드별 최고 기록(같은 판 재도전용) ──
  int? bestTimeForCode(String code) {
    final v = _prefs.getInt('$_kBestPrefix$code') ?? 0;
    return v > 0 ? v : null;
  }

  void recordCodeBest(String code, int sec) {
    final prev = _prefs.getInt('$_kBestPrefix$code') ?? 0;
    if (prev == 0 || sec < prev) _prefs.setInt('$_kBestPrefix$code', sec);
  }

  // ── 솔로 이어하기 스냅샷 ──
  static const _kResume = 'solo.resume.snapshot';
  String? get soloResumeJson => _prefs.getString(_kResume);
  void saveSoloResume(String json) => _prefs.setString(_kResume, json);
  void clearSoloResume() => _prefs.remove(_kResume);

  // ── 대전 전적 ──
  int get raceWins => _prefs.getInt(_kRaceWins) ?? 0;
  int get raceLosses => _prefs.getInt(_kRaceLosses) ?? 0;
  int get raceDraws => _prefs.getInt(_kRaceDraws) ?? 0;
  int get raceTotal => raceWins + raceLosses + raceDraws;
  int get raceWinRate {
    final decided = raceWins + raceLosses;
    if (decided == 0) return 0;
    return (raceWins / decided * 100).round();
  }

  /// 대전 한 판 결과 기록. 승리는 연승을 올리고 최고 연승을 갱신(패배는 연승 리셋, 무승부는 유지).
  void recordRace(RaceResult r) {
    switch (r) {
      case RaceResult.win:
        _prefs.setInt(_kRaceWins, raceWins + 1);
        final streak = currentWinStreak + 1;
        _prefs.setInt(_kCurStreak, streak);
        if (streak > bestWinStreak) _prefs.setInt(_kBestStreak, streak);
        _bumpDailyKind('raceWins');
      case RaceResult.lose:
        _prefs.setInt(_kRaceLosses, raceLosses + 1);
        _prefs.setInt(_kCurStreak, 0);
      case RaceResult.draw:
        _prefs.setInt(_kRaceDraws, raceDraws + 1);
    }
    refreshAchievements();
    _changed();
  }

  void recordRaceWin() => recordRace(RaceResult.win);
  void recordRaceLoss() => recordRace(RaceResult.lose);
  void recordRaceDraw() => recordRace(RaceResult.draw);

  // ── 협동("너에게 닿기를") 기록 ──
  int? get touchBest {
    final v = _prefs.getInt(_kTouchBest) ?? 0;
    return v > 0 ? v : null;
  }

  int get touchClears => _prefs.getInt(_kTouchClears) ?? 0;

  /// 협동 한 판 성공 기록 — 성공 횟수 누적 + 로컬 최고 갱신. 새 최고면 true.
  bool recordTouch(int timeSec) {
    if (timeSec <= 0) return false;
    _prefs.setInt(_kTouchClears, touchClears + 1);
    _bumpDailyKind('touch');
    final best = touchBest;
    final isBest = best == null || timeSec < best;
    if (isBest) _prefs.setInt(_kTouchBest, timeSec);
    refreshAchievements();
    _changed();
    return isBest;
  }

  // ── 업적용 통계 ──
  int get currentWinStreak => _prefs.getInt(_kCurStreak) ?? 0;
  int get bestWinStreak => _prefs.getInt(_kBestStreak) ?? 0;
  int get gachaDraws => _prefs.getInt(_kGachaDraws) ?? 0;
  int get gachaJackpots => _prefs.getInt(_kJackpots) ?? 0;
  int get goldenMinesFound => _prefs.getInt(_kGoldenMines) ?? 0;
  int get noItemExpertClears => _prefs.getInt(_kNoItemExpert) ?? 0;
  int get noItemUltimateClears => _prefs.getInt(_kNoItemUltimate) ?? 0;

  void addGachaDraws(int n) {
    _prefs.setInt(_kGachaDraws, gachaDraws + n);
    _changed();
  }

  void addJackpot() {
    _prefs.setInt(_kJackpots, gachaJackpots + 1);
    _changed();
  }

  void _bumpDailyKind(String kind, [int by = 1]) {
    // 순환 import를 피하려고 progression/daily.dart의 forDay를 여기서 직접 부르지 않는다.
    final today = DailyPool.forDayKinds(todayKey());
    if (!today.contains(kind)) return;
    bumpDaily(kind, by);
  }

  // ── 우편(수령 여부) ──
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  bool isMailClaimed(String id) => _prefs.getBool('mail.claimed.$id') ?? false;
  void markMailClaimed(String id) {
    _prefs.setBool('mail.claimed.$id', true);
    notifyListeners();
<<<<<<< HEAD
  }

  /// 같은 판 코드의 최고 클리어 시간(초) — Swift `best_<code>`.
  int? bestTimeForCode(String code) {
    final v = _prefs.getInt('best_$code') ?? 0;
    return v > 0 ? v : null;
=======
  }

  /// 우편 보상 일괄 지급(하나라도 지급되면 마지막에 한 번만 알림/백업).
  void grantMailReward(
      {int coins = 0, int flags = 0, int megaphones = 0, int radars = 0}) {
    var changed = false;
    if (coins > 0) {
      _prefs.setInt(_kCoins, this.coins + coins);
      changed = true;
    }
    if (flags > 0) {
      _add(_kOwnedFlags, flags, notify: false);
      changed = true;
    }
    if (megaphones > 0) {
      _add(_kOwnedMegaphones, megaphones, notify: false);
      changed = true;
    }
    if (radars > 0) {
      _add(_kOwnedRadars, radars, notify: false);
      changed = true;
    }
    if (changed) _changed();
  }

  // ── 색상 테마(스킨) 보유 ──
  Set<String> get ownedThemeIds =>
      {'classic', ...(_prefs.getStringList(_kOwnedThemes) ?? const [])};
  bool ownsTheme(String id) => ownedThemeIds.contains(id);

  /// 색상 테마 구매 — 이미 보유/잔액 부족이면 false(차감 없음).
  bool purchaseTheme(String id) {
    if (ownsTheme(id)) return false;
    if (coins < themeCost) return false;
    _prefs.setInt(_kCoins, coins - themeCost);
    _prefs.setStringList(_kOwnedThemes, [...ownedThemeIds]);
    refreshAchievements();
    _changed();
    return true;
  }

  // ── 칭호(보유/장착) ──
  Set<String> get ownedTitleIds {
    final list = _prefs.getStringList(_kOwnedTitles) ?? const [];
    return {...Title.starterIds, ...list}; // 스타터는 항상 보유
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  }

  void recordCodeWin(String code, int elapsed) {
    final prev = _prefs.getInt('best_$code') ?? 0;
    if (prev == 0 || elapsed < prev) _prefs.setInt('best_$code', elapsed);
  }

<<<<<<< HEAD
  String? get resumeSnapshotJson => _prefs.getString(_kResume);
  set resumeSnapshotJson(String? v) =>
      v == null ? _prefs.remove(_kResume) : _prefs.setString(_kResume, v);
}

class TripleDrawResult {
  TripleDrawResult(this.reels, this.jackpot);
  final List<GachaItem> reels;
  final bool jackpot;
=======
  /// 장착 칭호 id(보유 중일 때만). 미착용이면 null.
  String? get equippedTitleId {
    final id = _prefs.getString(_kEquippedTitleId) ?? '';
    if (id.isEmpty || !isTitleOwned(id)) return null;
    return id;
  }

  Title? get equippedTitle {
    final id = equippedTitleId;
    return id == null ? null : Title.byId(id);
  }

  /// 멀티/랭킹으로 전송할 장착 칭호 이름. 미착용이면 "".
  String get equippedTitleName => equippedTitle?.name ?? '';

  /// 칭호 장착(null이면 해제). 보유하지 않은 칭호는 무시.
  void equip(String? id) {
    if (id != null && !isTitleOwned(id)) return;
    _prefs.setString(_kEquippedTitleId, id ?? '');
    _prefs.remove(_kEquippedTitleName);
    _changed();
  }

  /// (호환) 칭호 장착 — 이름은 카탈로그에서 복원하므로 무시한다.
  void equipTitle(String id, [String? _]) => equip(id);

  /// 구매형 칭호를 코인으로 산다. 사면 곧바로 장착. 불가면 false(차감 없음).
  bool purchaseTitle(String id) {
    final t = Title.byId(id);
    final cost = t?.purchaseCost;
    if (t == null || cost == null || isTitleOwned(id)) return false;
    if (coins < cost) return false;
    _prefs.setInt(_kCoins, coins - cost);
    unlockTitle(id);
    equip(id);
    return true;
  }

  /// 업적형 칭호를 전부 재평가해 새로 충족된 것을 해금한다. 새로 해금한 칭호 목록을 돌려준다.
  /// - announce: true면 가장 높은 희귀도 1개를 `pendingUnlockToast`에 실어 축하 배너를 띄운다.
  List<Title> refreshAchievements({bool announce = true}) {
    final newly = <Title>[];
    for (final t in Title.achievements) {
      if (isTitleOwned(t.id)) continue;
      final g = t.source.goal;
      if (g != null && goalProgress(g).done) {
        unlockTitle(t.id);
        newly.add(t);
      }
    }
    if (newly.isEmpty) return const [];
    // 미착용 상태면 갓 얻은 칭호를 자동 장착(첫 보람).
    if ((_prefs.getString(_kEquippedTitleId) ?? '').isEmpty) {
      _prefs.setString(_kEquippedTitleId, newly.first.id);
    }
    if (announce) {
      pendingUnlockToast.value = newly.reduce(
          (a, b) => b.rarity.index > a.rarity.index ? b : a);
    }
    _changed();
    return newly;
  }

  // ── 클라우드 백업/복원 (Swift UserBackupService 스키마) ──

  /// users/{uid}에 저장할 페이로드 — Swift `UserBackupService.save`와 같은 필드.
  Map<String, Object> exportBackup() {
    lastSyncedDeviceId = deviceId;
    return {
      'nickname': nickname,
      'nicknameSetByUser': nicknameSetByUser,
      'records': [
        for (final e in _records)
          {
            'id': e.id,
            'name': e.name,
            'difficulty': e.difficulty,
            'timeSec': e.timeSec,
            'date': e.date.millisecondsSinceEpoch / 1000.0,
          }
      ],
      'raceWins': raceWins,
      'raceLosses': raceLosses,
      'raceDraws': raceDraws,
      'coins': coins,
      'ownedFlags': ownedFlags,
      'ownedMegaphones': ownedMegaphones,
      'ownedRadars': ownedRadars,
      'ownedThemeIDs': ownedThemeIds.toList(),
      'touchBest': touchBest ?? 0,
      'unlockedTitleIDs': ownedTitleIds.toList(),
      'equippedTitleID': equippedTitleId ?? '',
      'goldenMinesFound': goldenMinesFound,
      'gachaDraws': gachaDraws,
      'gachaJackpots': gachaJackpots,
      'bestWinStreak': bestWinStreak,
      'touchClears': touchClears,
      'noItemExpertClears': noItemExpertClears,
      'noItemUltimateClears': noItemUltimateClears,
      'lastSyncedDeviceId': deviceId,
      'schemaVersion': 1,
    };
  }

  /// 클라우드 백업을 로컬과 머지한다(Swift `RankingStore.merge` — 어느 기록도 잃지 않는 방향).
  /// - 기록: 합집합(난이도·시간·날짜초로 중복 제거)
  /// - 전적·재화·통계: 같은 기기 재로그인이면 max, 다른 기기면 합산. 최고 연승은 max.
  /// - 테마·칭호: 합집합. 협동 최고: 더 빠른 쪽. 닉네임: 사용자가 정한 쪽 우선.
  void mergeBackup(Map<String, dynamic> d, {String? suggestedName}) {
    int i(String k) => (d[k] as num?)?.toInt() ?? 0;
    List<String> strs(String k) =>
        (d[k] as List?)?.map((e) => e.toString()).toList() ?? const [];

    // 기록
    final remote = <ScoreEntry>[];
    for (final r in (d['records'] as List?) ?? const []) {
      if (r is Map) {
        final e = ScoreEntry.fromJson(Map<String, dynamic>.from(r));
        if (e != null) remote.add(e);
      }
    }
    String key(ScoreEntry e) =>
        '${e.difficulty}|${e.timeSec}|${e.date.millisecondsSinceEpoch ~/ 1000}';
    final seen = <String>{};
    _records = [
      for (final e in [..._records, ...remote])
        if (seen.add(key(e))) e,
    ];
    _trim();
    _persistRecords();

    final sameDevice = (d['lastSyncedDeviceId'] as String?) == deviceId;
    int m(int local, String k) => sameDevice ? max(local, i(k)) : local + i(k);
    _prefs.setInt(_kRaceWins, m(raceWins, 'raceWins'));
    _prefs.setInt(_kRaceLosses, m(raceLosses, 'raceLosses'));
    _prefs.setInt(_kRaceDraws, m(raceDraws, 'raceDraws'));
    _prefs.setInt(_kCoins, m(coins, 'coins'));
    _prefs.setInt(_kOwnedFlags, m(ownedFlags, 'ownedFlags'));
    _prefs.setInt(_kOwnedMegaphones, m(ownedMegaphones, 'ownedMegaphones'));
    _prefs.setInt(_kOwnedRadars, m(ownedRadars, 'ownedRadars'));
    _prefs.setInt(_kGoldenMines, m(goldenMinesFound, 'goldenMinesFound'));
    _prefs.setInt(_kGachaDraws, m(gachaDraws, 'gachaDraws'));
    _prefs.setInt(_kJackpots, m(gachaJackpots, 'gachaJackpots'));
    _prefs.setInt(_kTouchClears, m(touchClears, 'touchClears'));
    _prefs.setInt(_kNoItemExpert, m(noItemExpertClears, 'noItemExpertClears'));
    _prefs.setInt(
        _kNoItemUltimate, m(noItemUltimateClears, 'noItemUltimateClears'));
    _prefs.setInt(_kBestStreak, max(bestWinStreak, i('bestWinStreak')));

    _prefs.setStringList(
        _kOwnedThemes, {...ownedThemeIds, ...strs('ownedThemeIDs')}.toList());
    _prefs.setStringList(_kOwnedTitles,
        {...ownedTitleIds, ...strs('unlockedTitleIDs')}.toList());
    final rid = (d['equippedTitleID'] as String?) ?? '';
    if (equippedTitleId == null && rid.isNotEmpty && isTitleOwned(rid)) {
      _prefs.setString(_kEquippedTitleId, rid);
    }

    final rt = i('touchBest');
    if (rt > 0) _prefs.setInt(_kTouchBest, min(touchBest ?? rt, rt));

    final rName = (d['nickname'] as String?) ?? '';
    if (!nicknameSetByUser &&
        (d['nicknameSetByUser'] as bool? ?? false) &&
        rName.isNotEmpty) {
      _prefs.setString(_kNickname, rName);
      _prefs.setBool(_kNicknameSetByUser, true);
    }
    _applySuggestedName(suggestedName);
    refreshAchievements(announce: false);
    _changed(backup: false);
  }

  /// 로그인 제공자 이름을 닉네임으로 1회 반영(사용자가 아직 직접 정하지 않았을 때만).
  void _applySuggestedName(String? name) {
    if (name == null || name.trim().isEmpty || nicknameSetByUser) return;
    final n = name.trim();
    _prefs.setString(_kNickname, n.length > 16 ? n.substring(0, 16) : n);
    _prefs.setBool(_kNicknameSetByUser, true);
  }

  /// 클라우드 문서가 없을 때(첫 연동) — 제안 이름만 반영.
  void applySuggestedName(String? name) {
    _applySuggestedName(name);
    _changed(backup: false);
  }

  /// 계정 삭제 시 — 로컬의 모든 개인 데이터를 지우고 첫 실행(새 사용자) 상태로 되돌린다.
  /// 새 기기 ID를 발급해 이전 랭킹 기록과 완전히 분리한다(Swift와 동일). 설정(테마·햅틱)은 유지.
  Future<void> wipeLocalData() async {
    final keep = <String, Object?>{
      for (final k in [_kThemeMode, _kHaptics, _kFlagHaptics, _kNoticeLastSeen])
        k: _prefs.get(k),
    };
    await _prefs.clear();
    for (final e in keep.entries) {
      final v = e.value;
      if (v is String) await _prefs.setString(e.key, v);
      if (v is bool) await _prefs.setBool(e.key, v);
      if (v is int) await _prefs.setInt(e.key, v);
    }
    _records = [];
    _load();
    notifyListeners();
  }
}

/// 일일 도전과제 풀의 kind 목록과 결정적 선택 — progression/daily.dart와 같은 규칙.
/// (LocalStore → daily.dart 순환 의존 없이 오늘 미션 여부를 판단하려고 둔 최소 복제)
class DailyPool {
  static const kinds = ['clears', 'raceWins', 'golden', 'draws', 'touch'];
  static const dailyCount = 3;

  static List<String> forDayKinds(String dayKey) {
    final ordered = [...kinds]
      ..sort((a, b) => hash(dayKey + a).compareTo(hash(dayKey + b)));
    return ordered.take(dailyCount).toList();
  }

  /// FNV-1a 32bit (UTF-8 바이트 기준 — Swift `s.utf8`과 동일).
  static int hash(String s) {
    var h = 2166136261;
    for (final b in utf8.encode(s)) {
      h = (h ^ b) & 0xFFFFFFFF;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
}
