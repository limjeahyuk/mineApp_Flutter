import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'board.dart';

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
  static const _kOwnedFlags = 'inv.ownedFlags';
  static const _kOwnedRadars = 'inv.ownedRadars';
  static const _kOwnedMegaphones = 'inv.ownedMegaphones';
  static const _kCoins = 'shop.coins';
  static const _kAdRewardDay = 'shop.adRewardDay';
  static const _kAdsWatchedToday = 'shop.adsWatchedToday';

  /// 첫 실행 시작 지급 — Swift와 동일(자동깃발 10, 레이더 5, 코인 100).
  static const _startFlags = 10;
  static const _startRadars = 5;
  static const _startCoins = 100;

  /// 상점 상수(Swift RankingStore와 동일).
  static const drawCost = 30;
  static const tripleDrawCost = drawCost * 3;
  static const adRewardCoins = 30;
  static const dailyAdLimit = 5;

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

  // ── 아이템 인벤토리 ──
  // 키가 없으면(첫 실행) 시작 지급분을 저장해 안정적으로 만든다.
  int _owned(String key, int grant) {
    final v = _prefs.getInt(key);
    if (v == null) {
      _prefs.setInt(key, grant);
      return grant;
    }
    return v;
  }

  int get ownedFlags => _owned(_kOwnedFlags, _startFlags);
  int get ownedRadars => _owned(_kOwnedRadars, _startRadars);
  int get ownedMegaphones => _owned(_kOwnedMegaphones, 0);

  void consumeFlag() =>
      _prefs.setInt(_kOwnedFlags, max(0, ownedFlags - 1));
  void consumeRadar() =>
      _prefs.setInt(_kOwnedRadars, max(0, ownedRadars - 1));

  void addFlags(int n) => _prefs.setInt(_kOwnedFlags, max(0, ownedFlags + n));
  void addRadars(int n) => _prefs.setInt(_kOwnedRadars, max(0, ownedRadars + n));
  void addMegaphones(int n) =>
      _prefs.setInt(_kOwnedMegaphones, max(0, ownedMegaphones + n));

  // ── 코인 ──
  int get coins => _owned(_kCoins, _startCoins);

  /// 코인을 쓴다. 잔액 부족이면 false(차감 안 함).
  bool spendCoins(int amount) {
    if (amount <= 0 || coins < amount) return false;
    _prefs.setInt(_kCoins, coins - amount);
    return true;
  }

  void addCoins(int amount) {
    if (amount <= 0) return;
    _prefs.setInt(_kCoins, coins + amount);
  }

  // ── 광고 보상(하루 한도) ──
  String get _today {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  int get adsWatchedToday {
    if (_prefs.getString(_kAdRewardDay) != _today) return 0;
    return _prefs.getInt(_kAdsWatchedToday) ?? 0;
  }

  int get remainingRewardedAds => max(0, dailyAdLimit - adsWatchedToday);

  /// 보상형 광고 1회 시청분 지급. 한도 소진이면 null.
  int? claimRewardedAd() {
    final watched = adsWatchedToday; // 날짜 리셋 반영된 값
    if (watched >= dailyAdLimit) return null;
    _prefs.setString(_kAdRewardDay, _today);
    _prefs.setInt(_kAdsWatchedToday, watched + 1);
    addCoins(adRewardCoins);
    return adRewardCoins;
  }

  // ── 솔로 기록(난이도별) ──
  // Swift는 전체 기록 리스트를 저장하지만, UI는 최고 기록·클리어 수만 쓰므로 그 둘만 보관.
  String _bestKey(Difficulty d) => 'rank.best.${d.code}';
  String _countKey(Difficulty d) => 'rank.count.${d.code}';

  int? soloBest(Difficulty d) => _prefs.getInt(_bestKey(d));
  int soloClearCount(Difficulty d) => _prefs.getInt(_countKey(d)) ?? 0;

  /// 솔로 클리어 1건 기록. 개인 신기록이면 true.
  bool recordSolo(Difficulty d, int timeSec) {
    _prefs.setInt(_countKey(d), soloClearCount(d) + 1);
    final prev = soloBest(d);
    final isBest = prev == null || timeSec < prev;
    if (isBest) _prefs.setInt(_bestKey(d), timeSec);
    return isBest;
  }

  // ── 대전 전적 ──
  static const _kRaceWins = 'rank.raceWins';
  static const _kRaceLosses = 'rank.raceLosses';
  static const _kRaceDraws = 'rank.raceDraws';

  int get raceWins => _prefs.getInt(_kRaceWins) ?? 0;
  int get raceLosses => _prefs.getInt(_kRaceLosses) ?? 0;
  int get raceDraws => _prefs.getInt(_kRaceDraws) ?? 0;
  int get raceTotal => raceWins + raceLosses + raceDraws;
  int get raceWinRate {
    final decided = raceWins + raceLosses;
    if (decided == 0) return 0;
    return (raceWins / decided * 100).round();
  }

  void recordRaceWin() {
    _prefs.setInt(_kRaceWins, raceWins + 1);
    final streak = currentWinStreak + 1;
    _prefs.setInt(_kCurStreak, streak);
    if (streak > bestWinStreak) _prefs.setInt(_kBestStreak, streak);
  }

  void recordRaceLoss() {
    _prefs.setInt(_kRaceLosses, raceLosses + 1);
    _prefs.setInt(_kCurStreak, 0);
  }

  void recordRaceDraw() => _prefs.setInt(_kRaceDraws, raceDraws + 1);

  // ── 업적용 통계 ──
  static const _kCurStreak = 'stat.curStreak';
  static const _kBestStreak = 'stat.bestStreak';
  static const _kGachaDraws = 'stat.gachaDraws';
  static const _kJackpots = 'stat.jackpots';
  static const _kGoldenMines = 'stat.goldenMines';
  static const _kNoItemExpert = 'stat.noItemExpert';
  static const _kNoItemUltimate = 'stat.noItemUltimate';

  int get currentWinStreak => _prefs.getInt(_kCurStreak) ?? 0;
  int get bestWinStreak => _prefs.getInt(_kBestStreak) ?? 0;
  int get gachaDraws => _prefs.getInt(_kGachaDraws) ?? 0;
  int get gachaJackpots => _prefs.getInt(_kJackpots) ?? 0;
  int get goldenMinesFound => _prefs.getInt(_kGoldenMines) ?? 0;
  int get noItemExpertClears => _prefs.getInt(_kNoItemExpert) ?? 0;
  int get noItemUltimateClears => _prefs.getInt(_kNoItemUltimate) ?? 0;

  void addGachaDraws(int n) =>
      _prefs.setInt(_kGachaDraws, gachaDraws + n);
  void addJackpot() => _prefs.setInt(_kJackpots, gachaJackpots + 1);
  void addGoldenMines(int n) =>
      _prefs.setInt(_kGoldenMines, goldenMinesFound + n);
  void recordNoItemHardClear(Difficulty d) {
    if (d == Difficulty.expert) {
      _prefs.setInt(_kNoItemExpert, noItemExpertClears + 1);
    } else if (d == Difficulty.ultimate) {
      _prefs.setInt(_kNoItemUltimate, noItemUltimateClears + 1);
    }
  }

  // ── 우편(수령 여부) ──
  bool isMailClaimed(String id) => _prefs.getBool('mail.claimed.$id') ?? false;
  void markMailClaimed(String id) => _prefs.setBool('mail.claimed.$id', true);

  /// 우편 보상 일괄 지급.
  void grantMailReward(
      {int coins = 0, int flags = 0, int megaphones = 0, int radars = 0}) {
    if (coins > 0) addCoins(coins);
    if (flags > 0) addFlags(flags);
    if (megaphones > 0) addMegaphones(megaphones);
    if (radars > 0) addRadars(radars);
  }

  // ── 칭호(보유/장착) ──
  static const _kOwnedTitles = 'title.owned';
  static const _kEquippedTitleId = 'title.equippedId';

  Set<String> get ownedTitleIds {
    final list = _prefs.getStringList(_kOwnedTitles) ?? const [];
    return {'rookie', ...list}; // 스타터는 항상 보유
  }

  bool isTitleOwned(String id) => ownedTitleIds.contains(id);

  /// 칭호 해금(중복 무시). 새로 해금됐으면 true.
  bool unlockTitle(String id) {
    if (isTitleOwned(id)) return false;
    final list = _prefs.getStringList(_kOwnedTitles) ?? <String>[];
    list.add(id);
    _prefs.setStringList(_kOwnedTitles, list);
    return true;
  }

  String get equippedTitleId => _prefs.getString(_kEquippedTitleId) ?? 'rookie';

  /// 칭호 장착 — id와 표시 이름을 함께 저장(랭킹 제출/표시에 이름 사용).
  void equipTitle(String id, String name) {
    _prefs.setString(_kEquippedTitleId, id);
    equippedTitleName = name;
  }
}
