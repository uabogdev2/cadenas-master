import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';
import '../models/level_model.dart';
import 'level_service_nodejs.dart';
import 'user_data_service_nodejs.dart';
import 'local_storage_service.dart';
import 'sync_service_nodejs.dart';
import 'package:flutter/services.dart';
import 'ad_service.dart';
import 'user_profile_service.dart';

class GameService {
  static const String _pointsKey = 'points';
  static const String _unlockedLevelsKey = 'unlockedLevels';
  static const String _unlockedHintsKey = 'unlockedHints_';
  static const String _bestTimesKey = 'bestTimes_';
  static const String _attemptsKey = 'attempts_';
  static const String _lastSyncKey = 'lastSync';
  static const String _levelsKey = 'levels';
  static const String _completedLevelsKey = 'completedLevels';
  
  // Intervalle de synchronisation avec Firestore (en millisecondes)
  // Changé à 1 fois par semaine (7 jours = 604800000 millisecondes)
  static const int _syncInterval = 604800000; // 7 jours (1 semaine)
  
  // Singleton pattern
  static final GameService _instance = GameService._internal();
  factory GameService() => _instance;
  
  // Services
  final LevelServiceNodeJs _levelService = LevelServiceNodeJs();
  final UserDataServiceNodeJs _userDataService = UserDataServiceNodeJs();
  final LocalStorageService _localStorage = LocalStorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserProfileService _profileService = UserProfileService();
  
  // Ne pas créer SyncServiceNodeJs dans le constructeur pour éviter la dépendance circulaire
  // Utiliser un getter lazy à la place
  SyncServiceNodeJs get _syncService => SyncServiceNodeJs();
  
  // Cache pour les données
  int _points = 0;
  List<Level> _levels = [];
  bool _isInitialized = false;
  String _userPrefix = '';
  int _completedLevelsCount = 0;
  
  // Timer pour la synchronisation automatique (1 fois par semaine)
  Timer? _syncTimer;
  
  // Constructeur interne
  GameService._internal() {
    // Ne pas démarrer le timer dans le constructeur pour éviter la dépendance circulaire
    // Le timer sera démarré lors de l'initialisation si nécessaire
  }
  
  // Démarrer le timer de synchronisation automatique (1 fois par semaine)
  void _startSyncTimer() {
    // Annuler le timer existant s'il y en a un
    _syncTimer?.cancel();
    
    // Créer un nouveau timer qui vérifie si une synchronisation est nécessaire
    // On vérifie quotidiennement si une semaine s'est écoulée depuis la dernière sync
    // Utiliser le getter lazy pour éviter la dépendance circulaire
    _syncTimer = Timer.periodic(const Duration(days: 1), (_) {
      _syncService.checkAndSyncIfNeeded();
    });
  }
  
