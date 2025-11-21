import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// Widget pour afficher des cadenas animés en arrière-plan qui défilent verticalement de haut en bas
class AnimatedLocksBackground extends StatefulWidget {
  final int lockCount;
  final double lockSize;
  final Duration animationDuration;

  const AnimatedLocksBackground({
    Key? key,
    this.lockCount = 15,
    this.lockSize = 40,
    this.animationDuration = const Duration(seconds: 30),
  }) : super(key: key);

  @override
  State<AnimatedLocksBackground> createState() =>
      _AnimatedLocksBackgroundState();
}

class _AnimatedLocksBackgroundState extends State<AnimatedLocksBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<LockData> _locks = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Générer les positions initiales des cadenas
    _generateLocks();

    _controller.repeat();
  }

  void _generateLocks() {
    final random = math.Random();
    _locks.clear();

    // Couleurs des boutons
    final colors = [
      AppTheme.primaryColor, // Couleur principale (JOUER)
      AppTheme.errorColor, // Couleur rouge (DUEL)
      AppTheme.secondaryColor, // Couleur secondaire (CLASSEMENT)
      AppTheme.accentColor, // Couleur accent
      AppTheme.surfaceColor, // Couleur surface (PARAMÈTRES/AIDE)
      AppTheme.primaryColor.withOpacity(0.7),
      AppTheme.errorColor.withOpacity(0.7),
      AppTheme.secondaryColor.withOpacity(0.7),
    ];

    // Créer beaucoup de petits cadenas bien espacés horizontalement
    // Ils défilent de haut en bas verticalement
    final columns = 10; // Plus de colonnes pour plus de cadenas
    final locksPerColumn = (widget.lockCount / columns).ceil();
    
    int lockIndex = 0;
    for (int col = 0; col < columns && lockIndex < widget.lockCount; col++) {
      for (int i = 0; i < locksPerColumn && lockIndex < widget.lockCount; i++) {
        // Position X basée sur la colonne, bien espacée
        final baseX = (col + 0.5) / columns;
        
        // Position Y de départ : commencer hors écran en haut avec espacement
        // Chaque cadenas dans une colonne a un décalage vertical pour créer un flux continu
        final verticalSpacing = 1.5 / locksPerColumn; // Espacement vertical entre les cadenas
        final startY = -0.2 - (i * verticalSpacing); // Commencer hors écran en haut
        
        // Légère variation aléatoire pour l'aspect naturel
        final offsetX = (random.nextDouble() - 0.5) * 0.08; // Petite variation horizontale
        
        // Choisir une couleur aléatoire parmi les couleurs des boutons
        final lockColor = colors[random.nextInt(colors.length)];
        
        _locks.add(
          LockData(
            startX: (baseX + offsetX).clamp(0.05, 0.95), // Position X entre 5% et 95%
            startY: startY, // Position Y de départ (hors écran en haut)
            delay: random.nextDouble() * 2, // Petit délai aléatoire (0 à 2 secondes)
            size: widget.lockSize * (0.5 + random.nextDouble() * 0.5), // Petits cadenas (50% à 100% de la taille)
            opacity: 0.08 + random.nextDouble() * 0.12, // Opacité entre 0.08 et 0.2 (transparent)
            speed: 0.6 + random.nextDouble() * 0.4, // Vitesse variable (0.6 à 1.0)
            color: lockColor, // Couleur du cadenas
          ),
        );
        lockIndex++;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Filtrer et créer les widgets uniquement pour les cadenas visibles
          final visibleLocks = <Widget>[];
          
          for (final lock in _locks) {
            // Calculer la position actuelle avec le délai
            final durationSeconds = widget.animationDuration.inSeconds.toDouble();
            final adjustedProgress = ((_controller.value * durationSeconds + lock.delay) % durationSeconds) / durationSeconds;
            
            // Mouvement vertical de haut en bas
            // Position X reste constante (défilement vertical uniquement)
            final x = lock.startX * screenSize.width;
            
            // Position Y : mouvement vertical de haut en bas
            // Commencer hors écran en haut et descendre
            final startY = lock.startY * screenSize.height; // Position de départ (hors écran en haut)
            final totalDistance = screenSize.height * 2.0; // Distance totale (hauteur écran * 2 pour traverser)
            final distance = adjustedProgress * totalDistance * lock.speed;
            final y = startY + distance; // Descendre verticalement

            // Ne dessiner que si le cadenas est dans une zone visible (avec marge)
            final margin = lock.size * 2;
            if (y > -margin && y < screenSize.height + margin &&
                x > -margin && x < screenSize.width + margin) {
              visibleLocks.add(
                Positioned(
                  left: x - lock.size / 2,
                  top: y - lock.size / 2,
                  child: IgnorePointer(
                    child: Icon(
                      Icons.lock_outline,
                      size: lock.size,
                      color: lock.color.withOpacity(lock.opacity),
                    ),
                  ),
                ),
              );
            }
          }
          
          return Stack(
            clipBehavior: Clip.none,
            children: visibleLocks,
          );
        },
      ),
    );
  }
}

/// Données pour un cadenas
class LockData {
  final double startX;
  final double startY;
  final double delay;
  final double size;
  final double opacity;
  final double speed;
  final Color color; // Couleur du cadenas

  LockData({
    required this.startX,
    required this.startY,
    required this.delay,
    required this.size,
    required this.opacity,
    required this.speed,
    required this.color,
  });
}
