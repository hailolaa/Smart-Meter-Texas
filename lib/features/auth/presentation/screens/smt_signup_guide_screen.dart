import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';

class SmtSignupGuideScreen extends StatefulWidget {
  const SmtSignupGuideScreen({super.key});

  @override
  State<SmtSignupGuideScreen> createState() => _SmtSignupGuideScreenState();
}

class _SmtSignupGuideScreenState extends State<SmtSignupGuideScreen> {
  static final Uri _smtSignupUri = Uri.parse('https://www.smartmetertexas.com/home');

  Future<void> _openSmtSignupPortal() async {
    try {
      final launched = await launchUrl(
        _smtSignupUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !mounted) return;
      _showLaunchFallback();
    } catch (_) {
      if (!mounted) return;
      _showLaunchFallback();
    }
  }

  void _showLaunchFallback() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Could not open browser automatically. Portal link copied to clipboard.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warningOrange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    Clipboard.setData(ClipboardData(text: _smtSignupUri.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          'SMT Account Setup',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New to Smart Meter Texas?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Create your SMT portal account first, then connect it to ElectricToday.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registration Steps',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12),
                    _GuideStep(
                      step: '1',
                      text: 'Open the SMT portal and create your account.',
                    ),
                    _GuideStep(
                      step: '2',
                      text: 'Verify your email and sign in on the portal.',
                    ),
                    _GuideStep(
                      step: '3',
                      text: 'Add or confirm your service address and ESIID.',
                    ),
                    _GuideStep(
                      step: '4',
                      text: 'Come back to ElectricToday and log in with SMT credentials + 17-digit ESIID.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.26),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _openSmtSignupPortal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text(
                    'Go to SMT Portal Registration',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
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

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.step,
    required this.text,
  });

  final String step;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
