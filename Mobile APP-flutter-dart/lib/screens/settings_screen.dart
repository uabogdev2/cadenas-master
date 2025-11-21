import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AudioService _audioService = AudioService();
  bool _isLoading = false;
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  double _musicVolume = 0.5;
  double _soundVolume = 0.7;
  
  @override
  void initState() {
    super.initState();
    _loadAudioSettings();
  }
  
  Future<void> _loadAudioSettings() async {
    setState(() {
      _isLoading = true;
    });
    await _audioService.initialize();
    setState(() {
      _musicEnabled = _audioService.musicEnabled;
      _soundEnabled = _audioService.soundEnabled;
      _musicVolume = _audioService.musicVolume;
      _soundVolume = _audioService.soundVolume;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
        title: Text(
          'Paramètres',
          style: AppTheme.heading3.copyWith(fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Paramètres audio
                  Text(
                    'Audio',
                    style: AppTheme.heading2.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        // Musique
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.music_note, color: AppTheme.primaryColor, size: 24),
                          ),
                          title: Text(
                            'Musique',
                            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _musicEnabled ? 'Activée' : 'Désactivée',
                            style: AppTheme.bodyMedium,
                          ),
                          trailing: Switch(
                            value: _musicEnabled,
                            onChanged: (value) async {
                              setState(() {
                                _musicEnabled = value;
                              });
                              await _audioService.setMusicEnabled(value);
                            },
                            activeColor: AppTheme.primaryColor,
                          ),
                        ),
                        if (_musicEnabled) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.volume_down, color: AppTheme.textSecondary, size: 20),
                                Expanded(
                                  child: Slider(
                                    value: _musicVolume,
                                    min: 0.0,
                                    max: 1.0,
                                    divisions: 10,
                                    label: '${(_musicVolume * 100).toInt()}%',
                                    onChanged: (value) async {
                                      setState(() {
                                        _musicVolume = value;
                                      });
                                      await _audioService.setMusicVolume(value);
                                    },
                                    activeColor: AppTheme.primaryColor,
                                    inactiveColor: AppTheme.surfaceColor,
                                  ),
                                ),
                                Icon(Icons.volume_up, color: AppTheme.textSecondary, size: 20),
                              ],
                            ),
                          ),
                        ],
                        Divider(
                          color: AppTheme.textTertiary.withOpacity(0.3),
                          thickness: 1,
                        ),
                        
                        // Sons
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.volume_up, color: AppTheme.accentColor, size: 24),
                          ),
                          title: Text(
                            'Sons',
                            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _soundEnabled ? 'Activés' : 'Désactivés',
                            style: AppTheme.bodyMedium,
                          ),
                          trailing: Switch(
                            value: _soundEnabled,
                            onChanged: (value) async {
                              setState(() {
                                _soundEnabled = value;
                              });
                              await _audioService.setSoundEnabled(value);
                            },
                            activeColor: AppTheme.accentColor,
                          ),
                        ),
                        if (_soundEnabled) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.volume_down, color: AppTheme.textSecondary, size: 20),
                                Expanded(
                                  child: Slider(
                                    value: _soundVolume,
                                    min: 0.0,
                                    max: 1.0,
                                    divisions: 10,
                                    label: '${(_soundVolume * 100).toInt()}%',
                                    onChanged: (value) async {
                                      setState(() {
                                        _soundVolume = value;
                                      });
                                      await _audioService.setSoundVolume(value);
                                    },
                                    activeColor: AppTheme.accentColor,
                                    inactiveColor: AppTheme.surfaceColor,
                                  ),
                                ),
                                Icon(Icons.volume_up, color: AppTheme.textSecondary, size: 20),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }
} 