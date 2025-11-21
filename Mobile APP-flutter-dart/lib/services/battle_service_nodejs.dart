import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/level_model.dart';
import 'api_service.dart';
import '../config/api_config.dart';

@Deprecated('Utiliser SocketDuelService (Socket.IO) pour la synchro temps réel')
class BattleServiceNodeJs {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiService _apiService = ApiService();

  // Singleton pattern
  static final BattleServiceNodeJs _instance = BattleServiceNodeJs._internal();
  factory BattleServiceNodeJs() => _instance;
  BattleServiceNodeJs._internal();

  String? get _userId => _auth.currentUser?.uid;
  bool get isUserLoggedIn => _userId != null;
  String? get userId => _userId;

  // Timers pour le polling
  final Map<String, Timer> _pollTimers = {};
  final Map<String, Function(Map<String, dynamic>)> _pollCallbacks = {};
  final Map<String, int> _pollCounters = {}; // Compteur pour chaque bataille

  /// Créer une nouvelle bataille (salle) en attente
  /// [mode] : 'ranked' (classé) ou 'friendly' (amical)
  /// [roomId] : ID de la salle pour le mode amical (optionnel, généré si null)
  /// Retourne un Map avec 'battleId' et 'roomId'
  Future<Map<String, dynamic>?> createBattle({String mode = 'ranked', String? roomId}) async {
    if (!isUserLoggedIn) return null;

    try {
      final response = await _apiService.post('/api/battles/create', body: {
        'mode': mode,
        'roomId': roomId,
      });

      if (response != null && response['success'] == true) {
        final battle = response['battle'] as Map<String, dynamic>?;
        if (battle != null) {
          // L'ID peut être un int ou un String, le convertir en String pour être cohérent
          final id = battle['id'];
          final battleRoomId = battle['roomId'] as String?;
          if (id != null) {
            return {
              'battleId': id.toString(),
              'roomId': battleRoomId,
            };
          }
        }
        return null;
      } else {
        print('Erreur lors de la création de la bataille: ${response?['error']}');
        return null;
      }
    } catch (e) {
      print('Erreur lors de la création de la bataille: $e');
      return null;
    }
  }

  /// Trouver une salle amicale par son ID
  Future<String?> findFriendlyRoom(String roomId) async {
    if (!isUserLoggedIn) return null;

    try {
      final response = await _apiService.get('/api/battles/find-friendly/$roomId');

      if (response != null && response['success'] == true) {
        final battle = response['battle'] as Map<String, dynamic>?;
        if (battle != null) {
          final id = battle['id'];
          if (id != null) {
            return id.toString();
          }
        }
      }
      return null;
    } catch (e) {
      print('Erreur lors de la recherche de la salle amicale: $e');
      return null;
    }
  }

  /// Matchmaking classé : chercher une bataille et la rejoindre automatiquement, ou créer une nouvelle bataille
  /// Retourne un Map avec 'battleId' et 'joined' (true si rejoint, false si créé)
  Future<Map<String, dynamic>?> startRankedMatchmaking() async {
    if (!isUserLoggedIn) {
      print('startRankedMatchmaking: Utilisateur non connecté');
      return null;
    }

    try {
      print('startRankedMatchmaking: Démarrage du matchmaking classé pour $_userId');
      
      final response = await _apiService.post('/api/battles/matchmaking/ranked', body: {});

      if (response != null && response['success'] == true) {
        final battle = response['battle'] as Map<String, dynamic>?;
        if (battle != null) {
          final id = battle['id'];
          final joined = response['joined'] as bool? ?? false;
          if (id != null) {
            print('startRankedMatchmaking: Bataille ${joined ? "jointe" : "créée"}: $id');
            return {
              'battleId': id.toString(),
              'joined': joined,
              'status': battle['status'] as String? ?? 'waiting',
              'player2': battle['player2'] as String?,
            };
          }
        }
      }
      
      print('startRankedMatchmaking: Erreur lors du matchmaking');
      return null;
    } catch (e) {
      print('Erreur lors du matchmaking classé: $e');
      return null;
    }
  }

  /// Trouver une bataille en attente (mode classé uniquement) - DEPRECATED
  @Deprecated('Utiliser startRankedMatchmaking() à la place')
  Future<String?> findWaitingBattle() async {
    if (!isUserLoggedIn) {
      print('findWaitingBattle: Utilisateur non connecté');
      return null;
    }

    try {
      print('findWaitingBattle: Recherche d\'une bataille classée en attente pour $_userId');
      
      final response = await _apiService.get('/api/battles/find', queryParameters: {
        'mode': 'ranked',
      });

      if (response != null && response['success'] == true) {
        final battle = response['battle'] as Map<String, dynamic>?;
        if (battle != null) {
          final id = battle['id'];
          if (id != null) {
            print('findWaitingBattle: Bataille trouvée: $id');
            return id.toString();
          }
        }
      }
      
      print('findWaitingBattle: Aucune bataille disponible');
      return null;
    } catch (e) {
      print('Erreur lors de la recherche d\'une bataille: $e');
      return null;
    }
  }

