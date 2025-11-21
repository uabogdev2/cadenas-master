import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

/// Service pour gérer les données utilisateur via le serveur Node.js
class UserDataServiceNodeJs {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiService _apiService = ApiService();

  // Singleton pattern
  static final UserDataServiceNodeJs _instance = UserDataServiceNodeJs._internal();
  factory UserDataServiceNodeJs() => _instance;
  UserDataServiceNodeJs._internal();

  // Obtenir l'ID de l'utilisateur actuel
  String? get _userId => _auth.currentUser?.uid;

  // Vérifier si l'utilisateur est connecté
  bool get isUserLoggedIn => _userId != null;

  /// Initialiser les données utilisateur lors de la première connexion
  Future<bool> initializeUserData() async {
    if (!isUserLoggedIn) {
      print('Aucun utilisateur connecté, impossible d\'initialiser les données');
      return false;
    }

    try {
      print('Tentative d\'initialisation des données pour l\'utilisateur: $_userId');

      // Vérifier si l'utilisateur existe déjà
      final userExists = await doesUserExist();

      if (!userExists) {
        print('Création d\'un nouveau profil utilisateur pour: $_userId');
        // Créer un nouveau document utilisateur s'il n'existe pas
        final user = _auth.currentUser;
        final response = await _apiService.post('/api/users/initialize', body: {
          'displayName': user?.displayName ?? 'Joueur',
          'email': user?.email,
          'photoURL': user?.photoURL,
        });

        if (response != null && response['success'] == true) {
          print('Profil utilisateur créé avec succès');
          return true;
        } else {
          print('Erreur lors de la création du profil: ${response?['error']}');
          return false;
        }
      } else {
        print('Profil utilisateur existant trouvé pour: $_userId');
        return true;
      }
    } catch (e) {
      print('Erreur lors de l\'initialisation des données utilisateur: $e');
      return false;
    }
  }

