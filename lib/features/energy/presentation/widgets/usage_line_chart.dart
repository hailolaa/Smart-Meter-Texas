import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import 'scroll_hint_wrapper.dart';

class UsageLineChart extends StatefulWidget {
  final String filter;
  final List<double> values;
  final List<String> labels;
  const UsageLineChart({
    super.key,
    required this.filter,
    required this.values,
    required this.labels,
  });

  @override
  State<UsageLineChart> createState() => _UsageLineChartState();
}

class _UsageLineChartState extends State<UsageLineChart>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollCtrl = ScrollController();
  late AnimationController _drawController;
  late Animation<double> _drawAnimation;

  /// Track the last data fingerprint to re-trigger animation on new data.
  String _dataFingerprint = '';

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _drawAnimation = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeOutCubic,
    );
    _maybeAnimate();
  }

  @override
  void didUpdateWidget(covariant UsageLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeAnimate();
    // Reset scroll when filter or data size changes.
    if (oldWidget.filter != widget.filter ||
        oldWidget.values.length != widget.values.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });
    }
  }

  void _maybeAnimate() {
    final fp = '${widget.filter}_${widget.values.length}_'
        '${widget.values.isNotEmpty ? widget.values.first : 0}_'
        '${widget.values.isNotEmpty ? widget.values.last : 0}';
    if (fp != _dataFingerprint) {
      _dataFingerprint = fp;
      _drawController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _drawController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _drawAnimation,
      builder: (context, child) => _buildChart(_drawAnimation.value),
    );
  }

  Widget _buildChart(double progress) {
    // Show spots up to the current animation progress.
    final totalSpots = widget.values.length;
    final visibleCount = (totalSpots * progress).ceil().clamp(1, totalSpots);

    final spots = List.generate(visibleCount, (i) {
      return FlSpot(i.toDouble(), widget.values[i]);
    });

    final maxVal = widget.values.reduce((a, b) => a > b ? a : b);
    final maxX = (widget.values.length - 1).toDouble();
    final maxY = maxVal <= 0 ? 1.0 : maxVal * 1.25;

    final double stepWidth;
    if (widget.filter == '15 min') {
      stepWidth = 28.0;
    } else if (widget.filter == '1 hr') {
      stepWidth = 38.0;
    } else {
      stepWidth = 44.0;
    }

    const leftAxisWidth = 40.0;
    const rightPad = 24.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            widget.values.length * stepWidth + leftAxisWidth + rightPad;
        final chartWidth = contentWidth.clamp(constraints.maxWidth, 6000.0);
        final needsScroll = chartWidth > constraints.maxWidth;

        final chart = SizedBox(
          width: chartWidth,
          child: Padding(
            padding: const EdgeInsets.only(right: rightPad),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.none(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.textMuted.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: widget.filter == '15 min' ? 36 : 24,
                      interval: _labelInterval,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= widget.labels.length) {
                          return const SizedBox.shrink();
                        }
                        final style = TextStyle(
                          color: AppColors.textMuted,
                          fontSize: widget.filter == '15 min' ? 8 : 10,
                        );
                        final child = Text(widget.labels[idx],
                            style: style, textAlign: TextAlign.center);
                        if (widget.filter == '15 min') {
                          return Transform.rotate(
                            angle: -0.55,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: child,
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: child,
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: leftAxisWidth,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) return const SizedBox.shrink();
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
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
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) =>
                        AppColors.textMain.withValues(alpha: 0.85),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final idx = s.x.toInt();
                        final label =
                            (idx >= 0 && idx < widget.labels.length)
                                ? widget.labels[idx]
                                : '';
                        return LineTooltipItem(
                          '$label\n${s.y.toStringAsFixed(3)} kWh',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes
                        .map((_) => TouchedSpotIndicatorData(
                              FlLine(
                                color:
                                    AppColors.primaryBlue.withValues(alpha: 0.4),
                                strokeWidth: 1,
                                dashArray: [4, 4],
                              ),
                              const FlDotData(show: true),
                            ))
                        .toList();
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.22,
                    preventCurveOverShooting: true,
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.primaryGreen],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryBlue.withValues(alpha: 0.18),
                          AppColors.primaryGreen.withValues(alpha: 0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ),
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
              child: chart,
            ),
          ),
        );
      },
    );
  }

  double get _labelInterval {
    if (widget.values.length <= 24) return 1;
    if (widget.values.length <= 48) return 2;
    return 4;
  }
}
