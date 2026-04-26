import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';

/// Estado da ligação WebSocket (indicador na UI).
enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Evento de negócio recebido do servidor (`event`, `payload`, `ts`).
class RealtimePush {
  final String event;
  final dynamic payload;
  final int? ts;

  RealtimePush({required this.event, this.payload, this.ts});
}

/// Cliente WebSocket alinhado ao backend (`websocketService.js`): mensagens JSON
/// `{ event, payload, ts }` ou handshake `{ type, message }`.
class RealtimeService {
  RealtimeService(this.api);

  final ApiService api;

  final ValueNotifier<RealtimeConnectionStatus> status =
      ValueNotifier<RealtimeConnectionStatus>(RealtimeConnectionStatus.disconnected);

  final StreamController<RealtimePush> _pushController = StreamController<RealtimePush>.broadcast();

  Stream<RealtimePush> get pushes => _pushController.stream;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _wantsConnection = false;
  int _reconnectAttempt = 0;
  bool _disposed = false;

  static Uri _wsUriFromApiBase() {
    final base = ApiService.baseUrl.trim();
    final httpUri = Uri.parse(base.contains('://') ? base : 'http://$base');
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final path = httpUri.path.isEmpty || httpUri.path == '/' ? '/' : httpUri.path;
    return Uri(
      scheme: scheme,
      host: httpUri.host,
      port: httpUri.hasPort ? httpUri.port : null,
      path: path.endsWith('/') ? path : '$path/',
    );
  }

  /// Abre (ou reabre) a ligação. Sem token JWT não liga.
  void connect() {
    if (_disposed) return;
    if (api.token == null || api.token!.isEmpty) {
      status.value = RealtimeConnectionStatus.disconnected;
      return;
    }
    _wantsConnection = true;
    _reconnectAttempt = 0;
    _openSocket();
  }

  void _openSocket() {
    if (_disposed || !_wantsConnection || api.token == null || api.token!.isEmpty) return;

    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    status.value =
        _reconnectAttempt > 0 ? RealtimeConnectionStatus.reconnecting : RealtimeConnectionStatus.connecting;

    final uri = _wsUriFromApiBase();
    try {
      _channel = WebSocketChannel.connect(uri);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RealtimeService connect error: $e\n$st');
      }
      _scheduleReconnect();
      return;
    }

    _subscription = _channel!.stream.listen(
      _onMessage,
      onDone: _onSocketDone,
      onError: (_) => _onSocketDone(),
      cancelOnError: false,
    );

    status.value = RealtimeConnectionStatus.connected;
    _reconnectAttempt = 0;
  }

  void _onMessage(dynamic message) {
    if (message is! String) return;
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      if (data.containsKey('type') && data['type'] == 'connected') {
        return;
      }
      final event = data['event'] as String?;
      if (event == null) return;
      _pushController.add(RealtimePush(
        event: event,
        payload: data['payload'],
        ts: data['ts'] is int ? data['ts'] as int : int.tryParse('${data['ts'] ?? ''}'),
      ));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RealtimeService parse error: $e\n$st');
      }
    }
  }

  void _onSocketDone() {
    if (!_wantsConnection || _disposed) {
      status.value = RealtimeConnectionStatus.disconnected;
      return;
    }
    status.value = RealtimeConnectionStatus.disconnected;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_wantsConnection || _disposed || api.token == null) return;

    _reconnectAttempt += 1;
    final seconds = _backoffSeconds(_reconnectAttempt);
    status.value = RealtimeConnectionStatus.reconnecting;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (_wantsConnection && !_disposed && api.token != null) {
        _openSocket();
      }
    });
  }

  /// 1, 2, 4, 8, 16… até 60 s.
  static int _backoffSeconds(int attempt) {
    final exp = attempt.clamp(1, 8);
    final raw = 1 << (exp - 1);
    return raw > 60 ? 60 : raw;
  }

  /// Fecha a ligação e cancela tentativas de reconexão.
  void disconnect() {
    _wantsConnection = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    status.value = RealtimeConnectionStatus.disconnected;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _pushController.close();
  }
}
