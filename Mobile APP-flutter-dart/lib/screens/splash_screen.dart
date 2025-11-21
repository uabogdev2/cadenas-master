import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/connectivity_service.dart';
import 'package:flutter/services.dart';

/// Écran de démarrage (Splash Screen) - Affiche après l'initialisation, vérifie l'authentification
/// Aucune requête Firebase n'est envoyée au lancement
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  bool _navigationAttempted = false;
  late AnimationController _lockAnimationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _lockScaleAnimation;
  late Animation<double> _unlockAnimation;
  late Animation<double> _progressAnimation;
  
  double _loadingProgress = 0.0;
  String _version = '';
  String _loadingText = 'Chargement en cours...';
  
  @override
  void initState() {
    super.initState();
    _loadVersion();
    _startLoadingAnimation();
  }
  
  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = 'v${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de la version: $e');
    }
  }
  
  void _startLoadingAnimation() async {
    // Animation de progression du chargement (simulation)
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Animation du cadenas (jouée à la fin du chargement)
    // Le cadenas se débloque sans rotation, juste changement d'icône et léger mouvement
    _lockAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Animation d'échelle subtile (le cadenas pulse légèrement lors du déverrouillage)
    _lockScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.1).chain(CurveTween(curve: Curves.easeOut)), weight: 0.5),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 0.5),
    ]).animate(_lockAnimationController);
    
    // Animation de déverrouillage (translation vers le haut quand le cadenas s'ouvre)
    _unlockAnimation = Tween<double>(begin: 0.0, end: -20.0).animate(
      CurvedAnimation(
        parent: _lockAnimationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    
    // Écouter la progression
    _progressAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _loadingProgress = _progressAnimation.value;
        });
        
        // Mettre à jour le texte de chargement
        if (_loadingProgress < 0.3) {
          _loadingText = 'Initialisation...';
        } else if (_loadingProgress < 0.6) {
          _loadingText = 'Chargement des données...';
        } else if (_loadingProgress < 0.9) {
          _loadingText = 'Préparation de l\'application...';
        } else if (_loadingProgress < 1.0) {
          _loadingText = 'Presque prêt...';
        }
      }
    });
    
    // Démarrer l'animation de progression
    _progressAnimationController.forward().then((_) {
      // Quand la barre de progression est terminée, jouer l'animation du cadenas
      if (mounted) {
        setState(() {
          _loadingProgress = 1.0;
          _loadingText = 'Terminé !';
        });
        
        // Jouer l'animation du cadenas qui se débloque à la fin du chargement
        _lockAnimationController.forward().then((_) {
          // Navigation après l'animation du cadenas
          Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              _navigateToNextScreen();
            }
          });
        });
      }
    });
  }
  
  @override
  void dispose() {
    _lockAnimationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }
  
  Future<void> _navigateToNextScreen() async {
    if (_navigationAttempted) return;
    _navigationAttempted = true;
    
    try {
      await ConnectivityService.instance.ensureOnline();
      // IMPORTANT: Ne PAS faire d'appels Firebase ici
      // Utiliser seulement FirebaseAuth.instance.currentUser qui est en cache local
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/auth');
        }
      }
    } catch (e) {
      print('Erreur lors de la navigation: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Espace pour centrer le contenu
              const Spacer(),
              
              // Logo du cadenas avec animation (sans rotation)
              AnimatedBuilder(
                animation: _lockAnimationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _unlockAnimation.value),
                    child: Transform.scale(
                      scale: _lockScaleAnimation.value,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _lockAnimationController.value > 0.4 
                              ? Icons.lock_open 
                              : Icons.lock_outline,
                          size: 70,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 30),
              
              // Titre (réduit)
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                child: const Text(
                  'CADENAS MASTER',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Sous-titre
              Text(
                'Déverrouillez les défis',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  color: AppTheme.textSecondary.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const Spacer(),
              
              // Zone de chargement en bas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
                child: Column(
                  children: [
                    // Texte de chargement
                    Text(
                      _loadingText,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Barre de progression
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _loadingProgress,
                        minHeight: 6,
                        backgroundColor: AppTheme.surfaceColor.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Pourcentage
                    Text(
                      '${(_loadingProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withOpacity(0.7),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Version de l'application
                    if (_version.isNotEmpty)
                      Text(
                        _version,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary.withOpacity(0.5),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
