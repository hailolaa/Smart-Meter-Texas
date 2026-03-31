import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

class EnergyRealtimeMessage {
  final String type;
  final int sequence;
  final String? reason;
  final Map<String, dynamic> data;

  const EnergyRealtimeMessage({
    required this.type,
    required this.sequence,
    this.reason,
    required this.data,
  });
}

abstract class EnergyRealtimeClient {
  Stream<EnergyRealtimeMessage> connect({required String jwtToken});
  void disconnect();
  Future<void> dispose();
}

class WebSocketEnergyRealtimeClient implements EnergyRealtimeClient {
  WebSocketChannel? _channel;
  final _controller = StreamController<EnergyRealtimeMessage>.broadcast();
  StreamSubscription? _socketSubscription;

  @override
  Stream<EnergyRealtimeMessage> connect({required String jwtToken}) {
    disconnect();

    final uri = _buildWsUri(jwtToken);
    _channel = WebSocketChannel.connect(uri);
    _socketSubscription = _channel!.stream.listen(
      (raw) {
        final payload = _parse(raw);
        if (payload != null) {
          _controller.add(payload);
        }
      },
      onError: (error, stackTrace) {
        _controller.addError(error, stackTrace);
      },
      onDone: () {
        _controller.addError(StateError('Energy realtime socket closed.'));
      },
      cancelOnError: false,
    );

    return _controller.stream;
  }

  Uri _buildWsUri(String jwtToken) {
    final base = Uri.parse(AppConfig.backendBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/ws/energy',
      queryParameters: {'token': jwtToken},
    );
  }

  EnergyRealtimeMessage? _parse(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final type = decoded['type'];
    if (type is! String || type.isEmpty) return null;
    final data = decoded['data'];
    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final sequence = decoded['sequence'];
    final seq = sequence is num ? sequence.toInt() : 0;
    final reason = decoded['reason']?.toString();
    return EnergyRealtimeMessage(
      type: type,
      sequence: seq,
      reason: reason,
      data: payload,
    );
  }

  @override
  void disconnect() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<void> dispose() async {
    disconnect();
    await _controller.close();
  }
}
