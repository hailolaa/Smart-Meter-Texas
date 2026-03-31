import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'scroll_hint_wrapper.dart';

class UsageTrendBarChart extends StatefulWidget {
  const UsageTrendBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.showCurrency = false,
  });

  final List<double> values;
  final List<String> labels;
  final bool showCurrency;

  @override
  State<UsageTrendBarChart> createState() => _UsageTrendBarChartState();
}

class _UsageTrendBarChartState extends State<UsageTrendBarChart> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(covariant UsageTrendBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset scroll position when bar count changes significantly.
    if (oldWidget.values.length != widget.values.length && _scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return const Center(
        child: Text(
          'No usage data yet',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final highest = widget.values.reduce((a, b) => a > b ? a : b);
    final maxY = highest <= 0 ? 1.0 : highest * 1.2;
    final barCount = widget.values.length;

    // Dynamic sizing based on bar count.
    final bool dense = barCount > 12;
    final double barWidth = dense ? 14.0 : 18.0;
    final double groupSpacing = dense ? 28.0 : 0;
    // Left axis reserved + per-bar space + right padding.
    const double leftAxisWidth = 50.0;
    const double rightPad = 20.0;
    final double idealWidth =
        leftAxisWidth + rightPad + barCount * (barWidth + groupSpacing);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final needsScroll = idealWidth > availableWidth;
        final chartWidth = needsScroll ? idealWidth : availableWidth;

        final chart = SizedBox(
          width: chartWidth,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: needsScroll
                  ? BarChartAlignment.start
                  : BarChartAlignment.spaceAround,
              groupsSpace: needsScroll ? groupSpacing : null,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.textMuted.withValues(alpha: 0.16),
                  strokeWidth: 1,
                  dashArray: const [6, 4],
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) =>
                      AppColors.textMain.withValues(alpha: 0.85),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final idx = group.x;
                    final label =
                        (idx >= 0 && idx < widget.labels.length)
                            ? widget.labels[idx]
                            : '';
                    final val = rod.toY;
                    final formatted = widget.showCurrency
                        ? '\$${val.toStringAsFixed(2)}'
                        : '${val.toStringAsFixed(2)} kWh';
                    return BarTooltipItem(
                      '$label\n$formatted',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxY / 4,
                    reservedSize: leftAxisWidth,
                    getTitlesWidget: (value, _) => Text(
                      widget.showCurrency
                          ? '\$${value.toStringAsFixed(2)}'
                          : value.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= widget.labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.labels[idx],
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(widget.values.length, (index) {
                final isMax =
                    widget.values[index] == highest && highest > 0;
                return BarChartGroupData(
                  x: index,
                  barsSpace: 0,
                  barRods: [
                    BarChartRodData(
                      toY: widget.values[index],
                      width: barWidth,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: isMax
                            ? [
                                AppColors.primaryBlue
                                    .withValues(alpha: 0.7),
                                AppColors.primaryBlue,
                              ]
                            : [
                                AppColors.primaryBlue
                                    .withValues(alpha: 0.35),
                                AppColors.primaryBlue
                                    .withValues(alpha: 0.7),
                              ],
                      ),
                    ),
                  ],
                );
              }),
            ),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),
        );

        if (!needsScroll) return chart;

        return ScrollHintWrapper(
          scrollController: _scrollCtrl,
          child: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(right: rightPad),
                child: chart,
              ),
            ),
          ),
        );
      },
    );
  }
}
