import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smart_meter_texas/core/theme/app_theme.dart';
import '../../domain/entities/energy_summary.dart';

class MetricCardsRow extends StatelessWidget {
  final EnergySummary summary;
  const MetricCardsRow({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: "${summary.kwhToday}",
            subtitle: "kWh today",
            trend: summary.kwhTrend,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: "${summary.centsPerKwh}",
            subtitle: "per kWh",
            trend: summary.centsTrend,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required double trend,
  }) {
    final isUp = trend > 0;
    final color = isUp ? AppColors.primaryGreen : AppColors.primaryBlue;
    final bgColor = color.withValues(alpha: 0.12);
    final icon = isUp ? Icons.trending_up : Icons.trending_down;


    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 12,
                      color: color,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "${(trend.abs()*100).toInt()}%",
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
