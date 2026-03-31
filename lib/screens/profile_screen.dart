import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Header Title
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 32),

              //user info
              Row(
                children: [
                  //image placeholder
                  Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  //name and badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'John Doe',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      //premium badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Premium Subscriber',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),

              //menu card
              _buildMenuItem(
                title: 'Partner Offers',
                subtitle: 'Exclusive deals and services',
                icon: Icons.auto_awesome,
                isGradientIcon: true,
              ),
              const SizedBox(height: 16),

              _buildMenuItem(
                title: 'My home',
                subtitle: 'House 1',
                icon: Icons.home_outlined,
              ),

              const SizedBox(height: 16),

              _buildMenuItem(
                title: 'Electricity Company',
                subtitle: 'Oncor',
                icon: Icons.bolt_outlined,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required String subtitle,
    required IconData icon,
    bool isGradientIcon = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGradientIcon ? null : AppColors.cardBackground,
        gradient: isGradientIcon
            ? AppColors.primaryGradient.withOpacity(0.08)
            : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          //Icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isGradientIcon ? null : AppColors.background,
              gradient: isGradientIcon ? AppColors.primaryGradient : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 26,
              color: isGradientIcon ? Colors.white : AppColors.textMain,
            ),
          ),

          const SizedBox(width: 16),
          //Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          //Arrow
          const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }
}
