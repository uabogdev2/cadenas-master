import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/level_model.dart';

class LevelService {
  static const String _levelsJsonPath = 'assets/data/levels.json';
  
  // Singleton pattern
  static final LevelService _instance = LevelService._internal();
  factory LevelService() => _instance;
  LevelService._internal();
  
  List<Level> _cachedLevels = [];
  bool _isInitialized = false;
  
  // Initialiser le service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _cachedLevels = await loadLevelsFromJson();
      _isInitialized = true;
    } catch (e) {
      print('Erreur lors de l\'initialisation du LevelService: $e');
      _cachedLevels = Level.getSampleLevels();
      _isInitialized = true;
    }
  }
  
  // Charger les niveaux depuis le fichier JSON
  Future<List<Level>> loadLevelsFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString(_levelsJsonPath);
      final List<dynamic> jsonData = json.decode(jsonString);
      return jsonData.map((levelJson) => Level.fromJson(levelJson)).toList();
    } catch (e) {
      print('Erreur lors du chargement des niveaux depuis JSON: $e');
      // En cas d'erreur, utiliser les niveaux par défaut
      return Level.getSampleLevels();
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
      print('Niveau $id non trouvé: $e');
      return null;
    }
  }
  
  // Ajouter un nouveau niveau
  Future<void> addLevel(Level newLevel) async {
    await initialize();
    
    try {
      // Charger les niveaux existants
      final levels = await loadLevelsFromJson();
      
      // Vérifier si l'ID existe déjà
      if (levels.any((level) => level.id == newLevel.id)) {
        throw Exception('Un niveau avec cet ID existe déjà');
      }
      
      // Ajouter le nouveau niveau
      levels.add(newLevel);
      
      // Convertir en JSON
      final jsonData = levels.map((level) => level.toJson()).toList();
      final jsonString = json.encode(jsonData);
      
      // Écrire dans le fichier
      // Note: Cette opération nécessite des permissions d'écriture
      // qui ne sont pas disponibles dans une application Flutter standard
      // Cette méthode serait à implémenter avec un backend ou une solution de stockage
      print('Nouveau niveau ajouté (simulation): ${newLevel.name}');
      
      // Mettre à jour le cache
      _cachedLevels = levels;
    } catch (e) {
      print('Erreur lors de l\'ajout d\'un niveau: $e');
    }
  }
  
  // Mettre à jour un niveau existant
  Future<void> updateLevel(Level updatedLevel) async {
    await initialize();
    
    try {
      // Charger les niveaux existants
      final levels = await loadLevelsFromJson();
      
      // Trouver l'index du niveau à mettre à jour
      final index = levels.indexWhere((level) => level.id == updatedLevel.id);
      if (index == -1) {
        throw Exception('Niveau non trouvé');
      }
      
      // Mettre à jour le niveau
      levels[index] = updatedLevel;
      
      // Convertir en JSON
      final jsonData = levels.map((level) => level.toJson()).toList();
      final jsonString = json.encode(jsonData);
      
      // Écrire dans le fichier (simulation)
      print('Niveau mis à jour (simulation): ${updatedLevel.name}');
      
      // Mettre à jour le cache
      _cachedLevels = levels;
    } catch (e) {
      print('Erreur lors de la mise à jour d\'un niveau: $e');
    }
  }
  
  // Supprimer un niveau
  Future<void> deleteLevel(int levelId) async {
    await initialize();
    
    try {
      // Charger les niveaux existants
      final levels = await loadLevelsFromJson();
      
      // Filtrer le niveau à supprimer
      final filteredLevels = levels.where((level) => level.id != levelId).toList();
      
      if (levels.length == filteredLevels.length) {
        throw Exception('Niveau non trouvé');
      }
      
      // Convertir en JSON
      final jsonData = filteredLevels.map((level) => level.toJson()).toList();
      final jsonString = json.encode(jsonData);
      
      // Écrire dans le fichier (simulation)
      print('Niveau supprimé (simulation): ID $levelId');
      
      // Mettre à jour le cache
      _cachedLevels = filteredLevels;
    } catch (e) {
      print('Erreur lors de la suppression d\'un niveau: $e');
    }
  }
} 