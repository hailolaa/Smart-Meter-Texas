import 'package:flutter/material.dart';
import 'package:smart_meter_texas/core/theme/app_theme.dart';
import '../../domain/entities/energy_summary.dart';

class MetricCardsRow extends StatelessWidget {
  final EnergySummary summary;
  final VoidCallback? onRequestCurrentRead;
  final bool requestInProgress;
  final bool requestDisabled;
  final String? requestDisabledLabel;

  const MetricCardsRow({
    super.key,
    required this.summary,
    this.onRequestCurrentRead,
    this.requestInProgress = false,
    this.requestDisabled = false,
    this.requestDisabledLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: summary.kwhToday.toStringAsFixed(2),
            subtitle: "kWh today",
            trend: summary.kwhTrend,
            invertColors: true, // energy: down = good (green), up = caution (orange)
            onActionTap: onRequestCurrentRead,
            actionLabel: requestInProgress
                ? "Requesting..."
                : (requestDisabledLabel ?? "Request current read"),
            showProgress: requestInProgress,
            actionDisabled: requestInProgress || requestDisabled,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: "${summary.centsPerKwh.toStringAsFixed(1)}¢",
            subtitle: "per kWh",
            trend: summary.centsTrend,
            invertColors: true, // cost: down = good (green), up = caution (orange)
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required double trend,
    bool invertColors = false,
    VoidCallback? onActionTap,
    String? actionLabel,
    bool showProgress = false,
    bool actionDisabled = false,
  }) {
    // Determine trend display
    final isZero = trend.abs() < 0.005; // less than 0.5%
    final isUp = trend > 0;
    final pct = (trend.abs() * 100).round();

    // Color semantics:
    //   invertColors=true → down is green (good), up is orange (caution)
    //   invertColors=false → up is green, down is blue
    final Color trendColor;
    final Color trendBgColor;
    final IconData trendIcon;

    if (isZero) {
      trendColor = AppColors.textMuted;
      trendBgColor = AppColors.textMuted.withValues(alpha: 0.08);
      trendIcon = Icons.trending_flat;
    } else if (invertColors) {
      // For energy/cost: down = good (green), up = caution (orange)
      trendColor = isUp ? AppColors.warningOrange : AppColors.primaryGreen;
      trendBgColor = trendColor.withValues(alpha: 0.12);
      trendIcon = isUp ? Icons.trending_up : Icons.trending_down;
    } else {
      trendColor = isUp ? AppColors.primaryGreen : AppColors.primaryBlue;
      trendBgColor = trendColor.withValues(alpha: 0.12);
      trendIcon = isUp ? Icons.trending_up : Icons.trending_down;
    }

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (onActionTap != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Material(
                    color: (actionDisabled
                            ? AppColors.textMuted
                            : AppColors.primaryBlue)
                        .withValues(alpha: 0.12),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: actionDisabled ? null : onActionTap,
                      child: Center(
                        child: showProgress
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryBlue,
                                ),
                              )
                            : Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: actionDisabled
                                    ? AppColors.textMuted
                                    : AppColors.primaryBlue,
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        Row(
            children: [
              Flexible(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: trendBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, size: 12, color: trendColor),
                    const SizedBox(width: 2),
                    Text(
                      isZero
                          ? "—"
                          : "$pct%",
                      style: TextStyle(
                        color: trendColor,
                        fontSize: 10,
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
