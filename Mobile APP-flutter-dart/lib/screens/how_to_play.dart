import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

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
              'Comment jouer',
              style: AppTheme.heading3.copyWith(fontSize: 18),
            ),
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: AppTheme.textPrimary),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.help_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Comment jouer',
                  style: AppTheme.heading1.copyWith(fontSize: 26),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildInstructionCard(
              icon: Icons.lock,
              title: 'Objectif',
              description: 'Déverrouillez les cadenas en trouvant le bon code pour chaque niveau.',
            ),
            _buildInstructionCard(
              icon: Icons.lightbulb_outline,
              title: 'Indices',
              description: 'Chaque niveau contient un indice pour vous aider à trouver le code.',
            ),
            _buildInstructionCard(
              icon: Icons.keyboard,
              title: 'Saisie du code',
              description: 'Entrez les chiffres un par un. La validation est automatique une fois tous les chiffres saisis.',
            ),
            _buildInstructionCard(
              icon: Icons.star,
              title: 'Points',
              description: 'Gagnez des points en complétant des niveaux. Plus le niveau est difficile, plus vous gagnez de points.',
            ),
            _buildInstructionCard(
              icon: Icons.lock_open,
              title: 'Progression',
              description: 'Débloquez de nouveaux niveaux en réussissant les niveaux précédents.',
            ),
            const SizedBox(height: 32),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppTheme.secondaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryColor.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.celebration, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Bonne chance !',
                      style: AppTheme.heading2.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.heading3.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 