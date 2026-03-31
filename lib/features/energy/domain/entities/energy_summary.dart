class EnergySummary {
  final double currentSpend; // e.g., 4.23
  final double totalBudget;  // e.g., 8.00
  final double usedPercentage; // e.g., 0.53 (for 53%)
  final double percentVsYesterday; // e.g., -0.12 (for 12% vs yesterday)
  final double remainingAmount; // e.g., 3.77
  final double airConditionerCost; 
  final double kwhToday; 
  final double kwhTrend; // e.g., 0.08 (for 8% up)
  final double centsPerKwh;
  final double centsTrend; // e.g., -0.03 (for 3% down)
  final bool hasOdrData;
  final String? providerMessage;
  final String? readAt;

  EnergySummary({
    required this.currentSpend,
    required this.totalBudget,
    required this.usedPercentage,
    required this.percentVsYesterday,
    required this.remainingAmount,
    required this.airConditionerCost,
    required this.kwhToday,
    required this.kwhTrend,
    required this.centsPerKwh,
    required this.centsTrend,
    required this.hasOdrData,
    this.providerMessage,
    this.readAt,
  });
}