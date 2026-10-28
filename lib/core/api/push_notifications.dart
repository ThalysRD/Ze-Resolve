import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'api_client.dart';
import 'notification_client.dart';

class PushNotifications extends ChangeNotifier {
  PushNotifications._();
  static final instance = PushNotifications._();
  bool _initialized = false;
  int _generation = 0;
  int? _userId;
  StreamSubscription<String>? _refresh;
  RemoteMessage? _pending;
  void Function(int requestId)? onOpenChat;
  void Function(int requestId)? onOpenRequest;
  String status = 'Ative para receber avisos de novas mensagens.';

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      _initialized = true;
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      _pending = await FirebaseMessaging.instance.getInitialMessage();
      FirebaseMessaging.onMessage.listen((message) {
        final recipient = int.tryParse('${message.data['recipient_id']}');
        final id = int.tryParse('${message.data['message_id']}');
        if (recipient == _userId && id != null) {
          unawaited(
            NotificationClient.instance
                .handlePush(id)
                .catchError((Object _) {}),
          );
        }
      });
    } catch (_) {
      status = 'Notificações indisponíveis neste momento.';
    }
  }

  void _open(RemoteMessage message) {
    if (_userId == null) {
      _pending = message;
      return;
    }
    final recipient = int.tryParse('${message.data['recipient_id']}');
    final requestId = int.tryParse('${message.data['request_id']}');
    if (recipient != _userId ||
        requestId == null ||
        !const ['chat', 'request_event'].contains(message.data['type'])) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (message.data['type'] == 'request_event') {
        onOpenRequest?.call(requestId);
      } else {
        onOpenChat?.call(requestId);
      }
    });
  }

  Future<void> start(int userId, {bool requestPermission = false}) async {
    final generation = ++_generation;
    _userId = userId;
    await _refresh?.cancel();
    if (!_initialized) return;
    if (_pending != null) {
      final pending = _pending!;
      _pending = null;
      _open(pending);
    }
    try {
      final settings = requestPermission
          ? await FirebaseMessaging.instance.requestPermission()
          : await FirebaseMessaging.instance.getNotificationSettings();
      if (generation != _generation) return;
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        status = 'Ative as notificações para receber avisos com o app fechado.';
        notifyListeners();
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (generation != _generation) return;
      if (token == null) {
        throw const ApiException('Token de notificações indisponível.');
      }
      await _register(token, generation);
      if (generation != _generation) return;
      _refresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        unawaited(_register(token, generation).catchError((Object _) {}));
      });
    } catch (_) {
      if (generation != _generation) return;
      status = 'Não foi possível ativar os avisos. Tente novamente.';
      notifyListeners();
    }
  }

  Future<void> _register(String token, int generation) async {
    if (generation != _generation || ApiClient.instance.token == null) return;
    await ApiClient.instance.request(
      'PUT',
      '/users/me/push-device',
      body: {'token': token},
    );
    if (generation != _generation) return;
    final settings = await ApiClient.instance.request(
      'GET',
      '/users/me/notification-settings',
    );
    if (generation != _generation) return;
    status = settings['push_available'] == true
        ? 'Avisos ativados neste dispositivo.'
        : 'Os avisos estão temporariamente indisponíveis. Tente novamente.';
    notifyListeners();
  }

  void stop() {
    _generation++;
    _userId = null;
    _pending = null;
    unawaited(_refresh?.cancel());
    _refresh = null;
    status = 'Ative para receber avisos de novas mensagens.';
    notifyListeners();
  }
}
