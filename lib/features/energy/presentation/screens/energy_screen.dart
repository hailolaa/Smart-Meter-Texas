import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_state.dart';
import '../bloc/energy_event.dart';
import '../../data/repositories/backend_energy_repository.dart';
import '../../data/repositories/promo_catalog.dart';
import '../../../../core/navigation/presentation/screens/main_scaffold.dart';
import '../../../../core/session/smt_session_store.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/smt_api_client.dart';
import '../../domain/entities/energy_summary.dart';
import '../widgets/energy_hero_card.dart';
import '../widgets/ac_cost_card.dart';
import '../widgets/metric_cards_row.dart';
import '../widgets/usage_pattern_card.dart';
import '../widgets/navigation_tile.dart';
import '../widgets/promo_carousel.dart';
import '../widgets/business_store_card.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';

class EnergyScreen extends StatefulWidget {
  const EnergyScreen({
    super.key,
    this.refreshNonce,
    this.energyBloc,
  });

  final int? refreshNonce;
  final EnergyBloc? energyBloc;

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  late final EnergyBloc _energyBloc;
  late final bool _ownsBloc;
  StreamSubscription<void>? _settingsSubscription;
  Map<String, dynamic>? _cheapest;

  @override
  void initState() {
    super.initState();
    _ownsBloc = widget.energyBloc == null;
    _energyBloc = widget.energyBloc ?? EnergyBloc(repository: BackendEnergyRepository());
    _energyBloc.add(LoadEnergyData());
    _settingsSubscription = AppSettingsStore.instance.changes.listen((_) {
      _energyBloc.add(RefreshEnergyData());
    });
    _loadCheapest();
  }

  Future<void> _loadCheapest() async {
    try {
      final api = SmtApiClient();
      final data = await api.getCheapestProvider(usageKwh: 1000);
      if (!mounted) return;
      setState(() {
        _cheapest = data;
      });
    } catch (_) {
      // Non-fatal
    }
  }

  @override
  void didUpdateWidget(covariant EnergyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNonce = oldWidget.refreshNonce ?? 0;
    final newNonce = widget.refreshNonce ?? 0;
    if (oldNonce != newNonce) {
      _energyBloc.add(RefreshEnergyData());
    }
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    if (_ownsBloc) {
      _energyBloc.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _energyBloc,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocConsumer<EnergyBloc, EnergyState>(
            listener: (context, state) {
              if (state is EnergyActionSuccess) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(_buildThemedSnackBar(state.message, state.toastType));
              }
            },
            builder: (context, state) {
              if (state is EnergyInitial || state is EnergyLoading) {
                return const _EnergyLoadingSkeleton();
              }
              if (state is EnergyLoaded) {
                return _buildEnergyBody(
                  blocContext: context,
                  summary: state.summary,
                  requestInProgress: false,
                  meterReadLockedUntil: state.meterReadLockedUntil,
                );
              }
              if (state is EnergyRequestInProgress) {
                return _buildEnergyBody(
                  blocContext: context,
                  summary: state.summary,
                  requestInProgress: true,
                  meterReadLockedUntil: state.meterReadLockedUntil,
                );
              }
              if (state is EnergyActionSuccess && state.summary != null) {
                return _buildEnergyBody(
                  blocContext: context,
                  summary: state.summary!,
                  requestInProgress: false,
                  meterReadLockedUntil: _extractLockFromState(state),
                );
              }
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEnergyBody({
    required BuildContext blocContext,
    required EnergySummary summary,
    required bool requestInProgress,
    required DateTime? meterReadLockedUntil,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        blocContext.read<EnergyBloc>().add(RefreshEnergyData());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 28),

              // Hero card
              EnergyHeroCard(
                summary: summary,
                onAdjustLimit: () => _openAdjustLimitDialog(blocContext),
              ),
              const SizedBox(height: 16),

              // AC cost card
              ACcostCard(summary: summary),

              // Cheapest provider banner
              if (_cheapest != null) ...[
                const SizedBox(height: 12),
                _buildCheapestBanner(),
              ],
              const SizedBox(height: 16),

              // Usage & Rate metric cards
              MetricCardsRow(
                summary: summary,
                onRequestCurrentRead: requestInProgress
                    ? () {}
                    : () => _requestCurrentRead(blocContext),
                requestInProgress: requestInProgress,
                requestDisabled: _isRequestLocked(meterReadLockedUntil),
                requestDisabledLabel: _requestDisabledLabel(meterReadLockedUntil),
              ),
              const SizedBox(height: 24),

              // Usage pattern chart
              const UsagePatternCard(),
              const SizedBox(height: 16),

              // Navigation tile — Hourly Breakdown
              NavigationTile(
                title: "Hourly Breakdown",
                subtitle: "Detailed usage patterns",
                icon: Icons.access_time_rounded,
                iconColor: AppColors.primaryBlue,
                iconBgColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                onTap: () => MainScaffoldController.of(context)?.switchTab(2),
              ),
              const SizedBox(height: 16),

              // Promo carousel 1 — first half of offers
              PromoCarousel(offers: PromoCatalog.firstGroup),
              const SizedBox(height: 16),

              // Navigation tile — Usage History
              NavigationTile(
                title: "Usage History",
                subtitle: "30 days comprehensive view",
                icon: Icons.calendar_today_rounded,
                iconColor: AppColors.primaryGreen,
                iconBgColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                onTap: () => MainScaffoldController.of(context)?.switchTab(1),
              ),
              const SizedBox(height: 16),

              // Promo carousel 2 — second half of offers
              PromoCarousel(offers: PromoCatalog.secondGroup),
              const SizedBox(height: 24),

              // Business Store card
              const BusinessStoreCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheapestBanner() {
    final data = _cheapest!;
    final provider = (data['provider']?['name'] ?? '').toString();
    final cents = (data['provider']?['energy_rate_cents'] as num?)?.toDouble() ?? 0;
    final userSel = AppSettingsStore.instance.retailProvider ?? '';
    final map = <String, String>{
      'txu': 'TXU Energy',
      'reliant': 'Reliant Energy',
      'direct': 'Direct Energy',
      'green': 'Green Mountain',
      'cirro': 'Cirro Energy',
      'gexa': 'Gexa Energy',
    };
    final userProvider = map[userSel] ?? userSel;
    final isCheapestUser = userProvider.isNotEmpty && userProvider.toLowerCase() == provider.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_rounded, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCheapestUser
                  ? 'Great choice! $provider is currently among the cheapest (~${cents.toStringAsFixed(1)}¢/kWh).'
                  : 'Cheapest now: $provider at ~${cents.toStringAsFixed(1)}¢/kWh (1,000 kWh).',
              style: const TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push(AppRoutes.providers),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              foregroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Show more'),
          ),
        ],
      ),
    );
  }

