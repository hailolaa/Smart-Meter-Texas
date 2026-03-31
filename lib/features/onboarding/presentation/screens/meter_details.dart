import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/session/smt_session_store.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../core/network/smt_api_client.dart';
import '../../../../core/theme/app_theme.dart';

class MeterDetailsScreen extends StatefulWidget {
  const MeterDetailsScreen({super.key});

  @override
  State<MeterDetailsScreen> createState() => _MeterDetailsScreenState();
}

class _MeterDetailsScreenState extends State<MeterDetailsScreen> {
  String selectedCompany = 'oncor';
  final TextEditingController _esiidController = TextEditingController();
  final TextEditingController _meterNumberController = TextEditingController();
  String? _esiidError;
  String? _meterError;

  // YouTube video URLs and IDs for the "Explain" buttons
  static const _esiidVideoId = 'eBfjYz52jHo';
  static const _meterVideoId = 'eBfjYz52jHo';
  static const _tdspVideoId = 'eBfjYz52jHo';

  @override
  void dispose() {
    _esiidController.dispose();
    _meterNumberController.dispose();
    super.dispose();
  }

  void _showExplainSheet(BuildContext context, {
    required String videoId,
    required String title,
    required String description,
  }) {
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    final videoUrl = 'https://www.youtube.com/watch?v=$videoId';

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

            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
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
                    // Dark overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    // Play button
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
              // ── ESIID Number ──
              _buildSectionHeader(
                icon: Icons.tag_rounded,
                iconColor: AppColors.primaryBlue,
                title: "ESIID Number",
                onExplain: () => _showExplainSheet(
                  context,
                  videoId: _esiidVideoId,
                  title: "What is an ESIID?",
                  description: "Your Electric Service Identifier is a unique 17-22 digit number assigned to your meter.",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _esiidController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  hint: "Enter your 17-22 digit ESIID",
                  icon: Icons.tag_rounded,
                ),
              ),
              if (_esiidError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _esiidError!,
                  style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 28),

              // ── Meter Number ──
              _buildSectionHeader(
                icon: Icons.speed_rounded,
                iconColor: AppColors.primaryGreen,
                title: "Meter Number",
                onExplain: () => _showExplainSheet(
                  context,
                  videoId: _meterVideoId,
                  title: "Where is my Meter Number?",
                  description: "The meter number is printed on the front of your electric meter or on your electricity bill.",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _meterNumberController,
                decoration: _inputDecoration(
                  hint: "Enter your meter number",
                  icon: Icons.speed_rounded,
                ),
              ),
              if (_meterError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _meterError!,
                  style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 28),

              // ── Electricity Company (TDSP) ──
              _buildSectionHeader(
                icon: Icons.business_rounded,
                iconColor: const Color(0xFF1E293B),
                title: "Electricity Company",
                onExplain: () => _showExplainSheet(
                  context,
                  videoId: _tdspVideoId,
                  title: "What is a TDSP?",
                  description: "Your Transmission and Distribution Service Provider delivers electricity to your home.",
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Your transmission & distribution provider (TDSP)",
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),

              // Scrollable Company List
              Expanded(
                child: ListView(
                  children: [
                    _buildCompanyCard("Oncor", 'oncor'),
                    const SizedBox(height: 10),
                    _buildCompanyCard("CenterPoint", 'centerpoint'),
                    const SizedBox(height: 10),
                    _buildCompanyCard("AEP Texas", 'aep'),
                    const SizedBox(height: 10),
                    _buildCompanyCard("TNMP", 'tnmp'),
                    const SizedBox(height: 10),
                    _buildCompanyCard("Other / Not sure", 'other'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Confirm & Continue ──
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
                  onPressed: _onConfirm,
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

  Future<void> _onConfirm() async {
    final esiid = _esiidController.text.trim();
    final meterNumber = _meterNumberController.text.trim();
    bool hasError = false;

    if (esiid.isEmpty || esiid.length < 17) {
      setState(() => _esiidError = 'Please enter a valid ESIID (17+ digits).');
      hasError = true;
    } else {
      setState(() => _esiidError = null);
    }

    if (meterNumber.isEmpty) {
      setState(() => _meterError = 'Please enter your meter number.');
      hasError = true;
    } else {
      setState(() => _meterError = null);
    }

    if (hasError) return;

    // Save locally
    await SmtSessionStore.instance.saveMeterNumber(meterNumber);
    await AppSettingsStore.instance.setTdspCompany(selectedCompany);

    // Save ESIID to session store and push to backend
    final session = SmtSessionStore.instance;
    await session.saveSession(
      sessionId: session.sessionId ?? '',
      esiid: esiid,
    );

    // Best-effort push ESIID to backend DB
    try {
      await SmtApiClient().updateEsiid(esiid);
    } catch (_) {
      // Non-fatal — ESIID is already saved locally
    }

    if (!mounted) return;
    context.push(AppRoutes.provider);
  }

  // ── Reusable widgets ──

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onExplain,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: onExplain,
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
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
    );
  }

  Widget _buildCompanyCard(String title, String id) {
    bool isSelected = selectedCompany == id;
    return GestureDetector(
      onTap: () => setState(() => selectedCompany = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.02) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.textMain : Colors.grey[800],
          ),
        ),
      ),
    );
  }
}
