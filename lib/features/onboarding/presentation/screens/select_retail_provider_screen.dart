import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/smt_api_client.dart';

class SelectRetailProviderScreen extends StatefulWidget {
  const SelectRetailProviderScreen({super.key});

  @override
  State<SelectRetailProviderScreen> createState() => _SelectRetailProviderScreenState();
}

class _SelectRetailProviderScreenState extends State<SelectRetailProviderScreen> {
  String? selectedProviderName;
  List<Map<String, dynamic>> _providers = const [];
  bool _loading = true;

  // Full fallback matching the DB seed — onboarding never blocks.
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

  static const _explainVideoId = 'eBfjYz52jHo';

  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  void _showExplainSheet(BuildContext context) {
    const thumbnailUrl = 'https://img.youtube.com/vi/$_explainVideoId/hqdefault.jpg';
    const videoUrl = 'https://www.youtube.com/watch?v=$_explainVideoId';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              "What is a Retail Provider?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textMain),
            ),
            const SizedBox(height: 6),
            Text(
              "The company you pay for electricity. They set your rate and billing plan.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.4),
            ),
            const SizedBox(height: 20),

            // Video thumbnail with play overlay
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final uri = Uri.parse(videoUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.play_circle_fill_rounded, size: 64, color: AppColors.primaryBlue),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryBlue, size: 38),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Watch on YouTube button
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse(videoUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 22),
                label: const Text(
                  "Watch on YouTube",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                "Choose your Retail\nElectric Provider",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Select your electricity provider",
                style: TextStyle(fontSize: 16, color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Retail Electric Provider",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  GestureDetector(
                    onTap: () => _showExplainSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outline_rounded, color: AppColors.primaryBlue, size: 14),
                          SizedBox(width: 4),
                          Text(
                            "Explain",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Providers list (backend or fallback)
              Expanded(
                child: _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primaryBlue)),
                            const SizedBox(height: 12),
                            Text('Loading providers…', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: _providers.length + 1, // +1 for "Other / Not sure"
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == _providers.length) {
                            return _buildProviderCard("Other / Not sure", "", 'other');
                          }
                          final p = _providers[index];
                          final name = (p['name'] ?? '').toString();
                          final avgCents = (p['avg_all_in_cents'] as num?)?.toDouble();
                          final rateCents = (p['energy_rate_cents'] as num?)?.toDouble();
                          final planType = (p['plan_type'] ?? '').toString();
                          // Display avg all-in cents, fallback to energy rate cents
                          String subtitle = '';
                          if (avgCents != null && avgCents > 0) {
                            subtitle = '${avgCents.toStringAsFixed(1)}¢/kWh avg';
                          } else if (rateCents != null && rateCents > 0) {
                            subtitle = '${rateCents.toStringAsFixed(1)}¢/kWh';
                          }
                          if (planType.isNotEmpty) {
                            subtitle = subtitle.isNotEmpty ? '$subtitle • $planType' : planType;
                          }
                          return _buildProviderCard(name, subtitle, name.toLowerCase());
                        },
                      ),
              ),

              // Confirm & Continue Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.primaryGreen],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    // Resolve chosen provider name (allowing 'other')
                    final chosen = selectedProviderName;
                    if (chosen == null) return;
                    await AppSettingsStore.instance.setRetailProvider(
                      chosen == 'other' ? 'Other / Not sure' : chosen,
                    );

                    // Notify backend and set local rate from provider table (best-effort)
                    try {
                      final api = SmtApiClient();
                      if (chosen != 'other') {
                        await api.updateProviderName(chosen);
                        final providers = await api.getProviders();
                        final match = providers.firstWhere(
                          (p) => (p['name']?.toString().toLowerCase() ?? '') == chosen.toLowerCase(),
                          orElse: () => const <String, dynamic>{},
                        );
                        final cents = (match['avg_all_in_cents'] as num?)?.toDouble() ??
                            (match['energy_rate_cents'] as num?)?.toDouble();
                        if (cents != null && cents > 0) {
                          await AppSettingsStore.instance.setRatePerKwh(cents / 100.0);
                        }
                      }
                    } catch (_) {/* non-fatal */}

                    await AppSettingsStore.instance.setHasCompletedOnboarding(true);
                    if (!context.mounted) return;
                    if (AppSettingsStore.instance.isFreeTrialActive) {
                      context.go(AppRoutes.dashboard);
                    } else {
                      context.go(AppRoutes.paywall);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Confirm & Continue",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard(String title, String subtitle, String id) {
    bool isSelected = selectedProviderName == id || (id != 'other' && selectedProviderName == title);
    return GestureDetector(
      onTap: () => setState(() => selectedProviderName = id == 'other' ? 'other' : title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.02) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.textMain : Colors.grey[800],
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _fetchProviders() async {
    setState(() => _loading = true);
    try {
      final api = SmtApiClient();
      final list = await api.getProviders().timeout(const Duration(seconds: 5));
      debugPrint('[onboarding] Fetched ${list.length} providers from backend');
      _sortByCheapest(list);
      if (!mounted) return;
      setState(() {
        _providers = list.isNotEmpty ? list : List<Map<String, dynamic>>.from(_fallbackProviders);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[onboarding] Provider fetch failed: $e — using fallback');
      if (!mounted) return;
      final fallback = List<Map<String, dynamic>>.from(_fallbackProviders);
      _sortByCheapest(fallback);
      setState(() {
        _providers = fallback;
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
}
