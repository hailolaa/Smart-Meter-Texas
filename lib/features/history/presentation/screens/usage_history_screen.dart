import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/energy_realtime_client.dart';
import '../../../../core/session/smt_session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/backend_history_repository.dart';
import '../../domain/entities/usage_history_overview.dart';
import '../widgets/history_summary_card.dart';

class UsageHistoryScreen extends StatefulWidget {
  const UsageHistoryScreen({
    super.key,
    this.refreshNonce,
  });

  final int? refreshNonce;

  @override
  State<UsageHistoryScreen> createState() => _UsageHistoryScreenState();
}

class _UsageHistoryScreenState extends State<UsageHistoryScreen>
    with TickerProviderStateMixin {
  late Future<UsageHistoryOverview> _overviewFuture;
  final _repository = BackendHistoryRepository();
  final EnergyRealtimeClient _realtimeClient = WebSocketEnergyRealtimeClient();
  StreamSubscription<EnergyRealtimeMessage>? _realtimeSub;
  Timer? _realtimeDebounce;
  UsageHistoryOverview? _cachedOverview;
  bool? _showRefreshIndicator = false;

  // Staggered entrance animations
  late AnimationController _staggerController;
  late List<Animation<double>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _buildAnimations();
    _overviewFuture = _repository.fetchOverview();
    _startRealtime();
  }

  void _buildAnimations() {
    // 4 items: title, card1, card2, card3
    const count = 4;
    _slideAnimations = List.generate(count, (i) {
      final start = (i * 0.15).clamp(0.0, 0.7);
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<double>(begin: 40, end: 0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
    _fadeAnimations = List.generate(count, (i) {
      final start = (i * 0.15).clamp(0.0, 0.7);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
  }

  void _triggerEntrance() {
    if (!_hasAnimated) {
      _hasAnimated = true;
      _staggerController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _realtimeDebounce?.cancel();
    _realtimeSub?.cancel();
    _realtimeClient.disconnect();
    _realtimeClient.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UsageHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNonce = oldWidget.refreshNonce ?? 0;
    final newNonce = widget.refreshNonce ?? 0;
    if (oldNonce != newNonce) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _showRefreshIndicator = _cachedOverview != null;
      _overviewFuture = _repository.fetchOverview();
    });
    try {
      final updated = await _overviewFuture;
      if (!mounted) return;
      setState(() {
        _cachedOverview = updated;
        _showRefreshIndicator = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showRefreshIndicator = false;
      });
    }
  }

  void _startRealtime() {
    final token = SmtSessionStore.instance.jwtToken;
    if (token == null || token.isEmpty) return;
    try {
      _realtimeSub = _realtimeClient.connect(jwtToken: token).listen(
        (event) {
          if (event.type != 'history_changed' && event.type != 'energy_snapshot') {
            return;
          }
          if (!mounted) return;
          _realtimeDebounce?.cancel();
          _realtimeDebounce = Timer(const Duration(milliseconds: 700), _refresh);
        },
        onError: (_) {},
      );
    } catch (_) {
      // Pull-to-refresh and tab-refresh remain fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<UsageHistoryOverview>(
          future: _overviewFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData &&
                _cachedOverview == null) {
              return const _HistoryLoadingSkeleton();
            }

            if (snapshot.hasError && _cachedOverview == null) {
              final message = snapshot.error.toString().replaceFirst('Exception: ', '');
              return _HistoryStateCard(
                title: 'Usage history unavailable',
                message: message.isEmpty
                    ? 'Unable to load usage history right now. Please try again.'
                    : message,
                actionLabel: 'Try again',
                onPressed: _refresh,
              );
            }

            final data = snapshot.data ?? _cachedOverview;
            if (data == null) {
              return _HistoryStateCard(
                title: 'No history available',
                message: 'No usage history was returned for this account yet.',
                actionLabel: 'Refresh',
                onPressed: _refresh,
              );
            }
            _cachedOverview = data;

            // Start entrance animation when data arrives.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _triggerEntrance();
            });

            return Stack(
              children: [
                RefreshIndicator(
                  color: AppColors.primaryBlue,
                  onRefresh: _refresh,
                  child: AnimatedBuilder(
                    animation: _staggerController,
                    builder: (context, _) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            _animatedItem(
                              index: 0,
                              child: const Text(
                                'Usage History',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textMain,
                                  letterSpacing: -1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),

                            if (!data.hasAnyUsage) ...[
                              const _InlineHintCard(
                                message:
                                    'No usage history yet. Pull down to refresh after Smart Meter Texas posts readings.',
                              ),
                              const SizedBox(height: 18),
                            ],

                            // Yesterday
                            _animatedItem(
                              index: 1,
                              child: HistorySummaryCard(
                                title: 'Yesterday',
                                kwh: data.yesterdayKwh.toStringAsFixed(0),
                                cost: '\$${data.yesterdayCost.toStringAsFixed(2)}',
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Last 7 days
                            _animatedItem(
                              index: 2,
                              child: HistorySummaryCard(
                                title: 'Last 7 days',
                                kwh: data.last7DaysKwh.toStringAsFixed(0),
                                cost: '\$${data.last7DaysCost.toStringAsFixed(2)}',
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Last 30 days
                            _animatedItem(
                              index: 3,
                              child: HistorySummaryCard(
                                title: 'Last 30\ndays',
                                kwh: data.last30DaysKwh.toStringAsFixed(0),
                                cost: '\$${data.last30DaysCost.toStringAsFixed(2)}',
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Disclaimer
                            const _DisclaimerText(),
                            const SizedBox(height: 120),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_showRefreshIndicator == true)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.primaryBlue,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _animatedItem({required int index, required Widget child}) {
    return Transform.translate(
      offset: Offset(0, _slideAnimations[index].value),
      child: Opacity(
        opacity: _fadeAnimations[index].value,
        child: child,
      ),
    );
  }
}

// ─── Disclaimer ──────────────────────────────────────────────────────────────

class _DisclaimerText extends StatelessWidget {
  const _DisclaimerText();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'ElectricToday is an independent application and is not affiliated '
        'with, endorsed by, sponsored by, or associated with Smart Meter '
        'Texas, any electric utility, electricity provider, or network '
        'operator. All electricity usage data is accessed in read-only '
        'form only after the user provides explicit authorization through '
        'official, utility-authorized platforms. ElectricToday does not '
        'collect, store, or process utility login credentials and cannot '
        'modify meter data.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textMuted.withValues(alpha: 0.6),
          height: 1.5,
        ),
      ),
    );
  }
}

// ─── Loading Skeleton ────────────────────────────────────────────────────────

class _HistoryLoadingSkeleton extends StatefulWidget {
  const _HistoryLoadingSkeleton();

  @override
  State<_HistoryLoadingSkeleton> createState() => _HistoryLoadingSkeletonState();
}

class _HistoryLoadingSkeletonState extends State<_HistoryLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _shimmerBlock(height: 40, width: 200),
            const SizedBox(height: 26),
            _shimmerBlock(height: 80),
            const SizedBox(height: 14),
            _shimmerBlock(height: 80),
            const SizedBox(height: 14),
            _shimmerBlock(height: 80),
          ],
        );
      },
    );
  }

  Widget _shimmerBlock({required double height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE5E7EB),
            const Color(0xFFF3F4F6),
            const Color(0xFFE5E7EB),
          ],
          stops: [
            (_shimmerController.value - 0.3).clamp(0.0, 1.0),
            _shimmerController.value.clamp(0.0, 1.0),
            (_shimmerController.value + 0.3).clamp(0.0, 1.0),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}

// ─── Error / Empty state card ────────────────────────────────────────────────

class _HistoryStateCard extends StatelessWidget {
  const _HistoryStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.primaryBlue,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onPressed(),
                      child: Center(
                        child: Text(
                          actionLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Inline hint card ────────────────────────────────────────────────────────

class _InlineHintCard extends StatelessWidget {
  const _InlineHintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primaryBlue.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
