import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/level_model.dart';

class FirebaseLevelService {
  static const String _collectionName = 'levels';
  
  // Singleton pattern
  static final FirebaseLevelService _instance = FirebaseLevelService._internal();
  factory FirebaseLevelService() => _instance;
  FirebaseLevelService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Level> _cachedLevels = [];
  bool _isInitialized = false;
  
  // Initialiser le service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _cachedLevels = await loadLevelsFromFirestore();
      _isInitialized = true;
    } catch (e) {
      print('Erreur lors de l\'initialisation du FirebaseLevelService: $e');
      _cachedLevels = Level.getSampleLevels();
      _isInitialized = true;
    }
  }
  
  // Charger les niveaux depuis Firestore
  Future<List<Level>> loadLevelsFromFirestore() async {
    try {
      // Obtenir tous les documents de la collection 'levels', triés par ID
      final snapshot = await _firestore.collection(_collectionName).orderBy('id').get();
      
      if (snapshot.docs.isEmpty) {
        print('Aucun niveau trouvé dans Firestore, utilisation des niveaux par défaut');
        // Si aucun niveau n'existe, initialiser avec les niveaux par défaut
        try {
          await _initializeDefaultLevels();
          // Récupérer à nouveau les niveaux
          final newSnapshot = await _firestore.collection(_collectionName).orderBy('id').get();
          if (newSnapshot.docs.isNotEmpty) {
            return newSnapshot.docs.map((doc) => Level.fromJson(doc.data())).toList();
          }
        } catch (e) {
          print('Erreur lors de l\'initialisation des niveaux par défaut: $e');
        }
        // En cas d'erreur, retourner les niveaux par défaut
        return Level.getSampleLevels();
      }
      
      return snapshot.docs.map((doc) => Level.fromJson(doc.data())).toList();
    } catch (e) {
      print('Erreur lors du chargement des niveaux depuis Firestore: $e');
      // En cas d'erreur, utiliser les niveaux par défaut
      return Level.getSampleLevels();
    }
  }
  
  // Initialiser la collection avec les niveaux par défaut si elle est vide
  Future<void> _initializeDefaultLevels() async {
    try {
      final defaultLevels = Level.getSampleLevels();
      final batch = _firestore.batch();
      
      for (var level in defaultLevels) {
        final docRef = _firestore.collection(_collectionName).doc(level.id.toString());
        batch.set(docRef, level.toJson());
      }
      
      await batch.commit();
      print('Niveaux par défaut initialisés dans Firestore');
    } catch (e) {
      print('Erreur lors de l\'initialisation des niveaux par défaut: $e');
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
      // D'abord, vérifier dans le cache
      try {
        return _cachedLevels.firstWhere((level) => level.id == id);
      } catch (_) {
        // Si pas dans le cache, chercher dans Firestore
        final doc = await _firestore.collection(_collectionName).doc(id.toString()).get();
        if (doc.exists) {
          return Level.fromJson(doc.data()!);
        }
        return null;
      }
    } catch (e) {
      print('Niveau $id non trouvé: $e');
      return null;
    }
  }
  
  // Ajouter un nouveau niveau
  Future<void> addLevel(Level newLevel) async {
    await initialize();
    
    try {
      // Vérifier si l'ID existe déjà
      final docRef = _firestore.collection(_collectionName).doc(newLevel.id.toString());
      final doc = await docRef.get();
      
      if (doc.exists) {
        throw Exception('Un niveau avec cet ID existe déjà');
      }
      
      // Ajouter le nouveau niveau
      await docRef.set(newLevel.toJson());
      print('Nouveau niveau ajouté: ${newLevel.name}');
      
      // Mettre à jour le cache
      _cachedLevels.add(newLevel);
      // Trier par ID
      _cachedLevels.sort((a, b) => a.id.compareTo(b.id));
    } catch (e) {
      print('Erreur lors de l\'ajout d\'un niveau: $e');
      rethrow;
    }
  }
  
  // Mettre à jour un niveau existant
  Future<void> updateLevel(Level updatedLevel) async {
    await initialize();
    
    try {
      // Mettre à jour le niveau dans Firestore
      final docRef = _firestore.collection(_collectionName).doc(updatedLevel.id.toString());
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw Exception('Niveau non trouvé');
      }
      
      await docRef.update(updatedLevel.toJson());
      print('Niveau mis à jour: ${updatedLevel.name}');
      
      // Mettre à jour le cache
      final index = _cachedLevels.indexWhere((level) => level.id == updatedLevel.id);
      if (index != -1) {
        _cachedLevels[index] = updatedLevel;
      }
    } catch (e) {
      print('Erreur lors de la mise à jour d\'un niveau: $e');
      rethrow;
    }
  }
  
  // Supprimer un niveau
  Future<void> deleteLevel(int levelId) async {
    await initialize();
    
    try {
      // Supprimer le niveau de Firestore
      final docRef = _firestore.collection(_collectionName).doc(levelId.toString());
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw Exception('Niveau non trouvé');
      }
      
      await docRef.delete();
      print('Niveau supprimé: ID $levelId');
      
      // Mettre à jour le cache
      _cachedLevels.removeWhere((level) => level.id == levelId);
    } catch (e) {
      print('Erreur lors de la suppression d\'un niveau: $e');
      rethrow;
    }
  }
  
  // Réinitialiser tous les niveaux aux valeurs par défaut
  Future<void> resetToDefaultLevels() async {
    try {
      // Supprimer tous les niveaux existants
      final snapshot = await _firestore.collection(_collectionName).get();
      final batch = _firestore.batch();
      
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // Ajouter les niveaux par défaut
      await _initializeDefaultLevels();
      
      // Réinitialiser le cache
      _isInitialized = false;
      await initialize();
      
      print('Tous les niveaux ont été réinitialisés aux valeurs par défaut');
    } catch (e) {
      print('Erreur lors de la réinitialisation des niveaux: $e');
      rethrow;
    }
  }
} 