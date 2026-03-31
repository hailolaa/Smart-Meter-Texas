import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PromoCard extends StatelessWidget {
  final String badgeText;
  final String title;
  final String description;
  final String? sponsorName;
  final Widget imageLayer;
  final VoidCallback? onButtonPressed;
  final IconData? icon;
  final ElevatedButton? button;

  const PromoCard({
    super.key,
    required this.badgeText,
    required this.title,
    required this.description,
    this.sponsorName,
    required this.imageLayer,
    this.onButtonPressed,
    this.icon,
    this.button,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image / Header area
          SizedBox(
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageLayer, // Wait for future network image here
                // Dark Overlay so text is readable
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryBlue, AppColors.primaryGreen],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content Area
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMain.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: Colors.grey[400], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          sponsorName?.toUpperCase() ?? "",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[500],
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    button ?? const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
