import 'package:flutter/material.dart';
import '../models/level_model.dart';
import '../services/game_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'game_screen.dart';
import '../theme/app_theme.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final GameService _gameService = GameService();
  List<Level> _levels = [];
  bool _isLoading = true;
  int _totalPoints = 0;
  int _completedLevels = 0;
  Map<int, int?> _bestTimes = {};
  Map<int, int> _attempts = {};

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Charger toutes les données en parallèle pour améliorer les performances
      final results = await Future.wait([
        _gameService.getAllLevels(),
        _gameService.getPoints(),
        _gameService.getCompletedLevelsCount(),
      ]);
      
      // Récupérer les résultats
      final levels = results[0] as List<Level>;
      final points = results[1] as int;
      final completedLevels = results[2] as int;
      
      // Préparer les maps pour les temps et tentatives
      Map<int, int?> bestTimes = {};
      Map<int, int> attempts = {};
      
      // Charger les données pour chaque niveau en parallèle
      final levelDataFutures = <Future>[];
      
      for (var level in levels) {
        levelDataFutures.add(
          Future.wait([
            _gameService.getBestTime(level.id),
            _gameService.getAttempts(level.id),
          ]).then((data) {
            bestTimes[level.id] = data[0] as int?;
            attempts[level.id] = data[1] as int;
          }).catchError((e) {
            print('Erreur lors du chargement des données pour le niveau ${level.id}: $e');
            bestTimes[level.id] = null;
            attempts[level.id] = 0;
          })
        );
      }
      
      // Attendre que toutes les données des niveaux soient chargées
      await Future.wait(levelDataFutures);
      
      // Mettre à jour l'état si le widget est toujours monté
      if (mounted) {
        setState(() {
          _levels = levels;
          _totalPoints = points;
          _completedLevels = completedLevels;
          _bestTimes = bestTimes;
          _attempts = attempts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur générale lors du chargement des données: $e');
      // En cas d'erreur, charger les niveaux par défaut
      final defaultLevels = Level.getSampleLevels();
      if (defaultLevels.isNotEmpty) {
        defaultLevels[0] = defaultLevels[0].copyWith(isLocked: false);
      }
      
      if (mounted) {
        setState(() {
          _levels = defaultLevels;
          _isLoading = false;
        });
      }
    }
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
          'Sélection du niveau',
          style: AppTheme.heading3.copyWith(fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '$_totalPoints',
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white,
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
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  )
                : _levels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucun niveau disponible',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadLevels,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: RefreshIndicator(
                    onRefresh: _loadLevels,
                    color: Colors.blueAccent,
                    backgroundColor: Colors.grey[900],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête avec statistiques globales
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(AppTheme.radiusL),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.lock_open,
                                    iconColor: Colors.blueAccent,
                                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                                    label: 'Débloqués',
                                    value: '${_levels.where((level) => !level.isLocked).length}/${_levels.length}',
                                    valueColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.stars,
                                    iconColor: Colors.amber,
                                    backgroundColor: Colors.amber.withOpacity(0.2),
                                    label: 'Points',
                                    value: '$_totalPoints',
                                    valueColor: Colors.amber,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.check_circle,
                                    iconColor: Colors.green,
                                    backgroundColor: Colors.green.withOpacity(0.2),
                                    label: 'Complétés',
                                    value: '$_completedLevels/${_levels.length}',
                                    valueColor: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Titre
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Sélectionnez un niveau',
                                  style: AppTheme.heading3.copyWith(fontSize: 18),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Grille de niveaux
                          Expanded(
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _levels.length,
                              itemBuilder: (context, index) {
                                final level = _levels[index];
                                final bool isCompleted = _bestTimes[level.id] != null;
                                
                                return GestureDetector(
                                  onTap: level.isLocked
                                      ? () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Ce niveau est verrouillé ! Terminez les niveaux précédents pour le débloquer.'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              margin: const EdgeInsets.all(16),
                                            ),
                                          );
                                        }
                                      : () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => GameScreen(level: level),
                                            ),
                                          );
                                          // Recharger les données
                                          _loadLevels();
                                        },
                                  child: _buildLevelCard(level, isCompleted),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
          const SizedBox(height: 8),
          const BannerAdWidget(),
        ],
      ),
        ),
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  Widget _buildLevelCard(Level level, bool isCompleted) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: level.isLocked
              ? [AppTheme.surfaceColor, AppTheme.cardColor]
              : isCompleted
                  ? [
                      AppTheme.primaryColor.withOpacity(0.6),
                      AppTheme.primaryColor.withOpacity(0.3),
                    ]
                  : [AppTheme.surfaceColor, AppTheme.cardColor],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: level.isLocked
              ? AppTheme.textTertiary.withOpacity(0.3)
              : isCompleted
                  ? AppTheme.primaryColor.withOpacity(0.5)
                  : AppTheme.primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? AppTheme.primaryColor.withOpacity(0.4)
                : Colors.black.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Badge pour niveau complété
          if (isCompleted)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: AppTheme.successGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          
          // Contenu principal
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône de cadenas avec effet lumineux
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: level.isLocked
                            ? [AppTheme.surfaceColor, AppTheme.cardColor]
                            : isCompleted
                                ? [
                                    AppTheme.primaryColor.withOpacity(0.3),
                                    AppTheme.primaryColor.withOpacity(0.1),
                                  ]
                                : [
                                    AppTheme.primaryColor.withOpacity(0.2),
                                    AppTheme.primaryColor.withOpacity(0.05),
                                  ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: level.isLocked
                              ? Colors.transparent
                              : isCompleted
                                  ? AppTheme.primaryColor.withOpacity(0.5)
                                  : AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        level.isLocked
                            ? Icons.lock
                            : isCompleted
                                ? Icons.lock_open
                                : Icons.lock_outline,
                        color: level.isLocked
                            ? AppTheme.textTertiary
                            : isCompleted
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Nom du niveau
                  Text(
                    level.name,
                    style: AppTheme.bodyLarge.copyWith(
                      color: level.isLocked ? AppTheme.textTertiary : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  
                  // Informations du niveau
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          icon: Icons.stars,
                          value: '${level.pointsReward}',
                          color: level.isLocked ? Colors.grey : Colors.amber,
                        ),
                        _buildInfoChip(
                          icon: Icons.timer,
                          value: '${level.timeLimit}s',
                          color: level.isLocked ? Colors.grey : _getDifficultyColor(level.timeLimit),
                        ),
                      ],
                    ),
                  ),
                  
                  // Meilleur temps si disponible
                  if (!level.isLocked && _bestTimes[level.id] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: AppTheme.secondaryColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_bestTimes[level.id]}s',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.secondaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoChip({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTheme.bodySmall.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getDifficultyColor(int timeLimit) {
    if (timeLimit >= 50) {
      return Colors.green;
    } else if (timeLimit >= 40) {
      return Colors.lightGreen;
    } else if (timeLimit >= 30) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
} 