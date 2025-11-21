import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

/// Service de stockage local pour gérer toutes les données utilisateur hors ligne
/// Ce service stocke toutes les données localement et synchronise avec Firebase seulement sur demande
class LocalStorageService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Singleton pattern
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  // Préfixes pour les clés
  String get _userPrefix {
    final user = _auth.currentUser;
    if (user != null) {
      return 'user_${user.uid}_';
    }
    return 'anonymous_';
  }

  // Clés de stockage
  static const String _pointsKey = 'points';
  static const String _trophiesKey = 'trophies';
  static const String _completedLevelsKey = 'completedLevels';
  static const String _unlockedLevelsKey = 'unlockedLevels';
  static const String _displayNameKey = 'displayName';
  static const String _photoURLKey = 'photoURL';
  static const String _emailKey = 'email';
  static const String _lastSyncKey = 'lastSync';
  static const String _hasPendingChangesKey = 'hasPendingChanges';
  static const String _bestTimesKey = 'bestTimes_';
  static const String _attemptsKey = 'attempts_';
  static const String _unlockedHintsKey = 'unlockedHints_';
  static const String _statsKey = 'stats';

  /// Obtenir SharedPreferences
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ==================== POINTS ====================

  /// Obtenir les points localement
  Future<int> getPoints() async {
    final prefs = await _prefs;
    return prefs.getInt('$_userPrefix$_pointsKey') ?? 500;
  }

  /// Sauvegarder les points localement
  Future<void> savePoints(int points) async {
    final prefs = await _prefs;
    await prefs.setInt('$_userPrefix$_pointsKey', points);
    await _markPendingChanges();
  }

  // ==================== TROPHÉES ====================

  /// Obtenir les trophées localement
  Future<int> getTrophies() async {
    final prefs = await _prefs;
    return prefs.getInt('$_userPrefix$_trophiesKey') ?? 0;
  }

  /// Sauvegarder les trophées localement
  Future<void> saveTrophies(int trophies) async {
    final prefs = await _prefs;
    await prefs.setInt('$_userPrefix$_trophiesKey', trophies);
    await _markPendingChanges();
  }

  // ==================== PROGRESSION ====================

  /// Obtenir le nombre de niveaux complétés
  Future<int> getCompletedLevels() async {
    final prefs = await _prefs;
    return prefs.getInt('$_userPrefix$_completedLevelsKey') ?? 0;
  }

  /// Sauvegarder le nombre de niveaux complétés
  Future<void> saveCompletedLevels(int count) async {
    final prefs = await _prefs;
    await prefs.setInt('$_userPrefix$_completedLevelsKey', count);
    await _markPendingChanges();
  }

  /// Obtenir le dernier niveau débloqué
  Future<int> getUnlockedLevels() async {
    final prefs = await _prefs;
    return prefs.getInt('$_userPrefix$_unlockedLevelsKey') ?? 1;
  }

  /// Sauvegarder le dernier niveau débloqué
  Future<void> saveUnlockedLevels(int levelId) async {
    final prefs = await _prefs;
    await prefs.setInt('$_userPrefix$_unlockedLevelsKey', levelId);
    await _markPendingChanges();
  }

  // ==================== PROFIL ====================

  /// Obtenir le nom d'affichage local
  Future<String> getDisplayName() async {
    final prefs = await _prefs;
    return prefs.getString('$_userPrefix$_displayNameKey') ?? 
           _auth.currentUser?.displayName ?? 'Joueur';
  }

  /// Sauvegarder le nom d'affichage local
  Future<void> saveDisplayName(String displayName) async {
    final prefs = await _prefs;
    await prefs.setString('$_userPrefix$_displayNameKey', displayName);
    await _markPendingChanges();
  }

  /// Obtenir la photo URL locale
  Future<String?> getPhotoURL() async {
    final prefs = await _prefs;
    return prefs.getString('$_userPrefix$_photoURLKey') ?? 
           _auth.currentUser?.photoURL;
  }

  /// Sauvegarder la photo URL locale
  Future<void> savePhotoURL(String? photoURL) async {
    final prefs = await _prefs;
    if (photoURL != null) {
      await prefs.setString('$_userPrefix$_photoURLKey', photoURL);
    } else {
      await prefs.remove('$_userPrefix$_photoURLKey');
    }
    await _markPendingChanges();
  }

  /// Obtenir l'email local
  Future<String> getEmail() async {
    final prefs = await _prefs;
    return prefs.getString('$_userPrefix$_emailKey') ?? 
           _auth.currentUser?.email ?? 'Utilisateur anonyme';
  }

  /// Sauvegarder l'email local
  Future<void> saveEmail(String email) async {
    final prefs = await _prefs;
    await prefs.setString('$_userPrefix$_emailKey', email);
    await _markPendingChanges();
  }

  // ==================== STATISTIQUES ====================

  /// Obtenir le meilleur temps pour un niveau
  Future<int?> getBestTime(int levelId) async {
    final prefs = await _prefs;
    return prefs.getInt('$_userPrefix$_bestTimesKey$levelId');
  }

  /// Sauvegarder le meilleur temps pour un niveau
  Future<void> saveBestTime(int levelId, int timeInSeconds) async {
    final prefs = await _prefs;
    final currentBestTime = prefs.getInt('$_userPrefix$_bestTimesKey$levelId');
    
    // Si aucun temps précédent ou si le nouveau temps est meilleur
    if (currentBestTime == null || timeInSeconds < currentBestTime) {
      await prefs.setInt('$_userPrefix$_bestTimesKey$levelId', timeInSeconds);
      await _markPendingChanges();
    }
  }

  /// Obtenir le nombre de tentatives pour un niveau
  Future<int> getAttempts(int levelId) async {
    final prefs = await _prefs;
    return prefs.getInt('$_userPrefix$_attemptsKey$levelId') ?? 0;
  }

  /// Incrémenter le nombre de tentatives pour un niveau
  Future<void> incrementAttempts(int levelId) async {
    final prefs = await _prefs;
    final attempts = prefs.getInt('$_userPrefix$_attemptsKey$levelId') ?? 0;
    await prefs.setInt('$_userPrefix$_attemptsKey$levelId', attempts + 1);
    await _markPendingChanges();
  }

  /// Obtenir les indices débloqués pour un niveau
  Future<List<int>> getUnlockedHints(int levelId) async {
    final prefs = await _prefs;
    final hintsString = prefs.getStringList('$_userPrefix$_unlockedHintsKey$levelId') ?? [];
    return hintsString.map((e) => int.parse(e)).toList();
  }

  /// Sauvegarder les indices débloqués pour un niveau
  Future<void> saveUnlockedHints(int levelId, List<int> hints) async {
    final prefs = await _prefs;
    final hintsString = hints.map((e) => e.toString()).toList();
    await prefs.setStringList('$_userPrefix$_unlockedHintsKey$levelId', hintsString);
    await _markPendingChanges();
  }

  /// Obtenir les statistiques globales
  Future<Map<String, dynamic>> getStats() async {
    final prefs = await _prefs;
    final statsJson = prefs.getString('$_userPrefix$_statsKey');
    if (statsJson != null) {
      try {
        return jsonDecode(statsJson) as Map<String, dynamic>;
      } catch (e) {
        print('Erreur lors du décodage des statistiques: $e');
      }
    }
    return {
      'totalAttempts': 0,
      'totalPlayTime': 0,
      'bestTimes': {},
    };
  }

  /// Sauvegarder les statistiques globales
  Future<void> saveStats(Map<String, dynamic> stats) async {
    final prefs = await _prefs;
    final statsJson = jsonEncode(stats);
    await prefs.setString('$_userPrefix$_statsKey', statsJson);
    await _markPendingChanges();
  }

  // ==================== SYNCHRONISATION ====================

  /// Obtenir la date de dernière synchronisation
  Future<DateTime?> getLastSyncDate() async {
    final prefs = await _prefs;
    final lastSync = prefs.getInt('$_userPrefix$_lastSyncKey');
    if (lastSync != null) {
      return DateTime.fromMillisecondsSinceEpoch(lastSync);
    }
    return null;
  }

  /// Sauvegarder la date de synchronisation
  Future<void> saveLastSyncDate(DateTime date) async {
    final prefs = await _prefs;
    await prefs.setInt('$_userPrefix$_lastSyncKey', date.millisecondsSinceEpoch);
    await prefs.setBool('$_userPrefix$_hasPendingChangesKey', false);
  }

  /// Vérifier s'il y a des modifications en attente
  Future<bool> hasPendingChanges() async {
    final prefs = await _prefs;
    return prefs.getBool('$_userPrefix$_hasPendingChangesKey') ?? false;
  }

  /// Marquer qu'il y a des modifications en attente
  Future<void> _markPendingChanges() async {
    final prefs = await _prefs;
    await prefs.setBool('$_userPrefix$_hasPendingChangesKey', true);
  }

  /// Vérifier si la synchronisation est nécessaire (1 fois par semaine)
  Future<bool> shouldSync() async {
    final lastSync = await getLastSyncDate();
    if (lastSync == null) {
      return true; // Jamais synchronisé
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    // Synchroniser si plus d'une semaine s'est écoulée
    return difference.inDays >= 7;
  }

  /// Initialiser les données utilisateur depuis Firebase Auth
  Future<void> initializeUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await _prefs;
    
    // Initialiser les données de base si elles n'existent pas
    if (!prefs.containsKey('$_userPrefix$_pointsKey')) {
      await savePoints(500);
    }
    if (!prefs.containsKey('$_userPrefix$_trophiesKey')) {
      await saveTrophies(0);
    }
    if (!prefs.containsKey('$_userPrefix$_completedLevelsKey')) {
      await saveCompletedLevels(0);
    }
    if (!prefs.containsKey('$_userPrefix$_unlockedLevelsKey')) {
      await saveUnlockedLevels(1);
    }
    if (!prefs.containsKey('$_userPrefix$_displayNameKey')) {
      await saveDisplayName(user.displayName ?? 'Joueur');
    }
    if (!prefs.containsKey('$_userPrefix$_photoURLKey') && user.photoURL != null) {
      await savePhotoURL(user.photoURL);
    }
    if (!prefs.containsKey('$_userPrefix$_emailKey') && user.email != null) {
      await saveEmail(user.email!);
    }
  }

  /// Obtenir toutes les données utilisateur pour la synchronisation
  Future<Map<String, dynamic>> getAllUserData() async {
    return {
      'points': await getPoints(),
      'trophies': await getTrophies(),
      'completedLevels': await getCompletedLevels(),
      'displayName': await getDisplayName(),
      'photoURL': await getPhotoURL(),
      'email': await getEmail(),
      'stats': await getStats(),
    };
  }

  /// Charger les données depuis Firebase vers le stockage local (pour la première connexion)
  Future<void> loadFromFirebase(Map<String, dynamic> firebaseData) async {
    if (firebaseData.containsKey('points')) {
      await savePoints(firebaseData['points'] as int);
    }
    if (firebaseData.containsKey('trophies')) {
      await saveTrophies(firebaseData['trophies'] as int);
    }
    if (firebaseData.containsKey('completedLevels')) {
      await saveCompletedLevels(firebaseData['completedLevels'] as int);
    }
    if (firebaseData.containsKey('displayName')) {
      await saveDisplayName(firebaseData['displayName'] as String);
    }
    if (firebaseData.containsKey('photoURL')) {
      await savePhotoURL(firebaseData['photoURL'] as String?);
    }
    if (firebaseData.containsKey('email')) {
      await saveEmail(firebaseData['email'] as String);
    }
    if (firebaseData.containsKey('stats')) {
      await saveStats(firebaseData['stats'] as Map<String, dynamic>);
    }
    
    // Marquer comme synchronisé
    await saveLastSyncDate(DateTime.now());
  }

  /// Réinitialiser toutes les données locales
  Future<void> clearAllData() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys().where((key) => key.startsWith(_userPrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

