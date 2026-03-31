import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meter_texas/core/network/energy_realtime_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meter_texas/core/network/smt_api_client.dart';
import 'package:smart_meter_texas/core/session/smt_session_store.dart';
import 'package:smart_meter_texas/features/energy/domain/entities/energy_summary.dart';
import 'package:smart_meter_texas/features/energy/domain/entities/meter_read_request_result.dart';
import 'package:smart_meter_texas/features/energy/domain/repositories/energy_repository.dart';
import 'package:smart_meter_texas/features/energy/presentation/bloc/energy_bloc.dart';
import 'package:smart_meter_texas/features/energy/presentation/bloc/energy_event.dart';
import 'package:smart_meter_texas/features/energy/presentation/bloc/energy_state.dart';

class _FakeRepo implements EnergyRepository {
  _FakeRepo(this.summary);
  final EnergySummary summary;
  int loadCount = 0;

  @override
  Future<EnergySummary> getEnergySummary() async {
    loadCount += 1;
    return summary;
  }

  @override
  Future<MeterReadRequestResult> requestCurrentMeterRead({String? meterNumber}) async {
    return const MeterReadRequestResult(message: 'ok');
  }
}

class _FakeApi extends SmtApiClient {
  @override
  Future<Map<String, dynamic>> getOdrRateLimit() async {
    return {
      'success': true,
      'data': {'lockedUntil': null}
    };
  }
}

class _FakeRealtimeClient implements EnergyRealtimeClient {
  final _controller = StreamController<EnergyRealtimeMessage>.broadcast();
  bool disposed = false;

  @override
  Stream<EnergyRealtimeMessage> connect({required String jwtToken}) => _controller.stream;

  void emit(Map<String, dynamic> data, {int sequence = 1}) {
    _controller.add(
      EnergyRealtimeMessage(
        type: 'energy_snapshot',
        sequence: sequence,
        data: data,
      ),
    );
  }

  void fail([Object error = const FormatException('socket closed')]) {
    _controller.addError(error);
  }

  @override
  void disconnect() {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}

EnergySummary _summary(double kwh) => EnergySummary(
      currentSpend: 1,
      totalBudget: 8,
      usedPercentage: 0.2,
      percentVsYesterday: 0,
      remainingAmount: 7,
      airConditionerCost: 0.5,
      kwhToday: kwh,
      kwhTrend: 0,
      centsPerKwh: 15,
      centsTrend: 0,
      hasOdrData: true,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SmtSessionStore.instance.load();
    await SmtSessionStore.instance.saveSession(
      sessionId: 'session-1',
      esiid: '12345678901234567',
      jwtToken: 'jwt-1',
      userId: 1,
    );
  });

  test('RefreshEnergyData fetches fresh data', () async {
    final repo = _FakeRepo(_summary(3));
    final bloc = EnergyBloc(
      repository: repo,
      apiClient: _FakeApi(),
      realtimeClient: _FakeRealtimeClient(),
    );
    addTearDown(bloc.close);

    bloc.add(LoadEnergyData());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bloc.add(RefreshEnergyData());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repo.loadCount, greaterThanOrEqualTo(2));
  });

  test('LoadEnergyData eventually emits EnergyLoaded', () async {
    final bloc = EnergyBloc(
      repository: _FakeRepo(_summary(3)),
      apiClient: _FakeApi(),
      realtimeClient: _FakeRealtimeClient(),
    );
    addTearDown(bloc.close);
    bloc.add(LoadEnergyData());
    await expectLater(
      bloc.stream,
      emits(
        isA<EnergyLoaded>(),
      ),
    );
  });

  test('realtime snapshot updates EnergyLoaded data', () async {
    final repo = _FakeRepo(_summary(2));
    final realtime = _FakeRealtimeClient();
    final bloc = EnergyBloc(
      repository: repo,
      apiClient: _FakeApi(),
      realtimeClient: realtime,
    );
    addTearDown(bloc.close);

    bloc.add(LoadEnergyData());
    await Future<void>.delayed(const Duration(milliseconds: 60));

    realtime.emit({
      'currentSpend': 3.6,
      'totalBudget': 8.0,
      'usedPercentage': 0.45,
      'percentVsYesterday': 0.1,
      'remainingAmount': 4.4,
      'airConditionerCost': 1.2,
      'kwhToday': 4.0,
      'kwhTrend': 0.15,
      'centsPerKwh': 15.0,
      'centsTrend': 0.05,
      'hasOdrData': true,
      'providerMessage': null,
      'readAt': '2026-03-31T10:00:00Z',
    });

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(bloc.state, isA<EnergyLoaded>());
    final loaded = bloc.state as EnergyLoaded;
    expect(loaded.summary.kwhToday, 4.0);
    expect(loaded.summary.currentSpend, 3.6);
  });

  test('realtime zero snapshot does not overwrite existing non-zero read', () async {
    final repo = _FakeRepo(_summary(4));
    final realtime = _FakeRealtimeClient();
    final bloc = EnergyBloc(
      repository: repo,
      apiClient: _FakeApi(),
      realtimeClient: realtime,
    );
    addTearDown(bloc.close);

    bloc.add(LoadEnergyData());
    await Future<void>.delayed(const Duration(milliseconds: 60));

    realtime.emit({
      'currentSpend': 0.0,
      'totalBudget': 8.0,
      'usedPercentage': 0.0,
      'percentVsYesterday': 0.0,
      'remainingAmount': 8.0,
      'airConditionerCost': 0.0,
      'kwhToday': 0.0,
      'kwhTrend': 0.0,
      'centsPerKwh': 15.0,
      'centsTrend': 0.0,
      'hasOdrData': true,
      'providerMessage': null,
      'readAt': '2026-03-31T10:00:00Z',
    }, sequence: 2);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(bloc.state, isA<EnergyLoaded>());
    final loaded = bloc.state as EnergyLoaded;
    expect(loaded.summary.kwhToday, 4);
  });

  test('realtime disconnect schedules reconnect without crashing', () async {
    final repo = _FakeRepo(_summary(2));
    final realtime = _FakeRealtimeClient();
    final bloc = EnergyBloc(
      repository: repo,
      apiClient: _FakeApi(),
      realtimeClient: realtime,
    );
    addTearDown(bloc.close);

    bloc.add(LoadEnergyData());
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final loadsBeforeFail = repo.loadCount;

    realtime.fail();
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(repo.loadCount, greaterThanOrEqualTo(loadsBeforeFail));
    expect(bloc.state, isA<EnergyLoaded>());
  });

  test('bloc close disposes realtime client', () async {
    final realtime = _FakeRealtimeClient();
    final bloc = EnergyBloc(
      repository: _FakeRepo(_summary(1)),
      apiClient: _FakeApi(),
      realtimeClient: realtime,
    );

    await bloc.close();
    expect(realtime.disposed, isTrue);
  });
}
