import 'package:flutter/material.dart';
import 'app_theme.dart';

Widget buildAppDatePicker(BuildContext context, Widget? child) {
  if (child == null) return const SizedBox.shrink();

  final baseTheme = Theme.of(context);
  final mediaQuery = MediaQuery.of(context);

  final themed = baseTheme.copyWith(
    colorScheme: baseTheme.colorScheme.copyWith(
      primary: AppColors.primaryBlue,
      onPrimary: Colors.white,
      surface: AppColors.cardBackground,
      onSurface: AppColors.textMain,
    ),
    dialogTheme: baseTheme.dialogTheme.copyWith(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    datePickerTheme: baseTheme.datePickerTheme.copyWith(
      backgroundColor: AppColors.cardBackground,
      headerBackgroundColor: AppColors.primaryBlue,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.textMuted,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );

  return Theme(
    data: themed,
    child: MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.05),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 360,
            maxHeight: 520,
          ),
          child: child,
        ),
      ),
    ),
  );
}
