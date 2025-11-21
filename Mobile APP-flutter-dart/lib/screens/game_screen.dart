import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/level_model.dart';
import '../services/game_service.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../widgets/code_input.dart';
import '../widgets/banner_ad_widget.dart';
import '../theme/app_theme.dart';

class GameScreen extends StatefulWidget {
  final Level level;

  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _gameService = GameService();
  bool _isUnlocking = false;
  bool _isSuccess = false;
  bool _isError = false;
  String _currentCode = '';
  int _attempts = 0;
  Level? _nextLevel;
  
  // Timer et progression
  late Timer _timer;
  int _timeRemaining = 0;
  double _progress = 1.0;
  bool _isTimerActive = true;
  
  // Statistiques
  int _totalPoints = 0;
  int _totalAttempts = 0;
  int? _bestTime;
  
  // Indices
  List<int> _unlockedHints = [];
  bool _isHintMenuOpen = false;
  
  // État pour le déblocage d'indice via pub
  bool? _pendingHintRewardEarned;
  int? _pendingHintIndex;
  
  // Couleur de succès
  final Color _successColor = Colors.blueAccent;
  // Couleur d'échec
  final Color _failureColor = Colors.red;

  @override
  void initState() {
    super.initState();
    // Initialiser le timer
    _timeRemaining = widget.level.timeLimit;
    _startTimer();
    
    // Réinitialiser les indices débloqués pour ce niveau
    _gameService.resetUnlockedHints(widget.level.id);
    
    // Charger les données
    _loadData();
  }
  
  Future<void> _loadData() async {
    // Vérifier si un niveau suivant existe
    await _checkNextLevel();
    
    // Charger les points et autres données en une seule fois pour éviter les appels multiples
    await Future.wait([
      _loadPoints(),
      _loadAttempts(),
      _loadBestTime(),
      _loadUnlockedHints(),
    ]);
    
    if (mounted) {
      setState(() {});
    }
  }
  
  Future<void> _loadPoints() async {
    _totalPoints = await _gameService.getPoints();
  }
  
  Future<void> _loadAttempts() async {
    _totalAttempts = await _gameService.getAttempts(widget.level.id);
  }
  
  Future<void> _loadBestTime() async {
    _bestTime = await _gameService.getBestTime(widget.level.id);
  }
  
