import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/energy_realtime_client.dart';
import '../../../../core/network/smt_api_client.dart';
import '../../../../core/session/smt_session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_session_bloc.dart';
import '../../../auth/presentation/bloc/auth_session_event.dart';
import '../../../../core/settings/app_settings_store.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.refreshNonce});

  final int? refreshNonce;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with TickerProviderStateMixin {
  StreamSubscription<void>? _settingsSubscription;
  final EnergyRealtimeClient _realtimeClient = WebSocketEnergyRealtimeClient();
  StreamSubscription<EnergyRealtimeMessage>? _realtimeSub;
  Timer? _realtimeDebounce;

  // Staggered entrance animation
  late AnimationController _staggerController;
  static const int _animItemCount = 16;
  late List<Animation<double>> _slideAnims;
  late List<Animation<double>> _fadeAnims;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _settingsSubscription = AppSettingsStore.instance.changes.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
    _startRealtime();

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _buildAnimations();
  }

  void _buildAnimations() {
    _slideAnims = List.generate(_animItemCount, (i) {
      final start = (i * 0.07).clamp(0.0, 0.65);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 32, end: 0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
    _fadeAnims = List.generate(_animItemCount, (i) {
      final start = (i * 0.07).clamp(0.0, 0.65);
      final end = (start + 0.3).clamp(0.0, 1.0);
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

  Future<void> _loadSettings() async {
    await AppSettingsStore.instance.load();
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNonce = oldWidget.refreshNonce ?? 0;
    final newNonce = widget.refreshNonce ?? 0;
    if (oldNonce != newNonce) {
      _loadSettings();
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _settingsSubscription?.cancel();
    _realtimeDebounce?.cancel();
    _realtimeSub?.cancel();
    _realtimeClient.disconnect();
    _realtimeClient.dispose();
    super.dispose();
  }

  void _startRealtime() {
    final token = SmtSessionStore.instance.jwtToken;
    if (token == null || token.isEmpty) return;
    try {
      _realtimeSub = _realtimeClient.connect(jwtToken: token).listen((event) {
        if (event.type != 'settings_changed' &&
            event.type != 'history_changed' &&
            event.type != 'energy_snapshot') {
          return;
        }
        if (!mounted) return;
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(
          const Duration(milliseconds: 800),
          _loadSettings,
        );
      }, onError: (_) {});
    } catch (_) {}
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String? _formatHomeType(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'house':
        return 'House';
      case 'apartment':
        return 'Apartment';
      case 'business':
        return 'Business';
      default:
        return null;
    }
  }

  String? _formatTdspCompany(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'oncor':
        return 'Oncor';
      case 'centerpoint':
        return 'CenterPoint';
      case 'aep':
        return 'AEP Texas';
      case 'tnmp':
        return 'TNMP';
      case 'other':
        return 'Other / Not sure';
      default:
        return null;
    }
  }

  String _defaultHomeLabel(String username) {
    final parts = username.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : 'My';
    return "$first's Home";
  }

  String _partnerOfferSubtitle() {
    final rateCents = AppSettingsStore.instance.ratePerKwh * 100;
    final budget = AppSettingsStore.instance.dailyBudget;
    if (rateCents >= 18) {
      return 'High-rate relief plans available';
    }
    if (budget <= 6) {
      return 'Budget saver kits for your usage';
    }
    return 'Exclusive deals & services';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final store = SmtSessionStore.instance;
    final username = store.smtUsername ?? 'SMT User';
    final esiid = store.esiid ?? '—';
    final meterNumber = store.meterNumber ?? 'Not set';
    final onboardingHomeType = _formatHomeType(
      AppSettingsStore.instance.homeType,
    );
    final onboardingTdsp = _formatTdspCompany(
      AppSettingsStore.instance.tdspCompany,
    );
    final homeLabel =
        AppSettingsStore.instance.homeLabel?.trim().isNotEmpty == true
        ? AppSettingsStore.instance.homeLabel!.trim()
        : (onboardingHomeType ?? _defaultHomeLabel(username));
    final utilityCompany =
        AppSettingsStore.instance.utilityCompany?.trim().isNotEmpty == true
        ? AppSettingsStore.instance.utilityCompany!.trim()
        : (onboardingTdsp ?? 'Tap to set');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerEntrance();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _staggerController,
          builder: (context, _) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title ──
                  _anim(
                    0,
                    child: const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textMain,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Profile header ──
                  _anim(
                    1,
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              _initials(username),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMain,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Premium Subscriber',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Partner Offers (gradient card) ──
                  _anim(
                    2,
                    child: _ProfileMenuCard(
                      icon: Icons.auto_awesome,
                      iconGradient: true,
                      title: 'Partner Offers',
                      subtitle: _partnerOfferSubtitle(),
                      isGradientBg: true,
                      onTap: () => _showPartnerOffersSheet(
                        context,
                        homeLabel: homeLabel,
                        utilityCompany: utilityCompany,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── My Home ──
                  _anim(
                    3,
                    child: _ProfileMenuCard(
                      icon: Icons.home_outlined,
                      title: 'My home',
                      subtitle: homeLabel,
                      onTap: () => _editHomeType(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Electricity Company ──
                  _anim(
                    4,
                    child: _ProfileMenuCard(
                      icon: Icons.bolt_outlined,
                      title: 'Electricity company',
                      subtitle: utilityCompany,
                      onTap: () => _editTdspCompany(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Smart Meter Connection ──
                  _anim(
                    5,
                    child: _ProfileMenuCard(
                      icon: Icons.link_rounded,
                      title: 'Smart meter connection',
                      subtitle: esiid != '—' ? 'Connected' : 'Not connected',
                      onTap: () =>
                          _showMeterDetailsSheet(context, esiid, meterNumber),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Subscription plan ──
                  _anim(
                    6,
                    child: _ProfileMenuCard(
                      icon: Icons.settings_outlined,
                      title: 'Subscription plan',
                      subtitle: AppSettingsStore.instance.isFreeTrialActive
                          ? 'Free Trial (${AppSettingsStore.instance.freeTrialDaysRemaining}d left)'
                          : 'Premium',
                      onTap: () => _showSubscriptionSheet(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Payment method ──
                  _anim(
                    7,
                    child: _ProfileMenuCard(
                      icon: Icons.credit_card_rounded,
                      title: 'Payment method',
                      subtitle: 'Manage payment',
                      onTap: () => _showPaymentSheet(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Billing history ──
                  _anim(
                    8,
                    child: _ProfileMenuCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Billing history',
                      subtitle: 'View invoices',
                      onTap: () => _showBillingSheet(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Settings (Rate & Budget) ──
                  _anim(
                    9,
                    child: _ProfileMenuCard(
                      icon: Icons.tune_rounded,
                      title: 'Energy settings',
                      subtitle:
                          '${(AppSettingsStore.instance.ratePerKwh * 100).toStringAsFixed(1)}¢/kWh · \$${AppSettingsStore.instance.dailyBudget.toStringAsFixed(2)}/day',
                      onTap: () => _showEnergySettingsSheet(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── About ElectricToday ──
                  _anim(
                    10,
                    child: _ProfileMenuCard(
                      icon: Icons.info_outline_rounded,
                      title: 'About ElectricToday',
                      subtitle: 'How we use Smart Meter Texas data',
                      onTap: () => _showAboutSheet(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Data & Disclaimer ──
                  _anim(
                    11,
                    child: _ProfileMenuCard(
                      icon: Icons.gavel_rounded,
                      title: 'Data & Disclaimer',
                      subtitle: 'Read-only usage data and legal notes',
                      onTap: () => _showDisclaimerSheet(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Privacy & Terms ──
                  _anim(
                    12,
                    child: _ProfileMenuCard(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy & Terms',
                      subtitle: 'How your account data is handled',
                      onTap: () => _showPrivacySheet(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── App Version ──
                  _anim(
                    13,
                    child: _ProfileMenuCard(
                      icon: Icons.verified_rounded,
                      title: 'App version',
                      subtitle: 'v1.0.0',
                      onTap: () => _showAppVersionSheet(context),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Cancel subscription ──
                  _anim(
                    14,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _showCancelDialog(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Text(
                          'Cancel subscription',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Log Out ──
                  _anim(
                    15,
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => _confirmLogout(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: const Color(
                            0xFFFEE2E2,
                          ).withValues(alpha: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: const Color(0xFFEF4444),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Log Out',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Disclaimer ──
                  Text(
                    'ElectricToday is an independent application and is '
                    'not affiliated with, endorsed by, or sponsored by '
                    'Smart Meter Texas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _anim(int index, {required Widget child}) {
    final i = index.clamp(0, _animItemCount - 1);
    return Transform.translate(
      offset: Offset(0, _slideAnims[i].value),
      child: Opacity(opacity: _fadeAnims[i].value, child: child),
    );
  }

  // ── Meter details sheet ────────────────────────────────────────────────

  void _showMeterDetailsSheet(
    BuildContext context,
    String esiid,
    String meterNumber,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handleBar(),
                const SizedBox(height: 14),
                const Text(
                  'Smart Meter Connection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 20),
                _sheetInfoRow(
                  icon: Icons.tag_rounded,
                  label: 'ESIID',
                  value: esiid,
                  copiable: true,
                ),
                const SizedBox(height: 14),
                _sheetInfoRow(
                  icon: Icons.electric_meter_rounded,
                  label: 'Meter Number',
                  value: meterNumber,
                  copiable: meterNumber != 'Not set',
                ),
                const SizedBox(height: 14),
                _sheetInfoRow(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Status',
                  value: esiid != '—' ? 'Connected' : 'Not connected',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool copiable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (copiable)
            IconButton(
              icon: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('$label copied'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
              },
            ),
        ],
      ),
    );
  }

  // ── Subscription sheet ─────────────────────────────────────────────────

  void _showSubscriptionSheet(BuildContext context) {
    final settings = AppSettingsStore.instance;
    final isTrial = settings.isFreeTrialActive;
    final daysLeft = settings.freeTrialDaysRemaining;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handleBar(),
                const SizedBox(height: 14),
                const Text(
                  'Subscription Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Premium Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isTrial
                            ? 'Free trial · $daysLeft days remaining'
                            : '\$1.99/month',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _subscriptionFeature('Real-time usage monitoring'),
                _subscriptionFeature('Daily cost & budget alerts'),
                _subscriptionFeature('Detailed interval charts'),
                _subscriptionFeature('Partner offers & savings'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _subscriptionFeature(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.primaryGreen.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment sheet ──────────────────────────────────────────────────────

  void _showPaymentSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handleBar(),
                const SizedBox(height: 14),
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F71),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'VISA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          '•••• •••• •••• 4242',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Payment processing is coming soon. Your trial is active.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Billing sheet ──────────────────────────────────────────────────────

  void _showBillingSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handleBar(),
                const SizedBox(height: 14),
                const Text(
                  'Billing History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 32,
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No invoices yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Billing history will appear here once your subscription begins.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Energy settings sheet ──────────────────────────────────────────────

  void _showEnergySettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handleBar(),
                const SizedBox(height: 14),
                const Text(
                  'Energy Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 20),
                _settingsSheetRow(
                  icon: Icons.attach_money_rounded,
                  label: 'Electricity Rate',
                  value:
                      '${(AppSettingsStore.instance.ratePerKwh * 100).toStringAsFixed(1)}¢/kWh',
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _editRate(context);
                  },
                ),
                const SizedBox(height: 12),
                _settingsSheetRow(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Daily Budget',
                  value:
                      '\$${AppSettingsStore.instance.dailyBudget.toStringAsFixed(2)}',
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _editBudget(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _settingsSheetRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _handleBar() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  // ── About / Disclaimer / Privacy sheets ─────────────────────────────

  Future<void> _showAboutSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handleBar(),
                const SizedBox(height: 14),
                const Text(
                  'About ElectricToday',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ElectricToday helps you monitor electricity usage trends, '
                  'estimated costs, and budget progress in one place.\n\n'
                  'We use your Smart Meter Texas (SMT) credentials to fetch '
                  'read-only meter data. We do not modify your account, change '
                  'your plan, or share your data with third parties.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDisclaimerSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handleBar(),
                const SizedBox(height: 14),
                const Text(
                  'Data & Disclaimer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ElectricToday is an independent app and is not affiliated with, '
                  'endorsed by, or sponsored by Smart Meter Texas, any utility '
                  'company, or electricity provider.\n\n'
                  'All usage data is read-only and shown for informational purposes. '
                  'Estimated costs are approximate and depend on the electricity '
                  'rate you set. We do not guarantee billing accuracy.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPrivacySheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handleBar(),
                const SizedBox(height: 14),
                const Text(
                  'Privacy & Terms',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your SMT session and app settings are stored securely on '
                  'your device to keep your experience persistent across '
                  'restarts. Your SMT password is encrypted before storage.\n\n'
                  'We do not sell, share, or transfer your personal information '
                  'to third parties. By using ElectricToday, you agree to our '
                  'terms of service and privacy policy.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Cancel dialog ──────────────────────────────────────────────────────

  void _showCancelDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cancel Subscription',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Are you sure? You will lose access to premium features at the end of your billing period.',
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Keep Plan'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showToast(context, 'Cancellation is not yet available.');
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
              ),
              child: const Text(
                'Cancel Plan',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Existing dialogs ───────────────────────────────────────────────────

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AuthSessionBloc>().add(const LogoutRequested());
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editHomeType(BuildContext context) async {
    String selected =
        AppSettingsStore.instance.homeType?.trim().toLowerCase().isNotEmpty ==
            true
        ? AppSettingsStore.instance.homeType!.trim().toLowerCase()
        : 'house';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Select Home Type',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOptionTile(
                    title: 'House',
                    selected: selected == 'house',
                    onTap: () => setDialogState(() => selected = 'house'),
                  ),
                  _buildOptionTile(
                    title: 'Apartment',
                    selected: selected == 'apartment',
                    onTap: () => setDialogState(() => selected = 'apartment'),
                  ),
                  _buildOptionTile(
                    title: 'Business',
                    selected: selected == 'business',
                    onTap: () => setDialogState(() => selected = 'business'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                _buildGradientDialogAction(
                  label: 'Save',
                  onPressed: () async {
                    await AppSettingsStore.instance.setHomeType(selected);
                    await AppSettingsStore.instance.setHomeLabel(
                      _formatHomeType(selected),
                    );
                    if (!mounted || !dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    setState(() {});
                    _showToast(context, 'Home type updated.');
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editTdspCompany(BuildContext context) async {
    String selected =
        AppSettingsStore.instance.tdspCompany
                ?.trim()
                .toLowerCase()
                .isNotEmpty ==
            true
        ? AppSettingsStore.instance.tdspCompany!.trim().toLowerCase()
        : 'oncor';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Select Electricity Company',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOptionTile(
                    title: 'Oncor',
                    selected: selected == 'oncor',
                    onTap: () => setDialogState(() => selected = 'oncor'),
                  ),
                  _buildOptionTile(
                    title: 'CenterPoint',
                    selected: selected == 'centerpoint',
                    onTap: () => setDialogState(() => selected = 'centerpoint'),
                  ),
                  _buildOptionTile(
                    title: 'AEP Texas',
                    selected: selected == 'aep',
                    onTap: () => setDialogState(() => selected = 'aep'),
                  ),
                  _buildOptionTile(
                    title: 'TNMP',
                    selected: selected == 'tnmp',
                    onTap: () => setDialogState(() => selected = 'tnmp'),
                  ),
                  _buildOptionTile(
                    title: 'Other / Not sure',
                    selected: selected == 'other',
                    onTap: () => setDialogState(() => selected = 'other'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                _buildGradientDialogAction(
                  label: 'Save',
                  onPressed: () async {
                    await AppSettingsStore.instance.setTdspCompany(selected);
                    await AppSettingsStore.instance.setUtilityCompany(
                      _formatTdspCompany(selected),
                    );
                    if (!mounted || !dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    setState(() {});
                    _showToast(context, 'Electricity company updated.');
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editRate(BuildContext context) async {
    final controller = TextEditingController(
      text: (AppSettingsStore.instance.ratePerKwh * 100).toStringAsFixed(2),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Set Electricity Rate',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Cents per kWh',
              hintText: 'e.g., 15.0',
              filled: true,
              fillColor: AppColors.background,
              labelStyle: const TextStyle(color: AppColors.textMuted),
              hintStyle: const TextStyle(color: AppColors.textMuted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryBlue,
                  width: 1.6,
                ),
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
                final cents = double.tryParse(raw);
                if (cents == null || cents <= 0 || cents > 1000) {
                  _showToast(
                    context,
                    'Enter a valid rate (e.g., 15.0 cents/kWh).',
                    isError: true,
                  );
                  return;
                }
                await AppSettingsStore.instance.setRatePerKwh(cents / 100.0);
                if (!mounted) return;
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                setState(() {});
                _showToast(context, 'Rate updated.');
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _editBudget(BuildContext context) async {
    final controller = TextEditingController(
      text: AppSettingsStore.instance.dailyBudget.toStringAsFixed(2),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Set Daily Budget',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Budget in USD',
              hintText: 'e.g., 8.00',
              filled: true,
              fillColor: AppColors.background,
              labelStyle: const TextStyle(color: AppColors.textMuted),
              hintStyle: const TextStyle(color: AppColors.textMuted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryBlue,
                  width: 1.6,
                ),
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
                final dollars = double.tryParse(raw);
                if (dollars == null || dollars <= 0 || dollars > 1000) {
                  _showToast(
                    context,
                    'Enter a valid budget (e.g., 8.00).',
                    isError: true,
                  );
                  return;
                }
                await AppSettingsStore.instance.setDailyBudget(dollars);
                if (!mounted) return;
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                setState(() {});
                _showToast(context, 'Budget updated.');
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionTile({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryBlue.withValues(alpha: 0.08)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primaryBlue
                  : Colors.black.withValues(alpha: 0.08),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primaryBlue : AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showToast(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFEF4444)
              : AppColors.primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
  }

  Future<void> _showAppVersionSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handleBar(),
                const SizedBox(height: 14),
                const Text(
                  'App Version',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Build v1.0.0 is up to date.',
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Partner offers sheet ───────────────────────────────────────────────

  Future<void> _showPartnerOffersSheet(
    BuildContext context, {
    required String homeLabel,
    required String utilityCompany,
  }) async {
    final offersFuture = _buildPartnerOffers(
      homeLabel: homeLabel,
      utilityCompany: utilityCompany,
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: FutureBuilder<_PartnerOffersData>(
              future: offersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const SizedBox(
                    height: 240,
                    child: Center(
                      child: Text(
                        'Unable to load offers right now.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _handleBar(),
                      const SizedBox(height: 14),
                      const Text(
                        'Partner Offers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.summaryLine,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...data.offers.map(_buildOfferTile),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfferTile(_PartnerOffer offer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(offer.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<_PartnerOffersData> _buildPartnerOffers({
    required String homeLabel,
    required String utilityCompany,
  }) async {
    final rate = AppSettingsStore.instance.ratePerKwh;
    final budget = AppSettingsStore.instance.dailyBudget;
    final latestDailyKwh = await _fetchLatestDailyKwh();
    final latestDailyCost = latestDailyKwh != null
        ? latestDailyKwh * rate
        : null;
    final offers = <_PartnerOfferScore>[
      _PartnerOfferScore(
        score: rate >= 0.18 ? 100 : 70,
        offer: _PartnerOffer(
          icon: Icons.price_change_outlined,
          title: 'Rate Comparison Pack',
          subtitle:
              'Compare options around ${(rate * 100).toStringAsFixed(1)}c/kWh to reduce monthly spend.',
        ),
      ),
      _PartnerOfferScore(
        score: budget <= 6 ? 98 : 62,
        offer: _PartnerOffer(
          icon: Icons.savings_outlined,
          title: 'Budget Guard Bundle',
          subtitle:
              'Automation picks for a \$${budget.toStringAsFixed(2)}/day target.',
        ),
      ),
      _PartnerOfferScore(
        score: utilityCompany != 'Tap to set' ? 90 : 55,
        offer: _PartnerOffer(
          icon: Icons.bolt_outlined,
          title: 'Provider Tools',
          subtitle: utilityCompany != 'Tap to set'
              ? '$utilityCompany focused tips and add-ons.'
              : 'Set your utility to unlock recommendations.',
        ),
      ),
      _PartnerOfferScore(
        score: latestDailyKwh != null && latestDailyKwh >= 35 ? 95 : 60,
        offer: _PartnerOffer(
          icon: Icons.thermostat_outlined,
          title: 'Smart Cooling Upgrade',
          subtitle: latestDailyCost != null
              ? 'Latest daily \$${latestDailyCost.toStringAsFixed(2)}. Cooling optimization could help.'
              : 'Save on AC with thermostat scheduling.',
        ),
      ),
      _PartnerOfferScore(
        score: 50,
        offer: _PartnerOffer(
          icon: Icons.home_work_outlined,
          title: 'Home Efficiency Starter',
          subtitle: 'Tailored to $homeLabel with practical upgrades.',
        ),
      ),
    ];

    offers.sort((a, b) => b.score.compareTo(a.score));
    final ranked = offers.map((e) => e.offer).take(4).toList();
    final usageLine = latestDailyKwh != null
        ? 'Latest: ${latestDailyKwh.toStringAsFixed(1)} kWh.'
        : 'Showing settings-based recommendations.';

    return _PartnerOffersData(
      summaryLine: 'Ranked for your usage. $usageLine',
      offers: ranked,
    );
  }

  Future<double?> _fetchLatestDailyKwh() async {
    try {
      final response = await SmtApiClient().getUserUsageHistory(days: 14);
      final points = <_UsageSnapshot>[];
      _collectUsageSnapshots(response['data'], points);
      if (points.isEmpty) return null;
      points.sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return -1;
        if (b.date == null) return 1;
        return a.date!.compareTo(b.date!);
      });
      return points.last.kwh;
    } catch (_) {
      return null;
    }
  }

  void _collectUsageSnapshots(dynamic node, List<_UsageSnapshot> output) {
    if (node is Map) {
      final map = node.cast<dynamic, dynamic>();
      final kwh = _extractDoubleByKeys(map, const [
        'kwh',
        'usageKwh',
        'usage_kwh',
        'total_kwh',
        'value',
      ]);
      if (kwh != null && kwh >= 0) {
        final dateRaw = _extractValueByKeys(map, const [
          'date',
          'day',
          'readAt',
          'timestamp',
        ]);
        output.add(_UsageSnapshot(kwh: kwh, date: _tryParseDate(dateRaw)));
      }
      for (final value in map.values) {
        _collectUsageSnapshots(value, output);
      }
      return;
    }
    if (node is List) {
      for (final item in node) {
        _collectUsageSnapshots(item, output);
      }
    }
  }

  double? _extractDoubleByKeys(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  dynamic _extractValueByKeys(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) return map[key];
    }
    return null;
  }

  DateTime? _tryParseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      final millis = raw > 9999999999 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}

// ── Profile Menu Card ────────────────────────────────────────────────────────

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconGradient = false,
    this.isGradientBg = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool iconGradient;
  final bool isGradientBg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isGradientBg ? null : AppColors.cardBackground,
            gradient: isGradientBg
                ? LinearGradient(
                    colors: [
                      AppColors.primaryBlue.withValues(alpha: 0.07),
                      AppColors.primaryGreen.withValues(alpha: 0.07),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconGradient ? null : AppColors.background,
                  gradient: iconGradient ? AppColors.primaryGradient : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: iconGradient ? Colors.white : AppColors.textMain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted.withValues(alpha: 0.4),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

class _PartnerOffer {
  const _PartnerOffer({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _PartnerOfferScore {
  const _PartnerOfferScore({required this.score, required this.offer});

  final int score;
  final _PartnerOffer offer;
}

class _PartnerOffersData {
  const _PartnerOffersData({required this.summaryLine, required this.offers});

  final String summaryLine;
  final List<_PartnerOffer> offers;
}

class _UsageSnapshot {
  const _UsageSnapshot({required this.kwh, this.date});

  final double kwh;
  final DateTime? date;
}
