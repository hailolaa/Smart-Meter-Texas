import '../entities/energy_summary.dart';

abstract class EnergyRepository {
  Future<EnergySummary> getEnergySummary();
}