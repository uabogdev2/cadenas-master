import 'dart:async';
import 'api_service.dart';

/// Modèle pour un joueur dans le classement
class LeaderboardPlayer {
  final String userId;
  final String displayName;
  final int trophies;
  final int rank;
  final String? photoUrl;

  LeaderboardPlayer({
    required this.userId,
    required this.displayName,
    required this.trophies,
    required this.rank,
    this.photoUrl,
  });

  factory LeaderboardPlayer.fromJson(Map<String, dynamic> json, int rank) {
    return LeaderboardPlayer(
      userId: json['id'] ?? json['userId'] ?? '',
      displayName: json['displayName'] ?? 'Joueur',
      trophies: json['trophies'] ?? 0,
      rank: rank,
      photoUrl: json['photoURL']?.toString(),
    );
  }
}

/// Service pour gérer le classement via le serveur Node.js
class LeaderboardServiceNodeJs {
  final ApiService _apiService = ApiService();

  // Singleton pattern
  static final LeaderboardServiceNodeJs _instance = LeaderboardServiceNodeJs._internal();
  factory LeaderboardServiceNodeJs() => _instance;
  LeaderboardServiceNodeJs._internal();

  /// Obtenir le top 100 des joueurs
  Future<List<LeaderboardPlayer>> getTopPlayers({int limit = 100}) async {
    try {
      final response = await _apiService.get('/api/users/leaderboard', queryParameters: {
        'limit': limit.toString(),
      }, requireAuth: false);

      if (response != null && response['success'] == true) {
        final players = response['players'] as List;
        final leaderboardPlayers = <LeaderboardPlayer>[];
        int rank = 1;

        for (var playerJson in players) {
          leaderboardPlayers.add(LeaderboardPlayer.fromJson(playerJson as Map<String, dynamic>, rank));
          rank++;
        }

        return leaderboardPlayers;
      } else {
        print('Erreur lors de la récupération du classement: ${response?['error']}');
        return [];
      }
    } catch (e) {
      print('Erreur lors de la récupération du classement: $e');
      return [];
    }
  }

  /// Obtenir la position d'un joueur dans le classement
  Future<int?> getPlayerRank(String userId) async {
    try {
      final response = await _apiService.get('/api/users/$userId/rank', requireAuth: false);

      if (response != null && response['success'] == true) {
        return response['rank'] as int?;
      } else {
        return null;
      }
    } catch (e) {
      print('Erreur lors de la récupération du rang du joueur: $e');
      return null;
    }
  }

  /// Obtenir les informations du joueur actuel pour le classement
  Future<LeaderboardPlayer?> getMyPlayerInfo() async {
    try {
      // Obtenir les informations de l'utilisateur actuel
      final userResponse = await _apiService.get('/api/users/me');
      if (userResponse == null || userResponse['success'] != true) {
        return null;
      }

      final user = userResponse['user'] as Map<String, dynamic>;
      final userId = user['id'] as String;

      // Obtenir le rang du joueur
      final rank = await getPlayerRank(userId);
      if (rank == null) {
        return null;
      }

      return LeaderboardPlayer(
        userId: userId,
        displayName: user['displayName'] ?? 'Joueur',
        trophies: user['trophies'] ?? 0,
        rank: rank,
        photoUrl: user['photoURL']?.toString(),
      );
    } catch (e) {
      print('Erreur lors de la récupération des informations du joueur: $e');
      return null;
    }
  }

  /// Stream du top 100 pour les mises à jour en temps réel (polling)
  /// [callback] : Fonction appelée à chaque mise à jour du classement
  /// [interval] : Intervalle de polling en millisecondes (défaut: 5000)
  void getTopPlayersStream(
    Function(List<LeaderboardPlayer>) callback, {
    int interval = 5000,
  }) {
    Timer.periodic(Duration(milliseconds: interval), (timer) async {
      try {
        final players = await getTopPlayers();
        callback(players);
      } catch (e) {
        print('Erreur lors du polling du classement: $e');
      }
    });
  }
}

