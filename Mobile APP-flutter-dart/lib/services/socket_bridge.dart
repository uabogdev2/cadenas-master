import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'socket_duel_service.dart';

/// Gère la connexion/déconnexion automatique du Socket.IO
/// en fonction de l'état Firebase Auth.
class SocketBridge {
  SocketBridge._();
  static final SocketBridge _instance = SocketBridge._();
  factory SocketBridge() => _instance;

  final SocketDuelService _socketService = SocketDuelService();
  StreamSubscription<User?>? _authSubscription;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _authSubscription = FirebaseAuth.instance.idTokenChanges().listen(
      (user) async {
        if (user == null) {
          await _safeDisconnect();
          return;
        }

        try {
          if (_socketService.isConnected) {
            await _socketService.reconnect();
          } else {
            await _socketService.connect();
          }
        } catch (error, stack) {
          debugPrint('SocketBridge: erreur connexion socket -> $error\n$stack');
        }
      },
    );
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _safeDisconnect();
    _initialized = false;
  }

  Future<void> _safeDisconnect() async {
    try {
      await _socketService.disconnect();
    } catch (_) {
      // Ignorer
    }
  }
}

