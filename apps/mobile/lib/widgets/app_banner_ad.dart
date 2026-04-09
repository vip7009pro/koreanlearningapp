import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../providers/monetization_provider.dart';

const String _defaultBannerAdUnitId = String.fromEnvironment(
  'ADMOB_BANNER_UNIT_ID',
  defaultValue: 'ca-app-pub-3940256099942544/6300978111',
);

class AppBannerAd extends ConsumerStatefulWidget {
  const AppBannerAd({
    super.key,
    this.adUnitId = _defaultBannerAdUnitId,
    this.adSize = AdSize.banner,
  });

  final String adUnitId;
  final AdSize adSize;

  @override
  ConsumerState<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends ConsumerState<AppBannerAd> {
  BannerAd? _bannerAd;
  bool _loadStarted = false;
  bool _loadFailed = false;

  @override
  void didUpdateWidget(covariant AppBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adUnitId != widget.adUnitId ||
        oldWidget.adSize != widget.adSize) {
      _disposeBannerAd();
    }
  }

  @override
  void dispose() {
    _disposeBannerAd();
    super.dispose();
  }

  void _disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _loadStarted = false;
    _loadFailed = false;
  }

  void _ensureAdLoaded() {
    if (_loadStarted || _bannerAd != null || _loadFailed) {
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    _loadStarted = true;
    final ad = BannerAd(
      size: widget.adSize,
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted) {
            loadedAd.dispose();
            return;
          }
          setState(() {
            _bannerAd = loadedAd as BannerAd;
          });
        },
        onAdFailedToLoad: (failedAd, _) {
          failedAd.dispose();
          if (!mounted) return;
          setState(() {
            _loadFailed = true;
            _loadStarted = false;
          });
        },
      ),
    );
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final adFreeAsync = ref.watch(adFreeStatusProvider);
    final isAdFree =
        adFreeAsync.maybeWhen(data: (value) => value, orElse: () => false);

    if (isAdFree) {
      if (_bannerAd != null) {
        _disposeBannerAd();
      }
      return const SizedBox.shrink();
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    if (adFreeAsync.isLoading) {
      return _AdLoadingPlaceholder(adSize: widget.adSize);
    }

    _ensureAdLoaded();

    if (_bannerAd == null) {
      return _AdLoadingPlaceholder(adSize: widget.adSize);
    }

    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

class _AdLoadingPlaceholder extends StatelessWidget {
  const _AdLoadingPlaceholder({required this.adSize});

  final AdSize adSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: adSize.width.toDouble(),
      height: adSize.height.toDouble(),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Đang tải quảng cáo',
        style: TextStyle(
          fontSize: 12,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
