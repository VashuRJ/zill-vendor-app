// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/io.dart';
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

  // ── Internal: build a properly-formed wss:// Uri ───────────────────────
  // Constructs the Uri via the named-parameter constructor instead of
  // `Uri.parse` so the scheme/host/port are unambiguous. This sidesteps a
  // long-standing dart:io quirk where `IOWebSocketChannel.connect(String)`
  // round-trips through Uri and emits the upgrade request as
  // `https://host:0/...` — which servers reject with HTTP 400.
  Uri _buildWsUri(String path, String token) {
    final base = Uri.parse(ApiEndpoints.wsBaseUrl);
    return Uri(
      scheme: base.scheme,           // ws / wss
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      queryParameters: {'token': token},
    );
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

    // Build the URI explicitly — string-based parsing has historically
    // mangled wss:// URLs in dart:io (resulting in `https://host:0/...`
    // upgrade requests that the server rejects with HTTP 400).
    final Uri wsUri = _buildWsUri(path, token);
    AppLogger.i('[WS] Connecting $key → ${wsUri.scheme}://${wsUri.host}${wsUri.path}');

    try {
      // Use IOWebSocketChannel.connect(Uri) — the Uri overload bypasses
      // the buggy String → Uri conversion path, and we attach the JWT
      // both as a query param (current backend contract) and as an
      // Authorization header so future header-aware backends Just Work.
      final channel = IOWebSocketChannel.connect(
        wsUri,
        headers: {
          'Authorization': 'Bearer $token',
          'User-Agent': 'ZillVendorApp/Flutter',
        },
        pingInterval: const Duration(seconds: 25),
      );
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
            // Swallow server pong frames — they exist only to keep the
            // socket alive and shouldn't be propagated to listeners.
            if (data['type'] == 'pong') return;
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

      _startHeartbeat(conn);
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
    conn.heartbeatTimer?.cancel();
    conn.subscription?.cancel();
    conn.channel?.sink.close();
    AppLogger.i('[WS] Disconnected $key');
  }

  // ── Heartbeat: send {"type":"ping"} every 30s to keep the socket alive
  // and detect dead connections (Django Channels closes idle sockets).
  static const _heartbeatInterval = Duration(seconds: 30);

  void _startHeartbeat(_WsConnection conn) {
    conn.heartbeatTimer?.cancel();
    conn.heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final ch = conn.channel;
      if (ch == null) return;
      try {
        ch.sink.add(jsonEncode({'type': 'ping'}));
      } catch (e) {
        AppLogger.w('[WS] Heartbeat send failed on ${conn.key}: $e');
      }
    });
  }

  static const _maxReconnectAttempts = 10;

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
    // Stop heartbeating a dead socket — it'll restart on successful reconnect.
    existing.heartbeatTimer?.cancel();
    // Give up after max attempts to avoid infinite loop when offline
    if (existing.reconnectAttempts >= _maxReconnectAttempts) {
      AppLogger.w('[WS] Max reconnect attempts reached for $key — giving up');
      _disconnect(key);
      return;
    }

    existing.reconnectAttempts++;
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s ... capped at 30s.
    final secs = math.min(30, math.pow(2, existing.reconnectAttempts - 1).toInt());
    final delay = Duration(seconds: secs);
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
  Timer? heartbeatTimer;
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