  DateTime? _extractLockFromState(EnergyState state) {
    if (state is EnergyLoaded) return state.meterReadLockedUntil;
    if (state is EnergyRequestInProgress) return state.meterReadLockedUntil;
    return null;
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Take Control",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: AppColors.textMain,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              "of your energy usage",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.primaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
        ),
      ],
    );
  }

  Future<void> _requestCurrentRead(BuildContext context) async {
    final storedMeterNumber = SmtSessionStore.instance.meterNumber;
    if (storedMeterNumber != null && storedMeterNumber.isNotEmpty) {
      context.read<EnergyBloc>().add(RequestCurrentMeterRead());
      return;
    }
    await _openMeterReadRequestDialog(context);
  }

  Future<void> _openAdjustLimitDialog(BuildContext context) async {
    final currentBudget = AppSettingsStore.instance.dailyBudget;
    final controller = TextEditingController(
      text: currentBudget.toStringAsFixed(2),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Adjust Daily Limit',
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w800),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Daily Budget (\$)',
              hintText: 'e.g., 8.00',
              filled: true,
              fillColor: AppColors.background,
              labelStyle: const TextStyle(color: AppColors.textMuted),
              hintStyle: const TextStyle(color: AppColors.textMuted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.6),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            _buildGradientDialogAction(
              label: 'Save',
              onPressed: () async {
                final raw = controller.text.trim();
                final value = double.tryParse(raw);
                if (value == null || value <= 0) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      _buildThemedSnackBar(
                        'Please enter a valid daily limit greater than 0.',
                        ToastType.error,
                      ),
                    );
                  return;
                }
                await AppSettingsStore.instance.setDailyBudget(value);
                if (!dialogContext.mounted || !mounted) return;
                Navigator.of(dialogContext).pop();
                // The settings listener will fire RefreshEnergyData
                // automatically; no need to add it again here.
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    _buildThemedSnackBar(
                      'Daily limit updated to \$${value.toStringAsFixed(2)}.',
                      ToastType.success,
                    ),
                  );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildGradientDialogAction({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  bool _isRequestLocked(DateTime? lockedUntil) {
    return lockedUntil != null && DateTime.now().isBefore(lockedUntil);
  }

  String? _requestDisabledLabel(DateTime? lockedUntil) {
    if (!_isRequestLocked(lockedUntil)) return null;
    final diff = lockedUntil!.difference(DateTime.now());
    final mins = diff.inMinutes.clamp(1, 24 * 60);
    if (mins >= 60) {
      final hours = (mins / 60).ceil();
      return 'Try again in ~${hours}h';
    }
    return 'Try again in ~${mins}m';
  }

  SnackBar _buildThemedSnackBar(String message, ToastType type) {
    final Color bgColor;
    final IconData icon;
    switch (type) {
      case ToastType.success:
        bgColor = AppColors.primaryGreen;
        icon = Icons.check_circle_rounded;
        break;
      case ToastType.info:
        bgColor = AppColors.primaryBlue;
        icon = Icons.info_rounded;
        break;
      case ToastType.warning:
        bgColor = AppColors.warningOrange;
        icon = Icons.warning_amber_rounded;
        break;
      case ToastType.error:
        bgColor = const Color(0xFFEF4444);
        icon = Icons.error_rounded;
        break;
    }

    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 6,
      duration: type == ToastType.error
          ? const Duration(seconds: 4)
          : const Duration(seconds: 3),
    );
  }

  Future<void> _openMeterReadRequestDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Request Current Meter Read'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Meter Number',
              hintText: 'Enter your meter number',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final meterNumber = controller.text.trim();
                if (meterNumber.isEmpty) return;
                Navigator.of(dialogContext).pop();
                context.read<EnergyBloc>().add(
                  RequestCurrentMeterRead(meterNumber: meterNumber),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}

class _EnergyLoadingSkeleton extends StatelessWidget {
  const _EnergyLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: const [
        _SkeletonBlock(height: 56),
        SizedBox(height: 24),
        _SkeletonBlock(height: 180),
        SizedBox(height: 16),
        _SkeletonBlock(height: 120),
        SizedBox(height: 16),
        _SkeletonBlock(height: 140),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
