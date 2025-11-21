import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  // Chemins des fichiers audio (noms réels des fichiers)
  static const String _gameMusicPath = 'sound/game-music.mp3';
  static const String _gameClicPath = 'sound/game-clic.wav';
  static const String _succesPath = 'sound/succes.wav';
  static const String _echecPath = 'sound/echec.wav';
  
  // Clés pour SharedPreferences
  static const String _musicEnabledKey = 'music_enabled';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _musicVolumeKey = 'music_volume';
  static const String _soundVolumeKey = 'sound_volume';
  
  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();
  
  // Players
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _soundPlayer = AudioPlayer();
  
  // État
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  double _musicVolume = 0.5;
  double _soundVolume = 0.7;
  bool _isInitialized = false;
  bool _isMusicPlaying = false;
  
  // Getters
  bool get musicEnabled => _musicEnabled;
  bool get soundEnabled => _soundEnabled;
  double get musicVolume => _musicVolume;
  double get soundVolume => _soundVolume;
  bool get isMusicPlaying => _isMusicPlaying;
  
  // Initialiser le service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Charger les préférences
      await _loadPreferences();
      
      // Configurer le player de musique pour la lecture en boucle
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_musicVolume);
      
      // Configurer le player de sons
      await _soundPlayer.setVolume(_soundVolume);
      
      // Écouter les événements de fin de lecture
      _musicPlayer.onPlayerComplete.listen((_) {
        _isMusicPlaying = false;
      });
      
      _isInitialized = true;
      print('AudioService initialisé avec succès');
      print('Musique activée: $_musicEnabled, Volume: $_musicVolume');
      print('Sons activés: $_soundEnabled, Volume: $_soundVolume');
    } catch (e, stackTrace) {
      print('Erreur lors de l\'initialisation de l\'AudioService: $e');
      print('Stack trace: $stackTrace');
      _isInitialized = true; // Marquer comme initialisé même en cas d'erreur
    }
  }
  
  // Charger les préférences depuis SharedPreferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      _musicVolume = prefs.getDouble(_musicVolumeKey) ?? 0.5;
      _soundVolume = prefs.getDouble(_soundVolumeKey) ?? 0.7;
    } catch (e) {
      print('Erreur lors du chargement des préférences audio: $e');
    }
  }
  
  // Sauvegarder les préférences dans SharedPreferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicEnabledKey, _musicEnabled);
      await prefs.setBool(_soundEnabledKey, _soundEnabled);
      await prefs.setDouble(_musicVolumeKey, _musicVolume);
      await prefs.setDouble(_soundVolumeKey, _soundVolume);
    } catch (e) {
      print('Erreur lors de la sauvegarde des préférences audio: $e');
    }
  }
  
  // Jouer la musique de fond
  Future<void> playMusic() async {
    if (!_isInitialized) await initialize();
    
    if (!_musicEnabled) {
      print('Musique désactivée, ne pas jouer');
      return;
    }
    
    try {
      if (!_isMusicPlaying) {
        print('Tentative de lecture de la musique: $_gameMusicPath');
        // Vérifier que le plugin est disponible avant de jouer
        await _musicPlayer.play(AssetSource(_gameMusicPath));
        _isMusicPlaying = true;
        print('Musique de fond démarrée avec succès');
      } else {
        print('Musique déjà en cours de lecture');
      }
    } catch (e, stackTrace) {
      print('ERREUR lors de la lecture de la musique: $e');
      print('Chemin utilisé: $_gameMusicPath');
      print('Stack trace: $stackTrace');
      _isMusicPlaying = false;
      
      // Si c'est une MissingPluginException, le plugin n'est pas enregistré
      // Cela peut arriver si l'app n'a pas été complètement reconstruite
      if (e.toString().contains('MissingPluginException')) {
        print('ATTENTION: Le plugin audioplayers n\'est pas enregistré.');
        print('Solution: Arrêtez complètement l\'app et relancez-la (pas juste hot reload).');
        print('Ou faites: flutter clean && flutter pub get && flutter run');
      }
    }
  }
  
  // Arrêter la musique de fond
  Future<void> stopMusic() async {
    if (!_isInitialized) return;
    
    try {
      await _musicPlayer.stop();
      _isMusicPlaying = false;
      print('Musique de fond arrêtée');
    } catch (e) {
      // Ignorer les erreurs si le plugin n'est pas disponible
      if (!e.toString().contains('MissingPluginException')) {
        print('Erreur lors de l\'arrêt de la musique: $e');
      }
    }
  }
  
  // Pause la musique de fond
  Future<void> pauseMusic() async {
    if (!_isInitialized) return;
    
    try {
      await _musicPlayer.pause();
      _isMusicPlaying = false;
      print('Musique de fond mise en pause');
    } catch (e) {
      // Ignorer les erreurs si le plugin n'est pas disponible
      if (!e.toString().contains('MissingPluginException')) {
        print('Erreur lors de la pause de la musique: $e');
      }
    }
  }
  
  // Reprendre la musique de fond
  Future<void> resumeMusic() async {
    if (!_isInitialized) return;
    
    if (!_musicEnabled) return;
    
    try {
      await _musicPlayer.resume();
      _isMusicPlaying = true;
      print('Musique de fond reprise');
    } catch (e) {
      // Ignorer les erreurs si le plugin n'est pas disponible
      if (!e.toString().contains('MissingPluginException')) {
        print('Erreur lors de la reprise de la musique: $e');
      }
    }
  }
  
  // Jouer le son de clic (pour les boutons, sauf en jeu)
  Future<void> playClic() async {
    if (!_isInitialized) await initialize();
    
    if (!_soundEnabled) {
      print('Sons désactivés, ne pas jouer le clic');
      return;
    }
    
    try {
      print('Tentative de lecture du son de clic: $_gameClicPath');
      await _soundPlayer.play(AssetSource(_gameClicPath));
      print('Son de clic joué avec succès');
    } catch (e, stackTrace) {
      print('ERREUR lors de la lecture du son de clic: $e');
      print('Chemin utilisé: $_gameClicPath');
      print('Stack trace: $stackTrace');
    }
  }
  
  // Jouer le son de succès (en jeu)
  Future<void> playSucces() async {
    if (!_isInitialized) await initialize();
    
    if (!_soundEnabled) {
      print('Sons désactivés, ne pas jouer le succès');
      return;
    }
    
    try {
      print('Tentative de lecture du son de succès: $_succesPath');
      await _soundPlayer.play(AssetSource(_succesPath));
      print('Son de succès joué avec succès');
    } catch (e, stackTrace) {
      print('ERREUR lors de la lecture du son de succès: $e');
      print('Chemin utilisé: $_succesPath');
      print('Stack trace: $stackTrace');
    }
  }
  
  // Jouer le son d'échec (en jeu)
  Future<void> playEchec() async {
    if (!_isInitialized) await initialize();
    
    if (!_soundEnabled) {
      print('Sons désactivés, ne pas jouer l\'échec');
      return;
    }
    
    try {
      print('Tentative de lecture du son d\'échec: $_echecPath');
      await _soundPlayer.play(AssetSource(_echecPath));
      print('Son d\'échec joué avec succès');
    } catch (e, stackTrace) {
      print('ERREUR lors de la lecture du son d\'échec: $e');
      print('Chemin utilisé: $_echecPath');
      print('Stack trace: $stackTrace');
    }
  }
  
  // Activer/Désactiver la musique
  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    await _savePreferences();
    
    if (enabled) {
      await playMusic();
    } else {
      await stopMusic();
    }
  }
  
  // Activer/Désactiver les sons
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _savePreferences();
  }
  
  // Définir le volume de la musique (0.0 à 1.0)
  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    await _musicPlayer.setVolume(_musicVolume);
    await _savePreferences();
  }
  
  // Définir le volume des sons (0.0 à 1.0)
  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume.clamp(0.0, 1.0);
    await _soundPlayer.setVolume(_soundVolume);
    await _savePreferences();
  }
  
  // Libérer les ressources
  Future<void> dispose() async {
    try {
      await _musicPlayer.dispose();
      await _soundPlayer.dispose();
      _isInitialized = false;
      print('AudioService libéré');
    } catch (e) {
      print('Erreur lors de la libération de l\'AudioService: $e');
    }
  }
}

