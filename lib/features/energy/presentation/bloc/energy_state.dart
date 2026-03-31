import '../../domain/entities/energy_summary.dart';

abstract class EnergyState {}

class EnergyInitial extends EnergyState {}

class EnergyLoading extends EnergyState {}

class EnergyLoaded extends EnergyState {
  final EnergySummary summary;
  final DateTime? meterReadLockedUntil;
  EnergyLoaded(this.summary, {this.meterReadLockedUntil});
}

class EnergyRequestInProgress extends EnergyState {
  final EnergySummary summary;
  final String? message;
  final DateTime? meterReadLockedUntil;
  EnergyRequestInProgress(
    this.summary, {
    this.message,
    this.meterReadLockedUntil,
  });
}

class EnergyEmpty extends EnergyState {
  final String message;
  EnergyEmpty(this.message);
}

enum ToastType { success, info, warning, error }

class EnergyActionSuccess extends EnergyState {
  final String message;
  final EnergySummary? summary;
  final bool isError;
  final ToastType toastType;
  EnergyActionSuccess(
    this.message, {
    this.summary,
    this.isError = false,
    this.toastType = ToastType.success,
  });
}

class EnergyError extends EnergyState {
  final String message;
  EnergyError(this.message);
}