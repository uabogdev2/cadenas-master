import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  
  factory AdService() => _instance;
  
  AdService._internal();
  
  bool _initialized = false;
  bool get isInitialized => _initialized;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  
  // Counter for completed levels
  int _completedLevelsCounter = 0;
  // Frequency of ad display (show ad every X levels)
  static const int adFrequency = 7;
  
  // Rewarded ad settings
  static const int rewardedAdPoints = 50; // Points donnés pour chaque pub récompensée
  static const int maxRewardedAdsPerPeriod = 10; // Nombre maximum de pubs par période
  static const int rewardedAdCooldownMinutes = 10; // Période de cooldown en minutes
  
  // Variables de suivi des publicités récompensées
  int _rewardedAdsWatched = 0;
  DateTime? _lastRewardedAdResetTime;
  
  // Production Ad IDs - IDs de production AdMob
  static const String bannerAndroidId = 'ca-app-pub-6069477065860045/6334683521';
  static const String bannerIOSId = 'ca-app-pub-6069477065860045/9474076089';
  
  static const String interstitialAndroidId = 'ca-app-pub-6069477065860045/6464769361';
  static const String interstitialIOSId = 'ca-app-pub-6069477065860045/2036345869';
  
  static const String rewardedAndroidId = 'ca-app-pub-6069477065860045/2033025174';
  static const String rewardedIOSId = 'ca-app-pub-6069477065860045/5095847371';
  
  static const String videoInterstitialAndroidId = 'ca-app-pub-6069477065860045/6464769361';
  static const String videoInterstitialIOSId = 'ca-app-pub-6069477065860045/2036345869';
  
  // Ad Unit IDs getters - Utilise toujours les IDs de production
  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return bannerAndroidId;
    } else if (Platform.isIOS) {
      return bannerIOSId;
    }
    throw UnsupportedError('Unsupported platform');
  }
  
  String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return videoInterstitialAndroidId;
    } else if (Platform.isIOS) {
      return videoInterstitialIOSId;
    }
    throw UnsupportedError('Unsupported platform');
  }
  
  String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return rewardedAndroidId;
    } else if (Platform.isIOS) {
      return rewardedIOSId;
    }
    throw UnsupportedError('Unsupported platform');
  }
  
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Simple initialization as per documentation
      final initStatus = await MobileAds.instance.initialize();
      debugPrint('AdMob initialization status: ${initStatus.adapterStatuses}');
      
      _initialized = true;
      
      // Preload ads
      _loadInterstitialAd();
      loadRewardedAd();
      
      // Charger les données de suivi des publicités récompensées
      await _loadRewardedAdTracking();
      
      debugPrint('AdMob initialized successfully');
    } catch (e) {
      debugPrint('Error initializing AdMob: $e');
      _initialized = false;
    }
  }
  
  // Charger les données de suivi des publicités récompensées depuis SharedPreferences
  Future<void> _loadRewardedAdTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _rewardedAdsWatched = prefs.getInt('rewarded_ads_watched') ?? 0;
      
      final lastResetTimeMillis = prefs.getInt('last_rewarded_ad_reset_time');
      if (lastResetTimeMillis != null) {
        _lastRewardedAdResetTime = DateTime.fromMillisecondsSinceEpoch(lastResetTimeMillis);
      } else {
        _lastRewardedAdResetTime = DateTime.now();
        await _saveRewardedAdTracking();
      }
      
      // Vérifier si le cooldown est terminé
      _checkAndResetRewardedAdCooldown();
      
      debugPrint('Rewarded ad tracking loaded: $_rewardedAdsWatched ads watched, last reset: $_lastRewardedAdResetTime');
    } catch (e) {
      debugPrint('Error loading rewarded ad tracking: $e');
    }
  }
  
  // Sauvegarder les données de suivi des publicités récompensées dans SharedPreferences
  Future<void> _saveRewardedAdTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('rewarded_ads_watched', _rewardedAdsWatched);
      
      if (_lastRewardedAdResetTime != null) {
        await prefs.setInt('last_rewarded_ad_reset_time', _lastRewardedAdResetTime!.millisecondsSinceEpoch);
      }
      
      debugPrint('Rewarded ad tracking saved: $_rewardedAdsWatched ads watched');
    } catch (e) {
      debugPrint('Error saving rewarded ad tracking: $e');
    }
  }
  
  // Vérifier si le cooldown des publicités récompensées est terminé
  void _checkAndResetRewardedAdCooldown() {
    if (_lastRewardedAdResetTime == null) {
      _lastRewardedAdResetTime = DateTime.now();
      _rewardedAdsWatched = 0;
      _saveRewardedAdTracking();
      return;
    }
    
    final now = DateTime.now();
    final difference = now.difference(_lastRewardedAdResetTime!);
    
    // Si le cooldown est terminé (5 minutes écoulées)
    if (difference.inMinutes >= rewardedAdCooldownMinutes) {
      _lastRewardedAdResetTime = now;
      _rewardedAdsWatched = 0;
      _saveRewardedAdTracking();
      debugPrint('Rewarded ad cooldown reset. New ads can be watched.');
    }
  }
  
  // Vérifier si l'utilisateur peut regarder une publicité récompensée
  Future<bool> canWatchRewardedAd() async {
    // Vérifier si le cooldown est terminé
    _checkAndResetRewardedAdCooldown();
    
    // Vérifier si l'utilisateur a atteint la limite
    return _rewardedAdsWatched < maxRewardedAdsPerPeriod;
  }
  
  // Obtenir le nombre de publicités restantes que l'utilisateur peut regarder
  Future<int> getRemainingRewardedAds() async {
    // Vérifier si le cooldown est terminé
    _checkAndResetRewardedAdCooldown();
    
    return maxRewardedAdsPerPeriod - _rewardedAdsWatched;
  }
  
  // Obtenir le temps restant avant la réinitialisation du compteur
  Future<Duration> getTimeUntilRewardedAdReset() async {
    if (_lastRewardedAdResetTime == null) {
      return Duration.zero;
    }
    
    final now = DateTime.now();
    final resetTime = _lastRewardedAdResetTime!.add(Duration(minutes: rewardedAdCooldownMinutes));
    
    if (now.isAfter(resetTime)) {
      return Duration.zero;
    }
    
    return resetTime.difference(now);
  }
  
  // This method is no longer used - banner ads are created directly in the BannerAdWidget
  // Keeping it for reference
  /*
  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: ${error.message}');
          ad.dispose();
        },
      ),
    );
  }
  */
  
  // Interstitial Ad
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          
          // Set the full screen callback
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('Interstitial ad dismissed');
              ad.dispose();
              _loadInterstitialAd(); // Load a new ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Interstitial ad failed to show: $error');
              ad.dispose();
              _loadInterstitialAd(); // Try loading again
            },
          );
          
          debugPrint('Interstitial ad loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: ${error.message}');
          _interstitialAd = null;
          // Retry loading after failure with a shorter delay
          Future.delayed(const Duration(seconds: 30), () {
            if (_initialized) _loadInterstitialAd();
          });
        },
      ),
    );
  }
  
  // Increment level counter and check if we should show an ad
  Future<bool> shouldShowInterstitialAd() async {
    _completedLevelsCounter++;
    debugPrint('Completed levels counter: $_completedLevelsCounter');
    
    // Show ad every 7 levels
    return _completedLevelsCounter % adFrequency == 0;
  }
  
  Future<bool> showInterstitialAd() async {
    if (!_initialized) {
      debugPrint('AdMob not initialized');
      return false;
    }
    
    // Check if we should show an ad based on level count
    if (!(await shouldShowInterstitialAd())) {
      debugPrint('Skipping interstitial ad based on level count');
      return false;
    }
    
    if (_interstitialAd == null) {
      debugPrint('Interstitial ad not ready yet');
      _loadInterstitialAd();
      return false;
    }
    
    try {
      await _interstitialAd!.show();
      return true;
    } catch (e) {
      debugPrint('Error showing interstitial ad: $e');
      _interstitialAd = null;
      _loadInterstitialAd();
      return false;
    }
  }
  
  // Reset the level counter (useful for testing or when user resets progress)
  void resetLevelCounter() {
    _completedLevelsCounter = 0;
  }
  
  // Rewarded Ad
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          
          // Les callbacks seront définis lors de l'affichage de la pub
          // pour permettre de passer des callbacks personnalisés
          
          debugPrint('Rewarded ad loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: ${error.message}');
          _rewardedAd = null;
          
          // Retry loading after a delay
          Future.delayed(const Duration(seconds: 30), () {
            if (_initialized) loadRewardedAd();
          });
        },
      ),
    );
  }
  
  Future<bool> showRewardedAd(
    Function(RewardItem) onUserEarnedReward, {
    VoidCallback? onAdShown,
    VoidCallback? onAdDismissed,
  }) async {
    if (!_initialized) {
      debugPrint('AdMob not initialized');
      return false;
    }
    
    // Vérifier si l'utilisateur peut regarder une publicité
    if (!(await canWatchRewardedAd())) {
      debugPrint('User has reached the maximum number of rewarded ads');
      return false;
    }
    
    if (_rewardedAd == null) {
      debugPrint('Rewarded ad not ready yet');
      loadRewardedAd();
      return false;
    }
    
    try {
      // Sauvegarder la référence à la pub avant de la montrer
      final ad = _rewardedAd!;
      
      // Appeler onAdShown AVANT de montrer la pub car show() est asynchrone
      // mais la pub s'affiche immédiatement
      onAdShown?.call();
      
      // Configurer les callbacks avant de montrer la pub
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('Rewarded ad dismissed');
          // Appeler le callback onAdDismissed si fourni
          onAdDismissed?.call();
          ad.dispose();
          loadRewardedAd(); // Load a new ad
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('Rewarded ad failed to show: $error');
          // Appeler le callback onAdDismissed même en cas d'erreur
          onAdDismissed?.call();
          ad.dispose();
          loadRewardedAd(); // Try loading again
        },
      );
      
      await ad.show(
        onUserEarnedReward: (_, reward) {
          debugPrint('User earned reward from ad');
          // Incrémenter le compteur de publicités visionnées
          _rewardedAdsWatched++;
          _saveRewardedAdTracking();
          
          // Créer une récompense avec le montant fixe de 50 points
          final fixedReward = RewardItem(
            rewardedAdPoints,
            reward.type,
          );
          
          // Appeler le callback de récompense
          onUserEarnedReward(fixedReward);
          debugPrint('Rewarded ad watched: $_rewardedAdsWatched/$maxRewardedAdsPerPeriod');
        }
      );
      return true;
    } catch (e) {
      debugPrint('Error showing rewarded ad: $e');
      // Appeler le callback onAdDismissed en cas d'erreur
      onAdDismissed?.call();
      _rewardedAd = null;
      loadRewardedAd();
      return false;
    }
  }
  
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
} 