import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:io';
import '../services/firebase_service.dart';
import '../services/user_data_service_nodejs.dart';
import '../services/game_service.dart';
import '../services/sync_service_nodejs.dart';
import '../services/local_storage_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final UserDataServiceNodeJs _userDataService = UserDataServiceNodeJs();
  final GameService _gameService = GameService();
  final SyncServiceNodeJs _syncService = SyncServiceNodeJs();
  final LocalStorageService _localStorage = LocalStorageService();
  
  bool _isLoading = false;
  String _errorMessage = '';
  
  /// Charger les données depuis le serveur Node.js après la première connexion
  Future<void> _loadUserDataAfterLogin() async {
    try {
      print('AuthScreen: Chargement des données depuis le serveur Node.js après connexion...');
      
      // Charger les données depuis le serveur Node.js (première fois seulement)
      final loaded = await _syncService.loadFromServer();
      
      if (loaded) {
        print('AuthScreen: Données chargées depuis le serveur Node.js avec succès');
      } else {
        print('AuthScreen: Aucune donnée trouvée sur le serveur, utilisation des valeurs par défaut');
        // Initialiser les données locales avec les valeurs par défaut
        await _localStorage.initializeUserData();
      }
    } catch (e) {
      print('AuthScreen: Erreur lors du chargement des données depuis le serveur: $e');
      // En cas d'erreur, initialiser avec les valeurs par défaut
      await _localStorage.initializeUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAndroidPlatform = !kIsWeb && Platform.isAndroid;
    final bool isApplePlatform = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // Logo avec effet de brillance
                  Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Titre avec gradient
                  ShaderMask(
                    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                    child: Text(
                      'CADENAS MASTER',
                      textAlign: TextAlign.center,
                      style: AppTheme.heading1.copyWith(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sous-titre
                  Text(
                    'DÉVERROUILLEZ LES DÉFIS',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyLarge.copyWith(
                      fontSize: 16,
                      letterSpacing: 3,
                      color: AppTheme.textSecondary.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
              
                  // Message d'erreur avec style moderne
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusL),
                        border: Border.all(
                          color: AppTheme.errorColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.errorColor.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline,
                              color: AppTheme.errorColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.errorColor,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.visible,
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Bouton Google (Android)
                  if (isAndroidPlatform) ...[
                    _buildNeonButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: Icons.g_mobiledata,
                      label: 'CONTINUER AVEC GOOGLE',
                      gradient: AppTheme.primaryGradient,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bouton Apple (iOS/macOS)
                  if (isApplePlatform) ...[
                    _buildNeonButton(
                      onPressed: _isLoading ? null : _handleAppleSignIn,
                      icon: Icons.apple,
                      label: 'CONTINUER AVEC APPLE',
                      gradient: AppTheme.secondaryGradient,
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Bouton Invité avec style glassmorphism
                  _buildGlassButton(
                    onPressed: _isLoading ? null : _handleAnonymousSignIn,
                    icon: Icons.person_outline,
                    label: 'JOUER EN TANT QU\'INVITÉ',
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Indicateur de chargement
                  if (_isLoading)
                    Column(
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'CONNEXION EN COURS...',
                          style: AppTheme.bodyMedium.copyWith(
                            fontSize: 13,
                            letterSpacing: 2,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeonButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required LinearGradient gradient,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: AppTheme.bodyLarge.copyWith(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
  }) {
    return Container(
      height: 56,
      decoration: AppTheme.glassButton.copyWith(
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: AppTheme.textPrimary,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: AppTheme.bodyLarge.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    _setLoading(true);
    _setError('');
    
    try {
      final credential = await _firebaseService.signInWithGoogleSimple();
      
      if (credential != null) {
        // Charger les données depuis Firebase après la connexion (première fois)
        await _loadUserDataAfterLogin();
        
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erreur de connexion';
      switch (e.code) {
        case 'network-request-failed':
          errorMessage = 'Problème de connexion réseau. Vérifiez votre connexion internet.';
          break;
        case 'invalid-credential':
          errorMessage = 'Les identifiants sont invalides. Veuillez réessayer.';
          break;
        case 'account-exists-with-different-credential':
          errorMessage = 'Un compte existe déjà avec ces identifiants.';
          break;
        default:
          errorMessage = 'Une erreur s\'est produite lors de la connexion avec Google (${e.code})';
      }
      _setError(errorMessage);
    } on PlatformException catch (e) {
      if (e.code != 'sign_in_canceled') {
        _setError('Erreur lors de la connexion avec Google: ${e.message ?? e.code}');
      }
    } catch (e) {
      _setError('Une erreur inattendue s\'est produite. Veuillez réessayer.');
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    _setLoading(true);
    _setError('');
    
    try {
      final credential = await _firebaseService.signInWithAppleSimple();
      
      if (credential != null) {
        // Charger les données depuis Firebase après la connexion (première fois)
        await _loadUserDataAfterLogin();
        
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        _setError('Erreur lors de la connexion avec Apple: ${e.message ?? e.code.toString()}');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erreur de connexion';
      switch (e.code) {
        case 'network-request-failed':
          errorMessage = 'Problème de connexion réseau. Vérifiez votre connexion internet.';
          break;
        case 'invalid-credential':
          errorMessage = 'Les identifiants sont invalides. Veuillez réessayer.';
          break;
        case 'account-exists-with-different-credential':
          errorMessage = 'Un compte existe déjà avec ces identifiants.';
          break;
        default:
          errorMessage = 'Une erreur s\'est produite lors de la connexion avec Apple (${e.code})';
      }
      _setError(errorMessage);
    } on PlatformException catch (e) {
      if (e.code == 'PLATFORM_NOT_SUPPORTED') {
        _setError('Apple Sign In n\'est disponible que sur iOS et macOS');
      } else {
        _setError('Erreur lors de la connexion avec Apple: ${e.message ?? e.code}');
      }
    } catch (e) {
      _setError('Une erreur inattendue s\'est produite. Veuillez réessayer.');
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  Future<void> _handleAnonymousSignIn() async {
    _setLoading(true);
    _setError('');
    
    try {
      final userCredential = await _firebaseService.signInAnonymouslySimple();
      await Future.delayed(const Duration(seconds: 1));
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Charger les données depuis Firebase après la connexion (première fois)
        await _loadUserDataAfterLogin();
        
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } else {
        _setError('Échec de la connexion anonyme');
      }
    } on FirebaseAuthException catch (e) {
      _setError('La connexion a échoué (${e.code}). Veuillez réessayer.');
    } catch (e) {
      _setError('La connexion a échoué. Veuillez réessayer.');
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  void _setLoading(bool isLoading) {
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
        if (isLoading) {
          _errorMessage = '';
        }
      });
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
    }
  }
} 

