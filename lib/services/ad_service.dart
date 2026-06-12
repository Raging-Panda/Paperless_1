import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages AdMob banner and rewarded ad lifecycle.
///
/// TODO: Replace the test ad unit IDs below with your real IDs from
/// https://apps.admob.com before releasing to production.
class AdService {
  AdService._();
  static final instance = AdService._();

  // --- Test ad unit IDs (safe to use during development) ---
  static const _bannerAdUnitId = 'ca-app-pub-3739862204262213/6420771400';
  static const _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  RewardedAd? _rewardedAd;
  bool _rewardedLoading = false;

  Future<InitializationStatus> initialize() => MobileAds.instance.initialize();

  /// Creates and loads a [BannerAd]. Call [BannerAd.dispose] when done.
  BannerAd createBanner({required void Function() onLoaded}) {
    final ad = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    ad.load();
    return ad;
  }

  /// Loads and shows a rewarded ad.
  /// [onEarnedReward] is called only if the user watches to completion.
  /// [onFailed] is called if the ad cannot be loaded or shown.
  Future<void> showRewarded({
    required void Function() onEarnedReward,
    required void Function() onFailed,
  }) async {
    if (_rewardedLoading) {
      onFailed();
      return;
    }
    _rewardedLoading = true;

    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          _rewardedAd = ad;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _rewardedAd = null;
              onFailed();
            },
          );

          ad.show(
            onUserEarnedReward: (_, _) => onEarnedReward(),
          );
        },
        onAdFailedToLoad: (_) {
          _rewardedLoading = false;
          onFailed();
        },
      ),
    );
  }
}