  // Obtenir le préfixe utilisateur pour les sauvegardes
  String _getUserPrefix() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return 'user_${user.uid}_';
    }
    return 'anonymous_';
  }
  
  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Définir le préfixe utilisateur
      _userPrefix = _getUserPrefix();
      
      // Initialiser les données utilisateur dans le stockage local
      await _localStorage.initializeUserData();
      
      // Charger les données depuis le stockage local
      // Cette méthode charge TOUJOURS depuis le JSON d'abord
      await _loadFromLocalStorage();
      
      // Si les niveaux sont toujours vides après le chargement, essayer Firebase en dernier recours
      if (_levels.isEmpty) {
        print('Aucun niveau trouvé, tentative de chargement depuis Firebase');
        await _loadLevelsFromFirebase();
      }
      
      // Si toujours vide, utiliser les niveaux par défaut
      if (_levels.isEmpty) {
        print('Utilisation des niveaux par défaut en dernier recours');
        _levels = Level.getSampleLevels();
        if (_levels.isNotEmpty) {
          _levels[0] = _levels[0].copyWith(isLocked: false);
        }
      }
      
      // IMPORTANT: Ne PAS charger depuis Firebase au démarrage pour éviter les requêtes inutiles
      // Le chargement depuis Firebase se fera uniquement :
      // 1. Après la première connexion (dans l'écran d'authentification)
      // 2. Via la synchronisation manuelle (bouton dans le profil)
      // 3. Via la synchronisation périodique (1 fois par semaine, en arrière-plan)
      
      // Démarrer le timer de synchronisation après l'initialisation
      // (pour éviter la dépendance circulaire)
      // Le timer vérifiera périodiquement si une synchronisation est nécessaire
      _startSyncTimer();
      
      // NE PAS appeler checkAndSyncIfNeeded() au démarrage pour éviter les requêtes Firebase
      // La synchronisation se fera uniquement après la première connexion ou sur demande
      
      _isInitialized = true;
    } catch (e) {
      print('Erreur lors de l\'initialisation du GameService: $e');
      // Initialisation de secours en cas d'erreur
      _points = 0;
      _levels = Level.getSampleLevels();
      // Débloquer le premier niveau
      if (_levels.isNotEmpty) {
        _levels[0] = _levels[0].copyWith(isLocked: false);
      }
      _isInitialized = true;
    }
  }
  
  // Charger les données depuis le stockage local
  Future<void> _loadFromLocalStorage() async {
    try {
      final profile = await _profileService.ensureProfile();
      _points = profile?.points ?? _points;

      _completedLevelsCount = await _localStorage.getCompletedLevels();

      List<Level> loadedLevels = [];

      // 1) Tenter de charger les niveaux déjà mis en cache localement
      try {
        loadedLevels = await _loadLevelsFromCache();
        if (loadedLevels.isNotEmpty) {
          print('Niveaux chargés depuis le cache local: ${loadedLevels.length}');
        }
      } catch (e) {
        print('Impossible de charger les niveaux depuis le cache: $e');
      }

      // 2) Tenter de récupérer la dernière version depuis le serveur (source de vérité)
      var serverLoaded = false;
      try {
        final serverLevels = await _loadLevelsFromServer();
        if (serverLevels.isNotEmpty) {
          loadedLevels = serverLevels;
          serverLoaded = true;
          print('SUCCÈS: ${loadedLevels.length} niveaux chargés depuis le serveur');
        }
      } catch (e) {
        print('Erreur lors du chargement depuis le serveur: $e');
      }

      // 3) Fallback vers le fichier JSON intégré si aucune donnée disponible
      if (loadedLevels.isEmpty) {
        print('Tentative de chargement depuis le JSON local...');
        loadedLevels = await _loadLevelsFromJsonFile();
        if (loadedLevels.isEmpty) {
          print('ATTENTION: Aucun niveau trouvé dans le JSON local, utilisation des niveaux par défaut');
          loadedLevels = Level.getSampleLevels();
        }
      }

      _levels = loadedLevels;

      // Appliquer l'état de déverrouillage basé sur la progression locale
      final levelProgress = await _localStorage.getUnlockedLevels();
      _levels = _levels.map((level) {
        final unlocked = level.id <= levelProgress;
        return level.copyWith(isLocked: !unlocked);
      }).toList();

      // Sauvegarder les niveaux mis à jour (avec l'état de déverrouillage) dans le stockage local
      if (_levels.isNotEmpty) {
        await _saveLevelsToLocalStorage();
        if (!serverLoaded) {
          print('Niveaux sauvegardés depuis la source locale/fallback: ${_levels.length}');
        } else {
          print('Niveaux mis à jour et sauvegardés depuis le serveur');
        }
      }
    } catch (e) {
      print('Erreur lors du chargement depuis le stockage local: $e');
      _points = 0;
      _completedLevelsCount = 0;
      _levels = Level.getSampleLevels();
      if (_levels.isNotEmpty) {
        _levels[0] = _levels[0].copyWith(isLocked: false);
      }
    }
  }
  
  // Charger les niveaux depuis le serveur
  Future<List<Level>> _loadLevelsFromServer() async {
    try {
      print('Tentative de chargement des niveaux depuis le serveur...');
      final levels = await _levelService.loadLevelsFromServer();
      print('${levels.length} niveaux chargés depuis le serveur');
      
      // Sauvegarder les niveaux dans le stockage local
      final prefs = await SharedPreferences.getInstance();
      final levelsJson = jsonEncode(levels.map((e) => e.toJson()).toList());
      await prefs.setString('${_userPrefix}${_levelsKey}', levelsJson);
      print('Niveaux sauvegardés dans SharedPreferences: ${levels.length} niveaux');
      
      return levels;
    } catch (e, stackTrace) {
      print('ERREUR lors du chargement des niveaux depuis le serveur: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Re-lancer l'erreur pour que le code appelant puisse gérer le fallback
    }
  }

  // Charger les niveaux précédemment sauvegardés dans SharedPreferences
  Future<List<Level>> _loadLevelsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('${_userPrefix}${_levelsKey}');
      if (cachedJson == null || cachedJson.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(cachedJson) as List;
      return decoded.map((e) => Level.fromJson(e)).toList();
    } catch (e, stackTrace) {
      print('Erreur lors du chargement des niveaux depuis le cache: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Vérifier et charger les nouvelles questions depuis le serveur
  /// Compare les niveaux locaux avec ceux du serveur et met à jour si nécessaire
  Future<bool> checkAndUpdateLevelsFromServer() async {
    try {
      print('Vérification des nouvelles questions depuis le serveur...');
      
      // Charger les niveaux depuis le serveur
      final serverLevels = await _levelService.getAllLevels();
      
      // Charger les niveaux locaux
      final prefs = await SharedPreferences.getInstance();
      final localLevelsJson = prefs.getString('${_userPrefix}${_levelsKey}');
      
      bool hasUpdates = false;
      
      if (localLevelsJson == null) {
        // Pas de niveaux locaux, charger depuis le serveur
        print('Aucun niveau local trouvé, chargement depuis le serveur');
        _levels = serverLevels;
        hasUpdates = true;
      } else {
        // Comparer les niveaux
        final localLevels = (jsonDecode(localLevelsJson) as List)
            .map((e) => Level.fromJson(e))
            .toList();
        
        // Vérifier s'il y a de nouvelles questions (plus de niveaux sur le serveur)
        if (serverLevels.length > localLevels.length) {
          print('Nouvelles questions détectées: ${serverLevels.length} sur le serveur vs ${localLevels.length} localement');
          _levels = serverLevels;
          hasUpdates = true;
        } else {
          // Vérifier si des questions ont été modifiées (comparaison par ID et instruction)
          for (var serverLevel in serverLevels) {
            final localLevel = localLevels.firstWhere(
              (l) => l.id == serverLevel.id,
              orElse: () => serverLevel,
            );
            
            // Si l'instruction ou le code a changé, mettre à jour
            if (localLevel.instruction != serverLevel.instruction ||
                localLevel.code != serverLevel.code ||
                localLevel.pointsReward != serverLevel.pointsReward) {
              print('Question ${serverLevel.id} modifiée sur le serveur');
              hasUpdates = true;
              break;
            }
          }
          
          if (hasUpdates) {
            _levels = serverLevels;
          }
        }
      }
      
      if (hasUpdates) {
        // Sauvegarder les niveaux mis à jour
        await _saveLevelsToLocalStorage();
        print('Niveaux mis à jour depuis le serveur: ${_levels.length} niveaux');
        return true;
      } else {
        print('Aucune mise à jour nécessaire');
        return false;
      }
    } catch (e) {
      print('Erreur lors de la vérification des nouvelles questions: $e');
      return false;
    }
  }

  // Charger les niveaux depuis le fichier JSON intégré (fallback)
  Future<List<Level>> _loadLevelsFromJsonFile() async {
    try {
      print('Tentative de chargement du fichier JSON: assets/data/levels.json');
      // Utiliser le fichier JSON intégré à l'application
      final jsonString = await rootBundle.loadString('assets/data/levels.json');
      print('Fichier JSON chargé avec succès, longueur: ${jsonString.length} caractères');
      
      final levelsList = jsonDecode(jsonString) as List;
      print('JSON décodé avec succès, nombre d\'éléments: ${levelsList.length}');
      
      final levels = levelsList.map((e) => Level.fromJson(e)).toList();
      print('${levels.length} niveaux créés depuis le JSON');
      
      // Sauvegarder les niveaux dans le stockage local
      await _saveLevelsToLocalStorage();
      print('Niveaux sauvegardés dans SharedPreferences');
      
      return levels;
    } catch (e, stackTrace) {
      print('ERREUR lors du chargement des niveaux depuis le fichier JSON: $e');
      print('Stack trace: $stackTrace');
      print('Utilisation des niveaux par défaut (2 niveaux) en cas d\'erreur');
      return Level.getSampleLevels();
    }
  }
  
  // Charger les niveaux depuis Firebase
  Future<void> _loadLevelsFromFirebase() async {
    try {
      // Vérifier d'abord si nous avons déjà des niveaux locaux
      if (_levels.isNotEmpty) {
        return; // Utiliser les niveaux locaux si disponibles
      }
      
      _levels = await _levelService.getAllLevels();
      
      // Sauvegarder les niveaux dans le stockage local
      await _saveLevelsToLocalStorage();
      
      // Débloquer le premier niveau
      if (_levels.isNotEmpty) {
        _levels[0] = _levels[0].copyWith(isLocked: false);
      }
    } catch (e) {
      print('Erreur lors du chargement des niveaux depuis Firebase: $e');
      // En cas d'erreur, utiliser les niveaux par défaut
      _levels = await _loadLevelsFromJsonFile();
      if (_levels.isEmpty) {
        _levels = Level.getSampleLevels();
      }
      if (_levels.isNotEmpty) {
        _levels[0] = _levels[0].copyWith(isLocked: false);
      }
    }
  }
  
  // Sauvegarder les niveaux dans le stockage local
  Future<void> _saveLevelsToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final levelsJson = jsonEncode(_levels.map((e) => e.toJson()).toList());
      await prefs.setString('${_userPrefix}${_levelsKey}', levelsJson);
    } catch (e) {
      print('Erreur lors de la sauvegarde des niveaux dans le stockage local: $e');
    }
  }
  
  /// Synchroniser la progression de tous les niveaux vers Firebase
  /// Cette méthode est appelée par SyncService lors de la synchronisation
  Future<void> syncAllLevelProgressToServer() async {
    if (_auth.currentUser == null) return;
    
    try {
      print('GameService: Synchronisation de la progression des niveaux vers le serveur Node.js...');
      
      // Synchroniser la progression de tous les niveaux
      for (var level in _levels) {
        final bestTime = await _localStorage.getBestTime(level.id);
        final attempts = await _localStorage.getAttempts(level.id);
        final unlockedHints = await _localStorage.getUnlockedHints(level.id);
        
        if (bestTime != null) {
          await _syncService.syncLevelProgress(
            level.id,
            isCompleted: true,
            bestTime: bestTime,
            attempts: attempts,
          );
        }
        
        if (unlockedHints.isNotEmpty) {
          await _syncService.syncUnlockedHints(level.id, unlockedHints);
        }
      }
      
      print('GameService: Progression des niveaux synchronisée avec succès');
    } catch (e) {
      print('GameService: Erreur lors de la synchronisation de la progression: $e');
    }
  }
  
  // Alias pour compatibilité avec l'ancien code
  @Deprecated('Utiliser syncAllLevelProgressToServer() à la place')
  Future<void> syncAllLevelProgressToFirebase() async {
    await syncAllLevelProgressToServer();
  }
  
  // Arrêter le timer de synchronisation
  void stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  // Forcer une synchronisation immédiate
  // Note: Cette méthode délègue à SyncService qui synchronise toutes les données
  Future<void> forceSyncNow() async {
    await _syncService.forceSyncNow();
  }
  
  // Dispose pour libérer les ressources
  void dispose() {
    stopSyncTimer();
  }
  
  // Get current points
  Future<int> getPoints() async {
    await initialize();
    final profile = await _profileService.ensureProfile();
    _points = profile?.points ?? _points;
    return _points;
  }
  
  // Add points
  Future<void> addPoints(int points) async {
    await initialize();
    if (points == 0) return;
    final success = await _profileService.adjustPoints(points);
    if (success) {
      _points = await getPoints();
      print('Points ajoutés sur le serveur: $_points');
    } else {
      print('Échec de l\'ajout de points sur le serveur');
    }
  }
  
  // Spend points
  Future<bool> spendPoints(int points) async {
    await initialize();
    if (points <= 0) return true;
    final success = await _profileService.adjustPoints(-points);
    if (success) {
      _points = await getPoints();
      print('Points dépensés sur le serveur: $_points');
      return true;
    }
    return false;
  }
  
  // Get all levels
  Future<List<Level>> getLevels() async {
    await initialize();
    return _levels;
  }
  
  // Get level by id
  Future<Level?> getLevelById(int id) async {
    await initialize();
    try {
      return _levels.firstWhere((level) => level.id == id);
    } catch (e) {
      // Si le niveau n'est pas trouvé localement, essayer de le charger depuis Firebase
      return await _levelService.getLevelById(id);
    }
  }
  
  // Unlock next level
  Future<void> unlockNextLevel(int currentLevelId) async {
    await initialize();
    final nextLevelId = currentLevelId + 1;
    
    // Find the index of the next level
    final nextLevelIndex = _levels.indexWhere((level) => level.id == nextLevelId);
    if (nextLevelIndex != -1) {
      _levels[nextLevelIndex] = _levels[nextLevelIndex].copyWith(isLocked: false);
      
      // Sauvegarder uniquement dans le stockage local (hors ligne)
      await _localStorage.saveUnlockedLevels(nextLevelId);
      print('Niveau $nextLevelId déverrouillé et sauvegardé localement');
    }
  }
  
  // Reset game progress
  Future<void> resetProgress() async {
    try {
      // Réinitialiser les données locales
      final profile = await _profileService.ensureProfile();
      final currentPoints = profile?.points ?? 0;
      await _profileService.adjustPoints(500 - currentPoints);
      await _localStorage.saveUnlockedLevels(1);
      await _localStorage.saveCompletedLevels(0);
      _points = 500;
      _completedLevelsCount = 0;
      
      // Réinitialiser les niveaux
      for (var i = 0; i < _levels.length; i++) {
        if (i == 0) {
          _levels[i] = _levels[i].copyWith(isLocked: false);
        } else {
          _levels[i] = _levels[i].copyWith(isLocked: true);
        }
      }
      
      // Sauvegarder les niveaux
      await _saveLevelsToLocalStorage();
      
      print('Progression réinitialisée');
    } catch (e) {
      print('Erreur lors de la réinitialisation de la progression: $e');
    }
    
    _isInitialized = false;
    await initialize();
  }
  
  // Obtenir tous les niveaux
  Future<List<Level>> getAllLevels() async {
    try {
      await initialize();
      print('getAllLevels() retourne ${_levels.length} niveaux');
      return _levels;
    } catch (e) {
      print('Erreur dans getAllLevels: $e');
      // En cas d'erreur, retourner les niveaux par défaut
      return Level.getSampleLevels();
    }
  }
  
  // Forcer le rechargement des niveaux depuis le JSON (utile pour déboguer)
  Future<void> forceReloadLevelsFromJson() async {
    try {
      print('=== FORCE RELOAD DES NIVEAUX DEPUIS LE JSON ===');
      // Supprimer le cache des niveaux dans SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_userPrefix}${_levelsKey}');
      print('Cache des niveaux supprimé de SharedPreferences');
      
      // Réinitialiser le flag d'initialisation pour forcer le rechargement
      _isInitialized = false;
      _levels = [];
      
      // Recharger depuis le JSON
      _levels = await _loadLevelsFromJsonFile();
      print('Niveaux rechargés: ${_levels.length}');
      
      // Appliquer l'état de déverrouillage
      final levelProgress = prefs.getInt('${_userPrefix}${_unlockedLevelsKey}') ?? 1;
      for (var i = 0; i < _levels.length; i++) {
        if (_levels[i].id <= levelProgress) {
          _levels[i] = _levels[i].copyWith(isLocked: false);
        } else {
          _levels[i] = _levels[i].copyWith(isLocked: true);
        }
      }
      
      // Sauvegarder les niveaux mis à jour
      await _saveLevelsToLocalStorage();
      print('=== FIN DU FORCE RELOAD ===');
    } catch (e) {
      print('Erreur lors du force reload: $e');
      rethrow;
    }
  }
  
  // Obtenir les indices débloqués pour un niveau
  Future<List<int>> getUnlockedHints(int levelId) async {
    await initialize();
    return await _localStorage.getUnlockedHints(levelId);
  }
  
  // Débloquer un indice
  Future<bool> unlockHint(int levelId, int hintIndex, int cost) async {
    try {
      await initialize();
      
      // Vérifier si l'indice est déjà débloqué
      final unlockedHints = await getUnlockedHints(levelId);
      if (unlockedHints.contains(hintIndex)) {
        return true; // L'indice est déjà débloqué, pas besoin de payer
      }
      
      final success = await spendPoints(cost);
      if (!success) {
        return false;
      }

      unlockedHints.add(hintIndex);
      await _localStorage.saveUnlockedHints(levelId, unlockedHints);
      print('Indice débloqué via serveur: niveau $levelId, indice $hintIndex');
      return true;
    } catch (e) {
      print('Erreur lors du déblocage d\'un indice: $e');
      return false;
    }
  }

  // Débloquer un indice via une publicité (sans coût en points)
  Future<bool> unlockHintWithAd(int levelId, int hintIndex) async {
    try {
      await initialize();

      // Vérifier si l'indice est déjà débloqué
      final unlockedHints = await getUnlockedHints(levelId);
      if (unlockedHints.contains(hintIndex)) {
        print('Indice $hintIndex déjà débloqué pour le niveau $levelId');
        return true;
      }

      final updatedHints = List<int>.from(unlockedHints)..add(hintIndex);

      // Sauvegarder uniquement dans le stockage local (hors ligne)
      await _localStorage.saveUnlockedHints(levelId, updatedHints);
      print('Indice $hintIndex débloqué via pub et sauvegardé localement pour le niveau $levelId');

      return true;
    } catch (e) {
      print('Erreur lors du déblocage d\'un indice via pub: $e');
      return false;
    }
  }
  
  // Enregistrer le meilleur temps pour un niveau
  Future<void> saveBestTime(int levelId, int timeInSeconds) async {
    try {
      await initialize();
      
      // Obtenir le meilleur temps actuel
      final currentBestTime = await _localStorage.getBestTime(levelId);
      
      // Si aucun temps précédent ou si le nouveau temps est meilleur
      if (currentBestTime == null || timeInSeconds < currentBestTime) {
        await _localStorage.saveBestTime(levelId, timeInSeconds);
        
        // Incrémenter le compteur de niveaux complétés si c'est la première fois
        if (currentBestTime == null) {
          _completedLevelsCount++;
          await _localStorage.saveCompletedLevels(_completedLevelsCount);
          
          // Le niveau est complété pour la première fois, mettre à jour le compteur de l'AdService
          final adService = AdService();
          await adService.shouldShowInterstitialAd();
        }
        
        print('Meilleur temps sauvegardé localement: niveau $levelId, temps $timeInSeconds');
      }
    } catch (e) {
      print('Erreur lors de l\'enregistrement du meilleur temps: $e');
    }
  }
  
  // Obtenir le meilleur temps pour un niveau
  Future<int?> getBestTime(int levelId) async {
    await initialize();
    return await _localStorage.getBestTime(levelId);
  }
  
  // Incrémenter le nombre de tentatives pour un niveau
  Future<void> incrementAttempts(int levelId) async {
    await initialize();
    await _localStorage.incrementAttempts(levelId);
    print('Tentatives incrémentées pour le niveau $levelId');
  }
  
  // Obtenir le nombre de tentatives pour un niveau
  Future<int> getAttempts(int levelId) async {
    await initialize();
    return await _localStorage.getAttempts(levelId);
  }
  
  // Obtenir le nombre de niveaux complétés
  Future<int> getCompletedLevelsCount() async {
    await initialize();
    _completedLevelsCount = await _localStorage.getCompletedLevels();
    return _completedLevelsCount;
  }
  
  // Réinitialiser toutes les données du jeu
  Future<void> resetAllData() async {
    await initialize();
    
    try {
      // Réinitialiser toutes les données locales
      await _localStorage.clearAllData();
      
      // Réinitialiser les valeurs par défaut
      await _localStorage.initializeUserData();
      await _localStorage.saveUnlockedLevels(1);
      
      // Réinitialiser le compteur de publicités
      final adService = AdService();
      adService.resetLevelCounter();
      
      // Recharger les données
      await _loadFromLocalStorage();
      
      print('Toutes les données ont été réinitialisées');
    } catch (e) {
      print('Erreur lors de la réinitialisation des données: $e');
    }
    
    _isInitialized = false;
  }
  
  // Effacer les données lors de la déconnexion
  Future<void> clearUserData() async {
    _isInitialized = false;
    _points = 0;
    _levels = [];
    _completedLevelsCount = 0;
  }
  
  // Réinitialiser les indices débloqués pour un niveau
  Future<void> resetUnlockedHints(int levelId) async {
    try {
      await initialize();
      await _localStorage.saveUnlockedHints(levelId, []);
      print('Indices débloqués réinitialisés pour le niveau $levelId');
    } catch (e) {
      print('Erreur lors de la réinitialisation des indices débloqués: $e');
    }
  }
  
  // Réinitialiser tous les niveaux aux valeurs par défaut
  Future<void> resetAllLevels() async {
    try {
      // Charger les niveaux par défaut
      _levels = Level.getSampleLevels();
      
      // Sauvegarder les niveaux dans le stockage local
      await _saveLevelsToLocalStorage();
      
      // Si l'utilisateur est connecté, synchroniser avec Firestore
      if (_auth.currentUser != null) {
        await _levelService.resetToDefaultLevels();
      }
      
      _isInitialized = false;
      await initialize();
    } catch (e) {
      print('Erreur lors de la réinitialisation des niveaux: $e');
    }
  }
} 