import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/smt_api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_session_bloc.dart';
import '../../../auth/presentation/bloc/auth_session_event.dart';

enum _AdminModule { users, subscriptions, rates, companies, providers, reports }

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final SmtApiClient _apiClient = SmtApiClient();
  final TextEditingController _searchController = TextEditingController();
  _AdminModule _selectedModule = _AdminModule.users;
  bool _checkingAccess = true;
  bool _hasAdminAccess = false;
  String? _accessError;

  late final List<_AdminUser> _users = [
    _AdminUser(
      id: 'USR-1402',
      name: 'Emma Rodriguez',
      email: 'emma.rodriguez@demo.com',
      role: 'Viewer',
      active: true,
      verified: true,
    ),
    _AdminUser(
      id: 'USR-1403',
      name: 'Jamal Green',
      email: 'jamal.green@demo.com',
      role: 'Manager',
      active: true,
      verified: true,
    ),
    _AdminUser(
      id: 'USR-1404',
      name: 'Nina Patel',
      email: 'nina.patel@demo.com',
      role: 'Admin',
      active: false,
      verified: false,
    ),
  ];

  late final List<_SubscriptionPlan> _plans = [
    _SubscriptionPlan(
      id: 'PLN-01',
      name: 'Free Trial',
      pricePerMonth: 0,
      billingCycle: '14 days',
      isActive: true,
      members: 824,
    ),
    _SubscriptionPlan(
      id: 'PLN-02',
      name: 'Premium Monthly',
      pricePerMonth: 1.99,
      billingCycle: 'Monthly',
      isActive: true,
      members: 339,
    ),
    _SubscriptionPlan(
      id: 'PLN-03',
      name: 'Enterprise',
      pricePerMonth: 29.00,
      billingCycle: 'Monthly',
      isActive: false,
      members: 6,
    ),
  ];

  late final List<_RateConfig> _rates = [
    _RateConfig(
      id: 'RATE-11',
      label: 'Residential Default',
      centsPerKwh: 13.8,
      region: 'Texas North',
      isActive: true,
    ),
    _RateConfig(
      id: 'RATE-12',
      label: 'Peak Window',
      centsPerKwh: 18.2,
      region: 'Texas Metro',
      isActive: true,
    ),
    _RateConfig(
      id: 'RATE-13',
      label: 'Business Saver',
      centsPerKwh: 12.6,
      region: 'Texas South',
      isActive: false,
    ),
  ];

  late final List<_UtilityCompany> _companies = [
    _UtilityCompany(name: 'Oncor', coverage: 'North Texas', enabled: true),
    _UtilityCompany(name: 'CenterPoint', coverage: 'Houston', enabled: true),
    _UtilityCompany(name: 'AEP Texas', coverage: 'South Texas', enabled: true),
    _UtilityCompany(name: 'TNMP', coverage: 'Gulf Coast', enabled: false),
  ];

  late final List<_Provider> _providers = [
    _Provider(
      name: 'TXU Energy',
      planCount: 11,
      contactEmail: 'support@txu.demo',
      enabled: true,
    ),
    _Provider(
      name: 'Reliant',
      planCount: 8,
      contactEmail: 'admin@reliant.demo',
      enabled: true,
    ),
    _Provider(
      name: 'Champion Energy',
      planCount: 5,
      contactEmail: 'ops@champion.demo',
      enabled: false,
    ),
  ];

  String get _query => _searchController.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccess() async {
    try {
      final response = await _apiClient.getMe();
      final data =
          response['data'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final role = (data['role'] ?? '').toString().toLowerCase().trim();
      if (!mounted) return;
      setState(() {
        _hasAdminAccess = role == 'admin';
        _checkingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasAdminAccess = false;
        _checkingAccess = false;
        _accessError = 'Unable to verify admin access.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }

    if (!_hasAdminAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Access denied',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _accessError ??
                      'Your account does not have admin permissions.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            _buildHero(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildModulePicker(),
            const SizedBox(height: 14),
            _buildModuleSummary(),
            const SizedBox(height: 14),
            _buildModuleBody(),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleAddAction,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.textMain),
      title: const Text(
        'Admin Panel',
        style: TextStyle(
          color: AppColors.textMain,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Log out',
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
          onPressed: _confirmLogout,
        ),
      ],
    );
  }

  Future<void> _confirmLogout() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Are you sure you want to log out of the admin panel?',
            style: TextStyle(color: AppColors.textMuted, height: 1.35),
          ),
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

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  'Preview Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Operations Console',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage users, plans, rates, utilities, and providers with realistic interactions.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.35,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
        ),
        hintText: 'Search in ${_moduleTitle(_selectedModule)}',
        hintStyle: TextStyle(
          color: AppColors.textMuted.withValues(alpha: 0.85),
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildModulePicker() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _AdminModule.values.map((module) {
          final selected = _selectedModule == module;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_moduleTitle(module)),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedModule = module;
                });
              },
              selectedColor: AppColors.primaryBlue.withValues(alpha: 0.12),
              backgroundColor: AppColors.cardBackground,
              labelStyle: TextStyle(
                color: selected ? AppColors.primaryBlue : AppColors.textMain,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: selected
                    ? AppColors.primaryBlue.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.07),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModuleSummary() {
    final summary = _summaryByModule();
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            title: summary.metricTitle,
            value: summary.metricValue,
            icon: summary.metricIcon,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            title: summary.secondaryTitle,
            value: summary.secondaryValue,
            icon: summary.secondaryIcon,
          ),
        ),
      ],
    );
  }

  _ModuleSummary _summaryByModule() {
    switch (_selectedModule) {
      case _AdminModule.users:
        final active = _users.where((u) => u.active).length;
        return _ModuleSummary(
          metricTitle: 'Total Users',
          metricValue: _users.length.toString(),
          metricIcon: Icons.people_alt_rounded,
          secondaryTitle: 'Active',
          secondaryValue: '$active',
          secondaryIcon: Icons.verified_user_rounded,
        );
      case _AdminModule.subscriptions:
        final live = _plans.where((p) => p.isActive).length;
        return _ModuleSummary(
          metricTitle: 'Plans',
          metricValue: _plans.length.toString(),
          metricIcon: Icons.workspace_premium_rounded,
          secondaryTitle: 'Published',
          secondaryValue: '$live',
          secondaryIcon: Icons.check_circle_rounded,
        );
      case _AdminModule.rates:
        final active = _rates.where((r) => r.isActive).length;
        return _ModuleSummary(
          metricTitle: 'Rate Profiles',
          metricValue: _rates.length.toString(),
          metricIcon: Icons.speed_rounded,
          secondaryTitle: 'Active',
          secondaryValue: '$active',
          secondaryIcon: Icons.bolt_rounded,
        );
      case _AdminModule.companies:
        final enabled = _companies.where((c) => c.enabled).length;
        return _ModuleSummary(
          metricTitle: 'Companies',
          metricValue: _companies.length.toString(),
          metricIcon: Icons.location_city_rounded,
          secondaryTitle: 'Enabled',
          secondaryValue: '$enabled',
          secondaryIcon: Icons.domain_verification_rounded,
        );
      case _AdminModule.providers:
        final enabled = _providers.where((p) => p.enabled).length;
        return _ModuleSummary(
          metricTitle: 'Providers',
          metricValue: _providers.length.toString(),
          metricIcon: Icons.storefront_rounded,
          secondaryTitle: 'Live',
          secondaryValue: '$enabled',
          secondaryIcon: Icons.cloud_done_rounded,
        );
      case _AdminModule.reports:
        return const _ModuleSummary(
          metricTitle: 'Reports',
          metricValue: '0',
          metricIcon: Icons.bar_chart_rounded,
          secondaryTitle: 'Pending Jobs',
          secondaryValue: '0',
          secondaryIcon: Icons.pending_actions_rounded,
        );
    }
  }

  Widget _buildModuleBody() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: switch (_selectedModule) {
          _AdminModule.users => _buildUsersModule(),
          _AdminModule.subscriptions => _buildSubscriptionsModule(),
          _AdminModule.rates => _buildRatesModule(),
          _AdminModule.companies => _buildCompaniesModule(),
          _AdminModule.providers => _buildProvidersModule(),
          _AdminModule.reports => _buildReportsModule(),
        },
      ),
    );
  }

  Widget _buildUsersModule() {
    final filtered = _users
        .where(
          (u) =>
              u.name.toLowerCase().contains(_query) ||
              u.email.toLowerCase().contains(_query) ||
              u.role.toLowerCase().contains(_query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _moduleHeader('User Management', 'Tap a user to edit role and status.'),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _emptyResult('No users match your current search.'),
        ...filtered.map((user) {
          return _ActionListTile(
            icon: Icons.person_outline_rounded,
            title: user.name,
            subtitle: '${user.email} • ${user.role}',
            trailing: _statusChip(
              user.active ? 'Active' : 'Paused',
              user.active,
            ),
            onTap: () => _editUser(user),
          );
        }),
      ],
    );
  }

  Widget _buildSubscriptionsModule() {
    final filtered = _plans
        .where(
          (p) =>
              p.name.toLowerCase().contains(_query) ||
              p.billingCycle.toLowerCase().contains(_query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _moduleHeader(
          'Subscription Plans',
          'Use plan cards to publish or update pricing.',
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty) _emptyResult('No plans found for this search.'),
        ...filtered.map((plan) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plan.pricePerMonth <= 0
                                ? 'Free • ${plan.billingCycle}'
                                : '\$${plan.pricePerMonth.toStringAsFixed(2)} • ${plan.billingCycle}',
                            style: TextStyle(
                              color: AppColors.textMuted.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: plan.isActive,
                      activeColor: AppColors.primaryBlue,
                      onChanged: (value) {
                        setState(() => plan.isActive = value);
                        _showToast(
                          value
                              ? '${plan.name} published.'
                              : '${plan.name} moved to draft.',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${plan.members} members',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _editPlan(plan),
                      child: const Text('Edit Plan'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRatesModule() {
    final filtered = _rates
        .where(
          (r) =>
              r.label.toLowerCase().contains(_query) ||
              r.region.toLowerCase().contains(_query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _moduleHeader(
          'Rate Configurations',
          'Update kWh rates and active regions.',
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _emptyResult('No rate profiles match this search.'),
        ...filtered.map((rate) {
          return _ActionListTile(
            icon: Icons.auto_graph_rounded,
            title: rate.label,
            subtitle:
                '${rate.centsPerKwh.toStringAsFixed(2)}c/kWh • ${rate.region}',
            trailing: _statusChip(
              rate.isActive ? 'Active' : 'Draft',
              rate.isActive,
            ),
            onTap: () => _editRate(rate),
          );
        }),
      ],
    );
  }

  Widget _buildCompaniesModule() {
    final filtered = _companies
        .where(
          (c) =>
              c.name.toLowerCase().contains(_query) ||
              c.coverage.toLowerCase().contains(_query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _moduleHeader(
          'Electric Companies',
          'Enable/disable company visibility in app onboarding.',
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty) _emptyResult('No companies match your filter.'),
        ...filtered.map((company) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.apartment_rounded,
                  color: AppColors.primaryBlue,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                      Text(
                        company.coverage,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: company.enabled,
                  activeColor: AppColors.primaryBlue,
                  onChanged: (value) {
                    setState(() => company.enabled = value);
                    _showToast(
                      value
                          ? '${company.name} enabled for onboarding.'
                          : '${company.name} hidden from onboarding.',
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProvidersModule() {
    final filtered = _providers
        .where(
          (p) =>
              p.name.toLowerCase().contains(_query) ||
              p.contactEmail.toLowerCase().contains(_query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _moduleHeader(
          'Retail Providers',
          'Manage provider listing and support contacts.',
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty) _emptyResult('No providers match this query.'),
        ...filtered.map((provider) {
          return _ActionListTile(
            icon: Icons.store_mall_directory_outlined,
            title: provider.name,
            subtitle: '${provider.planCount} plans • ${provider.contactEmail}',
            trailing: _statusChip(
              provider.enabled ? 'Live' : 'Hidden',
              provider.enabled,
            ),
            onTap: () => _editProvider(provider),
          );
        }),
      ],
    );
  }

  Widget _buildReportsModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _moduleHeader(
          'Reports & Analytics',
          'Export and deep analytics are not connected yet.',
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warningOrange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.warningOrange.withValues(alpha: 0.3),
            ),
          ),
          child: const Text(
            'This module is in preview mode. Data export and trend forecasting will be available once backend reporting services are integrated.',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ActionListTile(
          icon: Icons.download_rounded,
          title: 'Request CSV Export',
          subtitle: 'Queue export for users, plans, rates, and providers',
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
          ),
          onTap: () =>
              _showToast('CSV export is not available yet in this build.'),
        ),
        _ActionListTile(
          icon: Icons.insights_rounded,
          title: 'Open Revenue Dashboard',
          subtitle: 'Revenue and churn metrics (coming soon)',
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
          ),
          onTap: () => _showToast('Revenue dashboard is not available yet.'),
        ),
      ],
    );
  }

  Widget _moduleHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textMuted.withValues(alpha: 0.88),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String label, bool positive) {
    final color = positive ? AppColors.primaryGreen : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _emptyResult(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _moduleTitle(_AdminModule module) {
    switch (module) {
      case _AdminModule.users:
        return 'Users';
      case _AdminModule.subscriptions:
        return 'Subscriptions';
      case _AdminModule.rates:
        return 'Rates';
      case _AdminModule.companies:
        return 'Companies';
      case _AdminModule.providers:
        return 'Providers';
      case _AdminModule.reports:
        return 'Reports';
    }
  }

  void _handleAddAction() {
    switch (_selectedModule) {
      case _AdminModule.users:
        _addUserDialog();
      case _AdminModule.subscriptions:
        _showToast('Plan creation wizard is coming soon.');
      case _AdminModule.rates:
        _addRateDialog();
      case _AdminModule.companies:
        _addCompanyDialog();
      case _AdminModule.providers:
        _showToast('Provider onboarding flow is not available yet.');
      case _AdminModule.reports:
        _showToast('Report jobs are not available yet.');
    }
  }

  Future<void> _editUser(_AdminUser user) async {
    String role = user.role;
    bool active = user.active;
    bool verified = user.verified;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(user.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const ['Viewer', 'Manager', 'Admin']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => role = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: active,
                    activeColor: AppColors.primaryBlue,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                  SwitchListTile(
                    value: verified,
                    activeColor: AppColors.primaryBlue,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Verified'),
                    onChanged: (value) =>
                        setDialogState(() => verified = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      user.role = role;
                      user.active = active;
                      user.verified = verified;
                    });
                    Navigator.of(dialogContext).pop();
                    _showToast('User updated in preview mode.');
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editPlan(_SubscriptionPlan plan) async {
    final priceController = TextEditingController(
      text: plan.pricePerMonth.toStringAsFixed(2),
    );
    final cycleController = TextEditingController(text: plan.billingCycle);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Edit ${plan.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly Price (USD)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cycleController,
                decoration: const InputDecoration(labelText: 'Billing Cycle'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final parsedPrice = double.tryParse(
                  priceController.text.trim(),
                );
                if (parsedPrice == null || parsedPrice < 0) {
                  _showToast('Enter a valid price.');
                  return;
                }
                setState(() {
                  plan.pricePerMonth = parsedPrice;
                  plan.billingCycle = cycleController.text.trim().isEmpty
                      ? plan.billingCycle
                      : cycleController.text.trim();
                });
                Navigator.of(dialogContext).pop();
                _showToast('Subscription plan updated.');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editRate(_RateConfig rate) async {
    final rateController = TextEditingController(
      text: rate.centsPerKwh.toStringAsFixed(2),
    );
    final regionController = TextEditingController(text: rate.region);
    bool active = rate.isActive;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(rate.label),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cents per kWh',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: regionController,
                    decoration: const InputDecoration(labelText: 'Region'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Active'),
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryBlue,
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final parsed = double.tryParse(rateController.text.trim());
                    if (parsed == null || parsed <= 0) {
                      _showToast('Enter a valid cents/kWh value.');
                      return;
                    }
                    setState(() {
                      rate.centsPerKwh = parsed;
                      rate.region = regionController.text.trim().isEmpty
                          ? rate.region
                          : regionController.text.trim();
                      rate.isActive = active;
                    });
                    Navigator.of(dialogContext).pop();
                    _showToast('Rate profile updated.');
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editProvider(_Provider provider) async {
    bool enabled = provider.enabled;
    final plansController = TextEditingController(
      text: provider.planCount.toString(),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(provider.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: plansController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Plan Count'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Enabled'),
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryBlue,
                    value: enabled,
                    onChanged: (value) => setDialogState(() => enabled = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final parsedPlans = int.tryParse(
                      plansController.text.trim(),
                    );
                    if (parsedPlans == null || parsedPlans < 0) {
                      _showToast('Enter a valid plan count.');
                      return;
                    }
                    setState(() {
                      provider.planCount = parsedPlans;
                      provider.enabled = enabled;
                    });
                    Navigator.of(dialogContext).pop();
                    _showToast('Provider updated in preview mode.');
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addRateDialog() async {
    final labelController = TextEditingController();
    final regionController = TextEditingController();
    final centsController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Rate Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: regionController,
                decoration: const InputDecoration(labelText: 'Region'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: centsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Cents per kWh'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final label = labelController.text.trim();
                final region = regionController.text.trim();
                final cents = double.tryParse(centsController.text.trim());
                if (label.isEmpty ||
                    region.isEmpty ||
                    cents == null ||
                    cents <= 0) {
                  _showToast('Fill all fields with valid values.');
                  return;
                }
                setState(() {
                  _rates.add(
                    _RateConfig(
                      id: 'RATE-${_rates.length + 20}',
                      label: label,
                      centsPerKwh: cents,
                      region: region,
                      isActive: true,
                    ),
                  );
                });
                Navigator.of(dialogContext).pop();
                _showToast('Rate profile added.');
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addCompanyDialog() async {
    final nameController = TextEditingController();
    final coverageController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Electric Company'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Company Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: coverageController,
                decoration: const InputDecoration(labelText: 'Coverage Area'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    coverageController.text.trim().isEmpty) {
                  _showToast('Company name and coverage are required.');
                  return;
                }
                setState(() {
                  _companies.add(
                    _UtilityCompany(
                      name: nameController.text.trim(),
                      coverage: coverageController.text.trim(),
                      enabled: true,
                    ),
                  );
                });
                Navigator.of(dialogContext).pop();
                _showToast('Electric company added.');
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addUserDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String role = 'Viewer';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add User'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const ['Viewer', 'Manager', 'Admin']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => role = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    if (name.isEmpty || email.isEmpty || !email.contains('@')) {
                      _showToast('Enter a valid name and email.');
                      return;
                    }
                    setState(() {
                      _users.add(
                        _AdminUser(
                          id: 'USR-${_users.length + 1405}',
                          name: name,
                          email: email,
                          role: role,
                          active: true,
                          verified: false,
                        ),
                      );
                    });
                    Navigator.of(dialogContext).pop();
                    _showToast('User created in preview mode.');
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryBlue,
        ),
      );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionListTile extends StatelessWidget {
  const _ActionListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleSummary {
  const _ModuleSummary({
    required this.metricTitle,
    required this.metricValue,
    required this.metricIcon,
    required this.secondaryTitle,
    required this.secondaryValue,
    required this.secondaryIcon,
  });

  final String metricTitle;
  final String metricValue;
  final IconData metricIcon;
  final String secondaryTitle;
  final String secondaryValue;
  final IconData secondaryIcon;
}

class _AdminUser {
  _AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.verified,
  });

  final String id;
  final String name;
  final String email;
  String role;
  bool active;
  bool verified;
}

class _SubscriptionPlan {
  _SubscriptionPlan({
    required this.id,
    required this.name,
    required this.pricePerMonth,
    required this.billingCycle,
    required this.isActive,
    required this.members,
  });

  final String id;
  final String name;
  double pricePerMonth;
  String billingCycle;
  bool isActive;
  int members;
}

class _RateConfig {
  _RateConfig({
    required this.id,
    required this.label,
    required this.centsPerKwh,
    required this.region,
    required this.isActive,
  });

  final String id;
  final String label;
  double centsPerKwh;
  String region;
  bool isActive;
}

class _UtilityCompany {
  _UtilityCompany({
    required this.name,
    required this.coverage,
    required this.enabled,
  });

  final String name;
  final String coverage;
  bool enabled;
}

class _Provider {
  _Provider({
    required this.name,
    required this.planCount,
    required this.contactEmail,
    required this.enabled,
  });

  final String name;
  int planCount;
  final String contactEmail;
  bool enabled;
}
