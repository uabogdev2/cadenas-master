import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'screens/launch_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/game_screen.dart';
import 'screens/level_select_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/how_to_play.dart';
import 'theme/app_theme.dart';
import 'screens/profile_screen.dart';
import 'services/firebase_service.dart';
import 'services/game_service.dart';
import 'services/user_data_service.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/connectivity_service.dart';
import 'services/user_profile_service.dart';
import 'services/version_check_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Assurer que Flutter est initialisé avant tout
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supprimer le contour vert de l'application
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));
  
  try {
    // Initialiser Firebase avant de lancer l'application
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialisé avec succès dans main()');

    if (FirebaseAuth.instance.currentUser != null) {
      await UserProfileService().refresh();
    }
    
    // Initialiser AdMob
    try {
      // Initialize AdMob directly
      await MobileAds.instance.initialize();
      print('AdMob initialisé avec succès dans main()');
      
      // Then initialize our service
      final adService = AdService();
      await adService.initialize();
      // Reset level counter at app start
      adService.resetLevelCounter();
      print('AdService initialisé et compteur de niveaux réinitialisé');
    } catch (e) {
      print('Erreur lors de l\'initialisation d\'AdMob: $e');
      // Continue anyway, ads will be disabled
    }
    
    // Précharger les assets
    await _preloadAssets();
  } catch (e) {
    print('ERREUR CRITIQUE lors de l\'initialisation: $e');
    // Continuer quand même pour afficher un écran d'erreur à l'utilisateur
  }
  
  // Exécuter l'application
  runApp(const MyApp());
}

// Précharger les assets importants
Future<void> _preloadAssets() async {
  try {
    // Précharger le fichier JSON des niveaux
    final data = await rootBundle.loadString('assets/data/levels.json');
    print('Assets préchargés avec succès: ${data.substring(0, 20)}...');
  } catch (e) {
    print('Erreur lors du préchargement des assets: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GameService _gameService = GameService();
  bool _initialized = false;
  bool _error = false;

  // Initialiser les services
  Future<void> _initializeApp() async {
    try {
      // Initialiser le service de jeu
      await _gameService.initialize();
      if (FirebaseAuth.instance.currentUser != null) {
        await UserProfileService().ensureProfile();
      }
      
      // Initialiser le service audio et démarrer la musique
      final audioService = AudioService();
      await audioService.initialize();
      await audioService.playMusic();

      // Vérifier la version et la configuration
      // Note: Le context n'est pas disponible ici, donc on le fera dans le SplashScreen
      
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      print('Erreur lors de l\'initialisation: $e');
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Ajouter l'observateur du cycle de vie de l'application
    WidgetsBinding.instance.addObserver(this);
    ConnectivityService.instance.initialize(appNavigatorKey);
    // Initialiser l'application
    _initializeApp();
  }

  @override
  void dispose() {
    // Supprimer l'observateur et libérer les ressources
    WidgetsBinding.instance.removeObserver(this);
    _gameService.dispose();
    ConnectivityService.instance.dispose();
    // Libérer les ressources des publicités
    AdService().dispose();
    // Libérer les ressources audio
    AudioService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audioService = AudioService();
    // Lorsque l'application est mise en arrière-plan ou fermée
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive || 
        state == AppLifecycleState.detached) {
      // Mettre en pause la musique
      audioService.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      // Reprendre la musique quand l'app revient au premier plan
      audioService.resumeMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vérifier si l'utilisateur est déjà connecté
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && _initialized) {
      print('Utilisateur déjà connecté dans main: ${currentUser.uid} (anonyme: ${currentUser.isAnonymous})');
    }
    
    // Afficher l'écran de lancement pendant l'initialisation
    if (!_initialized) {
      return MaterialApp(
        title: 'CADENAS MASTER',
        theme: AppTheme.darkTheme,
        home: const LaunchScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    // En cas d'erreur d'initialisation
    if (_error) {
      return MaterialApp(
        title: 'CADENAS MASTER',
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 100,
                  color: Colors.red,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Erreur d\'initialisation',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializeApp,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    // Application principale une fois initialisée
    return MaterialApp(
      title: 'CADENAS MASTER',
      theme: AppTheme.darkTheme,
      navigatorKey: appNavigatorKey,
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/auth': (context) => const AuthScreen(),
        '/levels': (context) => const LevelSelectScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/how_to_play': (context) => const HowToPlayScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
