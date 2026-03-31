//Alerts Screen

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Header Title
              const Text(
                'Recent Alerts',
                style:TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 32),

          


              //Alert items list
              _buildAlertCard(
                title:'High usage detected at 5:30 PM',
                timeAgo: '2 HOURS AGO',
                icon: Icons.error_outline,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFEF3C7),
              ),

              const SizedBox(height: 16),

              _buildAlertCard(
                title:"You've used 80% of your daily limit",
                timeAgo: '1 HOUR AGO',
                icon: Icons.attach_money,
                iconColor: AppColors.primaryBlue,
                iconBgColor: const Color(0xFFD8EAFE),
                
              ),

              const SizedBox(height: 16),

              _buildAlertCard(
                title:'Peak hours starting soon(4-7 PM)',
                timeAgo: '30 MINS AGO',
                icon: Icons.access_time,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFEF3C7),
                
              ),

              const SizedBox(height: 16),

              _buildAlertCard(
                title:'Daily limit exceeded by \$2,15',
                timeAgo: 'YESTERDAY',
                icon: Icons.money_off,
                iconColor: const Color(0xFFDC2626),
                iconBgColor: const Color(0xFFFEE2E2),
                isUnread: true,
                
              ),
              const SizedBox(height: 100)
              


            ],
          )
        )
      )
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String timeAgo,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    bool isUnread = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),


          //Texts column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                    height: 1.3
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timeAgo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if(isUnread) ...[
            const SizedBox(width: 12),
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ]
        ],
      ),
    );
  }
}