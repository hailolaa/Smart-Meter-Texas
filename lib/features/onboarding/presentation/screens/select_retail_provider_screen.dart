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
  String selectedProvider = 'txu';

  static const _explainVideoId = 'eBfjYz52jHo';

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

              // Scrollable Provider List
              Expanded(
                child: ListView(
                  children: [
                    _buildProviderCard("TXU Energy", "Fixed Rate 12mo", 'txu'),
                    const SizedBox(height: 12),
                    _buildProviderCard("Reliant Energy", "Flex Plan", 'reliant'),
                    const SizedBox(height: 12),
                    _buildProviderCard("Direct Energy", "Live Brighter 24", 'direct'),
                    const SizedBox(height: 12),
                    _buildProviderCard("Green Mountain", "100% Renewable", 'green'),
                    const SizedBox(height: 12),
                    _buildProviderCard("Cirro Energy", "Simple Rate", 'cirro'),
                    const SizedBox(height: 12),
                    _buildProviderCard("Gexa Energy", "Gexa Saver 12", 'gexa'),
                    const SizedBox(height: 12),
                    _buildProviderCard("Other / Not sure", "", 'other'),
                    const SizedBox(height: 16),
                  ],
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
                    // Persist selection locally
                    await AppSettingsStore.instance.setRetailProvider(selectedProvider);

                    // Map selection to canonical provider name in backend
                    final map = <String, String>{
                      'txu': 'TXU Energy',
                      'reliant': 'Reliant Energy',
                      'direct': 'Direct Energy',
                      'green': 'Green Mountain',
                      'cirro': 'Cirro Energy',
                      'gexa': 'Gexa Energy',
                    };
                    final canonical = map[selectedProvider];

                    // Notify backend and set local rate from provider table (best-effort)
                    try {
                      final api = SmtApiClient();
                      if (canonical != null) {
                        await api.updateProviderName(canonical);
                        final providers = await api.getProviders();
                        final match = providers.firstWhere(
                          (p) => (p['name']?.toString().toLowerCase() ?? '') == canonical.toLowerCase(),
                          orElse: () => const <String, dynamic>{},
                        );
                        final cents = (match['energy_rate_cents'] as num?)?.toDouble();
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
    bool isSelected = selectedProvider == id;
    return GestureDetector(
      onTap: () => setState(() => selectedProvider = id),
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
}
