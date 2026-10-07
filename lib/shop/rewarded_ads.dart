import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 보상형 광고(AdMob) — Swift RewardedAdManager 이식.
/// 시작 시 SDK 초기화 + 미리 로드, 실패하면 지수 백오프로 재시도, 로드 55분 지나면 만료 취급.
/// `present`가 false면(미준비) 호출부가 시뮬레이션 광고로 폴백한다.
class RewardedAdManager {
  RewardedAdManager._();
  static final shared = RewardedAdManager._();

  static const _iosTest = 'ca-app-pub-3940256099942544/1712485313';
  static const _iosLive = 'ca-app-pub-9773018240020529/7768066534';
  // ponytail: Android용 실제 광고 단위가 아직 없어 공식 테스트 ID — 출시 전 교체.
  static const _androidTest = 'ca-app-pub-3940256099942544/5224354917';

  String get adUnitId {
    if (Platform.isAndroid) return _androidTest;
    return kDebugMode ? _iosTest : _iosLive;
  }

  RewardedAd? _ad;
  bool _loading = false;
  DateTime? _loadedAt;
  Duration _retry = const Duration(seconds: 5);
  bool _started = false;

  bool get _expired =>
      _loadedAt != null &&
      DateTime.now().difference(_loadedAt!) > const Duration(minutes: 55);

  bool get isReady => _ad != null && !_expired;

  /// 앱 시작 시 — 추적 동의(ATT)를 먼저 받고, 그 결과를 반영해 SDK를 시작한다.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      if (Platform.isIOS &&
          await AppTrackingTransparency.trackingAuthorizationStatus ==
              TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
      await MobileAds.instance.initialize();
      load();
    } catch (_) {}
  }

  void load() {
    if (!_started) return; // SDK 시작 전(테스트 등)엔 아무것도 하지 않는다
    if (_ad != null && _expired) {
      _ad?.dispose();
      _ad = null;
      _loadedAt = null;
    }
    if (_ad != null || _loading) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loadedAt = DateTime.now();
          _retry = const Duration(seconds: 5);
          _loading = false;
        },
        onAdFailedToLoad: (_) {
          _loading = false;
          final delay = _retry;
          _retry = Duration(seconds: (_retry.inSeconds * 2).clamp(5, 300));
          Timer(delay, load);
        },
      ),
    );
  }

  /// 준비된 광고를 띄운다. 끝까지 보면 onReward 1회. 미준비면 false(호출부 폴백).
  bool present(void Function() onReward) {
    final ad = _ad;
    if (ad == null || _expired) {
      if (_expired) {
        _ad?.dispose();
        _ad = null;
        _loadedAt = null;
      }
      load();
      return false;
    }
    _ad = null; // 1회용
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        load();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        load();
      },
    );
    ad.show(onUserEarnedReward: (_, _) => onReward());
    return true;
  }
}
