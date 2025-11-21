import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/socket_config.dart';

class SocketDuelService {
  SocketDuelService._internal();
  static final SocketDuelService _instance = SocketDuelService._internal();
  factory SocketDuelService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  IO.Socket? _socket;
  bool _isConnecting = false;
  Completer<void>? _connectCompleter;

  final _connectionController = StreamController<bool>.broadcast();
  final _battleCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _battleFoundController = StreamController<Map<String, dynamic>>.broadcast();
  final _friendlyRoomController = StreamController<Map<String, dynamic>>.broadcast();
  final _battleStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _battleUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _battleFinishedController = StreamController<Map<String, dynamic>>.broadcast();
  final _battleDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connectionChanges => _connectionController.stream;
  Stream<Map<String, dynamic>> get battleCreated => _battleCreatedController.stream;
  Stream<Map<String, dynamic>> get battleFound => _battleFoundController.stream;
  Stream<Map<String, dynamic>> get friendlyRoomFound => _friendlyRoomController.stream;
  Stream<Map<String, dynamic>> get battleStarted => _battleStartedController.stream;
  Stream<Map<String, dynamic>> get battleUpdated => _battleUpdatedController.stream;
  Stream<Map<String, dynamic>> get battleFinished => _battleFinishedController.stream;
  Stream<Map<String, dynamic>> get battleDeleted => _battleDeletedController.stream;
  Stream<Map<String, dynamic>> get socketErrors => _errorController.stream;

  bool get isConnected => _socket?.connected == true;
  bool get isConnecting => _isConnecting;
  void _log(String message, [dynamic data]) {
    if (data != null) {
      debugPrint('[SocketDuelService] $message -> $data');
    } else {
      debugPrint('[SocketDuelService] $message');
    }
  }

  /// Établit (ou réutilise) la connexion Socket.IO.
  Future<void> connect() async {
    if (isConnected) return;
    if (_connectCompleter != null) {
      return _connectCompleter!.future;
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Utilisateur non connecté');
    }

    _isConnecting = true;
    _log('Connexion en cours pour ${user.uid}');
    final completer = Completer<void>();
    _connectCompleter = completer;

    IO.Socket? tempSocket;
    try {
      final token = await user.getIdToken();

      final options = IO.OptionBuilder()
          .setTransports(SocketConfig.transports)
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableForceNew()
          .build();

      tempSocket = IO.io(SocketConfig.baseUrl, options);
      _socket = tempSocket;
      _registerListeners(tempSocket);
      tempSocket.connect();
      _log('Socket connect() appelé');
    } catch (error) {
      tempSocket?.dispose();
      if (_socket == tempSocket) {
        _socket = null;
      }
      _completeConnection(error);
      rethrow;
    }

    return completer.future;
  }

  void _registerListeners(IO.Socket socket) {
    socket.onConnect((_) {
      if (_socket != socket) {
        return;
      }
      _log('Connecté (socketId=${socket.id})');
      _completeConnection();
      _connectionController.add(true);
    });
    socket.onDisconnect((reason) {
      if (_socket == socket) {
        _socket = null;
      }
      final reasonText = reason?.toString();
      _log('Déconnecté', reasonText);
      final hadPendingConnection = _connectCompleter != null && !_connectCompleter!.isCompleted;
      _completeConnection(
        hadPendingConnection ? StateError('Déconnecté avant connexion: $reasonText') : null,
      );
      _connectionController.add(false);
    });
    socket.onReconnect((attempt) {
      _log('Reconnecté', attempt);
      _connectionController.add(true);
    });
    socket.onConnectError((error) {
      _handleConnectError(socket, error);
    });

    void bind(String event, StreamController<Map<String, dynamic>> controller) {
      socket.on(event, (payload) {
        _log('event:$event', payload);
        controller.addSafe(payload);
      });
    }

    bind('battleCreated', _battleCreatedController);
    bind('battleFound', _battleFoundController);
    bind('friendlyRoomFound', _friendlyRoomController);
    bind('battleStarted', _battleStartedController);
    bind('battleUpdated', _battleUpdatedController);
    bind('battleFinished', _battleFinishedController);
    bind('battleDeleted', _battleDeletedController);
    socket.on('error', (payload) {
      _log('event:error', payload);
      _errorController.addSafe(payload);
    });
  }