  /// Sauvegarder les points de l'utilisateur
  Future<void> savePoints(int points) async {
    if (!isUserLoggedIn) return;

    try {
      final response = await _apiService.put('/api/users/me', body: {
        'points': points,
      });

      if (response != null && response['success'] == true) {
        print('Points sauvegardés avec succès: $points');
      } else {
        print('Erreur lors de la sauvegarde des points: ${response?['error']}');
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde des points: $e');
    }
  }

  /// Sauvegarder les points de l'utilisateur de manière sécurisée
  Future<bool> savePointsSecurely(int points) async {
    if (!isUserLoggedIn) {
      print('Aucun utilisateur connecté, impossible de sauvegarder les points');
      return false;
    }

    try {
      print('Sauvegarde de $points points pour l\'utilisateur: $_userId');
      final response = await _apiService.put('/api/users/me', body: {
        'points': points,
      });

      if (response != null && response['success'] == true) {
        print('Points sauvegardés avec succès');
        return true;
      } else {
        print('Erreur lors de la sauvegarde des points: ${response?['error']}');
        return false;
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde des points: $e');
      return false;
    }
  }

  /// Obtenir les points de l'utilisateur
  Future<int> getPoints() async {
    if (!isUserLoggedIn) return 0;

    try {
      // Initialiser les données utilisateur si nécessaire
      await initializeUserData();

      final response = await _apiService.get('/api/users/me');
      if (response != null && response['success'] == true) {
        final user = response['user'];
        return user['points'] ?? 0;
      } else {
        print('Erreur lors de la récupération des points: ${response?['error']}');
        return 0;
      }
    } catch (e) {
      print('Erreur lors de la récupération des points: $e');
      return 0;
    }
  }

  /// Sauvegarder la progression d'un niveau
  Future<void> saveLevelProgress(
    int levelId, {
    required bool isCompleted,
    int? bestTime,
    int attempts = 0,
  }) async {
    if (!isUserLoggedIn) return;

    try {
      final response = await _apiService.post('/api/users/progress/$levelId', body: {
        'isCompleted': isCompleted,
        'bestTime': bestTime,
        'attempts': attempts,
      });

      if (response != null && response['success'] == true) {
        print('Progression du niveau $levelId sauvegardée avec succès');
      } else {
        print(
            'Erreur lors de la sauvegarde de la progression: ${response?['error']}');
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde de la progression du niveau: $e');
    }
  }

  /// Obtenir la progression d'un niveau
  Future<Map<String, dynamic>> getLevelProgress(int levelId) async {
    if (!isUserLoggedIn) {
      return {
        'isCompleted': false,
        'bestTime': null,
        'attempts': 0,
      };
    }

    try {
      final response = await _apiService.get('/api/users/progress/$levelId');
      if (response != null && response['success'] == true) {
        final progress = response['progress'];
        return {
          'isCompleted': progress['isCompleted'] ?? false,
          'bestTime': progress['bestTime'],
          'attempts': progress['attempts'] ?? 0,
        };
      } else {
        return {
          'isCompleted': false,
          'bestTime': null,
          'attempts': 0,
        };
      }
    } catch (e) {
      print('Erreur lors de la récupération de la progression du niveau: $e');
      return {
        'isCompleted': false,
        'bestTime': null,
        'attempts': 0,
      };
    }
  }

  /// Sauvegarder les indices débloqués pour un niveau
  Future<void> saveUnlockedHints(int levelId, List<int> hintIndices) async {
    if (!isUserLoggedIn) return;

    try {
      final response = await _apiService.post('/api/users/hints/$levelId', body: {
        'indices': hintIndices,
      });

      if (response != null && response['success'] == true) {
        print('Indices débloqués pour le niveau $levelId sauvegardés');
      } else {
        print(
            'Erreur lors de la sauvegarde des indices débloqués: ${response?['error']}');
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde des indices débloqués: $e');
    }
  }

  /// Obtenir les indices débloqués pour un niveau
  Future<List<int>> getUnlockedHints(int levelId) async {
    if (!isUserLoggedIn) return [];

    try {
      print('Récupération des indices débloqués pour le niveau $levelId');
      final response = await _apiService.get('/api/users/hints/$levelId');
      if (response != null && response['success'] == true) {
        final indices = response['indices'];
        if (indices is List) {
          return indices.map<int>((item) {
            if (item is int) return item;
            if (item is String) return int.tryParse(item) ?? 0;
            if (item is double) return item.toInt();
            return 0;
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('Erreur lors de la récupération des indices débloqués: $e');
      return [];
    }
  }

  /// Réinitialiser les indices débloqués pour un niveau
  Future<void> resetUnlockedHints(int levelId) async {
    if (!isUserLoggedIn) return;

    try {
      // Pour réinitialiser, on envoie une liste vide
      final response = await _apiService.post('/api/users/hints/$levelId', body: {
        'indices': [],
      });

      if (response != null && response['success'] == true) {
        print('Indices débloqués pour le niveau $levelId réinitialisés');
      } else {
        print(
            'Erreur lors de la réinitialisation des indices: ${response?['error']}');
      }
    } catch (e) {
      print('Erreur lors de la réinitialisation des indices débloqués: $e');
    }
  }

  /// Obtenir le nombre de niveaux complétés
  Future<int> getCompletedLevelsCount() async {
    if (!isUserLoggedIn) return 0;

    try {
      final response = await _apiService.get('/api/users/me');
      if (response != null && response['success'] == true) {
        final user = response['user'];
        return user['completedLevels'] ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      print('Erreur lors de la récupération du nombre de niveaux complétés: $e');
      return 0;
    }
  }

  /// Sauvegarder le nombre de niveaux complétés
  Future<void> saveCompletedLevelsCount(int count) async {
    if (!isUserLoggedIn) return;

    try {
      final response = await _apiService.put('/api/users/me', body: {
        'completedLevels': count,
      });

      if (response != null && response['success'] == true) {
        print('Nombre de niveaux complétés sauvegardé: $count');
      } else {
        print(
            'Erreur lors de la sauvegarde du nombre de niveaux complétés: ${response?['error']}');
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde du nombre de niveaux complétés: $e');
    }
  }

  /// Obtenir les statistiques globales de l'utilisateur
  Future<Map<String, dynamic>> getGlobalStats() async {
    if (!isUserLoggedIn) {
      return {
        'totalAttempts': 0,
        'totalPlayTime': 0,
        'bestTimes': {},
      };
    }

    try {
      final response = await _apiService.get('/api/users/stats');
      if (response != null && response['success'] == true) {
        final stats = response['stats'];
        return {
          'totalAttempts': stats['totalAttempts'] ?? 0,
          'totalPlayTime': stats['totalPlayTime'] ?? 0,
          'bestTimes': stats['bestTimes'] ?? {},
        };
      } else {
        return {
          'totalAttempts': 0,
          'totalPlayTime': 0,
          'bestTimes': {},
        };
      }
    } catch (e) {
      print('Erreur lors de la récupération des statistiques globales: $e');
      return {
        'totalAttempts': 0,
        'totalPlayTime': 0,
        'bestTimes': {},
      };
    }
  }

  /// Réinitialiser toutes les données de l'utilisateur
  Future<void> resetAllUserData() async {
    if (!isUserLoggedIn) return;

    try {
      // Pour réinitialiser, on met à jour les points, trophées et niveaux complétés à 0
      await _apiService.put('/api/users/me', body: {
        'points': 0,
        'completedLevels': 0,
        'trophies': 0,
      });
      print('Toutes les données utilisateur ont été réinitialisées');
    } catch (e) {
      print('Erreur lors de la réinitialisation des données utilisateur: $e');
    }
  }

  /// Vérifie si l'utilisateur existe déjà dans la base de données
  Future<bool> doesUserExist() async {
    if (!isUserLoggedIn) {
      print('Aucun utilisateur connecté, impossible de vérifier l\'existence');
      return false;
    }

    try {
      print('Vérification de l\'existence de l\'utilisateur: $_userId');
      final response = await _apiService.get('/api/users/me');
      return response != null && response['success'] == true;
    } catch (e) {
      print('Erreur lors de la vérification de l\'existence de l\'utilisateur: $e');
      return false;
    }
  }

  /// Obtenir les données complètes de l'utilisateur
  Future<Map<String, dynamic>?> getUserData() async {
    if (!isUserLoggedIn) return null;

    try {
      final response = await _apiService.get('/api/users/me');
      if (response != null && response['success'] == true) {
        return response['user'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération des données utilisateur: $e');
      return null;
    }
  }

  /// Mettre à jour le profil utilisateur
  Future<void> updateUserProfile({String? displayName, String? photoURL}) async {
    if (!isUserLoggedIn) return;

    try {
      final updateData = <String, dynamic>{};
      if (displayName != null) {
        updateData['displayName'] = displayName;
      }
      if (photoURL != null) {
        updateData['photoURL'] = photoURL.isEmpty ? null : photoURL;
      }

      if (updateData.isNotEmpty) {
        await _apiService.put('/api/users/me', body: updateData);
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du profil: $e');
      rethrow;
    }
  }
}

