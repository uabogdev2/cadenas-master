/// Configuration de l'API
class ApiConfig {

  static const String baseUrl = 'https://socket.cdn-aboapp.online';

  // Timeout pour les requêtes HTTP (en secondes)
  static const int requestTimeout = 30;

  @Deprecated('Préférer SocketDuelService pour la synchronisation temps réel')
  static const int battlePollInterval = 300;
}

