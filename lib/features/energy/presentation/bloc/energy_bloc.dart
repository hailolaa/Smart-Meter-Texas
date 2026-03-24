import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/energy_repository.dart';
import 'energy_event.dart';
import 'energy_state.dart';

class EnergyBloc extends Bloc<EnergyEvent, EnergyState> {
  final EnergyRepository repository;

  EnergyBloc({required this.repository}) : super(EnergyInitial()) {
    on<LoadEnergyData>(_onLoadEnergyData);
  }
  Future<void>_onLoadEnergyData(
    LoadEnergyData event,
    Emitter<EnergyState> emit,
    ) async {
      emit(EnergyLoading());
      try {
        final summary = await repository.getEnergySummary();
        emit(EnergyLoaded(summary));
      } catch (e) {
        emit(EnergyError("Failed to load energy usage data."));
    }
  }
}


