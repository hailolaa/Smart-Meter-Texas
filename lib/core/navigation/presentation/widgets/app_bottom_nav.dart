import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.currentIndex,
    required this.onIndexChanged,
    this.hasUnreadAlerts,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final bool? hasUnreadAlerts;

  @override
  Widget build(BuildContext context) {
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
              _NavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                active: currentIndex == 0,
                onTap: () => onIndexChanged(0),
              ),
              _NavItem(
                icon: Icons.history,
                label: 'History',
                active: currentIndex == 1,
                onTap: () => onIndexChanged(1),
              ),
              const SizedBox(width: 70),
              _NavItem(
                icon: Icons.notifications_none_outlined,
                label: 'Alerts',
                active: currentIndex == 3,
                hasNotification: hasUnreadAlerts == true,
                onTap: () => onIndexChanged(3),
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: 'Account',
                active: currentIndex == 4,
                onTap: () => onIndexChanged(4),
              ),
            ],
          ),
          Positioned(
            top: -25,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: GestureDetector(
              onTap: () => onIndexChanged(2),
              child: Column(
                children: [
                  Container(
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
                  const SizedBox(height: 4),
                  Text(
                    'Energy',
                    style: TextStyle(
                      color: currentIndex == 2
                          ? AppColors.primaryBlue
                          : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight:
                          currentIndex == 2 ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.hasNotification = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool hasNotification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryBlue : AppColors.textMuted;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: active ? AppColors.primaryBlue : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 4),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 28),
                if (hasNotification && !active)
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
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
