import '../../domain/entities/energy_summary.dart';

abstract class EnergyState {}

class EnergyInitial extends EnergyState {}

class EnergyLoading extends EnergyState {}

class EnergyLoaded extends EnergyState {
  final EnergySummary summary;
  EnergyLoaded(this.summary);
}

class EnergyError extends EnergyState {
  final String message;
  EnergyError(this.message);
}