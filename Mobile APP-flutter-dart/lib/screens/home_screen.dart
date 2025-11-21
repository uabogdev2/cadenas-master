import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/game_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/floating_bubble_button.dart';
import '../widgets/animated_locks_background.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/trophy_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/display_name_dialog.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'how_to_play.dart';
import 'profile_screen.dart';
import 'matchmaking_screen.dart';
import 'leaderboard_screen.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GameService _gameService = GameService();
  final UserProfileService _profileService = UserProfileService();
  int _points = 0;
  int _trophies = 0;
  int _previousTrophies = 0;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  late AnimationController _trophyAnimationController;
  late Animation<double> _trophyScaleAnimation;
  bool _isTrophyIncreasing = true;
  bool _isAnimating = false;
  int _lastAnimatedTrophyValue = 0; // Pour éviter d'animer plusieurs fois pour le même changement
  bool _isLoadingData = false; // Pour éviter les appels multiples simultanés à _loadData
  bool _isShowingExitDialog = false; // Pour éviter d'afficher plusieurs dialogs
  bool _hasPromptedDisplayName = false;
  late VoidCallback _profileListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trophyAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _trophyScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _trophyAnimationController,
        curve: Curves.easeOut,
      ),
    );
    _profileListener = () {
      final profile = _profileService.profile.value;
      if (profile != null && mounted) {
        _updateUiFromProfile(profile, true);
      }
    };
    _profileService.profile.addListener(_profileListener);
    _loadData(animateIfChanged: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profileService.profile.removeListener(_profileListener);
    _trophyAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasLoadedOnce && !_isLoadingData) {
      // Recharger les données quand l'app revient au premier plan
      // Mais seulement si on n'est pas déjà en train de charger
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isLoadingData) {
          _loadData(animateIfChanged: true);
        }
      });
    }
  }

  // Méthode publique pour recharger les données depuis l'extérieur
  void reloadData({bool animate = true}) {
    _loadData(animateIfChanged: animate);
  }

  Future<void> _loadData({bool animateIfChanged = true}) async {
    // Éviter les appels multiples simultanés
    if (_isLoadingData) {
      debugPrint('⏸️ _loadData déjà en cours, ignoré');
      return;
    }
    
    _isLoadingData = true;
    
    try {
      final profile = await _profileService.refresh();
      if (profile != null && mounted) {
        await _updateUiFromProfile(profile, animateIfChanged);
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des données: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      _isLoadingData = false;
    }
  }

  Future<void> _updateUiFromProfile(UserProfile profile, bool animateIfChanged) async {
    if (!mounted) return;
    final newTrophies = profile.trophies;
    final newPoints = profile.points;
    final previousTrophies = _trophies;
    final wasFirstLoad = !_hasLoadedOnce;
    final hasChanged = newTrophies != previousTrophies;
    final isIncreasing = newTrophies > previousTrophies;

    final shouldAnimate = animateIfChanged &&
        !wasFirstLoad &&
        hasChanged &&
        _lastAnimatedTrophyValue != newTrophies;

    if (shouldAnimate) {
      _lastAnimatedTrophyValue = newTrophies;
      debugPrint('🎯 Animation déclenchée: $previousTrophies -> $newTrophies (${isIncreasing ? "augmentation +${newTrophies - previousTrophies}" : "diminution ${newTrophies - previousTrophies}"})');
    }

    setState(() {
      _points = newPoints;
      _trophies = newTrophies;
      _isTrophyIncreasing = isIncreasing;
      _isLoading = false;
      _hasLoadedOnce = true;
    });

    if (shouldAnimate) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (_trophyAnimationController.isAnimating) {
        _trophyAnimationController.stop();
        _trophyAnimationController.reset();
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted) return;
      setState(() => _isAnimating = true);
      _trophyAnimationController.forward().then((_) {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          _trophyAnimationController.reverse().then((_) {
            if (!mounted) return;
            _trophyAnimationController.reset();
            setState(() => _isAnimating = false);
          });
        });
      });
    } else {
      if (_trophyAnimationController.isAnimating) {
        _trophyAnimationController.stop();
        _trophyAnimationController.reset();
      }
      setState(() => _isAnimating = false);

      if (wasFirstLoad) {
        debugPrint('📊 Premier chargement: $newTrophies trophées');
      } else if (!hasChanged) {
        debugPrint('📊 Pas de changement: $newTrophies trophées');
      } else if (!animateIfChanged) {
        debugPrint('📊 Rechargement sans animation: $newTrophies trophées');
      } else if (_lastAnimatedTrophyValue == newTrophies) {
        debugPrint('📊 Déjà animé pour cette valeur: $newTrophies trophées');
      }
    }

    _maybePromptDisplayName();
  }

  void _maybePromptDisplayName() {
    if (_hasPromptedDisplayName) return;
    if (!_profileService.needsDisplayName) return;
    _hasPromptedDisplayName = true;
    Future.microtask(() async {
      if (!mounted) return;
      final updated = await showDisplayNameDialog(context, isInitial: true);
      if (!updated) {
        _hasPromptedDisplayName = false;
        return;
      }
      await _profileService.refresh(force: true);
      if (mounted) {
        _loadData(animateIfChanged: true);
      }
    });
  }

  void _showPointsOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1929),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.stars_rounded,
                color: Colors.blue.shade300,
                size: 50,
              ),
              const SizedBox(height: 15),
              const Text(
                'Obtenir des points',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Choisissez comment vous souhaitez obtenir des points supplémentaires.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('ACHETER DES POINTS'),
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: Colors.grey.shade800,
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showRewardedAd();
                      },
                      icon: const Icon(Icons.videocam),
                      label: const Text('REGARDER UNE PUB (+50 POINTS)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    FutureBuilder<int>(
                      future: AdService().getRemainingRewardedAds(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text(
                            'Publicités restantes: ${snapshot.data}/${AdService.maxRewardedAdsPerPeriod}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 15),
              
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'ANNULER',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRewardedAd() {
    try {
      final adService = AdService();
      
      adService.canWatchRewardedAd().then((canWatch) async {
        if (!canWatch) {
          final remainingTime = await adService.getTimeUntilRewardedAdReset();
          final minutes = remainingTime.inMinutes;
          final seconds = remainingTime.inSeconds % 60;
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Limite de publicités atteinte. Réessayez dans ${minutes}m ${seconds}s.',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.red.shade800,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(10),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.black.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Chargement de la publicité...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        adService.loadRewardedAd();
        
        Future.delayed(const Duration(seconds: 2), () {
          try {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
            
            if (!adService.isInitialized) {
              debugPrint("AdMob non initialisé, attribution de points de test");
              const int testPoints = AdService.rewardedAdPoints;
              _gameService.addPoints(testPoints);
              
              setState(() {
                _points += testPoints;
              });
              
              _showRewardDialog(testPoints);
              return;
            }
            
            adService.showRewardedAd((reward) {
              final pointsToAdd = reward.amount.toInt();
              _gameService.addPoints(pointsToAdd);
              
              setState(() {
                _points += pointsToAdd;
              });
              
              _showRewardDialog(pointsToAdd);
            }).then((shown) {
              if (!shown && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Aucune publicité disponible pour le moment.'),
                    backgroundColor: Colors.red.shade800,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(10),
                  ),
                );
              }
            }).catchError((error) {
              debugPrint('Erreur lors de l\'affichage de la pub: $error');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Erreur lors du chargement de la publicité.'),
                    backgroundColor: Colors.red.shade800,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(10),
                  ),
                );
              }
            });
          } catch (e) {
            debugPrint('Exception dans _showRewardedAd delayed: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Erreur lors du chargement de la publicité.'),
                  backgroundColor: Colors.red.shade800,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(10),
                ),
              );
            }
          }
        });
      });
    } catch (e) {
      debugPrint('Exception dans _showRewardedAd: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur lors du chargement de la publicité.'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    }
  }

  void _showRewardDialog(int points) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade800,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 60,
              ),
              const SizedBox(height: 15),
              Text(
                'Félicitations !',
                style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Vous avez gagné $points points !',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Super !'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Afficher le dialog de confirmation de fermeture
  Future<bool> _showExitDialog() async {
    if (_isShowingExitDialog) {
      return false; // Éviter les dialogs multiples
    }
    
    setState(() {
      _isShowingExitDialog = true;
    });
    
    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.surfaceColor,
                    AppTheme.cardColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: const Icon(
                      Icons.exit_to_app,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Titre
                  Text(
                    'Quitter l\'application',
                    style: AppTheme.heading2.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  
                  // Message
                  Text(
                    'Souhaitez-vous vraiment quitter l\'application ?',
                    style: AppTheme.bodyMedium.copyWith(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Boutons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Bouton Annuler
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.textSecondary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(dialogContext).pop(false);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Center(
                                child: Text(
                                  'ANNULER',
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Bouton Quitter
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(dialogContext).pop(true);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Center(
                                child: Text(
                                  'QUITTER',
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      return result ?? false;
    } finally {
      if (mounted) {
        setState(() {
          _isShowingExitDialog = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = AudioService();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return PopScope(
      canPop: false, // Empêcher la fermeture automatique
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Afficher le dialog de confirmation
          final shouldExit = await _showExitDialog();
          if (shouldExit && mounted) {
            // Quitter l'application
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: Stack(
        children: [
          // Fond avec gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),
          
          // Cadenas animés en arrière-plan - défilement vertical
          const AnimatedLocksBackground(
            lockCount: 80, // Encore plus de cadenas
            lockSize: 30, // Petits cadenas
            animationDuration: Duration(seconds: 20), // Animation plus rapide
          ),
          
          // Contenu principal
          SafeArea(
            child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                )
              : Column(
                  children: [
                    // Header compact avec points et profil
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Bouton profil
                          GestureDetector(
                            onTap: () async {
                              final refreshed = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ProfileScreen(),
                                ),
                              );
                              if (mounted && !_isLoadingData) {
                                if (refreshed == true) {
                                  _loadData(animateIfChanged: true);
                                } else {
                                  Future.delayed(const Duration(milliseconds: 200), () {
                                    if (mounted && !_isLoadingData) {
                                      _loadData(animateIfChanged: true);
                                    }
                                  });
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                color: AppTheme.textPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                          // Points et Trophées
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Points
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatNumber(_points),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: _showPointsOptionsDialog,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.add, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Trophées avec animation
                              AnimatedBuilder(
                                animation: _trophyAnimationController,
                                builder: (context, child) {
                                  final isAnimating = _isAnimating && _trophyAnimationController.isAnimating;
                                  final gradient = isAnimating
                                      ? (_isTrophyIncreasing
                                          ? LinearGradient(
                                              colors: [
                                                AppTheme.accentColor,
                                                AppTheme.accentColor.withOpacity(0.8),
                                              ],
                                            )
                                          : LinearGradient(
                                              colors: [
                                                AppTheme.errorColor,
                                                AppTheme.errorColor.withOpacity(0.8),
                                              ],
                                            ))
                                      : AppTheme.secondaryGradient;
                                  
                                  return Transform.scale(
                                    scale: isAnimating ? _trophyScaleAnimation.value : 1.0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: gradient,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: isAnimating
                                            ? [
                                                BoxShadow(
                                                  color: (_isTrophyIncreasing
                                                          ? AppTheme.accentColor
                                                          : AppTheme.errorColor)
                                                      .withOpacity(0.6),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: AppTheme.secondaryColor.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isAnimating)
                                            Icon(
                                              _isTrophyIncreasing
                                                  ? Icons.trending_up
                                                  : Icons.trending_down,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          if (isAnimating) const SizedBox(width: 4),
                                          const Icon(Icons.emoji_events, color: Colors.white, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            TrophyService.formatTrophies(_trophies),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Contenu principal - Bulles flottantes en cercle
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: screenWidth,
                          height: screenHeight * 0.6,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Boutons disposés en cercle bien espacés
                              // JOUER - au milieu vertical exact entre CLASSEMENT (60°) et PARAMÈTRES (120°)
                              // Milieu vertical = 90°, symétrie à gauche = 270° (4.712 radians)
                              _buildCircularButton(
                                angle: 4.712, // 270° - Milieu vertical exact entre CLASSEMENT et PARAMÈTRES
                                radius: screenWidth * 0.32,
                                child: FloatingBubbleButton(
                                  icon: Icons.play_arrow,
                                  label: 'JOUER',
                                  gradient: AppTheme.primaryGradient,
                                  size: 85, // Même taille que DUEL
                                  delay: const Duration(milliseconds: 0),
                                  onTap: () {
                                    audioService.playClic();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LevelSelectScreen(),
                                      ),
                                    );
                                    Future.delayed(const Duration(milliseconds: 300), () {
                                      if (mounted && !_isLoadingData) {
                                        _loadData(animateIfChanged: true);
                                      }
                                    });
                                  },
                                ),
                              ),
                              
                              // DUEL - En haut
                              _buildCircularButton(
                                angle: 0, // 0° - En haut
                                radius: screenWidth * 0.32,
                                child: FloatingBubbleButton(
                                  icon: Icons.sports_esports,
                                  label: 'DUEL',
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.errorColor,
                                      AppTheme.errorColor.withOpacity(0.8),
                                    ],
                                  ),
                                  size: 85,
                                  delay: const Duration(milliseconds: 200),
                                  onTap: () async {
                                    audioService.playClic();
                                    final shouldRefresh = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const MatchmakingScreen(),
                                      ),
                                    );
                                    if (mounted && !_isLoadingData) {
                                      if (shouldRefresh == true) {
                                        _loadData(animateIfChanged: true);
                                      } else {
                                        Future.delayed(const Duration(milliseconds: 1000), () {
                                          if (mounted && !_isLoadingData) {
                                            _loadData(animateIfChanged: true);
                                          }
                                        });
                                      }
                                    }
                                  },
                                ),
                              ),
                              
                              // CLASSEMENT - En haut à droite
                              _buildCircularButton(
                                angle: 1.047, // 60° - En haut à droite
                                radius: screenWidth * 0.32,
                                child: FloatingBubbleButton(
                                  icon: Icons.leaderboard,
                                  label: 'CLASS.',
                                  gradient: AppTheme.secondaryGradient,
                                  size: 75,
                                  delay: const Duration(milliseconds: 400),
                                  onTap: () async {
                                    audioService.playClic();
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LeaderboardScreen(),
                                      ),
                                    );
                                    Future.delayed(const Duration(milliseconds: 200), () {
                                      if (mounted && !_isLoadingData) {
                                        _loadData(animateIfChanged: true);
                                      }
                                    });
                                  },
                                ),
                              ),
                              
                              // PARAMÈTRES - En bas à droite
                              _buildCircularButton(
                                angle: 2.094, // 120° - En bas à droite
                                radius: screenWidth * 0.32,
                                child: FloatingBubbleButton(
                                  icon: Icons.settings,
                                  label: 'PARAM.',
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.surfaceColor,
                                      AppTheme.cardColor,
                                    ],
                                  ),
                                  size: 75,
                                  delay: const Duration(milliseconds: 600),
                                  onTap: () async {
                                    audioService.playClic();
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const SettingsScreen(),
                                      ),
                                    );
                                    Future.delayed(const Duration(milliseconds: 200), () {
                                      if (mounted && !_isLoadingData) {
                                        _loadData(animateIfChanged: true);
                                      }
                                    });
                                  },
                                ),
                              ),
                              
                              // AIDE - En bas
                              _buildCircularButton(
                                angle: 3.142, // 180° - En bas
                                radius: screenWidth * 0.32,
                                child: FloatingBubbleButton(
                                  icon: Icons.help_outline,
                                  label: 'AIDE',
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.surfaceColor.withOpacity(0.8),
                                      AppTheme.cardColor.withOpacity(0.8),
                                    ],
                                  ),
                                  size: 70,
                                  delay: const Duration(milliseconds: 800),
                                  onTap: () async {
                                    audioService.playClic();
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const HowToPlayScreen(),
                                      ),
                                    );
                                    Future.delayed(const Duration(milliseconds: 200), () {
                                      if (mounted && !_isLoadingData) {
                                        _loadData(animateIfChanged: true);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bannière publicitaire en bas
                    const BannerAdWidget(),
                  ],
                ),
          ),
        ],
      ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// Positionner un widget en cercle autour du centre
  Widget _buildCircularButton({
    required double angle, // Angle en radians
    required double radius, // Rayon du cercle
    required Widget child,
  }) {
    // Calculer la position x et y sur le cercle
    final x = radius * math.cos(angle - math.pi / 2); // -pi/2 pour commencer en haut
    final y = radius * math.sin(angle - math.pi / 2);
    
    return Transform.translate(
      offset: Offset(x, y),
      child: child,
    );
  }
}
