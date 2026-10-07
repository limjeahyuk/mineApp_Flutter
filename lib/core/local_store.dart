import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../progression/title.dart';
import '../multiplayer/multiplayer.dart' show RaceResult;
import 'board.dart';
import 'score_entry.dart';

/// Swift `RankingStore` 이식 — 로컬 개인 기록·닉네임·재화·아이템·칭호·통계·일일 도전과제 보관.
/// 값이 바뀌면 `notifyListeners`로 알린다(홈 코인 칩·뱃지 등이 구독).
/// deviceId는 반드시 **안정적**이어야 한다(매칭에서 "방금 나간 내 방"을 남의 방으로 오인하는 걸 막음).
class LocalStore extends ChangeNotifier {
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

  /// 초기화 전이면 null(테스트에서 GameModel만 쓸 때).
  static LocalStore? get maybeShared => _instance;

  static Future<LocalStore> init() async {
    final prefs = await SharedPreferences.getInstance();
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
  static const startingCoins = 100;
  static const startingFlags = 10;
  static const startingMegaphones = 5;
  static const startingRadars = 5;

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
    // 기존 통계로 이미 충족된 업적을 조용히 해금(배너 없이).
    refreshAchievements(announce: false);
  }

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
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  set themeMode(String v) => _prefs.setString(_kThemeMode, v);

  /// 적용 중인 색상 테마(스킨) id. 기본 classic.
  String get colorThemeId => _prefs.getString(_kColorTheme) ?? 'classic';
  set colorThemeId(String v) => _prefs.setString(_kColorTheme, v);

  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? true;
  set hapticsEnabled(bool v) => _prefs.setBool(_kHaptics, v);

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
  }

  bool isNoticeDismissedToday(String id) =>
      _prefs.getString('notice.dismissedToday.$id') == todayKey();
  void dismissNoticeForToday(String id) =>
      _prefs.setString('notice.dismissedToday.$id', todayKey());

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
  bool isMailClaimed(String id) => _prefs.getBool('mail.claimed.$id') ?? false;
  void markMailClaimed(String id) {
    _prefs.setBool('mail.claimed.$id', true);
    notifyListeners();
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
}