  Future<void> disconnect() async {
    _log('Déconnexion demandée');
    final socket = _socket;
    _socket = null;
    _completeConnection(StateError('Déconnexion demandée'));
    if (socket != null) {
      try {
        socket.disconnect();
      } catch (_) {}
      try {
        socket.dispose();
      } catch (_) {}
    }
    _connectionController.add(false);
  }

  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  void createBattle({String mode = 'ranked', String? roomId}) {
    _emit('createBattle', {
      'mode': mode,
      if (roomId != null) 'roomId': roomId,
    });
  }

  void matchmakingRanked() => _emit('matchmakingRanked');
  void findBattle({String mode = 'ranked'}) => _emit('findBattle', mode);
  void findFriendlyRoom(String roomId) => _emit('findFriendlyRoom', {'roomId': roomId});
  void joinBattle(String battleId) =>
      _emit('joinBattle', {'battleId': int.tryParse(battleId) ?? battleId});
  void incrementScore(String battleId, int questionIndex) => _emit('incrementScoreAndNext', {
        'battleId': int.tryParse(battleId) ?? battleId,
        'questionIndex': questionIndex,
      });
  void nextQuestion(String battleId) =>
      _emit('nextQuestion', {'battleId': int.tryParse(battleId) ?? battleId});
  void abandonBattle(String battleId) =>
      _emit('abandonBattle', {'battleId': int.tryParse(battleId) ?? battleId});
  void finishBattle(String battleId) =>
      _emit('finishBattle', {'battleId': int.tryParse(battleId) ?? battleId});
  void deleteBattle(String battleId) =>
      _emit('deleteBattle', {'battleId': int.tryParse(battleId) ?? battleId});

  void _emit(String event, [dynamic data]) {
    if (_socket == null) {
      throw StateError('Socket non connectée. Appelez connect() avant d\'émettre un événement.');
    }
    _log('emit:$event', data);
    _socket!.emit(event, data);
  }

  void _handleConnectError(IO.Socket socket, dynamic error) {
    if (_socket == socket) {
      _socket = null;
    }
    final message = error?.toString() ?? 'unknown';
    _log('connect_error', message);
    _connectionController.add(false);
    _errorController.addSafe({
      'action': 'connect_error',
      'error': message,
    });
    try {
      socket.disconnect();
    } catch (_) {}
    try {
      socket.dispose();
    } catch (_) {}
    _completeConnection(StateError('connect_error: $message'));
  }

  void _completeConnection([Object? error]) {
    final completer = _connectCompleter;
    if (completer != null && !completer.isCompleted) {
      if (error != null) {
        completer.completeError(error);
      } else {
        completer.complete();
      }
    }
    _connectCompleter = null;
    _isConnecting = false;
  }

  void dispose() {
    _connectionController.close();
    _battleCreatedController.close();
    _battleFoundController.close();
    _friendlyRoomController.close();
    _battleStartedController.close();
    _battleUpdatedController.close();
    _battleFinishedController.close();
    _battleDeletedController.close();
    _errorController.close();
    _socket?.dispose();
    _socket = null;
  }
}

extension _StreamControllerHelpers on StreamController<Map<String, dynamic>> {
  void addSafe(dynamic data) {
    if (isClosed) return;
    if (data is Map<String, dynamic>) {
      add(data);
    } else if (data is Map) {
      add(Map<String, dynamic>.from(data));
    } else if (data == null) {
      add({});
    } else {
      add({'data': data});
    }
  }
}

