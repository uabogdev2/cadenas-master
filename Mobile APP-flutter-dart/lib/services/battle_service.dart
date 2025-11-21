import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/level_model.dart';
import 'dart:async';
import 'dart:math';

/// Service pour gérer les duels (battles)
class BattleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final BattleService _instance = BattleService._internal();
  factory BattleService() => _instance;
  BattleService._internal();

  String? get _userId => _auth.currentUser?.uid;
  bool get isUserLoggedIn => _userId != null;
  
  // Méthode publique pour obtenir l'ID de l'utilisateur
  String? get userId => _userId;
  

  /// Créer une nouvelle bataille (salle) en attente
  /// [mode] : 'ranked' (classé) ou 'friendly' (amical)
  /// [roomId] : ID de la salle pour le mode amical (optionnel, généré si null)
  Future<String?> createBattle({String mode = 'ranked', String? roomId}) async {
    if (!isUserLoggedIn) return null;

    try {
      // Pour le mode amical, générer un roomId si non fourni
      String? finalRoomId = roomId;
      if (mode == 'friendly' && finalRoomId == null) {
        // Générer un ID de 6 caractères aléatoires
        finalRoomId = _generateRoomId();
      }

      final battleRef = _firestore.collection('battles').doc();
      await battleRef.set({
        'player1': _userId,
        'player2': null,
        'status': 'waiting',
        'mode': mode, // 'ranked' ou 'friendly'
        'roomId': finalRoomId, // ID de la salle pour le mode amical
        'player1Score': 0,
        'player2Score': 0,
        'player1Abandoned': false,
        'player2Abandoned': false,
        'startTime': null,
        'endTime': null,
        'totalTimeLimit': 300, // 5 minutes en secondes
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return battleRef.id;
    } catch (e) {
      print('Erreur lors de la création de la bataille: $e');
      return null;
    }
  }

  /// Générer un ID de salle aléatoire (6 caractères)
  String _generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (int i = 0; i < 6; i++) {
      // Utiliser une combinaison de timestamp et position pour plus de randomisation
      final seed = (random * (i + 1)) % chars.length;
      buffer.write(chars[seed]);
    }
    return buffer.toString();
  }

  /// Trouver une salle amicale par son ID
  Future<String?> findFriendlyRoom(String roomId) async {
    if (!isUserLoggedIn) return null;

    try {
      final querySnapshot = await _firestore
          .collection('battles')
          .where('mode', isEqualTo: 'friendly')
          .where('roomId', isEqualTo: roomId)
          .where('status', isEqualTo: 'waiting')
          .where('player2', isEqualTo: null)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final player1 = data['player1'] as String?;
        
        // Vérifier que ce n'est pas notre propre salle
        if (player1 != null && player1 != _userId) {
          return doc.id;
        }
      }

      return null;
    } catch (e) {
      print('Erreur lors de la recherche de la salle amicale: $e');
      return null;
    }
  }

  /// Convertir un Level en format JSON simplifié pour le duel
  /// Ne garde que les informations essentielles : id, instruction, code, codeLength
  /// Exclut : isLocked, additionalHints, hintCost, pointsReward, timeLimit, name
  Map<String, dynamic> _levelToDuelJson(Level level) {
    return {
      'id': level.id,
      'instruction': level.instruction,
      'code': level.code,
      'codeLength': level.codeLength,
    };
  }

  /// Mélanger les questions de manière déterministe basé sur l'ID de la bataille
  /// Cela garantit que tous les joueurs auront exactement les mêmes questions dans le même ordre
  List<Level> _shuffleQuestionsDeterministic(List<Level> questions, String battleId) {
    if (questions.isEmpty) return questions;
    
    // Créer un seed déterministe basé sur l'ID de la bataille
    int seed = 0;
    for (int i = 0; i < battleId.length; i++) {
      seed = (seed * 31 + battleId.codeUnitAt(i)) % 0x7FFFFFFF;
    }
    
    // Utiliser ce seed pour mélanger de manière déterministe
    final shuffled = List<Level>.from(questions);
    final random = Random(seed);
    
    // Mélange de Fisher-Yates avec seed déterministe
    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }
    
    print('_shuffleQuestionsDeterministic: ${shuffled.length} questions mélangées avec seed=$seed (battleId=$battleId)');
    return shuffled;
  }

  /// Rejoindre une bataille en attente
  /// Les questions sont mélangées automatiquement de manière déterministe basée sur l'ID de la bataille
  Future<bool> joinBattle(String battleId, List<Level> allQuestions) async {
    if (!isUserLoggedIn) {
      print('joinBattle: Utilisateur non connecté');
      return false;
    }

    try {
      print('joinBattle: Tentative de rejoindre la bataille $battleId par $_userId');
      final battleRef = _firestore.collection('battles').doc(battleId);
      
      return await _firestore.runTransaction((transaction) async {
        final battleDoc = await transaction.get(battleRef);
        
        if (!battleDoc.exists) {
          print('joinBattle: La bataille $battleId n\'existe pas');
          return false;
        }
        
        final data = battleDoc.data()!;
        print('joinBattle: Données de la bataille - status: ${data['status']}, player1: ${data['player1']}, player2: ${data['player2']}');
        
        // Vérifier que la bataille est en attente et qu'il n'y a pas déjà de joueur 2
        if (data['status'] != 'waiting') {
          print('joinBattle: La bataille n\'est pas en attente (status: ${data['status']})');
          return false;
        }
        
        if (data['player2'] != null) {
          print('joinBattle: La bataille a déjà un joueur 2');
          return false;
        }

        // Vérifier que l'utilisateur n'est pas le joueur 1
        if (data['player1'] == _userId) {
          print('joinBattle: L\'utilisateur ne peut pas rejoindre sa propre bataille');
          return false;
        }

        // Mélanger les questions de manière déterministe basée sur l'ID de la bataille
        // Cela garantit que tous les joueurs auront exactement les mêmes questions dans le même ordre
        final shuffledQuestions = _shuffleQuestionsDeterministic(allQuestions, battleId);
        
        if (shuffledQuestions.isEmpty) {
          print('joinBattle: ERREUR - Aucune question après mélange!');
          return false;
        }

        // Convertir les questions en format JSON simplifié (sans indices ni état de verrouillage)
        final questionsJson = shuffledQuestions.map((q) => _levelToDuelJson(q)).toList();
        print('joinBattle: ${questionsJson.length} questions mélangées automatiquement et partagées entre les joueurs');

        // Mettre à jour la bataille - démarrer le timer global avec les questions mélangées
        // IMPORTANT: Les deux joueurs auront exactement la même liste de questions dans le même ordre
        transaction.update(battleRef, {
          'player2': _userId,
          'status': 'active',
          'questions': questionsJson,
          'player1QuestionIndex': 0,
          'player2QuestionIndex': 0,
          'player1AnsweredQuestions': [], // Liste des indices de questions déjà répondues correctement
          'player2AnsweredQuestions': [], // Liste des indices de questions déjà répondues correctement
          'startTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('joinBattle: Transaction préparée avec succès');
        return true;
      });
    } catch (e) {
      print('Erreur lors de la jonction à la bataille: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Trouver une bataille en attente (mode classé uniquement)
  Future<String?> findWaitingBattle() async {
    if (!isUserLoggedIn) {
      print('findWaitingBattle: Utilisateur non connecté');
      return null;
    }

    try {
      print('findWaitingBattle: Recherche d\'une bataille classée en attente pour $_userId');
      
      // Essayer d'abord avec l'index composite (mode classé uniquement)
      try {
        final querySnapshot = await _firestore
            .collection('battles')
            .where('mode', isEqualTo: 'ranked')
            .where('status', isEqualTo: 'waiting')
            .where('player2', isEqualTo: null)
            .limit(10)
            .get();

        print('findWaitingBattle: ${querySnapshot.docs.length} batailles trouvées');

        // Filtrer pour exclure les batailles créées par l'utilisateur actuel
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final player1 = data['player1'] as String?;
          print('findWaitingBattle: Bataille ${doc.id}, player1: $player1, current user: $_userId');
          
          if (player1 != null && player1 != _userId) {
            print('findWaitingBattle: Bataille trouvée: ${doc.id}');
            return doc.id;
          }
        }
      } catch (e) {
        // Si l'index n'existe pas, utiliser une requête alternative
        print('findWaitingBattle: Index composite non disponible, utilisation de la méthode alternative: $e');
        
        // Méthode alternative : récupérer toutes les batailles classées en attente et filtrer
        final querySnapshot = await _firestore
            .collection('battles')
            .where('mode', isEqualTo: 'ranked')
            .where('status', isEqualTo: 'waiting')
            .limit(20)
            .get();

        print('findWaitingBattle (alternative): ${querySnapshot.docs.length} batailles trouvées');

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final player1 = data['player1'] as String?;
          final player2 = data['player2'];
          
          // Vérifier que player2 est null et que ce n'est pas notre propre bataille
          if (player2 == null && player1 != null && player1 != _userId) {
            print('findWaitingBattle: Bataille trouvée (alternative): ${doc.id}');
            return doc.id;
          }
        }
      }
      
      print('findWaitingBattle: Aucune bataille disponible');
      return null;
    } catch (e) {
      print('Erreur lors de la recherche d\'une bataille: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Obtenir les données d'une bataille
  Stream<DocumentSnapshot> getBattleStream(String battleId) {
    return _firestore.collection('battles').doc(battleId).snapshots();
  }

  /// Mettre à jour le score d'un joueur (incrémenter de 1 si bonne réponse) et passer à la question suivante
  Future<bool> incrementScoreAndNext(String battleId, int questionIndex) async {
    if (!isUserLoggedIn) return false;

    try {
      final battleRef = _firestore.collection('battles').doc(battleId);
      
      return await _firestore.runTransaction((transaction) async {
        final battleDoc = await transaction.get(battleRef);
        
        if (!battleDoc.exists) return false;
        
        final data = battleDoc.data()!;
        final isPlayer1 = data['player1'] == _userId;
        final isPlayer2 = data['player2'] == _userId;
        
        if (!isPlayer1 && !isPlayer2) return false;

        final scoreField = isPlayer1 ? 'player1Score' : 'player2Score';
        final indexField = isPlayer1 ? 'player1QuestionIndex' : 'player2QuestionIndex';
        final answeredField = isPlayer1 ? 'player1AnsweredQuestions' : 'player2AnsweredQuestions';
        final currentScore = data[scoreField] ?? 0;
        final currentIndex = data[indexField] ?? 0;
        
        // Ajouter la question actuelle à la liste des questions répondues correctement
        final answeredQuestions = List<int>.from(data[answeredField] ?? []);
        if (!answeredQuestions.contains(questionIndex)) {
          answeredQuestions.add(questionIndex);
        }

        transaction.update(battleRef, {
          scoreField: currentScore + 1,
          indexField: currentIndex + 1,
          answeredField: answeredQuestions,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Erreur lors de la mise à jour du score: $e');
      return false;
    }
  }

  /// Passer à la question suivante (sans incrémenter le score)
  /// Trouve la prochaine question non répondue correctement dans la liste
  Future<bool> nextQuestion(String battleId) async {
    if (!isUserLoggedIn) return false;

    try {
      final battleRef = _firestore.collection('battles').doc(battleId);
      
      return await _firestore.runTransaction((transaction) async {
        final battleDoc = await transaction.get(battleRef);
        
        if (!battleDoc.exists) return false;
        
        final data = battleDoc.data()!;
        final isPlayer1 = data['player1'] == _userId;
        final isPlayer2 = data['player2'] == _userId;
        
        if (!isPlayer1 && !isPlayer2) return false;

        final indexField = isPlayer1 ? 'player1QuestionIndex' : 'player2QuestionIndex';
        final answeredField = isPlayer1 ? 'player1AnsweredQuestions' : 'player2AnsweredQuestions';
        final currentIndex = data[indexField] ?? 0;
        final answeredQuestions = List<int>.from(data[answeredField] ?? []);
        final questions = data['questions'] as List? ?? [];
        
        if (questions.isEmpty) {
          return false;
        }
        
        // Trouver la prochaine question non répondue
        // On incrémente l'index et on cherche la prochaine question non répondue
        int nextIndex = (currentIndex + 1) % questions.length;
        
        // Chercher la prochaine question non répondue (maximum questions.length itérations pour éviter boucle infinie)
        int attempts = 0;
        while (answeredQuestions.contains(nextIndex) && attempts < questions.length) {
          nextIndex = (nextIndex + 1) % questions.length;
          attempts++;
        }
        
        // Si toutes les questions sont répondues, on continue quand même en boucle
        // mais on évite de rester bloqué sur la même question

        transaction.update(battleRef, {
          indexField: nextIndex,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Erreur lors du passage à la question suivante: $e');
      return false;
    }
  }

  /// Abandonner une bataille
  Future<bool> abandonBattle(String battleId) async {
    if (!isUserLoggedIn) return false;

    try {
      final battleRef = _firestore.collection('battles').doc(battleId);
      
      return await _firestore.runTransaction((transaction) async {
        final battleDoc = await transaction.get(battleRef);
        
        if (!battleDoc.exists) return false;
        
        final data = battleDoc.data()!;
        
        // Vérifier si la bataille est déjà terminée
        if (data['status'] == 'finished') {
          return true;
        }
        
        final isPlayer1 = data['player1'] == _userId;
        final isPlayer2 = data['player2'] == _userId;
        
        if (!isPlayer1 && !isPlayer2) return false;

        // Marquer l'abandon
        final abandonField = isPlayer1 ? 'player1Abandoned' : 'player2Abandoned';
        final player1Abandoned = data['player1Abandoned'] ?? false;
        final player2Abandoned = data['player2Abandoned'] ?? false;
        
        // Déterminer le gagnant immédiatement
        String winner;
        String result;
        
        if (isPlayer1) {
          // Le joueur 1 abandonne, le joueur 2 gagne
          winner = data['player2'] as String;
          result = 'player2_win';
        } else {
          // Le joueur 2 abandonne, le joueur 1 gagne
          winner = data['player1'] as String;
          result = 'player1_win';
        }
        
        transaction.update(battleRef, {
          abandonField: true,
          'status': 'finished',
          'winner': winner,
          'result': result,
          'endTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Erreur lors de l\'abandon de la bataille: $e');
      return false;
    }
  }

  /// Terminer une bataille et calculer le résultat (appelé quand le timer expire)
  Future<Map<String, dynamic>?> finishBattle(String battleId) async {
    if (!isUserLoggedIn) return null;

    try {
      final battleRef = _firestore.collection('battles').doc(battleId);
      
      return await _firestore.runTransaction((transaction) async {
        final battleDoc = await transaction.get(battleRef);
        
        if (!battleDoc.exists) return null;

        final data = battleDoc.data()!;
        
        // Vérifier si la bataille est déjà terminée
        if (data['status'] == 'finished') {
          return {
            'winner': data['winner'],
            'result': data['result'],
            'player1Score': data['player1Score'] ?? 0,
            'player2Score': data['player2Score'] ?? 0,
          };
        }

        final player1Score = data['player1Score'] ?? 0;
        final player2Score = data['player2Score'] ?? 0;
        final player1Abandoned = data['player1Abandoned'] ?? false;
        final player2Abandoned = data['player2Abandoned'] ?? false;

        String winner;
        String result;

        // Gérer les abandons
        if (player1Abandoned && !player2Abandoned) {
          winner = data['player2'];
          result = 'player2_win';
        } else if (player2Abandoned && !player1Abandoned) {
          winner = data['player1'];
          result = 'player1_win';
        } else if (player1Abandoned && player2Abandoned) {
          winner = 'draw';
          result = 'draw';
        } else {
          // Pas d'abandon, comparer les scores
          if (player1Score > player2Score) {
            winner = data['player1'];
            result = 'player1_win';
          } else if (player2Score > player1Score) {
            winner = data['player2'];
            result = 'player2_win';
          } else {
            winner = 'draw';
            result = 'draw';
          }
        }

        transaction.update(battleRef, {
          'status': 'finished',
          'winner': winner,
          'result': result,
          'endTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return {
          'winner': winner,
          'result': result,
          'player1Score': player1Score,
          'player2Score': player2Score,
          'mode': data['mode'] ?? 'ranked', // Retourner le mode de la bataille
        };
      });
    } catch (e) {
      print('Erreur lors de la finalisation de la bataille: $e');
      return null;
    }
  }

  /// Obtenir les données d'une bataille (une seule fois)
  Future<Map<String, dynamic>?> getBattle(String battleId) async {
    try {
      final doc = await _firestore.collection('battles').doc(battleId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de la bataille: $e');
      return null;
    }
  }

  /// Supprimer une bataille (seulement si elle est en attente et que l'utilisateur est le créateur)
  Future<bool> deleteBattle(String battleId) async {
    if (!isUserLoggedIn) return false;

    try {
      final battleRef = _firestore.collection('battles').doc(battleId);
      
      return await _firestore.runTransaction((transaction) async {
        final battleDoc = await transaction.get(battleRef);
        
        if (!battleDoc.exists) return false;
        
        final data = battleDoc.data()!;
        
        // Vérifier que la bataille est en attente et que l'utilisateur est le créateur
        if (data['status'] == 'waiting' && data['player1'] == _userId && data['player2'] == null) {
          transaction.delete(battleRef);
          return true;
        }
        
        return false;
      });
    } catch (e) {
      print('Erreur lors de la suppression de la bataille: $e');
      return false;
    }
  }

  /// Nettoyer automatiquement les batailles vides, terminées ou annulées
  /// - Batailles en attente vides (waiting, player2 = null) de plus de 5 minutes
  /// - Batailles terminées (finished) de plus de 1 heure
  Future<void> cleanupOldBattles() async {
    try {
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      int deletedCount = 0;
      WriteBatch? batch;
      int batchCount = 0;

      // 1. Nettoyer les batailles en attente vides (plus de 5 minutes)
      final waitingQuery = await _firestore
          .collection('battles')
          .where('status', isEqualTo: 'waiting')
          .where('player2', isEqualTo: null)
          .get();

      for (var doc in waitingQuery.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        
        if (createdAt != null) {
          final createdTime = createdAt.toDate();
          if (createdTime.isBefore(fiveMinutesAgo)) {
            if (batch == null || batchCount >= 500) {
              if (batch != null) {
                await batch.commit();
              }
              batch = _firestore.batch();
              batchCount = 0;
            }
            batch.delete(doc.reference);
            batchCount++;
            deletedCount++;
          }
        }
      }

      // 2. Nettoyer les batailles terminées (plus de 1 heure après la fin)
      final finishedQuery = await _firestore
          .collection('battles')
          .where('status', isEqualTo: 'finished')
          .get();

      for (var doc in finishedQuery.docs) {
        final data = doc.data();
        final endTime = data['endTime'] as Timestamp?;
        
        if (endTime != null) {
          final endDateTime = endTime.toDate();
          if (endDateTime.isBefore(oneHourAgo)) {
            if (batch == null || batchCount >= 500) {
              if (batch != null) {
                await batch.commit();
              }
              batch = _firestore.batch();
              batchCount = 0;
            }
            batch.delete(doc.reference);
            batchCount++;
            deletedCount++;
          }
        } else {
          // Si pas de endTime, vérifier createdAt (fallback)
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final createdTime = createdAt.toDate();
            if (createdTime.isBefore(oneHourAgo)) {
              if (batch == null || batchCount >= 500) {
                if (batch != null) {
                  await batch.commit();
                }
                batch = _firestore.batch();
                batchCount = 0;
              }
              batch.delete(doc.reference);
              batchCount++;
              deletedCount++;
            }
          }
        }
      }

      // Commit le dernier batch
      if (batch != null && batchCount > 0) {
        await batch.commit();
      }

      if (deletedCount > 0) {
        print('Nettoyage automatique: $deletedCount batailles supprimées');
      }
    } catch (e) {
      print('Erreur lors du nettoyage automatique des batailles: $e');
    }
  }

  /// Nettoyer les batailles en attente trop anciennes (plus de 5 minutes)
  /// @deprecated Utiliser cleanupOldBattles() à la place
  @Deprecated('Utiliser cleanupOldBattles() à la place')
  Future<void> cleanupOldWaitingBattles() async {
    await cleanupOldBattles();
  }

  /// Supprimer immédiatement une bataille terminée (appelé après affichage des résultats)
  Future<void> deleteFinishedBattle(String battleId) async {
    try {
      final battleRef = _firestore.collection('battles').doc(battleId);
      final battleDoc = await battleRef.get();
      
      if (battleDoc.exists) {
        final data = battleDoc.data()!;
        // Supprimer seulement si la bataille est terminée
        if (data['status'] == 'finished') {
          await battleRef.delete();
          print('Bataille terminée supprimée: $battleId');
        }
      }
    } catch (e) {
      print('Erreur lors de la suppression de la bataille terminée: $e');
    }
  }
}

