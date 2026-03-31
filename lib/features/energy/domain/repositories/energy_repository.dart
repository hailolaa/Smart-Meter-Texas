import '../entities/energy_summary.dart';
import '../entities/meter_read_request_result.dart';

abstract class EnergyRepository {
  Future<EnergySummary> getEnergySummary();
  Future<MeterReadRequestResult> requestCurrentMeterRead({String? meterNumber});
}