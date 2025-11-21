import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../services/user_profile_service.dart';
import '../services/trophy_service.dart';
import '../theme/app_theme.dart';
import '../widgets/display_name_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final UserProfileService _profileService = UserProfileService();
  bool _isLoading = true;
  int _totalPoints = 0;
  int _trophies = 0;
  String _displayName = '';
  String? _photoURL;
  String _userEmail = '';
  UserProfile? _profile;
  late VoidCallback _profileListener;

  @override
  void initState() {
    super.initState();
    _profileListener = () {
      final profile = _profileService.profile.value;
      if (profile != null && mounted) {
        _applyProfile(profile);
      }
    };
    _profileService.profile.addListener(_profileListener);
    _loadUserData();
  }

  @override
  void dispose() {
    _profileService.profile.removeListener(_profileListener);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await _profileService.refresh();
      final user = _auth.currentUser;
      if (profile != null) {
        _applyProfile(profile);
        return;
      } else if (user != null) {
        _displayName = user.displayName ?? 'Joueur';
        _photoURL = user.photoURL;
        _userEmail = user.email ?? 'Utilisateur anonyme';
      }
    } catch (e) {
      print('Erreur lors du chargement des données du profil: $e');
      final user = _auth.currentUser;
      if (user != null) {
        _displayName = user.displayName ?? 'Joueur';
        _photoURL = user.photoURL;
        _userEmail = user.email ?? 'Utilisateur anonyme';
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyProfile(UserProfile profile) {
    _profile = profile;
    _totalPoints = profile.points;
    _trophies = profile.trophies;
    _displayName = profile.displayName;
    _photoURL = profile.photoURL;
    _userEmail = profile.email ?? _auth.currentUser?.email ?? 'Utilisateur anonyme';
    setState(() {});
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
              'Profil',
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
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                // Photo de profil
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppTheme.primaryGradient,
                                    boxShadow: AppTheme.buttonShadow,
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.transparent,
                                    backgroundImage: _photoURL != null && _photoURL!.isNotEmpty
                                        ? NetworkImage(_photoURL!)
                                        : null,
                                    child: _photoURL == null || _photoURL!.isEmpty
                                        ? Text(
                                            _displayName.isNotEmpty
                                                ? _displayName[0].toUpperCase()
                                                : 'J',
                                            style: AppTheme.heading1.copyWith(
                                              fontSize: 40,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Nom
                                Text(
                                  _displayName,
                                  style: AppTheme.heading2.copyWith(fontSize: 24),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _isLoading ? null : _editDisplayName,
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Modifier mon nom'),
                                ),
                                if (_profileService.needsDisplayName)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                      border: Border.all(
                                        color: AppTheme.errorColor.withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Choisis un nom unique pour apparaître dans le classement.',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.errorColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                // Email
                                Text(
                                  _userEmail,
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 40),
                                // Informations importantes
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Points
                                    _buildInfoCard(
                                      icon: Icons.stars,
                                      iconColor: Colors.amber,
                                      label: 'Points',
                                      value: '$_totalPoints',
                                    ),
                                    const SizedBox(width: 20),
                                    // Trophées
                                    _buildInfoCard(
                                      icon: Icons.emoji_events,
                                      iconColor: AppTheme.accentColor,
                                      label: 'Trophées',
                                      value: TrophyService.formatTrophies(_trophies),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (_profile?.stats != null)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildInfoCard(
                                        icon: Icons.timeline,
                                        iconColor: Colors.purpleAccent,
                                        label: 'Tentatives',
                                        value: '${_profile!.stats.totalAttempts}',
                                      ),
                                      const SizedBox(width: 20),
                                      _buildInfoCard(
                                        icon: Icons.timer,
                                        iconColor: Colors.tealAccent,
                                        label: 'Temps',
                                        value: _formatPlayTime(_profile!.stats.totalPlayTime),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 40),
                                // Informations de synchronisation
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                    border: Border.all(
                                      color: AppTheme.textSecondary.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.sync_rounded,
                                            color: AppTheme.accentColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Synchronisation automatique active',
                                            style: AppTheme.bodySmall.copyWith(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Vos points, trophées et statistiques sont mis à jour en temps réel depuis le serveur.',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Bouton de déconnexion
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _showLogoutDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.logout, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'DÉCONNEXION',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTheme.heading2.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _editDisplayName() async {
    final updated = await showDisplayNameDialog(context, isInitial: false);
    if (updated) {
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nom mis à jour !'),
          ),
        );
      }
    }
  }

  String _formatPlayTime(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${duration.inMinutes} min';
  }

  // Afficher le dialogue de déconnexion
  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(
              color: AppTheme.errorColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.logout,
                color: AppTheme.errorColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Déconnexion',
                style: AppTheme.heading2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Voulez-vous vraiment vous déconnecter ?',
                  style: AppTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Flexible(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text(
                        'ANNULER',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text(
                        'DÉCONNEXION',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _logout();
    }
  }

  // Déconnexion
  Future<void> _logout() async {
    try {
      // Afficher un indicateur de chargement
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        );
      }

      // Déconnexion
      await _firebaseService.signOut();

      // Rediriger vers l'écran d'authentification
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
      }
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Fermer le dialogue de chargement
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déconnexion: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

