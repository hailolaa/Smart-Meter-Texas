import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'profile_screen.dart'; 
import '../features/energy/presentation/screens/energy_screen.dart';
import '../features/auth/presentation/screens/welcome_back_screen.dart';
import '../features/onboarding/presentation/screens/meter_details.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0; // Default to 4 (Account/Profile Tab)

  // Our list of screens. For now, most are just placeholders.
  final List<Widget> _screens = [
    const EnergyScreen(),
    const WelcomeBackScreen(),
    const SizedBox(), // The center button doesn't swap to a screen in the bottom nav array
    const MeterDetailsScreen(), 
    const ProfileScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      // We use a custom widget at the bottom instead of BottomNavigationBar
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  Widget _buildCustomBottomNav() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_outlined, 'Home'),
              _buildNavItem(1, Icons.history, 'History'),
              const SizedBox(width: 70), // Empty space for the floating center button
              _buildNavItem(3, Icons.notifications_none_outlined, 'Alerts', hasNotification: true),
              _buildNavItem(4, Icons.person_outline, 'Account'),
            ],
          ),
          
          // Floating Center 'Energy' Button
          Positioned(
            top: -25,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: GestureDetector(
              onTap: () {
                // Action for center energy button
                debugPrint("Energy Button Tapped");
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reusable widget for each nav item standardizing the active/inactive states
  Widget _buildNavItem(int index, IconData icon, String label, {bool hasNotification = false}) {
    final isActive = _currentIndex == index;
    final color = isActive ? AppColors.primaryBlue : AppColors.textMuted;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The active blue dot above the icon
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryBlue : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 4),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 28),
                // The red notification dot on top right of icon
                if (hasNotification && !isActive) 
                  Positioned(
                    right: 0,
                    top: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
