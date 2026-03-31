import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/selectable_option_card.dart';

class SelectHomeTypeScreen extends StatefulWidget {
  const SelectHomeTypeScreen({super.key});

  @override
  State<SelectHomeTypeScreen> createState() => _SelectHomeTypeScreenState();
}

class _SelectHomeTypeScreenState extends State<SelectHomeTypeScreen> {
  String selectedType = 'house';

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
                "Select your home\ntype",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 48),
              
             
              Expanded(
                child: ListView(
                  children: [
                    SelectableOptionCard(
                      title: "House",
                      subtitle: "Standalone residence",
                      icon: Icons.home_rounded,
                      isSelected: selectedType == 'house',
                      onTap: () {
                        setState(() {
                          selectedType = 'house';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
           
                    SelectableOptionCard(
                      title: "Apartment",
                      subtitle: "Multi-unit building",
                      icon: Icons.domain_rounded,
                      isDisabled: true, 
                      trailingBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "COMING SOON",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      isSelected: selectedType == 'apartment',
                      onTap: () {
                        setState(() {
                          selectedType = 'apartment';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SelectableOptionCard(
                      title: "Business",
                      subtitle: "Store or commercial",
                      icon: Icons.storefront_rounded,
                      isSelected: selectedType == 'business',
                      onTap: () {
                        setState(() {
                          selectedType = 'business';
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              // Continue Button anchored securely to bottom
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
                    await AppSettingsStore.instance.setHomeType(selectedType);
                    if (!context.mounted) return;
                    context.push(AppRoutes.network);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
