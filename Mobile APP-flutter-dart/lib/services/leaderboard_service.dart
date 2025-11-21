import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Modèle pour un joueur dans le classement
class LeaderboardPlayer {
  final String userId;
  final String displayName;
  final int trophies;
  final int rank;

  LeaderboardPlayer({
    required this.userId,
    required this.displayName,
    required this.trophies,
    required this.rank,
  });

  factory LeaderboardPlayer.fromFirestore(DocumentSnapshot doc, int rank) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardPlayer(
      userId: doc.id,
      displayName: data['displayName'] ?? 'Joueur',
      trophies: data['trophies'] ?? 0,
      rank: rank,
    );
  }
}

/// Service pour gérer le classement
class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  String? get _userId => _auth.currentUser?.uid;
  bool get isUserLoggedIn => _userId != null;

  /// Obtenir le top 100 des joueurs
  Future<List<LeaderboardPlayer>> getTopPlayers({int limit = 100}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('trophies', isGreaterThan: 0)
          .orderBy('trophies', descending: true)
          .limit(limit)
          .get();

      final players = <LeaderboardPlayer>[];
      int rank = 1;

      for (var doc in querySnapshot.docs) {
        players.add(LeaderboardPlayer.fromFirestore(doc, rank));
        rank++;
      }

      return players;
    } catch (e) {
      print('Erreur lors de la récupération du classement: $e');
      return [];
    }
  }

  /// Obtenir la position d'un joueur dans le classement
  Future<int?> getPlayerRank(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists || userDoc.data() == null) return null;

      final userTrophies = userDoc.data()!['trophies'] ?? 0;

      // Compter combien de joueurs ont plus de trophées
      final querySnapshot = await _firestore
          .collection('users')
          .where('trophies', isGreaterThan: userTrophies)
          .orderBy('trophies', descending: true)
          .get();

      return querySnapshot.docs.length + 1;
    } catch (e) {
      print('Erreur lors de la récupération du rang du joueur: $e');
      return null;
    }
  }

  /// Obtenir les informations du joueur actuel pour le classement
  Future<LeaderboardPlayer?> getMyPlayerInfo() async {
    if (!isUserLoggedIn) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (!userDoc.exists || userDoc.data() == null) return null;

      final rank = await getPlayerRank(_userId!);
      if (rank == null) return null;

      return LeaderboardPlayer.fromFirestore(userDoc, rank);
    } catch (e) {
      print('Erreur lors de la récupération des informations du joueur: $e');
      return null;
    }
  }

  /// Stream du top 100 pour les mises à jour en temps réel
  Stream<List<LeaderboardPlayer>> getTopPlayersStream({int limit = 100}) {
    return _firestore
        .collection('users')
        .where('trophies', isGreaterThan: 0)
        .orderBy('trophies', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final players = <LeaderboardPlayer>[];
      int rank = 1;

      for (var doc in snapshot.docs) {
        players.add(LeaderboardPlayer.fromFirestore(doc, rank));
        rank++;
      }

      return players;
    });
  }
}

