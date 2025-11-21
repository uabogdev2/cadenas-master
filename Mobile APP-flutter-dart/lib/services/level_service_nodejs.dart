import '../models/level_model.dart';
import 'api_service.dart';

class LevelServiceNodeJs {
  final ApiService _apiService = ApiService();

  // Singleton pattern
  static final LevelServiceNodeJs _instance = LevelServiceNodeJs._internal();
  factory LevelServiceNodeJs() => _instance;
  LevelServiceNodeJs._internal();

  List<Level> _cachedLevels = [];
  bool _isInitialized = false;

  void _updateCache(List<Level> levels) {
    _cachedLevels = levels;
    _isInitialized = true;
  }

  // Initialiser le service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final levels = await loadLevelsFromServer();
      _updateCache(levels);
    } catch (e) {
      print('Erreur lors de l\'initialisation du LevelServiceNodeJs: $e');
      _updateCache(Level.getSampleLevels());
    }
  }

  // Charger les niveaux depuis le serveur Node.js
  Future<List<Level>> loadLevelsFromServer() async {
    try {
      final response = await _apiService.get('/api/levels', requireAuth: false);

      if (response != null && response['success'] == true) {
        final levels = response['levels'] as List;
        final parsedLevels = levels.map((levelJson) => Level.fromJson(levelJson)).toList();
        _updateCache(parsedLevels);
        return parsedLevels;
      } else {
        print('Erreur lors du chargement des niveaux: ${response?['error']}');
        final fallback = Level.getSampleLevels();
        _updateCache(fallback);
        return fallback;
      }
    } catch (e) {
      print('Erreur lors du chargement des niveaux depuis le serveur: $e');
      final fallback = Level.getSampleLevels();
      _updateCache(fallback);
      return fallback;
    }
  }

  // Obtenir tous les niveaux
  Future<List<Level>> getAllLevels() async {
    await initialize();
    return _cachedLevels;
  }

  // Obtenir un niveau par son ID
  Future<Level?> getLevelById(int id) async {
    await initialize();
    try {
      return _cachedLevels.firstWhere((level) => level.id == id);
    } catch (e) {
      print('Niveau $id non trouvé dans le cache, tentative depuis le serveur');
      try {
        final response = await _apiService.get('/api/levels/$id', requireAuth: false);
        if (response != null && response['success'] == true) {
          final levelJson = response['level'];
          return Level.fromJson(levelJson);
        }
        return null;
      } catch (e) {
        print('Erreur lors de la récupération du niveau depuis le serveur: $e');
        return null;
      }
    }
  }

  // Ajouter un nouveau niveau (nécessite des permissions admin)
  Future<void> addLevel(Level newLevel) async {
    try {
      final response = await _apiService.post('/api/levels', body: newLevel.toJson());

      if (response != null && response['success'] == true) {
        print('Nouveau niveau ajouté: ${newLevel.name}');
        // Recharger les niveaux depuis le serveur
        _isInitialized = false;
        await initialize();
      } else {
        print('Erreur lors de l\'ajout d\'un niveau: ${response?['error']}');
        throw Exception(response?['error'] ?? 'Erreur lors de l\'ajout d\'un niveau');
      }
    } catch (e) {
      print('Erreur lors de l\'ajout d\'un niveau: $e');
      rethrow;
    }
  }

  // Mettre à jour un niveau existant (nécessite des permissions admin)
  Future<void> updateLevel(Level updatedLevel) async {
    try {
      final response = await _apiService.put('/api/levels/${updatedLevel.id}', body: updatedLevel.toJson());

      if (response != null && response['success'] == true) {
        print('Niveau mis à jour: ${updatedLevel.name}');
        // Recharger les niveaux depuis le serveur
        _isInitialized = false;
        await initialize();
      } else {
        print('Erreur lors de la mise à jour d\'un niveau: ${response?['error']}');
        throw Exception(response?['error'] ?? 'Erreur lors de la mise à jour d\'un niveau');
      }
    } catch (e) {
      print('Erreur lors de la mise à jour d\'un niveau: $e');
      rethrow;
    }
  }

  // Supprimer un niveau (nécessite des permissions admin)
  Future<void> deleteLevel(int levelId) async {
    try {
      final response = await _apiService.delete('/api/levels/$levelId');

      if (response != null && response['success'] == true) {
        print('Niveau supprimé: ID $levelId');
        // Recharger les niveaux depuis le serveur
        _isInitialized = false;
        await initialize();
      } else {
        print('Erreur lors de la suppression d\'un niveau: ${response?['error']}');
        throw Exception(response?['error'] ?? 'Erreur lors de la suppression d\'un niveau');
      }
    } catch (e) {
      print('Erreur lors de la suppression d\'un niveau: $e');
      rethrow;
    }
  }

  // Réinitialiser tous les niveaux aux valeurs par défaut (nécessite des permissions admin)
  Future<void> resetToDefaultLevels() async {
    try {
      final response = await _apiService.post('/api/levels/initialize', body: {});

      if (response != null && response['success'] == true) {
        print('Tous les niveaux ont été réinitialisés aux valeurs par défaut');
        // Recharger les niveaux depuis le serveur
        _isInitialized = false;
        await initialize();
      } else {
        print('Erreur lors de la réinitialisation des niveaux: ${response?['error']}');
        throw Exception(response?['error'] ?? 'Erreur lors de la réinitialisation des niveaux');
      }
    } catch (e) {
      print('Erreur lors de la réinitialisation des niveaux: $e');
      rethrow;
    }
  }
}

