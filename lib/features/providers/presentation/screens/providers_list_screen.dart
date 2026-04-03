import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/smt_api_client.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';

class ProvidersListScreen extends StatefulWidget {
  const ProvidersListScreen({super.key});

  @override
  State<ProvidersListScreen> createState() => _ProvidersListScreenState();
}

class _ProvidersListScreenState extends State<ProvidersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _alphaFilter = ValueNotifier<String>('All');
  List<Map<String, dynamic>> _all = const [];
  bool _loading = true;
  String? _error;
  StreamSubscription<void>? _settingsSub;

  // Same fallback as onboarding — keeps the screen useful offline.
  static const List<Map<String, dynamic>> _fallbackProviders = [
    {'name': 'Gexa Energy',         'energy_rate_cents': 8.0,  'avg_all_in_cents': 11.2, 'plan_type': 'Bill Credit',     'term_months': 12},
    {'name': 'Cirro Energy',        'energy_rate_cents': 8.1,  'avg_all_in_cents': 11.5, 'plan_type': 'Tiered',          'term_months': 12},
    {'name': '4Change Energy',      'energy_rate_cents': 8.3,  'avg_all_in_cents': 10.9, 'plan_type': 'Value Fixed',     'term_months': 12},
    {'name': 'Rhythm Energy',       'energy_rate_cents': 8.4,  'avg_all_in_cents': 11.0, 'plan_type': '100% Renewable',  'term_months': 12},
    {'name': 'Champion Energy',     'energy_rate_cents': 8.6,  'avg_all_in_cents': 11.3, 'plan_type': 'Fixed',           'term_months': 12},
    {'name': 'Discount Power',      'energy_rate_cents': 8.7,  'avg_all_in_cents': 11.4, 'plan_type': 'Fixed',           'term_months': 12},
    {'name': 'Amigo Energy',        'energy_rate_cents': 8.8,  'avg_all_in_cents': 11.6, 'plan_type': 'Fixed',           'term_months': 12},
    {'name': 'Payless Power',       'energy_rate_cents': 8.9,  'avg_all_in_cents': 12.2, 'plan_type': 'Prepaid',         'term_months': 1},
    {'name': 'First Choice Power',  'energy_rate_cents': 9.0,  'avg_all_in_cents': 11.8, 'plan_type': 'Fixed',           'term_months': 12},
    {'name': 'Just Energy',         'energy_rate_cents': 9.2,  'avg_all_in_cents': 12.1, 'plan_type': 'Fixed Green',     'term_months': 12},
    {'name': 'TriEagle Energy',     'energy_rate_cents': 9.3,  'avg_all_in_cents': 11.7, 'plan_type': 'Fixed',           'term_months': 24},
    {'name': 'Spark Energy',        'energy_rate_cents': 9.4,  'avg_all_in_cents': 12.0, 'plan_type': 'Fixed',           'term_months': 12},
    {'name': 'TXU Energy',          'energy_rate_cents': 11.5, 'avg_all_in_cents': 15.1, 'plan_type': 'Fixed / Free Nights',    'term_months': 12},
    {'name': 'Reliant Energy',      'energy_rate_cents': 11.9, 'avg_all_in_cents': 14.8, 'plan_type': 'Fixed / Free Weekends',  'term_months': 12},
    {'name': 'Green Mountain',      'energy_rate_cents': 12.3, 'avg_all_in_cents': 15.9, 'plan_type': '100% Renewable',  'term_months': 12},
    {'name': 'Direct Energy',       'energy_rate_cents': 14.9, 'avg_all_in_cents': 16.5, 'plan_type': 'Simple Fixed',    'term_months': 12},
  ];

  @override
  void initState() {
    super.initState();
    _fetchProviders();
    _settingsSub = AppSettingsStore.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProviders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = SmtApiClient();
      final list = await api.getProviders().timeout(const Duration(seconds: 6));
      debugPrint('[providers] Fetched ${list.length} providers from backend');
      _sortByCheapest(list);
      if (!mounted) return;
      setState(() {
        _all = list.isNotEmpty ? list : List<Map<String, dynamic>>.from(_fallbackProviders);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[providers] Fetch failed: $e — using fallback');
      if (!mounted) return;
      final fallback = List<Map<String, dynamic>>.from(_fallbackProviders);
      _sortByCheapest(fallback);
      setState(() {
        _all = fallback;
        _error = null; // show fallback data, not an error wall
        _loading = false;
      });
    }
  }

  void _sortByCheapest(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aC = (a['avg_all_in_cents'] as num?)?.toDouble() ?? (a['energy_rate_cents'] as num?)?.toDouble() ?? 9999;
      final bC = (b['avg_all_in_cents'] as num?)?.toDouble() ?? (b['energy_rate_cents'] as num?)?.toDouble() ?? 9999;
      return aC.compareTo(bC);
    });
  }

  List<Map<String, dynamic>> _filtered() {
    final q = _searchController.text.trim().toLowerCase();
    final alpha = _alphaFilter.value;
    return _all.where((p) {
      final name = (p['name'] ?? '').toString();
      final okQ = q.isEmpty || name.toLowerCase().contains(q);
      final okA = alpha == 'All' || (name.isNotEmpty && name[0].toUpperCase() == alpha);
      return okQ && okA;
    }).toList();
  }

  Future<void> _selectProvider(Map<String, dynamic> p) async {
    final name = (p['name'] ?? '').toString();
    final avgCents = (p['avg_all_in_cents'] as num?)?.toDouble();
    final rateCents = (p['energy_rate_cents'] as num?)?.toDouble();
    final displayCents = avgCents ?? rateCents;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSwitchSheet(providerName: name, centsPerKwh: displayCents),
    );
    if (confirmed != true) return;
    try {
      final api = SmtApiClient();
      await api.updateProviderName(name);
      await AppSettingsStore.instance.setRetailProvider(name);
      final effectiveCents = rateCents ?? avgCents;
      if (effectiveCents != null && effectiveCents > 0) {
        await AppSettingsStore.instance.setRatePerKwh(effectiveCents / 100.0);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryGreen,
          content: Text('Provider updated to $name', style: const TextStyle(color: Colors.white)),
        ),
      );
      context.pop(); // go back to previous page if navigated here
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update provider')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Electric Providers'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _SearchAndFilter(
              controller: _searchController,
              alphaFilter: _alphaFilter,
              onChanged: () => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading providers…',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _fetchProviders,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchProviders,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: ListView.separated(
                            key: ValueKey('${_searchController.text}-${_alphaFilter.value}'),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemBuilder: (context, index) {
                              final p = _filtered()[index];
                              return _ProviderTile(
                                provider: p,
                                isSelected: (AppSettingsStore.instance.retailProvider ?? '').toLowerCase() ==
                                    (p['name'] ?? '').toString().toLowerCase(),
                                onTap: () => _selectProvider(p),
                              );
                            },
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemCount: _filtered().length,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilter extends StatelessWidget {
  const _SearchAndFilter({
    required this.controller,
    required this.alphaFilter,
    required this.onChanged,
  });
  final TextEditingController controller;
  final ValueNotifier<String> alphaFilter;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final letters = ['All', ...List.generate(26, (i) => String.fromCharCode('A'.codeUnitAt(0) + i))];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium search field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            style: const TextStyle(fontSize: 15, color: AppColors.textMain, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search providers',
              hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, v, __) {
                  if (v.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () {
                      controller.clear();
                      onChanged();
                    },
                    tooltip: 'Clear',
                  );
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ValueListenableBuilder<String>(
            valueListenable: alphaFilter,
            builder: (_, sel, __) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    for (final l in letters) ...[
                      _AlphaPill(
                        label: l,
                        selected: sel == l,
                        onTap: () {
                          alphaFilter.value = l;
                          onChanged();
                        },
                      ),
                      const SizedBox(width: 8),
                    ]
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AlphaPill extends StatelessWidget {
  const _AlphaPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected ? const LinearGradient(colors: [AppColors.primaryBlue, AppColors.primaryGreen]) : null,
          color: selected ? null : Colors.white,
          border: Border.all(color: selected ? Colors.transparent : Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.10 : 0.04),
              blurRadius: selected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.textMain,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.isSelected,
    required this.onTap,
  });
  final Map<String, dynamic> provider;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (provider['name'] ?? '').toString();
    final avgCents = (provider['avg_all_in_cents'] as num?)?.toDouble();
    final rateCents = (provider['energy_rate_cents'] as num?)?.toDouble();
    final planType = (provider['plan_type'] ?? '').toString();

    // Build subtitle: "11.2¢/kWh avg • Bill Credit"
    String sub = '';
    if (avgCents != null && avgCents > 0) {
      sub = '${avgCents.toStringAsFixed(1)}¢/kWh avg';
    } else if (rateCents != null && rateCents > 0) {
      sub = '${rateCents.toStringAsFixed(1)}¢/kWh';
    }
    if (planType.isNotEmpty) {
      sub = sub.isNotEmpty ? '$sub • $planType' : planType;
    }
    if (sub.isEmpty) sub = '—';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.primaryBlue : Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppColors.primaryBlue, AppColors.primaryGreen]),
              ),
              child: const Icon(Icons.flash_on_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: isSelected
                  ? const Icon(Icons.check_circle_rounded, key: ValueKey('sel'), color: AppColors.primaryGreen)
                  : const Icon(Icons.chevron_right_rounded, key: ValueKey('nav'), color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmSwitchSheet extends StatelessWidget {
  const _ConfirmSwitchSheet({required this.providerName, required this.centsPerKwh});
  final String providerName;
  final num? centsPerKwh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryBlue, size: 44),
          const SizedBox(height: 8),
          Text(
            'Switch to $providerName?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textMain),
          ),
          const SizedBox(height: 6),
          Text(
            centsPerKwh != null ? 'Estimated ${centsPerKwh!.toStringAsFixed(1)}¢/kWh' : 'Rate info will update',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMain,
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
