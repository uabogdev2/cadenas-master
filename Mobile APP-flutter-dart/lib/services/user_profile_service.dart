import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class UserStatsSummary {
  final int totalAttempts;
  final int totalPlayTime;
  final Map<String, dynamic> bestTimes;

  const UserStatsSummary({
    required this.totalAttempts,
    required this.totalPlayTime,
    required this.bestTimes,
  });

  factory UserStatsSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UserStatsSummary(
        totalAttempts: 0,
        totalPlayTime: 0,
        bestTimes: {},
      );
    }
    return UserStatsSummary(
      totalAttempts: json['totalAttempts'] is int ? json['totalAttempts'] as int : 0,
      totalPlayTime: json['totalPlayTime'] is int ? json['totalPlayTime'] as int : 0,
      bestTimes: json['bestTimes'] is Map<String, dynamic> ? json['bestTimes'] as Map<String, dynamic> : {},
    );
  }
}

class UserProfile {
  final String id;
  final String displayName;
  final String? email;
  final String? photoURL;
  final int points;
  final int trophies;
  final int completedLevels;
  final UserStatsSummary stats;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.photoURL,
    required this.points,
    required this.trophies,
    required this.completedLevels,
    required this.stats,
  });

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoURL,
    int? points,
    int? trophies,
    int? completedLevels,
    UserStatsSummary? stats,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      points: points ?? this.points,
      trophies: trophies ?? this.trophies,
      completedLevels: completedLevels ?? this.completedLevels,
      stats: stats ?? this.stats,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json, Map<String, dynamic>? statsJson) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Joueur',
      email: json['email']?.toString(),
      photoURL: json['photoURL']?.toString(),
      points: json['points'] is int ? json['points'] as int : 0,
      trophies: json['trophies'] is int ? json['trophies'] as int : 0,
      completedLevels: json['completedLevels'] is int ? json['completedLevels'] as int : 0,
      stats: UserStatsSummary.fromJson(statsJson),
    );
  }
}

class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  static final RegExp _displayNameRegex = RegExp(r'^[A-Za-z0-9]{3,10}$');

  final ApiService _apiService = ApiService();
  final ValueNotifier<UserProfile?> profile = ValueNotifier<UserProfile?>(null);
  bool _isRefreshing = false;

  UserProfile? get current => profile.value;
  int get currentPoints => profile.value?.points ?? 0;
  int get currentTrophies => profile.value?.trophies ?? 0;
  bool get needsDisplayName => !isDisplayNameFormatValid(profile.value?.displayName ?? '');

  Future<UserProfile?> ensureProfile({bool force = false}) async {
    if (!force && profile.value != null) {
      return profile.value;
    }
    return await refresh(force: force);
  }

  Future<UserProfile?> refresh({bool force = false}) async {
    if (_isRefreshing) {
      return profile.value;
    }
    _isRefreshing = true;
    try {
      final response = await _apiService.get(
        '/api/users/me',
        queryParameters: {'includeStats': 'true'},
      );
      if (response == null || response['success'] != true) {
        debugPrint('UserProfileService.refresh: impossible de récupérer le profil (${response?['error']})');
        return profile.value;
      }

      final userJson = response['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        debugPrint('UserProfileService.refresh: réponse invalide (user manquant)');
        return profile.value;
      }

      final statsJson = response['stats'] as Map<String, dynamic>?;
      final newProfile = UserProfile.fromJson(userJson, statsJson);
      profile.value = newProfile;
      return newProfile;
    } catch (e) {
      debugPrint('UserProfileService.refresh: erreur $e');
      return profile.value;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<bool> adjustPoints(int delta) async {
    try {
      final response = await _apiService.post(
        '/api/users/me/points/adjust',
        body: {'delta': delta},
      );

      if (response == null || response['success'] != true) {
        debugPrint('UserProfileService.adjustPoints: échec (${response?['error']})');
        return false;
      }

      final updatedPoints = response['points'] is int ? response['points'] as int : currentPoints;
      if (profile.value != null) {
        profile.value = profile.value!.copyWith(points: updatedPoints);
      } else {
        await refresh(force: true);
      }
      return true;
    } catch (e) {
      debugPrint('UserProfileService.adjustPoints: erreur $e');
      return false;
    }
  }

  Future<bool> adjustTrophies(int delta) async {
    try {
      final response = await _apiService.post(
        '/api/users/me/trophies/adjust',
        body: {'delta': delta},
      );

      if (response == null || response['success'] != true) {
        debugPrint('UserProfileService.adjustTrophies: échec (${response?['error']})');
        return false;
      }

      final updatedTrophies = response['trophies'] is int ? response['trophies'] as int : currentTrophies;
      if (profile.value != null) {
        profile.value = profile.value!.copyWith(trophies: updatedTrophies);
      } else {
        await refresh(force: true);
      }
      return true;
    } catch (e) {
      debugPrint('UserProfileService.adjustTrophies: erreur $e');
      return false;
    }
  }

  Future<void> clear() async {
    profile.value = null;
  }

  String _sanitizeDisplayName(String value) => value.trim();

  bool isDisplayNameFormatValid(String value) {
    final sanitized = _sanitizeDisplayName(value);
    return _displayNameRegex.hasMatch(sanitized);
  }

  Future<bool> isDisplayNameAvailable(String value) async {
    final sanitized = _sanitizeDisplayName(value);
    if (!isDisplayNameFormatValid(sanitized)) {
      return false;
    }
    try {
      final response = await _apiService.get(
        '/api/users/display-name/${Uri.encodeComponent(sanitized)}',
      );
      if (response == null) return false;
      return response['valid'] == true && response['available'] == true;
    } catch (e) {
      debugPrint('UserProfileService.isDisplayNameAvailable: erreur $e');
      return false;
    }
  }

  Future<DisplayNameUpdateResult> updateDisplayName(String value) async {
    final sanitized = _sanitizeDisplayName(value);
    if (!isDisplayNameFormatValid(sanitized)) {
      return DisplayNameUpdateResult(
        success: false,
        errorCode: 'DISPLAY_NAME_INVALID',
        message: 'Le nom doit contenir 3 à 10 caractères alphanumériques sans espace.',
      );
    }

    try {
      final response = await _apiService.post(
        '/api/users/display-name',
        body: {'displayName': sanitized},
      );

      if (response != null && response['success'] == true) {
        await refresh(force: true);
        return DisplayNameUpdateResult(success: true, displayName: sanitized);
      }

      return DisplayNameUpdateResult(
        success: false,
        errorCode: response?['errorCode']?.toString(),
        message: response?['error']?.toString() ?? 'Erreur inconnue',
      );
    } catch (e) {
      debugPrint('UserProfileService.updateDisplayName: erreur $e');
      return DisplayNameUpdateResult(
        success: false,
        errorCode: 'UNKNOWN',
        message: 'Impossible de mettre à jour le nom.',
      );
    }
  }
}

class DisplayNameUpdateResult {
  final bool success;
  final String? errorCode;
  final String? message;
  final String? displayName;

  DisplayNameUpdateResult({
    required this.success,
    this.errorCode,
    this.message,
    this.displayName,
  });
}