  Future<void> _loadUnlockedHints() async {
    _unlockedHints = await _gameService.getUnlockedHints(widget.level.id);
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0 && _isTimerActive) {
        setState(() {
          _timeRemaining--;
          _progress = _timeRemaining / widget.level.timeLimit;
        });
      } else if (_timeRemaining <= 0) {
        _timer.cancel();
        if (_isTimerActive) {
          _handleTimeOut();
        }
      }
    });
  }
  
  void _pauseTimer() {
    setState(() {
      _isTimerActive = false;
    });
  }
  
  void _resumeTimer() {
    if (_timeRemaining > 0 && !_isSuccess) {
      setState(() {
        _isTimerActive = true;
      });
    }
  }
  
  Future<void> _checkNextLevel() async {
    final nextLevelId = widget.level.id + 1;
    _nextLevel = await _gameService.getLevelById(nextLevelId);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _checkCode(String code) {
    setState(() {
      _isUnlocking = true;
      _currentCode = code;
    });

    // Increment attempts
    _gameService.incrementAttempts(widget.level.id);
    
    // Vérification immédiate au lieu d'un délai artificiel
    if (code == widget.level.code) {
      _handleSuccess();
    } else {
      _handleError();
    }
  }

  void _handleSuccess() async {
    // Jouer le son de succès
    final audioService = AudioService();
    await audioService.playSucces();
    
    // Arrêter le timer
    _timer.cancel();
    _isTimerActive = false;
    
    // Sauvegarder le temps
    final timeSpent = widget.level.timeLimit - _timeRemaining;
    final previousBestTime = await _gameService.getBestTime(widget.level.id);
    final bool isFirstCompletion = previousBestTime == null;
    final bool isNewRecord = previousBestTime == null || timeSpent < previousBestTime;
    final int pointsEarned = isFirstCompletion ? widget.level.pointsReward : 0;
    
    setState(() {
      _isSuccess = true;
      _isUnlocking = false;
    });

    // Afficher immédiatement la boîte de dialogue de succès
    if (mounted) {
      _showSuccessDialog(
        isFirstCompletion: isFirstCompletion,
        isNewRecord: isNewRecord,
        pointsEarned: pointsEarned,
      );
    }
    
    // Effectuer les opérations de sauvegarde en arrière-plan
    // sans bloquer l'interface utilisateur
    Future.microtask(() async {
      await Future.wait([
        _gameService.saveBestTime(widget.level.id, timeSpent),
        // Ajouter des points uniquement lors de la première complétion
        isFirstCompletion
            ? _gameService.addPoints(pointsEarned)
            : Future.value(),
        _gameService.unlockNextLevel(widget.level.id),
        _checkNextLevel(),
      ]);
    });
  }

  void _handleError() async {
    // Jouer le son d'échec
    final audioService = AudioService();
    await audioService.playEchec();
    
    setState(() {
      _isError = true;
      _isUnlocking = false;
      _attempts++;
    });

    // Reset error state after delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isError = false;
        });
      }
    });
  }
  
  void _handleTimeOut() {
    setState(() {
      _isTimerActive = false;
    });
    
    if (mounted) {
      _showTimeOutDialog();
    }
  }
  
  Future<void> _unlockHint(int index) async {
    // Vérifier si l'indice est déjà débloqué
    if (_unlockedHints.contains(index)) {
      return;
    }

    final int cost = widget.level.hintCost;
    final bool hasEnoughPoints = _totalPoints >= cost;

    if (hasEnoughPoints) {
      setState(() {
        _unlockedHints.add(index);
        _totalPoints -= cost;
      });

      // Afficher un message de succès immédiatement
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Indice débloqué !'),
            backgroundColor: _successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      Future.microtask(() async {
        final result = await _gameService.unlockHint(
          widget.level.id,
          index,
          cost,
        );

        if (!result && mounted) {
          setState(() {
            _unlockedHints.remove(index);
            _totalPoints += cost;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Impossible de débloquer l\'indice. Veuillez réessayer.'),
                backgroundColor: _failureColor,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      });
      return;
    }

    // L'utilisateur n'a pas assez de points, proposer de regarder une publicité
    final bool? watchAd = await _showAdConfirmationDialog();
    if (watchAd != true) {
      return;
    }

    final adService = AdService();
    final canWatch = await adService.canWatchRewardedAd();
    if (!canWatch) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Limite de publicités atteinte. Réessayez plus tard.'),
            backgroundColor: _failureColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Stocker l'index de l'indice en attente
    _pendingHintIndex = index;
    _pendingHintRewardEarned = false;

    final adShown = await adService.showRewardedAd(
      (reward) {
        // Cette fonction est appelée quand l'utilisateur gagne la récompense
        debugPrint('Reward earned, unlocking hint $index');
        _pendingHintRewardEarned = true;
        
        // Débloquer l'indice immédiatement
        _gameService.unlockHintWithAd(widget.level.id, index).then((success) {
          debugPrint('unlockHintWithAd result: $success for hint $index');
          if (success && mounted) {
            // Mettre à jour l'état immédiatement
            setState(() {
              if (!_unlockedHints.contains(index)) {
                _unlockedHints.add(index);
                debugPrint('Hint $index added to _unlockedHints');
              }
            });
            
            // Recharger les indices pour s'assurer de la synchronisation
            _loadUnlockedHints().then((_) {
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Indice débloqué !'),
                    backgroundColor: _successColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            });
          } else if (mounted) {
            debugPrint('Failed to unlock hint $index via ad');
          }
        }).catchError((e) {
          debugPrint('Error unlocking hint with ad: $e');
        });
      },
      onAdShown: () {
        debugPrint('Rewarded ad shown - pausing timer');
        // Mettre en pause le timer quand la pub est réellement affichée
        if (mounted) {
          _pauseTimer();
        }
      },
      onAdDismissed: () {
        debugPrint('Rewarded ad dismissed - resuming timer');
        // Reprendre le timer après la fermeture de la pub
        if (mounted) {
          _resumeTimer();
          
          // Vérifier l'état du déblocage après un court délai
          final hintIndexToCheck = _pendingHintIndex;
          final rewardEarned = _pendingHintRewardEarned ?? false;
          
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (mounted && hintIndexToCheck != null) {
              // Recharger les indices pour vérifier l'état actuel
              await _loadUnlockedHints();
              
              if (mounted) {
                setState(() {});
                final isUnlocked = _unlockedHints.contains(hintIndexToCheck);
                debugPrint('After ad dismissed: hint $hintIndexToCheck unlocked=$isUnlocked, rewardEarned=$rewardEarned');
                
                if (!isUnlocked) {
                  if (!rewardEarned) {
                    // L'utilisateur n'a pas regardé la pub jusqu'à la fin
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Regardez la pub jusqu\'à la fin pour débloquer l\'indice.'),
                        backgroundColor: _failureColor,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } else {
                    // La récompense a été gagnée mais le déblocage semble avoir échoué
                    // Réessayer de débloquer
                    debugPrint('Retrying to unlock hint $hintIndexToCheck');
                    final retrySuccess = await _gameService.unlockHintWithAd(widget.level.id, hintIndexToCheck);
                    if (retrySuccess) {
                      await _loadUnlockedHints();
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Indice débloqué !'),
                            backgroundColor: _successColor,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Erreur lors du déblocage. Réessayez.'),
                          backgroundColor: _failureColor,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                }
              }
              
              // Réinitialiser l'état
              _pendingHintIndex = null;
              _pendingHintRewardEarned = null;
            }
          });
        }
      },
    );

    if (!adShown) {
      // Reprendre le timer si la pub n'a pas pu être affichée
      _resumeTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aucune publicité disponible pour le moment.'),
            backgroundColor: _failureColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<bool?> _showAdConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.live_tv, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Voir une pub ?',
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'Pas assez de points. Regardez une pub pour débloquer l\'indice gratuitement.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Voir'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog({required bool isFirstCompletion, required bool isNewRecord, required int pointsEarned}) {
    // Précharger une pub interstitielle
    final adService = AdService();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.successGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
          ],
        ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Text(
                'Niveau terminé !',
                style: AppTheme.heading2.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
            Text(
              'Vous avez déverrouillé le niveau ${widget.level.id} en ${widget.level.timeLimit - _timeRemaining} secondes.',
                style: AppTheme.bodyLarge.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
            ),
              if (isNewRecord) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Nouveau record !',
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            const SizedBox(height: 16),
            if (isFirstCompletion)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
              Text(
                        '+$pointsEarned points',
                        style: AppTheme.heading3.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
              )
            else
              Text(
                  'Niveau déjà complété',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.8),
              ),
        ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_nextLevel != null)
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          adService.showInterstitialAd().then((_) {
                            Navigator.of(context).pop();
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Text(
                          'Continuer',
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        adService.showInterstitialAd().then((_) {
                          Navigator.of(context).pop();
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Continuer',
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (_nextLevel != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          adService.showInterstitialAd().then((_) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => GameScreen(level: _nextLevel!),
                              ),
                            );
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.accentColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text(
                          'Suivant',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showTimeOutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.errorGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            boxShadow: [
              BoxShadow(
                color: AppTheme.errorColor.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              const Icon(Icons.timer_off, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Text(
                  'Temps écoulé !',
                style: AppTheme.heading2.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              Text(
                  'Vous n\'avez pas réussi à déverrouiller le cadenas à temps.',
                style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Menu des niveaux'),
                    ),
                  ),
              const SizedBox(height: 12),
              SizedBox(
                    width: double.infinity,
                child: OutlinedButton(
                      onPressed: () {
                    Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(level: widget.level),
                          ),
                        );
                      },
                  style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Recommencer'),
                  ),
                ),
              ],
          ),
        ),
      ),
    );
  }
  
  void _toggleHintMenu() {
    setState(() {
      _isHintMenuOpen = !_isHintMenuOpen;
    });
  }

  // Afficher la boîte de dialogue de pause
  void _showPauseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  color: AppTheme.primaryColor,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Jeu en pause',
                  style: AppTheme.heading2,
                ),
                const SizedBox(height: 8),
                Text(
                  'Que souhaitez-vous faire ?',
                  style: AppTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Text(
                          'Reprendre',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop(); // Retour à l'écran précédent
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text(
                          'Quitter',
                          overflow: TextOverflow.ellipsis,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isSuccess 
                  ? AppTheme.accentColor.withOpacity(0.5)
                  : AppTheme.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
                color: _isSuccess ? AppTheme.accentColor : AppTheme.primaryColor,
                size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Niveau ${widget.level.id}',
                style: AppTheme.bodyLarge.copyWith(
                  color: _isSuccess ? AppTheme.accentColor : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
              ),
            ),
          ],
          ),
        ),
        actions: [
          // Bouton de pause
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.pause_circle_outline, color: AppTheme.textPrimary),
            onPressed: () => _showPauseDialog(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Lock visualization with timer
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final circleSize = screenWidth < 360 ? 120.0 : 140.0;
                            final lockSize = circleSize * 0.85;
                            final iconSize = lockSize * 0.5;
                            
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                      SizedBox(
                                        width: circleSize,
                                        height: circleSize,
                                        child: CircularProgressIndicator(
                                          value: _progress,
                                          strokeWidth: 6,
                                          backgroundColor: AppTheme.surfaceColor,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _progress > 0.5 
                                                ? AppTheme.accentColor
                                              : _progress > 0.25 
                                                    ? AppTheme.secondaryColor
                                                    : AppTheme.errorColor,
                                          ),
                                        ),
                                      ),
                                      // Lock container
                                      Container(
                                        width: lockSize,
                                        height: lockSize,
                                        decoration: BoxDecoration(
                                          gradient: RadialGradient(
                                            colors: _isSuccess
                                                ? [
                                                    AppTheme.accentColor.withOpacity(0.3),
                                                    AppTheme.accentColor.withOpacity(0.1),
                                                  ]
                                                : _isError
                                                    ? [
                                                        AppTheme.errorColor.withOpacity(0.3),
                                                        AppTheme.errorColor.withOpacity(0.1),
                                                      ]
                                                    : [
                                                        AppTheme.primaryColor.withOpacity(0.2),
                                                        AppTheme.primaryColor.withOpacity(0.05),
                                                      ],
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _isSuccess
                                                ? AppTheme.accentColor
                                                : _isError
                                                    ? AppTheme.errorColor
                                                    : AppTheme.primaryColor,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (_isSuccess
                                                      ? AppTheme.accentColor
                                                      : _isError
                                                          ? AppTheme.errorColor
                                                          : AppTheme.primaryColor)
                                                  .withOpacity(0.4),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _isSuccess ? Icons.lock_open : Icons.lock,
                                          size: iconSize,
                                          color: _isSuccess
                                              ? AppTheme.accentColor
                                              : _isError
                                                  ? AppTheme.errorColor
                                                  : AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                        const SizedBox(height: 30),
                        // Instructions
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Text(
                          widget.level.instruction,
                            style: AppTheme.bodyLarge.copyWith(
                            fontSize: 16,
                              height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Bouton d'indice
                        if (widget.level.additionalHints.isNotEmpty && !_isSuccess && _isTimerActive)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                              boxShadow: AppTheme.buttonShadow,
                            ),
                            child: ElevatedButton.icon(
                            onPressed: _toggleHintMenu,
                            icon: Icon(
                              _isHintMenuOpen ? Icons.lightbulb : Icons.lightbulb_outline,
                                color: AppTheme.secondaryColor,
                            ),
                            label: Text(
                              _isHintMenuOpen ? "Masquer les indices" : "Afficher les indices",
                                style: AppTheme.bodyLarge.copyWith(
                                  color: Colors.white,
                                ),
                            ),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.surfaceColor,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ),
                        
                        // Menu d'indices
                        if (_isHintMenuOpen && !_isSuccess && _isTimerActive)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                              border: Border.all(
                                color: AppTheme.secondaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < widget.level.additionalHints.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: _unlockedHints.contains(i)
                                      ? Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2.0),
                                              child: Icon(
                                                Icons.lightbulb,
                                                color: AppTheme.secondaryColor,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                widget.level.additionalHints[i],
                                                style: AppTheme.bodyMedium.copyWith(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Icon(
                                              Icons.lock,
                                              color: AppTheme.textTertiary,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _totalPoints >= widget.level.hintCost
                                                    ? "Indice ${i + 1} (coût: ${widget.level.hintCost} points)"
                                                    : "Indice ${i + 1} (regarder une pub pour débloquer)",
                                                style: AppTheme.bodyMedium.copyWith(
                                                  color: AppTheme.textTertiary,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              height: 32,
                                              width: 32,
                                              decoration: BoxDecoration(
                                                gradient: _totalPoints >= widget.level.hintCost
                                                    ? AppTheme.secondaryGradient
                                                    : LinearGradient(
                                                        colors: [
                                                          AppTheme.errorColor,
                                                          AppTheme.errorColor.withOpacity(0.8),
                                                        ],
                                                      ),
                                                borderRadius: BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: (_totalPoints >= widget.level.hintCost
                                                            ? AppTheme.secondaryColor
                                                            : AppTheme.errorColor)
                                                        .withOpacity(0.3),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () => _unlockHint(i),
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: Center(
                                                child: Icon(
                                                      _totalPoints >= widget.level.hintCost
                                                          ? Icons.lock_open
                                                          : Icons.play_circle_outline,
                                                      size: 16,
                                                  color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 20),
                        // Code input
                        _isSuccess
                            ? Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.successGradient,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentColor.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                'Code correct !',
                                      style: AppTheme.heading3.copyWith(
                                        color: Colors.white,
                                  fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _isTimerActive 
                                ? CodeInput(
                                    codeLength: widget.level.codeLength,
                                    onCompleted: _checkCode,
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.errorGradient,
                                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.errorColor.withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.timer_off, color: Colors.white, size: 24),
                                        const SizedBox(width: 12),
                                        Text(
                                    'Temps écoulé !',
                                          style: AppTheme.heading3.copyWith(
                                            color: Colors.white,
                                      fontSize: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                        const SizedBox(height: 20),
                        // Status text
                        if (_isUnlocking)
                          const Column(
                            children: [
                              SizedBox(height: 20),
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 10),
                              Text(
                                'Vérification du code...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          )
                        else if (_isError)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                              border: Border.all(
                                color: AppTheme.errorColor.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close, color: AppTheme.errorColor, size: 20),
                                const SizedBox(width: 8),
                          Text(
                            'Code incorrect ! Essai ${_attempts}',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.errorColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                        // Statistiques
                        if (!_isSuccess && !_isUnlocking && _isTimerActive)
                          Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_bestTime != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.timer, color: AppTheme.secondaryColor, size: 16),
                                        const SizedBox(width: 6),
                                  Text(
                                    'Record: $_bestTime s',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.secondaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh, color: AppTheme.textSecondary, size: 16),
                                      const SizedBox(width: 6),
                                Text(
                                  'Tentatives: $_totalAttempts',
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                        // Espace supplémentaire en bas pour le défilement
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const BannerAdWidget(),
        ],
      ),
        ),
      ),
    );
  }
} 