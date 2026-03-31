import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../core/theme/app_theme.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String selectedPayment = 'credit_card';

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
              // Back button
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textMain),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Payment method",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMain,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),

              // Payment options
              Expanded(
                child: ListView(
                  children: [
                    _buildPaymentOption(
                      id: 'credit_card',
                      title: "Credit / Debit\nCard",
                      icon: Icons.credit_card_rounded,
                      iconBg: AppColors.primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentOption(
                      id: 'apple_pay',
                      title: "Apple Pay",
                      icon: Icons.apple,
                      iconBg: Colors.grey[400]!,
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentOption(
                      id: 'google_pay',
                      title: "Google Pay",
                      icon: Icons.g_mobiledata_rounded,
                      iconBg: Colors.grey[400]!,
                    ),
                  ],
                ),
              ),

              // "You will not be charged today" + Confirm
              Text(
                "You will not be charged today",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
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
                    // Start the trial on confirm
                    await AppSettingsStore.instance.ensureTrialStarted();
                    if (!context.mounted) return;
                    context.push(AppRoutes.success);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Confirm subscription",
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

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required IconData icon,
    required Color iconBg,
  }) {
    final isSelected = selectedPayment == id;
    return GestureDetector(
      onTap: () => setState(() => selectedPayment = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected ? iconBg : Colors.grey[200],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey[500], size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.textMain : Colors.grey[600],
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
