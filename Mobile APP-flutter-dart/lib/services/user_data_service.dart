import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service pour gérer les données utilisateur dans Firestore
class UserDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Singleton pattern
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();
  
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
        await _firestore.collection('users').doc(_userId).set({
          'createdAt': FieldValue.serverTimestamp(),
          'displayName': _auth.currentUser?.displayName ?? 'Joueur',
          'email': _auth.currentUser?.email,
          'photoURL': _auth.currentUser?.photoURL,
          'points': 500,
          'completedLevels': 0,
          'trophies': 0,
          'isAnonymous': _auth.currentUser?.isAnonymous ?? false,
        });
        
        // Initialiser les statistiques de l'utilisateur
        await _firestore.collection('users').doc(_userId).collection('stats').doc('global').set({
          'totalAttempts': 0,
          'totalPlayTime': 0,
          'bestTimes': {},
        });
        
        print('Profil utilisateur créé avec succès');
      } else {
        print('Profil utilisateur existant trouvé pour: $_userId');
        // Vérifier et initialiser les trophées si nécessaire
        final userDoc = await _firestore.collection('users').doc(_userId).get();
        if (userDoc.exists && userDoc.data() != null && !userDoc.data()!.containsKey('trophies')) {
          await _firestore.collection('users').doc(_userId).update({
            'trophies': 0,
          });
        }
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de l\'initialisation des données utilisateur: $e');
      // Ne pas propager l'erreur pour éviter de bloquer l'application
      return false;
    }
  }
  
  /// Sauvegarder les points de l'utilisateur
  Future<void> savePoints(int points) async {
    if (!isUserLoggedIn) return;
    
    try {
      await _firestore.collection('users').doc(_userId).update({
        'points': points,
      });
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
      
      // Utiliser une transaction pour éviter les problèmes de concurrence
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(_userId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          // Si l'utilisateur n'existe pas, créer un nouveau document
          transaction.set(userRef, {
            'points': points,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Sinon, mettre à jour les points
          transaction.update(userRef, {
            'points': points,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      
      print('Points sauvegardés avec succès');
      return true;
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
      
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      return userDoc.data()?['points'] ?? 0;
    } catch (e) {
      print('Erreur lors de la récupération des points: $e');
      return 0; // Retourner 0 en cas d'erreur
    }
  }
  
  /// Sauvegarder la progression d'un niveau
  Future<void> saveLevelProgress(int levelId, {
    required bool isCompleted,
    int? bestTime,
    int attempts = 0,
  }) async {
    if (!isUserLoggedIn) return;
    
    try {
      // Mettre à jour le document de progression du niveau
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('progress')
          .doc(levelId.toString())
          .set({
        'isCompleted': isCompleted,
        'bestTime': bestTime,
        'attempts': attempts,
        'lastPlayed': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Si le niveau est complété, mettre à jour le compteur global
      if (isCompleted) {
        // Obtenir le nombre actuel de niveaux complétés
        final userDoc = await _firestore.collection('users').doc(_userId).get();
        final int currentCompletedLevels = userDoc.data()?['completedLevels'] ?? 0;
        
        // Vérifier si ce niveau a déjà été compté comme complété
        final levelDoc = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('progress')
            .doc(levelId.toString())
            .get();
        
        final bool wasAlreadyCompleted = levelDoc.exists && 
            levelDoc.data() != null && 
            levelDoc.data()!['isCompleted'] == true;
        
        // Mettre à jour le compteur uniquement si c'est un nouveau niveau complété
        if (!wasAlreadyCompleted) {
          await _firestore.collection('users').doc(_userId).update({
            'completedLevels': currentCompletedLevels + 1,
          });
        }
      }
      
      // Mettre à jour les statistiques globales
      if (bestTime != null) {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('stats')
            .doc('global')
            .set({
          'bestTimes': {levelId.toString(): bestTime},
          'totalAttempts': FieldValue.increment(attempts),
        }, SetOptions(merge: true));
      } else {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('stats')
            .doc('global')
            .set({
          'totalAttempts': FieldValue.increment(attempts),
        }, SetOptions(merge: true));
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
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('progress')
          .doc(levelId.toString())
          .get();
      
      if (doc.exists && doc.data() != null) {
        return {
          'isCompleted': doc.data()!['isCompleted'] ?? false,
          'bestTime': doc.data()!['bestTime'],
          'attempts': doc.data()!['attempts'] ?? 0,
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
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('unlockedHints')
          .doc(levelId.toString())
          .set({
        'indices': hintIndices,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erreur lors de la sauvegarde des indices débloqués: $e');
    }
  }
  
  /// Obtenir les indices débloqués pour un niveau
  Future<List<int>> getUnlockedHints(int levelId) async {
    if (!isUserLoggedIn) return [];
    
    try {
      print('Récupération des indices débloqués pour le niveau $levelId');
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('unlockedHints')
          .doc(levelId.toString())
          .get();
      
      if (doc.exists && doc.data() != null) {
        if (doc.data()!.containsKey('indices')) {
          final indices = doc.data()!['indices'];
          
          if (indices is List) {
            print('Indices trouvés: $indices (type: ${indices.runtimeType})');
            // Convertir manuellement chaque élément en int
            return indices.map<int>((item) {
              if (item is int) {
                return item;
              } else if (item is String) {
                return int.tryParse(item) ?? 0;
              } else if (item is double) {
                return item.toInt();
              } else {
                print('Type d\'indice non géré: ${item.runtimeType}');
                return 0;
              }
            }).toList();
          } else {
            print('Le champ "indices" n\'est pas une liste: ${indices.runtimeType}');
          }
        } else {
          print('Le document existe mais ne contient pas le champ "indices"');
        }
      } else {
        print('Aucun document d\'indices trouvé pour le niveau $levelId');
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
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('unlockedHints')
          .doc(levelId.toString())
          .delete();
    } catch (e) {
      print('Erreur lors de la réinitialisation des indices débloqués: $e');
    }
  }
  
  /// Obtenir le nombre de niveaux complétés
  Future<int> getCompletedLevelsCount() async {
    if (!isUserLoggedIn) return 0;
    
    try {
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.data() == null) return 0;
      return userDoc.data()!['completedLevels'] ?? 0;
    } catch (e) {
      print('Erreur lors de la récupération du nombre de niveaux complétés: $e');
      return 0;
    }
  }
  
  /// Sauvegarder le nombre de niveaux complétés
  Future<void> saveCompletedLevelsCount(int count) async {
    if (!isUserLoggedIn) return;
    
    try {
      await _firestore.collection('users').doc(_userId).update({
        'completedLevels': count,
      });
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
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('stats')
          .doc('global')
          .get();
      
      if (doc.exists && doc.data() != null) {
        return {
          'totalAttempts': doc.data()!['totalAttempts'] ?? 0,
          'totalPlayTime': doc.data()!['totalPlayTime'] ?? 0,
          'bestTimes': doc.data()!['bestTimes'] ?? {},
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
      // Obtenir toutes les sous-collections
      final progressDocs = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('progress')
          .get();
      
      final statsDocs = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('stats')
          .get();
      
      final hintsDocs = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('unlockedHints')
          .get();
      
      // Créer un batch pour les opérations groupées
      final batch = _firestore.batch();
      
      // Supprimer tous les documents de progression
      for (final doc in progressDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // Supprimer tous les documents de statistiques
      for (final doc in statsDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // Supprimer tous les documents d'indices débloqués
      for (final doc in hintsDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // Réinitialiser les données principales de l'utilisateur
      batch.update(_firestore.collection('users').doc(_userId), {
        'points': 0,
        'completedLevels': 0,
      });
      
      // Initialiser les statistiques de l'utilisateur
      batch.set(_firestore.collection('users').doc(_userId).collection('stats').doc('global'), {
        'totalAttempts': 0,
        'totalPlayTime': 0,
        'bestTimes': {},
      });
      
      // Exécuter le batch
      await batch.commit();
    } catch (e) {
      print('Erreur lors de la réinitialisation des données utilisateur: $e');
    }
  }
  
  /// Vérifie si l'utilisateur existe déjà dans Firestore
  Future<bool> doesUserExist() async {
    if (!isUserLoggedIn) {
      print('Aucun utilisateur connecté, impossible de vérifier l\'existence');
      return false;
    }
    
    try {
      print('Vérification de l\'existence de l\'utilisateur: $_userId');
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      return userDoc.exists;
    } catch (e) {
      print('Erreur lors de la vérification de l\'existence de l\'utilisateur: $e');
      return false;
    }
  }
}