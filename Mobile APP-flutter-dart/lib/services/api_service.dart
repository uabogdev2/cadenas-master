import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

/// Service API pour communiquer avec le serveur Node.js
class ApiService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Obtenir le token d'authentification Firebase
  Future<String?> _getAuthToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (e) {
      print('Erreur lors de la récupération du token: $e');
      return null;
    }
  }

  /// Effectuer une requête HTTP GET
  Future<Map<String, dynamic>?> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    try {
      // Construire l'URL avec les paramètres de requête
      var uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      // Préparer les headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      // Ajouter le token d'authentification si requis
      if (requireAuth) {
        final token = await _getAuthToken();
        if (token == null) {
          print('Token d\'authentification non disponible');
          return null;
        }
        headers['Authorization'] = 'Bearer $token';
      }

      // Effectuer la requête
      final response = await http
          .get(uri, headers: headers)
          .timeout(Duration(seconds: ApiConfig.requestTimeout));

      // Vérifier le code de statut
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        print('Erreur d\'authentification: ${response.statusCode}');
        return {'success': false, 'error': 'Non autorisé'};
      } else if (response.statusCode == 403) {
        print('Accès refusé: ${response.statusCode}');
        return {'success': false, 'error': 'Accès refusé'};
      } else if (response.statusCode == 404) {
        print('Ressource non trouvée: ${response.statusCode}');
        return {'success': false, 'error': 'Ressource non trouvée'};
      } else {
        print('Erreur HTTP: ${response.statusCode} - ${response.body}');
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (_) {
          return {
            'success': false,
            'error': 'Erreur HTTP ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('Erreur lors de la requête GET $endpoint: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Effectuer une requête HTTP POST
  Future<Map<String, dynamic>?> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      // Préparer les headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      // Ajouter le token d'authentification si requis
      if (requireAuth) {
        final token = await _getAuthToken();
        if (token == null) {
          print('Token d\'authentification non disponible');
          return null;
        }
        headers['Authorization'] = 'Bearer $token';
      }

      // Préparer le corps de la requête
      final bodyJson = body != null ? json.encode(body) : null;

      // Effectuer la requête
      final response = await http
          .post(uri, headers: headers, body: bodyJson)
          .timeout(Duration(seconds: ApiConfig.requestTimeout));

      // Vérifier le code de statut
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        if (response.body.isEmpty) {
          return {'success': true};
        }
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print('Erreur HTTP: ${response.statusCode} - ${response.body}');
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (_) {
          return {
            'success': false,
            'error': 'Erreur HTTP ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('Erreur lors de la requête POST $endpoint: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Effectuer une requête HTTP PUT
  Future<Map<String, dynamic>?> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      // Préparer les headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      // Ajouter le token d'authentification si requis
      if (requireAuth) {
        final token = await _getAuthToken();
        if (token == null) {
          print('Token d\'authentification non disponible');
          return null;
        }
        headers['Authorization'] = 'Bearer $token';
      }

      // Préparer le corps de la requête
      final bodyJson = body != null ? json.encode(body) : null;

      // Effectuer la requête
      final response = await http
          .put(uri, headers: headers, body: bodyJson)
          .timeout(Duration(seconds: ApiConfig.requestTimeout));

      // Vérifier le code de statut
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        if (response.body.isEmpty) {
          return {'success': true};
        }
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print('Erreur HTTP: ${response.statusCode} - ${response.body}');
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (_) {
          return {
            'success': false,
            'error': 'Erreur HTTP ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('Erreur lors de la requête PUT $endpoint: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Effectuer une requête HTTP DELETE
  Future<Map<String, dynamic>?> delete(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      // Préparer les headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      // Ajouter le token d'authentification si requis
      if (requireAuth) {
        final token = await _getAuthToken();
        if (token == null) {
          print('Token d\'authentification non disponible');
          return null;
        }
        headers['Authorization'] = 'Bearer $token';
      }

      // Effectuer la requête
      final response = await http
          .delete(uri, headers: headers)
          .timeout(Duration(seconds: ApiConfig.requestTimeout));

      // Vérifier le code de statut
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        if (response.body.isEmpty) {
          return {'success': true};
        }
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print('Erreur HTTP: ${response.statusCode} - ${response.body}');
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (_) {
          return {
            'success': false,
            'error': 'Erreur HTTP ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('Erreur lors de la requête DELETE $endpoint: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Vérifier si l'utilisateur est authentifié
  bool get isAuthenticated => _auth.currentUser != null;

  /// Obtenir l'ID de l'utilisateur actuel
  String? get userId => _auth.currentUser?.uid;
}

