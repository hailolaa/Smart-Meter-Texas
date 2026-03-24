import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';

class UsageLineChart extends StatelessWidget {
  final String filter;
  const UsageLineChart({super.key, required this.filter});

  @override
  Widget build(BuildContext context) {
    final spots = [
      const FlSpot(0, 1.2),
      const FlSpot(10, 0.8),
      const FlSpot(20, 2.8),
      const FlSpot(28, 0.9),
      const FlSpot(38, 4.2),
      const FlSpot(42, 1.0),
      const FlSpot(50, 3.8),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 50,
        minY: 0,
        maxY: 4.5,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.textMuted.withValues(alpha: 0.15),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),

          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 10,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${value.toInt()}m',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() == 0 || value > 4)
                  return const SizedBox.shrink();
                if (value == 4) {
                  return const Text(
                    "4 kWh",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  );
                }
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => AppColors.textMuted.withValues(alpha: 0.5),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                return LineTooltipItem(
                  '${touchedSpot.y} kWh',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
            return spotIndexes.map((spotIndex) {
              return const TouchedSpotIndicatorData(
                FlLine(color: Colors.transparent),
                FlDotData(show: false),
              );
            }).toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: const LinearGradient(
              colors: [
                AppColors.primaryBlue,
                AppColors.primaryGreen,
              ],
            ) ,
            barWidth: 5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: false,
              checkToShowDot: (spot, barData) => spot.x == 42,
              getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 6,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: AppColors.primaryGreen,
                )
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                 AppColors.primaryBlue.withValues(alpha: 0.2), // Light fade below line
                  AppColors.primaryGreen.withValues(alpha: 0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      curve: Curves.easeInCubic,
      duration: const Duration(milliseconds: 600),
    );
  }
}
