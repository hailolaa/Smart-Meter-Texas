import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class HistorySummaryCard extends StatelessWidget {
  const HistorySummaryCard({
    required this.title,
    required this.kwh,
    required this.cost,
    super.key,
  });

  final String title;
  final String kwh;
  final String cost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Calendar icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // Title + kWh
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: AppColors.primaryGreen.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$kwh kWh',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Cost
          Text(
            cost,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
