import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Autoridade certificadora fixada no aplicativo (PEM em base64).
///
/// Informada na compilação com `--dart-define=API_CA_CERT_B64=...`
/// (o script `scripts/run_android_usb.ps1` faz isso). Quando presente, o
/// aplicativo confia **somente** nesta AC: certificados assinados por
/// qualquer outra autoridade, inclusive as instaladas no aparelho, são
/// recusados. Isso impede a interceptação da comunicação (ataque
/// "homem no meio") mesmo com um certificado falso instalado no celular.
const String pinnedCaBase64 = String.fromEnvironment('API_CA_CERT_B64');

/// Contexto TLS que aceita apenas a AC fixada; `null` usa as AC do sistema.
SecurityContext? pinnedSecurityContext([String encoded = pinnedCaBase64]) {
  if (encoded.isEmpty) return null;
  final context = SecurityContext(withTrustedRoots: false);
  context.setTrustedCertificatesBytes(base64Decode(encoded));
  return context;
}

/// Cliente HTTP usado pela API REST e pelos WebSockets.
HttpClient secureHttpClient([String encoded = pinnedCaBase64]) {
  final client = HttpClient(context: pinnedSecurityContext(encoded));
  client.connectionTimeout = const Duration(seconds: 15);
  return client;
}

/// Cliente REST: com AC fixada, só aceita o certificado do Zé Resolve.
http.Client apiHttpClient() =>
    pinnedCaBase64.isEmpty ? http.Client() : IOClient(secureHttpClient());

/// WebSocket (wss) com a mesma regra de confiança da API REST.
WebSocketChannel openWebSocket(Uri url) => pinnedCaBase64.isEmpty
    ? WebSocketChannel.connect(url)
    : IOWebSocketChannel.connect(url, customClient: secureHttpClient());
