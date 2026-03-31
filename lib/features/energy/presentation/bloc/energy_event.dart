abstract class EnergyEvent {}

class LoadEnergyData extends EnergyEvent {}

class RefreshEnergyData extends EnergyEvent {}

class RequestCurrentMeterRead extends EnergyEvent {
  RequestCurrentMeterRead({this.meterNumber});
  final String? meterNumber;
}
