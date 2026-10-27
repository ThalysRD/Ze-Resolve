import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import '../errors/user_message.dart';

/// Canal autenticado. Mensagens só são confirmadas ao receber ACK do banco.
class ChatClient extends ChangeNotifier {
  ChatClient(this.requestId, {ApiClient? client})
    : _api = client ?? ApiClient.instance;
  final int requestId;
  final ApiClient _api;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _handshake;
  final _messages = <int, Map<String, dynamic>>{};
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  bool connected = false;
  bool connecting = false;
  bool _disposed = false;
  int _generation = 0;
  int _lastReceivedId = 0;
  String? error;
  List<Map<String, dynamic>> get messages {
    final result = _messages.values.toList();
    result.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return result;
  }

  Future<void> connect() async {
    if (_disposed) return;
    final generation = ++_generation;
    await _subscription?.cancel();
    unawaited(_channel?.sink.close());
    _handshake?.cancel();
    _failPending(
      'Estamos reabrindo a conversa. Tente enviar novamente em instantes.',
    );
    connected = false;
    connecting = true;
    error = null;
    notifyListeners();
    final base = Uri.parse(_api.baseUrl);
    final url = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path}/ws/requests/$requestId',
      query: null,
    );
    final channel = WebSocketChannel.connect(url);
    final connectionToken = _api.token;
    _channel = channel;
    _subscription = channel.stream.listen(
      (frame) {
        if (!_disposed && generation == _generation) _receive(frame);
      },
      onError: (Object _) {
        if (!_disposed && generation == _generation) {
          _disconnect(
            'Não conseguimos abrir a conversa agora. Tente novamente.',
          );
        }
      },
      onDone: () {
        if (_disposed || generation != _generation) return;
        if (channel.closeCode == 4401 && _api.token == connectionToken) {
          _api.token = null;
          _api.onUnauthorized?.call();
        }
        _disconnect(switch (channel.closeCode) {
          4401 => 'Sua sessão expirou. Entre novamente.',
          4403 => 'Você não tem acesso a esta conversa.',
          4404 => 'Solicitação não encontrada.',
          _ =>
            'A conversa perdeu a conexão. Toque em Reconectar para continuar.',
        });
      },
    );
    try {
      await channel.ready.timeout(const Duration(seconds: 10));
      if (_disposed || generation != _generation) return;
      final token = connectionToken;
      if (token == null) {
        throw const ApiException('Entre para acessar as mensagens.');
      }
      channel.sink.add(
        jsonEncode({'type': 'auth', 'token': token, 'after': _lastReceivedId}),
      );
      _handshake = Timer(const Duration(seconds: 10), () {
        if (!connected && !_disposed) {
          _disconnect('Não foi possível abrir a conversa. Tente novamente.');
          unawaited(channel.sink.close());
        }
      });
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _disconnect('Não conseguimos abrir a conversa agora. Tente novamente.');
      }
    }
  }

  void _receive(dynamic frame) {
    try {
      final event = jsonDecode(frame as String) as Map;
      if (event['type'] == 'ready') {
        _handshake?.cancel();
        connected = true;
        connecting = false;
        error = null;
      } else if (event['type'] == 'message' || event['type'] == 'ack') {
        final message = Map<String, dynamic>.from(event['message'] as Map);
        _messages[message['id'] as int] = message;
        // Um ACK pode chegar antes de eventos anteriores do outro participante.
        // Somente o fluxo ordenado de eventos avança o cursor de recuperação.
        if (event['type'] == 'message') {
          _lastReceivedId = message['id'] as int;
        }
        if (event['type'] == 'ack') {
          _pending.remove(event['client_message_id'])?.complete(message);
        }
      } else if (event['type'] == 'error') {
        error = serverErrorMessage(
          event['detail'],
          event['status'] is int ? event['status'] as int : null,
        );
        _failPending(error!);
      }
      notifyListeners();
    } catch (_) {
      _disconnect('Não foi possível atualizar a conversa. Tente reconectar.');
    }
  }

  Future<Map<String, dynamic>> send(String body, String id) async {
    if (!connected) {
      throw const ApiException('Reconecte ao chat antes de enviar.');
    }
    final ack = Completer<Map<String, dynamic>>();
    _pending[id] = ack;
    try {
      _channel!.sink.add(
        jsonEncode({'type': 'message', 'body': body, 'client_message_id': id}),
      );
      return await ack.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException(
        'Não foi possível confirmar o envio. Tente novamente.',
      );
    } finally {
      if (_pending[id] == ack) _pending.remove(id);
    }
  }

  void _failPending(String message) {
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(ApiException(message));
    }
    _pending.clear();
  }

  void _disconnect(String message) {
    _handshake?.cancel();
    connected = false;
    connecting = false;
    error = message;
    _failPending(message);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _handshake?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_channel?.sink.close());
    _failPending('Conversa fechada.');
    super.dispose();
  }
}
