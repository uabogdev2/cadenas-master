import 'user_profile_service.dart';

/// Service pour accéder aux trophées synchronisés avec le serveur Node.js.
class TrophyService {
  TrophyService._internal();
  static final TrophyService _instance = TrophyService._internal();
  factory TrophyService() => _instance;

  final UserProfileService _profileService = UserProfileService();

  Future<int> getMyTrophies() async {
    final profile = await _profileService.ensureProfile();
    return profile?.trophies ?? 0;
  }

  static String formatTrophies(int trophies) {
    if (trophies < 1000) {
      return trophies.toString();
    } else if (trophies < 1000000) {
      final k = trophies / 1000;
      return k % 1 == 0 ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
    } else {
      final m = trophies / 1000000;
      return m % 1 == 0 ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
  }
}

