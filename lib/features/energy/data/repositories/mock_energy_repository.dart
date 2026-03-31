import '../../domain/entities/energy_summary.dart';
import '../../domain/entities/meter_read_request_result.dart';
import '../../domain/repositories/energy_repository.dart';

class MockEnergyRepository implements EnergyRepository {
  @override
  Future<EnergySummary> getEnergySummary() async {
    await Future.delayed(const Duration(milliseconds: 800));

    return EnergySummary(
      currentSpend: 4.23,
      totalBudget: 8.00,
      usedPercentage: 0.53,
      percentVsYesterday: -0.12,
      remainingAmount: 3.77,
      airConditionerCost: 2.15,
      kwhToday: 12.5,
      kwhTrend: 0.08,
      centsPerKwh: 15.5,
      centsTrend: -0.03,
      hasOdrData: true,
      providerMessage: null,
      readAt: null,
    );
  }

  @override
  Future<MeterReadRequestResult> requestCurrentMeterRead({String? meterNumber}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const MeterReadRequestResult(
      message: 'Meter read request submitted for further processing.',
    );
  }
}
