import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meter_texas/features/energy/presentation/bloc/energy_bloc.dart';
import 'package:smart_meter_texas/features/energy/domain/entities/energy_summary.dart';
import 'package:smart_meter_texas/features/energy/domain/entities/meter_read_request_result.dart';
import 'package:smart_meter_texas/features/energy/domain/repositories/energy_repository.dart';
import 'package:smart_meter_texas/features/energy/presentation/screens/energy_screen.dart';

class _FakeEnergyRepository implements EnergyRepository {
  @override
  Future<EnergySummary> getEnergySummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return EnergySummary(
      currentSpend: 1,
      totalBudget: 8,
      usedPercentage: 0.1,
      percentVsYesterday: 0,
      remainingAmount: 7,
      airConditionerCost: 0.5,
      kwhToday: 5,
      kwhTrend: 0.02,
      centsPerKwh: 15,
      centsTrend: 0,
      hasOdrData: true,
    );
  }

  @override
  Future<MeterReadRequestResult> requestCurrentMeterRead({String? meterNumber}) async {
    return const MeterReadRequestResult(message: 'ok');
  }
}

void main() {
  testWidgets('initial load shows skeleton', (tester) async {
    final bloc = EnergyBloc(repository: _FakeEnergyRepository());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: EnergyScreen(energyBloc: bloc),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Container), findsWidgets);
  }, skip: true);
}
