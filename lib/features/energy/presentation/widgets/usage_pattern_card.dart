import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class UsagePatternCard extends StatefulWidget {
  const UsagePatternCard({super.key});

  @override
  State<UsagePatternCard> createState() => _UsagePatternCardState();
}

class _UsagePatternCardState extends State<UsagePatternCard> {
  String selectedFilter = '1 hr';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardBackground,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.show_chart,
                      color: AppColors.textMain,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                "Usage Pattern",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          //Time Toggle Container
          Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [ 
                '15 min', '1 hr', '24h'].map((filter) {
                  final isSelected = selectedFilter == filter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = filter;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? AppColors.textMain : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        //chat Area Placeholder

        SizedBox(
          height: 220,
          child: Center(
            child: Text(
              "Chart Area\n(We will add fl_chart here next!)",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],  
    ),
  );
  }
}
