import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/notification_client.dart';
import '../../../core/api/push_notifications.dart';

import 'dart:async';

class AppSession {
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static String get _storageKey =>
      'ze_resolve.session.${ApiClient.instance.baseUrl}';
  static Map<String, dynamic>? user;
  static bool get isLoggedIn =>
      user != null && ApiClient.instance.token != null;
  static String get selectedProfile => user?['role'] as String? ?? 'cliente';

  static Future<void> login(String email, String password) async {
    final result = await ApiClient.instance.request(
      'POST',
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    ApiClient.instance.token = result['access_token'] as String;
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode({
          'token': result['access_token'],
          'expires_at': result['expires_at'],
        }),
      );
    } catch (_) {
      try {
        await ApiClient.instance.request('POST', '/auth/logout');
      } catch (_) {}
      logout();
      throw const ApiException(
        'Não foi possível guardar a sessão com segurança. Tente entrar novamente.',
      );
    }
    user = Map<String, dynamic>.from(result['user'] as Map);
    NotificationClient.instance.start();
    unawaited(PushNotifications.instance.start(user!['id'] as int));
  }

  static Future<bool> restore() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return false;
    try {
      final saved = jsonDecode(raw) as Map;
      final expiry = DateTime.parse(saved['expires_at'] as String);
      if (!expiry.isAfter(DateTime.now().toUtc())) {
        await deleteStoredSession();
        logout();
        return false;
      }
      ApiClient.instance.token = saved['token'] as String;
    } on FormatException {
      await deleteStoredSession();
      logout();
      return false;
    } on TypeError {
      await deleteStoredSession();
      logout();
      return false;
    }
    try {
      final result = await ApiClient.instance.request('GET', '/users/me');
      user = Map<String, dynamic>.from(result as Map);
      NotificationClient.instance.start();
      unawaited(PushNotifications.instance.start(user!['id'] as int));
      return true;
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      await deleteStoredSession();
      logout();
      return false;
    }
  }

  static Future<void> deleteStoredSession() =>
      _storage.delete(key: _storageKey);

  static Future<void> revoke() async {
    await ApiClient.instance.request('POST', '/auth/logout');
    logout();
    await deleteStoredSession();
  }

  static void logout() {
    NotificationClient.instance.stop();
    PushNotifications.instance.stop();
    ApiClient.instance.token = null;
    user = null;
  }
}
