class MockAppSettingsStore {
  double ratePerKwh = 0.15;
  double dailyBudget = 8.0;
  String? homeType;
  String? networkState;
  String? tdspCompany;
  String? retailProvider;
  bool hasCompletedOnboarding = false;
  DateTime? trialStartDate;

  bool get isFreeTrialActive {
    if (trialStartDate == null) return false;
    return DateTime.now().isBefore(trialStartDate!.add(const Duration(days: 7)));
  }
}
