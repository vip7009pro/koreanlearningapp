import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../providers/monetization_provider.dart';

const String _defaultAppOpenAdUnitId = String.fromEnvironment(
  'ADMOB_APP_OPEN_UNIT_ID',
  defaultValue: 'ca-app-pub-3940256099942544/9257395921',
);

const String _defaultInterstitialAdUnitId = String.fromEnvironment(
  'ADMOB_INTERSTITIAL_UNIT_ID',
  defaultValue: 'ca-app-pub-3940256099942544/1033173712',
);

const Duration _adFreshnessTimeout = Duration(hours: 4);
const Duration _appOpenCooldown = Duration(minutes: 1);
const Duration _interstitialCooldown = Duration(minutes: 2);

final adsManagerProvider = Provider<AdsManager>((ref) => AdsManager(ref));

class AdsManager {
  AdsManager(this._ref);

  final Ref _ref;

  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;

  DateTime? _appOpenLoadedAt;
  DateTime? _interstitialLoadedAt;
  DateTime? _lastAppOpenShownAt;
  DateTime? _lastInterstitialShownAt;

  bool _appOpenLoading = false;
  bool _appOpenShowing = false;
  bool _appOpenShouldShowWhenLoaded = false;
  bool _interstitialLoading = false;
  bool _interstitialShowing = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  bool _isFresh(DateTime? loadedAt) {
    return loadedAt != null &&
        DateTime.now().difference(loadedAt) < _adFreshnessTimeout;
  }

  Future<bool> _isAdFree() async {
    try {
      return await _ref.read(adFreeStatusProvider.future);
    } catch (_) {
      return false;
    }
  }

  void preload() {
    if (!_isAndroid) return;
    unawaited(_loadAppOpenAd());
    unawaited(_loadInterstitialAd());
  }

  Future<void> handleAppResumed() async {
    if (!_isAndroid) return;
    if (await _isAdFree()) return;

    final now = DateTime.now();
    if (_lastAppOpenShownAt != null &&
        now.difference(_lastAppOpenShownAt!) < _appOpenCooldown) {
      return;
    }

    _appOpenShouldShowWhenLoaded = true;

    if (_appOpenAd != null && _isFresh(_appOpenLoadedAt)) {
      _appOpenShouldShowWhenLoaded = false;
      unawaited(_presentAppOpenAd(_appOpenAd!));
      return;
    }

    unawaited(_loadAppOpenAd());
  }

  Future<bool> maybeShowInterstitialAd() async {
    if (!_isAndroid) return false;
    if (await _isAdFree()) return false;

    final now = DateTime.now();
    if (_lastInterstitialShownAt != null &&
        now.difference(_lastInterstitialShownAt!) < _interstitialCooldown) {
      unawaited(_loadInterstitialAd());
      return false;
    }

    if (_interstitialAd == null || !_isFresh(_interstitialLoadedAt)) {
      unawaited(_loadInterstitialAd());
      return false;
    }

    return _presentInterstitialAd(_interstitialAd!);
  }

  Future<void> _loadAppOpenAd() async {
    if (!_isAndroid || _appOpenLoading || _appOpenShowing) return;
    _appOpenLoading = true;
    if (await _isAdFree()) {
      _appOpenLoading = false;
      return;
    }
    if (_appOpenAd != null && _isFresh(_appOpenLoadedAt)) {
      _appOpenLoading = false;
      if (_appOpenShouldShowWhenLoaded) {
        _appOpenShouldShowWhenLoaded = false;
        unawaited(_presentAppOpenAd(_appOpenAd!));
      }
      return;
    }

    try {
      AppOpenAd.load(
        adUnitId: _defaultAppOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenLoading = false;
            _appOpenAd = ad;
            _appOpenLoadedAt = DateTime.now();

            if (_appOpenShouldShowWhenLoaded) {
              _appOpenShouldShowWhenLoaded = false;
              unawaited(_presentAppOpenAd(ad));
            }
          },
          onAdFailedToLoad: (error) {
            _appOpenLoading = false;
            _appOpenAd = null;
            _appOpenLoadedAt = null;
          },
        ),
      );
    } catch (_) {
      _appOpenLoading = false;
      _appOpenAd = null;
      _appOpenLoadedAt = null;
    }
  }

  Future<void> _loadInterstitialAd() async {
    if (!_isAndroid || _interstitialLoading || _interstitialShowing) return;
    _interstitialLoading = true;
    if (await _isAdFree()) {
      _interstitialLoading = false;
      return;
    }
    if (_interstitialAd != null && _isFresh(_interstitialLoadedAt)) {
      _interstitialLoading = false;
      return;
    }

    try {
      InterstitialAd.load(
        adUnitId: _defaultInterstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialLoading = false;
            _interstitialAd = ad;
            _interstitialLoadedAt = DateTime.now();
          },
          onAdFailedToLoad: (error) {
            _interstitialLoading = false;
            _interstitialAd = null;
            _interstitialLoadedAt = null;
          },
        ),
      );
    } catch (_) {
      _interstitialLoading = false;
      _interstitialAd = null;
      _interstitialLoadedAt = null;
    }
  }

  Future<void> _presentAppOpenAd(AppOpenAd ad) async {
    if (_appOpenShowing) return;
    if (await _isAdFree()) {
      ad.dispose();
      _appOpenAd = null;
      _appOpenShowing = false;
      return;
    }

    final completer = Completer<void>();
    _appOpenShowing = true;
    _appOpenAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenShowing = false;
        _lastAppOpenShownAt = DateTime.now();
        if (!completer.isCompleted) completer.complete();
        unawaited(_loadAppOpenAd());
        unawaited(_loadInterstitialAd());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenShowing = false;
        if (!completer.isCompleted) completer.complete();
        unawaited(_loadAppOpenAd());
      },
    );

    ad.show();
    await completer.future;
  }

  Future<bool> _presentInterstitialAd(InterstitialAd ad) async {
    if (_interstitialShowing) return false;
    if (await _isAdFree()) {
      ad.dispose();
      _interstitialAd = null;
      _interstitialShowing = false;
      return false;
    }

    final completer = Completer<bool>();
    _interstitialShowing = true;
    _interstitialAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialShowing = false;
        _lastInterstitialShownAt = DateTime.now();
        if (!completer.isCompleted) completer.complete(true);
        unawaited(_loadInterstitialAd());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialShowing = false;
        if (!completer.isCompleted) completer.complete(false);
        unawaited(_loadInterstitialAd());
      },
    );

    ad.show();
    return completer.future;
  }
}
