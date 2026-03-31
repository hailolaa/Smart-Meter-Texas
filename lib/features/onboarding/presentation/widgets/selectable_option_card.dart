import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SelectableOptionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isDisabled;
  final Widget? trailingBadge; // Custom badge like "COMING SOON"
  final VoidCallback? onTap;

  const SelectableOptionCard({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.isSelected = false,
    this.isDisabled = false,
    this.trailingBadge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic color resolution based on component state
    final Color iconColor = isDisabled
        ? Colors.grey[400]!
        : isSelected
            ? AppColors.primaryBlue
            : Colors.grey[600]!;

    final Color iconBgColor = isDisabled
        ? Colors.grey[100]!
        : isSelected
            ? AppColors.primaryBlue.withValues(alpha: 0.1)
            : AppColors.background;

    final Color borderColor = isSelected ? AppColors.primaryBlue : Colors.transparent;
    final Color bgColor = isSelected ? AppColors.primaryBlue.withValues(alpha: 0.02) : AppColors.cardBackground;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer( 
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            if (!isSelected && !isDisabled)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Opacity(
          opacity: isDisabled ? 0.8 : 1.0,
          child: Row(
            children: [
              // Left Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDisabled ? Colors.grey[900] : AppColors.textMain,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected && !isDisabled
                              ? AppColors.primaryBlue
                              : Colors.grey[500],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              // Right Side Indicator
              if (trailingBadge != null)
                trailingBadge!
              else if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                )
            ],
          ),
        ),
      ),
    );
  }
}
