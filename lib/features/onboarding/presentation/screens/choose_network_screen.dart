import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/selectable_option_card.dart';

class ChooseNetworkScreen extends StatefulWidget {
  const ChooseNetworkScreen({super.key});

  @override
  State<ChooseNetworkScreen> createState() => _ChooseNetworkScreenState();
}

class _ChooseNetworkScreenState extends State<ChooseNetworkScreen> {
  String selectedNetwork = 'texas';

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
                "Choose electricity\nnetwork",
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
                "Select your local electricity network\nNetwork support by state – more coming soon",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              
              // ListView handles our scrollability elegantly
              Expanded(
                child: ListView(
                  children: [
                    SelectableOptionCard(
                      title: "Texas",
                      subtitle: "Available",
                      icon: Icons.location_on_rounded, // The map pin icon
                      isSelected: selectedNetwork == 'texas',
                      onTap: () async {
                       setState(() => selectedNetwork = 'texas');
                       await AppSettingsStore.instance.setNetworkState('texas');
                       if (!context.mounted) return;
                       context.push(AppRoutes.meter);
                      },
                    ),
                    const SizedBox(height: 16),
                    SelectableOptionCard(
                      title: "California",
                      subtitle: "Coming soon",
                      icon: Icons.location_on_rounded,
                      isDisabled: true, // Gracefully handles grey styling
                      isSelected: selectedNetwork == 'california',
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),
                    SelectableOptionCard(
                      title: "New York",
                      subtitle: "Coming soon",
                      icon: Icons.location_on_rounded,
                      isDisabled: true, // Gracefully handles grey styling
                      isSelected: selectedNetwork == 'new_york',
                      onTap: () {},
                    ),
                    const SizedBox(height: 48),
                    // Fine print footer
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "NETWORK AVAILABILITY DEPENDS ON YOUR STATE",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey[400],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "More states coming soon",
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
