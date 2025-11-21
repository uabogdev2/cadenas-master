import 'dart:async';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/offline_dialog.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _dialogVisible = false;

  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _subscription ??= _connectivity.onConnectivityChanged.listen((_) {
      _refreshStatus();
    });
    _refreshStatus();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _refreshStatus() async {
    final hasInternet = await _hasInternetAccess();
    if (hasInternet != isOnline.value) {
      isOnline.value = hasInternet;
    }
    if (!hasInternet) {
      _showDialog();
    } else {
      _hideDialog();
    }
  }

  Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureOnline() async {
    if (isOnline.value) return;
    final completer = Completer<void>();

    void listener() {
      if (isOnline.value) {
        isOnline.removeListener(listener);
        completer.complete();
      }
    }

    isOnline.addListener(listener);
    _showDialog();
    return completer.future;
  }

  void _showDialog() {
    if (_dialogVisible) return;
    if (_navigatorKey?.currentState == null) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_dialogVisible && !isOnline.value) {
          _showDialog();
        }
      });
      return;
    }
    _dialogVisible = true;
    final context = _navigatorKey!.currentState!.overlay!.context;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OfflineDialog(
        onQuit: () => SystemNavigator.pop(),
        onSettings: () {
          final type = Platform.isAndroid ? AppSettingsType.wifi : AppSettingsType.settings;
          AppSettings.openAppSettings(
            asAnotherTask: true,
            type: type,
          );
        },
      ),
    );
  }

  void _hideDialog() {
    if (!_dialogVisible || _navigatorKey?.currentState == null) return;
    _dialogVisible = false;
    Navigator.of(_navigatorKey!.currentState!.overlay!.context, rootNavigator: true).pop();
  }
}

