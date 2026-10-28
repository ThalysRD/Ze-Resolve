import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import '../errors/user_message.dart';

class NotificationClient extends ChangeNotifier with WidgetsBindingObserver {
  NotificationClient._();
  static final instance = NotificationClient._();
  final _items = <int, Map<String, dynamic>>{};
  final _alerted = <int>{};
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  Timer? _handshake;
  int _generation = 0, _cursor = 0, _eventCursor = 0;
  int _sessionGeneration = 0;
  Future<void>? _refreshFuture;
  bool _initialized = false;
  bool connected = false;
  bool loading = false;
  bool hasLoaded = false;
  String? loadError;
  int? activeRequestId;
  bool get foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool canReadConversation(int requestId) =>
      foreground && activeRequestId == requestId;
  void Function(Map<String, dynamic>)? onNewMessage;
  List<Map<String, dynamic>> get items => _items.values.toList()
    ..sort((a, b) {
      final order = '${b['created_at'] ?? ''}'.compareTo(
        '${a['created_at'] ?? ''}',
      );
      return order != 0
          ? order
          : (b['id'] as int).abs().compareTo((a['id'] as int).abs());
    });
  int get unreadCount =>
      _items.values.where((n) => n['is_read'] != true).length;

  void start() {
    stop();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ApiClient.instance.token != null) {
      _connect();
      unawaited(refresh().catchError((Object _) {}));
    }
  }

  Future<void> _connect() async {
    final api = ApiClient.instance;
    final token = api.token;
    if (token == null) return;
    final generation = ++_generation;
    connected = false;
    _retry?.cancel();
    _handshake?.cancel();
    await _subscription?.cancel();
    unawaited(_channel?.sink.close());
    if (generation != _generation) return;
    final base = Uri.parse(api.baseUrl);
    final channel = WebSocketChannel.connect(
      base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '${base.path}/ws/notifications',
        query: null,
      ),
    );
    _channel = channel;
    void disconnected() {
      if (generation != _generation) return;
      _handshake?.cancel();
      connected = false;
      notifyListeners();
      if (channel.closeCode == 4401 && api.token == token) {
        api.token = null;
        api.onUnauthorized?.call();
        return;
      }
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 5), _connect);
    }

    _subscription = channel.stream.listen(
      (raw) {
        if (generation != _generation) return;
        try {
          final event = jsonDecode(raw as String) as Map;
          if (event['type'] == 'ready') {
            _handshake?.cancel();
            _initialized = connected = true;
            hasLoaded = true;
            loadError = null;
          } else if (event['type'] == 'request_event') {
            final row = Map<String, dynamic>.from(event['event'] as Map);
            final item = _requestEvent(row);
            final fresh = !_items.containsKey(item['id']);
            _items[item['id'] as int] = item;
            _eventCursor = row['id'] as int;
            if (_initialized && fresh && item['is_read'] != true) _show(item);
          } else if (event['type'] == 'notification') {
            final item = Map<String, dynamic>.from(
              event['notification'] as Map,
            );
            final id = item['id'] as int;
            final fresh = !_items.containsKey(id);
            _items[id] = item;
            _cursor = id;
            if (canReadConversation(item['request_id'] as int)) {
              unawaited(markRead(id).catchError((Object _) {}));
            } else if (_initialized && fresh && item['is_read'] != true) {
              _show(item);
            }
          }
          notifyListeners();
        } catch (_) {
          unawaited(channel.sink.close());
        }
      },
      onError: (Object _) => disconnected(),
      onDone: disconnected,
    );
    try {
      await channel.ready.timeout(const Duration(seconds: 10));
      if (generation != _generation) return;
      channel.sink.add(
        jsonEncode({
          'type': 'auth',
          'token': token,
          'after': _cursor,
          'events_after': _eventCursor,
        }),
      );
      _handshake = Timer(const Duration(seconds: 10), () {
        if (generation != _generation || connected) return;
        unawaited(channel.sink.close());
        disconnected();
      });
    } catch (_) {
      unawaited(channel.sink.close());
      disconnected();
    }
  }

  Future<void> refresh() {
    if (_refreshFuture != null) return _refreshFuture!;
    loading = true;
    loadError = null;
    notifyListeners();
    return _refreshFuture = _load(_sessionGeneration);
  }

  Future<void> _load(int generation) async {
    try {
      final rows = await ApiClient.instance.list('/notifications');
      if (generation != _sessionGeneration) return;
      for (final row in rows) {
        _items[row['id'] as int] = row;
      }
      final events = await ApiClient.instance.list('/request-events');
      if (generation != _sessionGeneration) return;
      for (final row in events.where((row) => row['kind'] != null)) {
        _items[-(row['id'] as int)] = _requestEvent(row);
      }
      hasLoaded = true;
    } catch (error) {
      if (generation != _sessionGeneration) return;
      loadError = userErrorMessage(
        error,
        fallback:
            'Não foi possível carregar suas notificações. Tente novamente.',
      );
      rethrow;
    } finally {
      if (generation == _sessionGeneration) {
        loading = false;
        _refreshFuture = null;
        notifyListeners();
      }
    }
  }

  void _show(Map<String, dynamic> item) {
    if (_alerted.add(item['id'] as int)) onNewMessage?.call(item);
  }

  Map<String, dynamic> _requestEvent(Map<String, dynamic> row) => {
    ...row,
    'id': -(row['id'] as int),
    'sender_name': 'Agendamento',
    'kind': 'request_event',
  };

  Future<void> handlePush(int id) async {
    final generation = _generation;
    await refresh();
    if (generation != _generation) return;
    final item = _items[id];
    if (item == null || item['is_read'] == true) return;
    if (id > 0 && canReadConversation(item['request_id'] as int)) {
      await markRead(id);
    } else {
      _show(item);
    }
  }

  Future<void> markRead(int id) async {
    final generation = _generation;
    await ApiClient.instance.request(
      'POST',
      id < 0 ? '/request-events/${-id}/read' : '/notifications/$id/read',
    );
    if (generation != _generation) return;
    _items[id]?['is_read'] = true;
    notifyListeners();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _sessionGeneration++;
    _retry?.cancel();
    _handshake?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_channel?.sink.close());
    _channel = null;
    _subscription = null;
    _items.clear();
    _alerted.clear();
    _cursor = 0;
    _eventCursor = 0;
    _initialized = connected = false;
    loading = hasLoaded = false;
    loadError = null;
    _refreshFuture = null;
    activeRequestId = null;
    notifyListeners();
  }
}
