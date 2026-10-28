import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../errors/user_message.dart';

class ApiException implements UserFacingException {
  const ApiException(this.message, [this.statusCode]);
  @override
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

String _validationMessage(dynamic error) {
  const labels = {
    'name': 'Nome',
    'phone': 'Telefone',
    'email': 'Email',
    'password': 'Senha',
    'current_password': 'Senha atual',
    'new_password': 'Nova senha',
    'label': 'Apelido',
    'postal_code': 'CEP',
    'street': 'Rua',
    'number': 'Número',
    'complement': 'Complemento',
    'neighborhood': 'Bairro',
    'city': 'Cidade',
    'state': 'UF',
    'body': 'Mensagem',
    'title': 'Serviço',
    'description': 'Descrição',
    'address': 'Endereço',
    'scheduled_at': 'Agendamento',
    'duration_minutes': 'Duração',
    'visit_fee_cents': 'Valor da visita',
    'expected_visit_fee_cents': 'Valor da visita',
    'slot_id': 'Horário escolhido',
    'starts_at': 'Início do horário',
    'ends_at': 'Fim do horário',
    'category_id': 'Categoria',
    'rating': 'Nota',
    'comment': 'Comentário',
  };
  if (error is! Map) return 'Confira os dados informados.';
  final location = error['loc'];
  final field = location is List && location.length > 1
      ? location.last.toString()
      : '';
  final label = labels[field];
  final message = switch (error['type']) {
    'value_error' when field == 'scheduled_at' => 'Escolha uma data futura.',
    'value_error' when field == 'starts_at' => 'Escolha um horário futuro.',
    'value_error' when field == 'email' => 'Informe um email válido.',
    'value_error' when field == 'password' || field == 'new_password' =>
      'Confira a senha informada e seu limite de tamanho.',
    'missing' => 'Preencha este campo.',
    'literal_error' || 'enum' => 'Escolha uma opção válida.',
    'string_pattern_mismatch' => 'Confira o formato informado.',
    _ => 'Confira o valor informado.',
  };
  return label == null ? message : '$label: $message';
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ?? configuredUrl).replaceFirst(RegExp(r'/+$'), '');

  static String get configuredUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (const bool.fromEnvironment('dart.vm.product')) {
      final uri = Uri.tryParse(configured);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          const ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host) ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw StateError(
          'Configure API_BASE_URL com o endereço HTTPS de produção.',
        );
      }
    }
    if (configured.isNotEmpty) return configured;
    return 'http://127.0.0.1:8000';
  }

  static ApiClient instance = ApiClient();
  final http.Client _client;
  final String baseUrl;
  String? token;
  VoidCallback? onUnauthorized;

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri);
    request.headers['Content-Type'] = 'application/json';
    final sentToken = token;
    if (sentToken != null) {
      request.headers['Authorization'] = 'Bearer $sentToken';
    }
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await (() async {
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 &&
          sentToken != null &&
          token == sentToken) {
        token = null;
        onUnauthorized?.call();
      }
      dynamic decoded;
      try {
        decoded = response.bodyBytes.isEmpty
            ? null
            : jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw ApiException(
          response.statusCode >= 400
              ? serverErrorMessage(null, response.statusCode)
              : unexpectedMessage,
          response.statusCode,
        );
      }
      if (response.statusCode >= 400) {
        final detail = decoded is Map ? decoded['detail'] : null;
        final message =
            response.statusCode == 422 && detail is List && detail.isNotEmpty
            ? detail.map(_validationMessage).join('\n')
            : serverErrorMessage(detail, response.statusCode);
        throw ApiException(message, response.statusCode);
      }
      return decoded;
    } on TimeoutException {
      throw ApiException(
        path == '/auth/login'
            ? 'Não conseguimos entrar agora. Tente novamente em instantes.'
            : path == '/auth/register'
            ? 'Não conseguimos confirmar o cadastro agora. Tente entrar antes de criar a conta novamente.'
            : method.toUpperCase() == 'GET' || method.toUpperCase() == 'HEAD'
            ? 'Está demorando para carregar. Tente novamente em instantes.'
            : 'Não conseguimos confirmar a ação agora. Confira se ela foi concluída antes de repetir.',
      );
    } on http.ClientException {
      throw const ApiException(unavailableMessage);
    } on FormatException {
      throw const ApiException(unexpectedMessage);
    }
  }

  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, String>? query,
  }) async => (await request('GET', path, query: query) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Future<List<Map<String, dynamic>>> all(
    String path, {
    Map<String, String>? query,
  }) async {
    final result = <Map<String, dynamic>>[];
    while (true) {
      final page = await list(
        path,
        query: {...?query, 'limit': '100', 'offset': '${result.length}'},
      );
      result.addAll(page);
      if (page.length < 100) return result;
    }
  }
}