  /// Rejoindre une bataille en attente
  /// Le serveur mélange automatiquement les questions de manière déterministe
  /// allQuestions n'est plus nécessaire car le serveur charge automatiquement les questions
  Future<bool> joinBattle(String battleId, [List<Level>? allQuestions]) async {
    if (!isUserLoggedIn) {
      print('joinBattle: Utilisateur non connecté');
      return false;
    }

    try {
      print('joinBattle: Tentative de rejoindre la bataille $battleId par $_userId');
      
      // Le serveur gère le mélange des questions de manière déterministe
      // Les questions sont chargées automatiquement depuis la base de données
      final response = await _apiService.post('/api/battles/join/$battleId', body: {});

      if (response != null && response['success'] == true) {
        print('joinBattle: Bataille rejointe avec succès');
        return true;
      } else {
        print('joinBattle: Erreur lors de la jonction: ${response?['error']}');
        print('joinBattle: Détails: ${response?['details']}');
        return false;
      }
    } catch (e) {
      print('Erreur lors de la jonction à la bataille: $e');
      return false;
    }
  }

  /// Convertir un Level en format JSON simplifié pour le duel
  /// Ne garde que les informations essentielles : id, instruction, code, codeLength
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

  /// Obtenir les données d'une bataille (une seule fois)
  /// [forceRefresh] : Si true, force le serveur à ignorer le cache
  Future<Map<String, dynamic>?> getBattle(String battleId, {bool forceRefresh = false}) async {
    try {
      final queryParams = forceRefresh ? {'force': 'true'} : null;
      final response = await _apiService.get('/api/battles/$battleId', queryParameters: queryParams);
      if (response != null && response['success'] == true) {
        return response['battle'];
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de la bataille: $e');
      return null;
    }
  }

  /// Obtenir les données d'une bataille avec polling (stream)
  /// [callback] : Fonction appelée à chaque mise à jour de la bataille
  void getBattleStream(String battleId, Function(Map<String, dynamic>) callback) {
    // Arrêter le polling précédent pour cette bataille si il existe
    stopPolling(battleId);

    // Ajouter le callback
    _pollCallbacks[battleId] = callback;

    // Démarrer le polling
    _startPolling(battleId, callback);
  }

  /// Démarrer le polling pour une bataille
  void _startPolling(String battleId, Function(Map<String, dynamic>) callback) {
    // Arrêter le polling précédent si il existe
    stopPolling(battleId);

    // Ajouter le callback
    _pollCallbacks[battleId] = callback;

    // Faire un premier appel immédiatement
    getBattle(battleId, forceRefresh: true).then((battle) {
      if (battle != null && _pollCallbacks.containsKey(battleId)) {
        callback(battle);
        // Ne pas arrêter le polling même si la bataille est terminée
        // pour permettre à tous les joueurs de voir l'écran de fin
      }
    }).catchError((e) {
      print('Erreur lors du premier polling de la bataille: $e');
    });

    // Créer un nouveau timer pour le polling périodique avec synchronisation
    _pollCounters[battleId] = 0; // Initialiser le compteur
    
    // Pour une meilleure synchronisation, utiliser un intervalle plus court et toujours rafraîchir
    // Les batailles actives nécessitent une synchronisation en temps réel
    _pollTimers[battleId] = Timer.periodic(
      Duration(milliseconds: ApiConfig.battlePollInterval),
      (timer) async {
        try {
          // Incrémenter le compteur
          _pollCounters[battleId] = (_pollCounters[battleId] ?? 0) + 1;
          
          // Pour les batailles actives, toujours utiliser forceRefresh pour garantir la synchronisation
          // Cela évite les décalages entre les joueurs
          // Utiliser forceRefresh toutes les requêtes pour les batailles actives
          final useForceRefresh = true; // Toujours rafraîchir pour une synchronisation optimale
          
          final battle = await getBattle(battleId, forceRefresh: useForceRefresh);
          if (battle != null && _pollCallbacks.containsKey(battleId)) {
            // Vérifier si les données ont vraiment changé pour éviter les mises à jour inutiles
            final status = battle['status'] as String?;
            
            // Appeler le callback pour mettre à jour l'interface
            // Le callback vérifiera lui-même si les données ont changé
            callback(battle);

            // Ne pas arrêter le polling même si la bataille est terminée
            // pour permettre à tous les joueurs de voir l'écran de fin
            // Le polling sera arrêté lors du dispose de l'écran
          }
        } catch (e) {
          print('Erreur lors du polling de la bataille: $e');
          // Ne pas arrêter le polling en cas d'erreur, continuer à essayer
          // Le polling sera arrêté lors du dispose de l'écran
        }
      },
    );
  }

  /// Arrêter le polling pour une bataille
  void stopPolling(String battleId) {
    final timer = _pollTimers[battleId];
    if (timer != null) {
      timer.cancel();
      _pollTimers.remove(battleId);
    }
    _pollCallbacks.remove(battleId);
    _pollCounters.remove(battleId);
  }

  /// Mettre à jour le score d'un joueur (incrémenter de 1 si bonne réponse) et passer à la question suivante
  Future<bool> incrementScoreAndNext(String battleId, int questionIndex) async {
    if (!isUserLoggedIn) return false;

    try {
      final response = await _apiService.post('/api/battles/$battleId/score', body: {
        'questionIndex': questionIndex,
      });

      if (response != null && response['success'] == true) {
        // Forcer une récupération immédiate de la bataille pour mettre à jour les données
        // Le polling prendra automatiquement en compte les nouvelles données
        print('incrementScoreAndNext: Score mis à jour avec succès');
        return true;
      } else {
        print('Erreur lors de la mise à jour du score: ${response?['error']}');
        return false;
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du score: $e');
      return false;
    }
  }

  /// Passer à la question suivante (sans incrémenter le score)
  Future<bool> nextQuestion(String battleId) async {
    if (!isUserLoggedIn) return false;

    try {
      final response = await _apiService.post('/api/battles/$battleId/next', body: {});

      if (response != null && response['success'] == true) {
        print('nextQuestion: Question suivante avec succès');
        return true;
      } else {
        print('Erreur lors du passage à la question suivante: ${response?['error']}');
        return false;
      }
    } catch (e) {
      print('Erreur lors du passage à la question suivante: $e');
      return false;
    }
  }

  /// Abandonner une bataille
  Future<bool> abandonBattle(String battleId) async {
    if (!isUserLoggedIn) return false;

    try {
      final response = await _apiService.post('/api/battles/$battleId/abandon', body: {});

      if (response != null && response['success'] == true) {
        // Arrêter le polling
        stopPolling(battleId);
        return true;
      } else {
        print('Erreur lors de l\'abandon de la bataille: ${response?['error']}');
        return false;
      }
    } catch (e) {
      print('Erreur lors de l\'abandon de la bataille: $e');
      return false;
    }
  }

  /// Terminer une bataille et calculer le résultat (appelé quand le timer expire)
  Future<Map<String, dynamic>?> finishBattle(String battleId) async {
    if (!isUserLoggedIn) return null;

    try {
      final response = await _apiService.post('/api/battles/$battleId/finish', body: {});

      if (response != null && response['success'] == true) {
        // Arrêter le polling
        stopPolling(battleId);
        return response['result'];
      } else {
        print('Erreur lors de la finalisation de la bataille: ${response?['error']}');
        return null;
      }
    } catch (e) {
      print('Erreur lors de la finalisation de la bataille: $e');
      return null;
    }
  }

  /// Supprimer une bataille (seulement si elle est en attente et que l'utilisateur est le créateur)
  Future<bool> deleteBattle(String battleId) async {
    if (!isUserLoggedIn) return false;

    try {
      final response = await _apiService.delete('/api/battles/$battleId');

      if (response != null && response['success'] == true) {
        // Arrêter le polling
        stopPolling(battleId);
        return true;
      } else {
        print('Erreur lors de la suppression de la bataille: ${response?['error']}');
        return false;
      }
    } catch (e) {
      print('Erreur lors de la suppression de la bataille: $e');
      return false;
    }
  }

  /// Supprimer immédiatement une bataille terminée (appelé après affichage des résultats)
  Future<void> deleteFinishedBattle(String battleId) async {
    try {
      // Arrêter le polling
      stopPolling(battleId);
      
      // Supprimer la bataille
      await deleteBattle(battleId);
      print('Bataille terminée supprimée: $battleId');
    } catch (e) {
      print('Erreur lors de la suppression de la bataille terminée: $e');
    }
  }

  /// Nettoyer automatiquement les batailles (ne fait rien côté client, c'est le serveur qui gère)
  Future<void> cleanupOldBattles() async {
    // Le nettoyage est géré par le serveur
    print('Nettoyage des batailles géré par le serveur');
  }

  /// Nettoyer les batailles en attente trop anciennes (ne fait rien côté client)
  @Deprecated('Utiliser cleanupOldBattles() à la place')
  Future<void> cleanupOldWaitingBattles() async {
    await cleanupOldBattles();
  }

  /// Arrêter tous les timers de polling
  void dispose() {
    for (final timer in _pollTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();
    _pollCallbacks.clear();
    _pollCounters.clear();
  }
}

