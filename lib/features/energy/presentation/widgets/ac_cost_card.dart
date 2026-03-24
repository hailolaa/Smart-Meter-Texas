import 'package:flutter/material.dart';
import 'package:smart_meter_texas/core/theme/app_theme.dart';

class ACcostCard extends StatelessWidget {
  const ACcostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB92C), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.air,
            color: Colors.white,
            size: 28
          ),
        ),
        const SizedBox(width: 16),

        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Air Conditioner cost today", 
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ) ,
            ),
            const SizedBox(height: 4),
            Text(
              "Estimated cost from your AC usage today",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
