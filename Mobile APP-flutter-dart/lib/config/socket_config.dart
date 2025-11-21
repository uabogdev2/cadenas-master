/// Configuration du serveur Socket.IO (temps réel)
class SocketConfig {

  static const String baseUrl = 'https://test.cdn-aboapp.online';

  /// Transports autorisés (activer polling pour les proxies LiteSpeed).
  static const List<String> transports = ['websocket', 'polling'];
}

