import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_storage_service.dart';
import 'user_data_service.dart';
import 'game_service.dart';

/// Service de synchronisation avec Firebase
/// Synchronise les données locales avec Firebase seulement sur demande ou périodiquement (1 fois par semaine)
class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorageService _localStorage = LocalStorageService();
  final UserDataService _userDataService = UserDataService();
  
  // Ne pas créer GameService dans le constructeur pour éviter la dépendance circulaire
  // Utiliser un getter lazy à la place
  GameService get _gameService => GameService();

  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  String? get _userId => _auth.currentUser?.uid;
  bool get isUserLoggedIn => _userId != null;

  /// Synchroniser toutes les données locales vers Firebase
  /// Retourne true si la synchronisation a réussi
  Future<bool> syncToFirebase({bool force = false}) async {
    if (!isUserLoggedIn) {
      print('SyncService: Aucun utilisateur connecté, impossible de synchroniser');
      return false;
    }

    try {
      print('SyncService: Début de la synchronisation vers Firebase...');
      
      // Obtenir toutes les données locales
      final localData = await _localStorage.getAllUserData();
      
      // Initialiser les données utilisateur dans Firebase si nécessaire
      await _userDataService.initializeUserData();
      
      // Synchroniser les points
      await _userDataService.savePoints(localData['points'] as int);
      print('SyncService: Points synchronisés: ${localData['points']}');
      
      // Synchroniser les trophées
      final userRef = _firestore.collection('users').doc(_userId);
      await userRef.update({
        'trophies': localData['trophies'] as int,
        'completedLevels': localData['completedLevels'] as int,
        'displayName': localData['displayName'] as String,
        'photoURL': localData['photoURL'] as String?,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('SyncService: Trophées et progression synchronisés');
      
      // Synchroniser les statistiques
      final stats = localData['stats'] as Map<String, dynamic>;
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('stats')
          .doc('global')
          .set(stats, SetOptions(merge: true));
      print('SyncService: Statistiques synchronisées');
      
      // Synchroniser la progression des niveaux via GameService
      await _gameService.syncAllLevelProgressToFirebase();
      print('SyncService: Progression des niveaux synchronisée');
      
      // Marquer comme synchronisé
      await _localStorage.saveLastSyncDate(DateTime.now());
      
      print('SyncService: Synchronisation terminée avec succès');
      return true;
    } catch (e) {
      print('SyncService: Erreur lors de la synchronisation: $e');
      return false;
    }
  }

  /// Synchroniser la progression des niveaux depuis GameService
  Future<void> _syncLevelProgressFromGameService() async {
    if (!isUserLoggedIn) return;

    try {
      // Initialiser GameService pour obtenir tous les niveaux
      await _gameService.initialize();
      final levels = await _gameService.getLevels();
      
      // Pour chaque niveau, synchroniser la progression
      for (var level in levels) {
        final bestTime = await _localStorage.getBestTime(level.id);
        final attempts = await _localStorage.getAttempts(level.id);
        final unlockedHints = await _localStorage.getUnlockedHints(level.id);
        
        if (bestTime != null) {
          await _userDataService.saveLevelProgress(
            level.id,
            isCompleted: true,
            bestTime: bestTime,
            attempts: attempts,
          );
        }
        
        if (unlockedHints.isNotEmpty) {
          await _userDataService.saveUnlockedHints(level.id, unlockedHints);
        }
      }
    } catch (e) {
      print('SyncService: Erreur lors de la synchronisation de la progression: $e');
    }
  }

  /// Synchroniser la progression d'un niveau spécifique
  /// Cette méthode est appelée par GameService qui connaît tous les niveaux
  Future<void> syncLevelProgress(int levelId, {
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
  /// Cette méthode sera appelée par GameService qui connaît tous les niveaux
  Future<void> syncUnlockedHints(int levelId, List<int> hints) async {
    if (!isUserLoggedIn) return;

    try {
      await _userDataService.saveUnlockedHints(levelId, hints);
    } catch (e) {
      print('SyncService: Erreur lors de la synchronisation des indices: $e');
    }
  }

  /// Charger les données depuis Firebase vers le stockage local (première connexion)
  Future<bool> loadFromFirebase() async {
    if (!isUserLoggedIn) {
      print('SyncService: Aucun utilisateur connecté, impossible de charger depuis Firebase');
      return false;
    }

    try {
      print('SyncService: Chargement des données depuis Firebase...');
      
      // NOTE: Ne pas appeler initializeUserData() ici car cela fait des appels Firebase supplémentaires
      // Les données utilisateur sont déjà créées lors de la connexion (dans FirebaseService)
      // On charge simplement les données existantes
      
      // Charger les données utilisateur
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        
        // Charger les statistiques
        final statsDoc = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('stats')
            .doc('global')
            .get();
        
        final stats = statsDoc.exists && statsDoc.data() != null
            ? statsDoc.data()!
            : {
                'totalAttempts': 0,
                'totalPlayTime': 0,
                'bestTimes': {},
              };
        
        // Charger les données dans le stockage local
        final firebaseData = {
          'points': data['points'] ?? 500,
          'trophies': data['trophies'] ?? 0,
          'completedLevels': data['completedLevels'] ?? 0,
          'displayName': data['displayName'] ?? _auth.currentUser?.displayName ?? 'Joueur',
          'photoURL': data['photoURL'] ?? _auth.currentUser?.photoURL,
          'email': data['email'] ?? _auth.currentUser?.email ?? 'Utilisateur anonyme',
          'stats': stats,
        };
        
        await _localStorage.loadFromFirebase(firebaseData);
        
        print('SyncService: Données chargées depuis Firebase avec succès');
        return true;
      } else {
        // Aucune donnée dans Firebase, initialiser avec les valeurs par défaut
        await _localStorage.initializeUserData();
        print('SyncService: Aucune donnée dans Firebase, initialisation avec les valeurs par défaut');
        return true;
      }
    } catch (e) {
      print('SyncService: Erreur lors du chargement depuis Firebase: $e');
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
        await syncToFirebase();
      }
    } catch (e) {
      print('SyncService: Erreur lors de la vérification de synchronisation: $e');
    }
  }

  /// Forcer la synchronisation maintenant
  Future<bool> forceSyncNow() async {
    return await syncToFirebase(force: true);
  }
}

