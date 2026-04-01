// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_endpoints.dart';
import '../utils/app_logger.dart';
import 'storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  WebSocket Service — manages persistent connections with auto-reconnect
// ─────────────────────────────────────────────────────────────────────────────

class WebSocketService {
  final StorageService _storageService;

  // ── Active connections keyed by path ────────────────────────────────────
  final Map<String, _WsConnection> _connections = {};

  // ── Broadcast stream for notification-type messages ────────────────────
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotification =>
      _notificationController.stream;

  // ── Broadcast stream for order tracking messages ───────────────────────
  final _orderTrackingController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onOrderTracking =>
      _orderTrackingController.stream;

  WebSocketService({required StorageService storageService})
      : _storageService = storageService;

  // ── Connect to notification channel ────────────────────────────────────
  Future<void> connectNotifications() async {
    await _connect(
      path: ApiEndpoints.wsNotifications,
      key: 'notifications',
      onMessage: (data) {
        AppLogger.i('[WS] Notification: type=${data['type']}');
        _notificationController.add(data);
      },
    );
  }

  // ── Connect to order tracking channel ──────────────────────────────────
  Future<void> connectOrderTracking(int orderId) async {
    final path = ApiEndpoints.wsOrderTrack(orderId);
    await _connect(
      path: path,
      key: 'order_$orderId',
      onMessage: (data) {
        AppLogger.i('[WS] Order $orderId: type=${data['type']}');
        _orderTrackingController.add(data);
      },
    );
  }

  // ── Disconnect specific tracking channel ───────────────────────────────
  void disconnectOrderTracking(int orderId) {
    _disconnect('order_$orderId');
  }

  // ── Send message on a connection ───────────────────────────────────────
  void send(String key, Map<String, dynamic> data) {
    final conn = _connections[key];
    if (conn != null && conn.channel != null) {
      conn.channel!.sink.add(jsonEncode(data));
    }
  }

  // ── Disconnect all (call on logout) ────────────────────────────────────
  void disconnectAll() {
    for (final key in _connections.keys.toList()) {
      _disconnect(key);
    }
    AppLogger.i('[WS] All connections closed');
  }

  // ── Dispose (app shutdown) ─────────────────────────────────────────────
  void dispose() {
    disconnectAll();
    _notificationController.close();
    _orderTrackingController.close();
  }

  // ── Internal: connect with auto-reconnect ──────────────────────────────
  Future<void> _connect({
    required String path,
    required String key,
    required void Function(Map<String, dynamic>) onMessage,
  }) async {
    // Close existing connection for this key if any
    _disconnect(key);

    final token = await _storageService.getAccessToken();
    if (token == null || token.isEmpty) {
      AppLogger.w('[WS] No token — skipping $key connection');
      return;
    }

    // Build URI manually to preserve wss:// scheme correctly.
    // Uri.parse('wss://...') can mangle scheme/port on some platforms.
    final base = Uri.parse(ApiEndpoints.wsBaseUrl);
    final uri = Uri(
      scheme: base.scheme.isNotEmpty ? base.scheme : 'wss',
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      queryParameters: {'token': token},
    );
    AppLogger.i('[WS] Connecting $key → $uri');

    try {
      final channel = WebSocketChannel.connect(uri);
      // Wait for the connection to be established
      await channel.ready;

      final conn = _WsConnection(
        channel: channel,
        path: path,
        key: key,
        onMessage: onMessage,
      );
      _connections[key] = conn;

      conn.reconnectAttempts = 0; // Reset on successful connection
      conn.subscription = channel.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            onMessage(data);
          } catch (e) {
            AppLogger.w('[WS] Failed to parse message on $key: $e');
          }
        },
        onError: (Object error) {
          AppLogger.e('[WS] Error on $key: $error');
          _scheduleReconnect(key, path, onMessage);
        },
        onDone: () {
          AppLogger.w('[WS] Connection closed on $key');
          _scheduleReconnect(key, path, onMessage);
        },
        cancelOnError: false,
      );

      AppLogger.i('[WS] Connected $key');
    } catch (e) {
      AppLogger.e('[WS] Failed to connect $key: $e');
      _scheduleReconnect(key, path, onMessage);
    }
  }

  void _disconnect(String key) {
    final conn = _connections.remove(key);
    if (conn == null) return;
    conn.reconnectTimer?.cancel();
    conn.subscription?.cancel();
    conn.channel?.sink.close();
    AppLogger.i('[WS] Disconnected $key');
  }

  static const _maxReconnectAttempts = 10;
  static const _baseReconnectDelay = Duration(seconds: 3);

  void _scheduleReconnect(
    String key,
    String path,
    void Function(Map<String, dynamic>) onMessage,
  ) {
    final existing = _connections[key];
    // Don't reconnect if explicitly disconnected (key removed)
    if (existing == null) return;
    // Don't stack multiple reconnect timers
    if (existing.reconnectTimer?.isActive == true) return;
    // Give up after max attempts to avoid infinite loop when offline
    if (existing.reconnectAttempts >= _maxReconnectAttempts) {
      AppLogger.w('[WS] Max reconnect attempts reached for $key — giving up');
      _disconnect(key);
      return;
    }

    existing.reconnectAttempts++;
    // Exponential backoff: 3s, 6s, 12s, 24s ... capped at 60s
    final delay = Duration(
      seconds: (_baseReconnectDelay.inSeconds *
              (1 << (existing.reconnectAttempts - 1)))
          .clamp(3, 60),
    );
    AppLogger.i('[WS] Reconnecting $key in ${delay.inSeconds}s '
        '(attempt ${existing.reconnectAttempts}/$_maxReconnectAttempts)');

    existing.reconnectTimer = Timer(delay, () {
      // Check again — may have been disconnected during the delay
      if (!_connections.containsKey(key)) return;
      _connect(path: path, key: key, onMessage: onMessage);
    });
  }
}

// ── Internal connection holder ───────────────────────────────────────────────

class _WsConnection {
  WebSocketChannel? channel;
  StreamSubscription? subscription;
  Timer? reconnectTimer;
  final String path;
  final String key;
  final void Function(Map<String, dynamic>) onMessage;
  int reconnectAttempts = 0;

  _WsConnection({
    required this.channel,
    required this.path,
    required this.key,
    required this.onMessage,
  });
}
