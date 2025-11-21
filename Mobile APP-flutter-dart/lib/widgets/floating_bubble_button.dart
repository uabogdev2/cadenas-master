import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// Widget de bouton en forme de bulle flottante avec animation
class FloatingBubbleButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final double size;
  final Duration animationDuration;
  final Duration delay;

  const FloatingBubbleButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
    this.size = 80,
    this.animationDuration = const Duration(milliseconds: 2000),
    this.delay = Duration.zero,
  }) : super(key: key);

  @override
  State<FloatingBubbleButton> createState() => _FloatingBubbleButtonState();
}

class _FloatingBubbleButtonState extends State<FloatingBubbleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Animation de flottement (haut/bas)
    _floatAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Animation de scale (pulse)
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Animation d'ombre (pour effet de profondeur)
    _shadowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Démarrer l'animation après le délai
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        // Animation de pression
        _controller.stop();
        _controller.reverse();
      },
      onTapUp: (_) {
        // Relancer l'animation après le tap
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            widget.onTap();
            _controller.repeat(reverse: true);
          }
        });
      },
      onTapCancel: () {
        if (mounted) {
          _controller.repeat(reverse: true);
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Calculer la position de flottement
          final floatOffset = math.sin(_floatAnimation.value * 2 * math.pi) * 8;
          
          return Transform.translate(
            offset: Offset(0, floatOffset),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.gradient,
                  boxShadow: [
                    BoxShadow(
                      color: widget.gradient.colors.first
                          .withOpacity(_shadowAnimation.value),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: Offset(0, floatOffset + 5),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(widget.size / 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icône
                        Icon(
                          widget.icon,
                          color: Colors.white,
                          size: widget.size * 0.35,
                        ),
                        const SizedBox(height: 4),
                        // Label
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.size * 0.12,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
