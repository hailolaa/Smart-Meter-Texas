import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/energy_bloc.dart';
import '../bloc/energy_state.dart';
import '../bloc/energy_event.dart';
import '../../data/repositories/mock_energy_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/energy_hero_card.dart';
import '../widgets/ac_cost_card.dart';
import '../widgets/metric_cards_row.dart';
import '../widgets/usage_pattern_card.dart';
import '../widgets/navigation_tile.dart';
import '../widgets/promo_card.dart';

class EnergyScreen extends StatelessWidget {
  const EnergyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          EnergyBloc(repository: MockEnergyRepository())..add(LoadEnergyData()),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocBuilder<EnergyBloc, EnergyState>(
            builder: (context, state) {
              if (state is EnergyInitial || state is EnergyLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryBlue),
                );
              } else if (state is EnergyLoaded) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [_buildHeader(), 
                      const SizedBox(height: 32),
                      EnergyHeroCard(summary: state.summary),
                      const SizedBox(height: 16),
                      ACcostCard(),
                      const SizedBox(height: 16),
                      MetricCardsRow(summary: state.summary),
                      const SizedBox(height: 24),
                      UsagePatternCard(),
                      const SizedBox(height: 16),
                      NavigationTile(
                        title: "Hourly Breakdown",
                        subtitle: "Detailed usage patterns",
                        icon: Icons.access_time_rounded,
                        iconColor: AppColors.primaryBlue,
                        iconBgColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                        onTap: () {
                          // Navigate to hourly breakdown
                        },
                      ),


                      const SizedBox(height: 16),
                       PromoCard(
                        badgeText: "Sponsored",
                        title: "Smart Home Energy Kit",
                        description: "Get a smart thermostat, LED kit and energy monitor",
                        imageLayer: Container(
                          color: Colors.blueGrey, // Placeholder for future network image
                        ),
                      ),
                      const SizedBox(height: 16),
                      NavigationTile(
                        title: "Usage History",
                        subtitle: "30 days comprehensive view",
                        icon: Icons.calendar_today_rounded,
                        iconColor: AppColors.primaryGreen,
                        iconBgColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                        onTap: () {
                          // Navigate to usage history
                        },
                      ),

                      const SizedBox(height: 16),
                      PromoCard(
                        badgeText: "Sponsored",
                        title: "Free Solar Panel Estimate",
                        description: "See how much you could save with solar energy at home. Free quote in minutes.",
                        sponsorName: "Sunrun Solar",
                        icon: Icons.campaign_outlined,
                        button: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Get Estimate",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        imageLayer: Container(
                          color: Colors.blueGrey, // Placeholder for future network image
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Take Control",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: AppColors.textMain,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              "of your energy usage",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.primaryGreen],
              begin: Alignment.topLeft,
              end: AlignmentGeometry.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
        ),
      ],
    );
  }
}
