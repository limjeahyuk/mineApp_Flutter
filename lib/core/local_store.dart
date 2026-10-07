import 'dart:convert';
import 'dart:math';

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

  static Future<LocalStore> init() async {
    // 원본 Swift 앱과 같은 키를 쓰려고 'flutter.' 접두사를 뗀다(getInstance 전에만 가능).
    try {
      SharedPreferences.setPrefix('');
    } on StateError {
      // 이미 초기화됨(테스트 재진입 등) — 그대로 쓴다.
    }
    final prefs = await SharedPreferences.getInstance();
    final s = LocalStore._(prefs);
    s._load();
    return _instance = s;
  }

  // ── 상수 (Swift와 동일) ──
  static const dailyAdLimit = 5;
  static const adRewardCoins = 30;
  static const startingCoins = 100;
  static const startingFlags = 10;
  static const startingMegaphones = 5;
  static const startingRadars = 5;
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
    // 기존 통계로 이미 충족된 업적을 조용히 해금(배너 없이).
    refreshAchievements(announce: false);
  }

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
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  set themeMode(String v) => _prefs.setString(_kThemeMode, v);

  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? true;
  set hapticsEnabled(bool v) => _prefs.setBool(_kHaptics, v);

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
  }

  bool isNoticeDismissedToday(String id) =>
      _prefs.getString('notice.dismissedToday.$id') == todayKey();
  void dismissNoticeForToday(String id) =>
      _prefs.setString('notice.dismissedToday.$id', todayKey());

  bool isMailClaimed(String id) => _prefs.getBool('mail.claimed.$id') ?? false;
  void markMailClaimed(String id) {
    _prefs.setBool('mail.claimed.$id', true);
    notifyListeners();
  }

  /// 같은 판 코드의 최고 클리어 시간(초) — Swift `best_<code>`.
  int? bestTimeForCode(String code) {
    final v = _prefs.getInt('best_$code') ?? 0;
    return v > 0 ? v : null;
  }

  void recordCodeWin(String code, int elapsed) {
    final prev = _prefs.getInt('best_$code') ?? 0;
    if (prev == 0 || elapsed < prev) _prefs.setInt('best_$code', elapsed);
  }

  String? get resumeSnapshotJson => _prefs.getString(_kResume);
  set resumeSnapshotJson(String? v) =>
      v == null ? _prefs.remove(_kResume) : _prefs.setString(_kResume, v);
}

class TripleDrawResult {
  TripleDrawResult(this.reels, this.jackpot);
  final List<GachaItem> reels;
  final bool jackpot;
}
