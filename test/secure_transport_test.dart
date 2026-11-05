import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ze_resolve/core/api/secure_transport.dart';

// Certificado público de uma AC de teste (sem chave privada).
const _testCa = '''-----BEGIN CERTIFICATE-----
MIIBsTCCAVegAwIBAgIUFqZh2K2itS2mMeeM8Z9OnkJDlE8wCgYIKoZIzj0EAwIw
NTEUMBIGA1UECgwLWsOpIFJlc29sdmUxHTAbBgNVBAMMFFrDqSBSZXNvbHZlIEFD
IGxvY2FsMB4XDTI2MTEwNTIxMjU0NloXDTI4MTEwNDIxMjU0NlowNTEUMBIGA1UE
CgwLWsOpIFJlc29sdmUxHTAbBgNVBAMMFFrDqSBSZXNvbHZlIEFDIGxvY2FsMFkw
EwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEeOpVBmTE9rl9gTTwseC6lM/lZVor2GML
emSQ0c72ydvctKWSBkzZ8dzC+OGHiOFjinvXTXwYHXa30PQwW/xVnKNFMEMwEgYD
VR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYEFArdnyPr
B8rkoHjMlbHKo679JXBzMAoGCCqGSM49BAMCA0gAMEUCIBpu0Kujbg5YNnGbt3op
mPmIKCWdo29tfm6frQyOd6pqAiEAk4ODBK+SaX3YcgeFN5tzxjp/4k73ps1Flwl+
rBozZo0=
-----END CERTIFICATE-----
''';

void main() {
  test('sem AC fixada, usa as autoridades do sistema', () {
    expect(pinnedSecurityContext(''), isNull);
    expect(secureHttpClient(''), isNotNull);
  });

  test('com AC fixada, cria contexto TLS que confia só nela', () {
    final encoded = base64Encode(utf8.encode(_testCa));
    expect(pinnedSecurityContext(encoded), isNotNull);
    expect(secureHttpClient(encoded), isNotNull);
  });

  test('AC inválida é recusada em vez de cair para as do sistema', () {
    final garbage = base64Encode(utf8.encode('isto não é um certificado'));
    expect(() => pinnedSecurityContext(garbage), throwsA(anything));
  });
}
