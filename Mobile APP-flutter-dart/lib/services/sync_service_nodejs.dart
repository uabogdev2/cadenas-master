import 'package:firebase_auth/firebase_auth.dart';
import 'local_storage_service.dart';
import 'user_data_service_nodejs.dart';
import 'game_service.dart';
import 'api_service.dart';

/// Service de synchronisation avec le serveur Node.js
/// Synchronise les données locales avec le serveur Node.js seulement sur demande ou périodiquement (1 fois par semaine)
class SyncServiceNodeJs {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorageService _localStorage = LocalStorageService();
  final UserDataServiceNodeJs _userDataService = UserDataServiceNodeJs();
  final ApiService _apiService = ApiService();

  // Ne pas créer GameService dans le constructeur pour éviter la dépendance circulaire
  // Utiliser un getter lazy à la place
  GameService get _gameService => GameService();

  // Singleton pattern
  static final SyncServiceNodeJs _instance = SyncServiceNodeJs._internal();
  factory SyncServiceNodeJs() => _instance;
  SyncServiceNodeJs._internal();

  String? get _userId => _auth.currentUser?.uid;
  bool get isUserLoggedIn => _userId != null;

  /// Synchroniser toutes les données locales vers le serveur Node.js
  /// Retourne true si la synchronisation a réussi
  Future<bool> syncToServer({bool force = false}) async {
    if (!isUserLoggedIn) {
      print('SyncService: Aucun utilisateur connecté, impossible de synchroniser');
      return false;
    }

    try {
      print('SyncService: Début de la synchronisation vers le serveur Node.js...');

      // Obtenir toutes les données locales
      final localData = await _localStorage.getAllUserData();

      // Initialiser les données utilisateur dans le serveur si nécessaire
      await _userDataService.initializeUserData();

      // Synchroniser les points, trophées, et niveaux complétés
      await _apiService.put('/api/users/me', body: {
        'points': localData['points'] as int,
        'trophies': localData['trophies'] as int,
        'completedLevels': localData['completedLevels'] as int,
        'displayName': localData['displayName'] as String,
        'photoURL': localData['photoURL'] as String?,
      });
      print('SyncService: Points, trophées et progression synchronisés');

      // Synchroniser les statistiques
      final stats = localData['stats'] as Map<String, dynamic>;
      await _apiService.post('/api/users/sync', body: {
        'stats': stats,
      });
      print('SyncService: Statistiques synchronisées');

      // Synchroniser la progression des niveaux via GameService
      try {
        await _gameService.syncAllLevelProgressToServer();
        print('SyncService: Progression des niveaux synchronisée');
      } catch (e) {
        print('SyncService: Erreur lors de la synchronisation de la progression des niveaux: $e');
        // Continuer malgré l'erreur
      }

      // Marquer comme synchronisé
      await _localStorage.saveLastSyncDate(DateTime.now());

      print('SyncService: Synchronisation terminée avec succès');
      return true;
    } catch (e) {
      print('SyncService: Erreur lors de la synchronisation: $e');
      return false;
    }
  }

  /// Synchroniser la progression d'un niveau spécifique
  Future<void> syncLevelProgress(
    int levelId, {
    required bool isCompleted,
    int? bestTime,
    int attempts = 0,
  }) async {
    if (!isUserLoggedIn) return;

    try {
      await _userDataService.saveLevelProgress(
        levelId,
        isCompleted: isCompleted,
        bestTime: bestTime,
        attempts: attempts,
      );
    } catch (e) {
      print('SyncService: Erreur lors de la synchronisation de la progression: $e');
    }
  }

  /// Synchroniser les indices débloqués
  Future<void> syncUnlockedHints(int levelId, List<int> hints) async {
    if (!isUserLoggedIn) return;

    try {
      await _userDataService.saveUnlockedHints(levelId, hints);
    } catch (e) {
      print('SyncService: Erreur lors de la synchronisation des indices: $e');
    }
  }

  /// Charger les données depuis le serveur Node.js vers le stockage local (première connexion)
  Future<bool> loadFromServer() async {
    if (!isUserLoggedIn) {
      print('SyncService: Aucun utilisateur connecté, impossible de charger depuis le serveur');
      return false;
    }

    try {
      print('SyncService: Chargement des données depuis le serveur Node.js...');

      // Initialiser les données utilisateur si nécessaire
      await _userDataService.initializeUserData();

      // Charger les données utilisateur
      final userData = await _userDataService.getUserData();
      if (userData == null) {
        print('SyncService: Aucune donnée utilisateur trouvée, initialisation avec les valeurs par défaut');
        await _localStorage.initializeUserData();
        return true;
      }

      // Charger les statistiques
      final stats = await _userDataService.getGlobalStats();

      // Charger les données dans le stockage local
      final serverData = {
        'points': userData['points'] ?? 500,
        'trophies': userData['trophies'] ?? 0,
        'completedLevels': userData['completedLevels'] ?? 0,
        'displayName': userData['displayName'] ?? _auth.currentUser?.displayName ?? 'Joueur',
        'photoURL': userData['photoURL'] ?? _auth.currentUser?.photoURL,
        'email': userData['email'] ?? _auth.currentUser?.email ?? 'Utilisateur anonyme',
        'stats': stats,
      };

      await _localStorage.loadFromFirebase(serverData);

      // Charger et vérifier les nouvelles questions depuis le serveur
      try {
        await _gameService.initialize();
        // Vérifier s'il y a de nouvelles questions
        await _gameService.checkAndUpdateLevelsFromServer();
        print('SyncService: Niveaux chargés et vérifiés depuis le serveur');
      } catch (e) {
        print('SyncService: Erreur lors du chargement des niveaux: $e');
        // Continuer malgré l'erreur
      }

      print('SyncService: Données chargées depuis le serveur Node.js avec succès');
      return true;
    } catch (e) {
      print('SyncService: Erreur lors du chargement depuis le serveur: $e');
      return false;
    }
  }

  /// Vérifier et effectuer la synchronisation si nécessaire (1 fois par semaine)
  Future<void> checkAndSyncIfNeeded() async {
    if (!isUserLoggedIn) return;

    try {
      final shouldSync = await _localStorage.shouldSync();
      if (shouldSync) {
        print('SyncService: Synchronisation périodique déclenchée');
        await syncToServer();
      }
    } catch (e) {
      print('SyncService: Erreur lors de la vérification de synchronisation: $e');
    }
  }

  /// Forcer la synchronisation maintenant
  Future<bool> forceSyncNow() async {
    return await syncToServer(force: true);
  }
}

