import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class VersionCheckService {
  Future<void> checkVersion(BuildContext context) async {
    try {
      // 1. Récupérer la version actuelle de l'app
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // 2. Récupérer la config depuis le serveur
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/config'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final config = data['config'];

          final bool forceUpdate = config['force_update'] ?? false;
          final bool maintenanceMode = config['maintenance_mode'] ?? false;
          final String minVersionAndroid = config['min_version_android'] ?? '1.0.0';
          final String minVersionIos = config['min_version_ios'] ?? '1.0.0';

          if (maintenanceMode) {
            _showMaintenanceDialog(context);
            return;
          }

          String minVersion = Platform.isAndroid ? minVersionAndroid : minVersionIos;

          bool updateNeeded = _isVersionLower(currentVersion, minVersion);

          if (updateNeeded || (forceUpdate && updateNeeded)) {
             _showUpdateDialog(context, forceUpdate);
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification de version: $e');
      // En cas d'erreur réseau, on laisse passer (sauf si critique)
    }
  }

  bool _isVersionLower(String current, String min) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> minParts = min.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      int c = i < currentParts.length ? currentParts[i] : 0;
      int m = i < minParts.length ? minParts[i] : 0;

      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, bool force) {
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (context) => WillPopScope(
        onWillPop: () async => !force,
        child: AlertDialog(
          title: const Text('Mise à jour requise'),
          content: const Text('Une nouvelle version de l\'application est disponible. Veuillez mettre à jour pour continuer à jouer.'),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Plus tard'),
              ),
            ElevatedButton(
              onPressed: () {
                // Ouvrir le store
                _launchStore();
              },
              child: const Text('Mettre à jour'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Maintenance'),
          content: const Text('Le jeu est actuellement en maintenance. Veuillez réessayer plus tard.'),
        ),
      ),
    );
  }

  void _launchStore() {
    // Implémenter la logique pour ouvrir le Play Store ou App Store
  }
}
