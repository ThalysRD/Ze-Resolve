# Segurança da apresentação local

Senhas são armazenadas como hashes bcrypt com salt e custo 12. Não são reversivelmente cifradas. Sessões têm validade de 30 dias; o banco guarda somente o digest do token, datas e revogação. Logout e redefinição de senha invalidam acesso no servidor. Senhas não ficam salvas no aplicativo.

Campos privados recuperáveis usam AES-GCM e chave externa ao banco. Preserve `backend/secrets/data-encryption.key` junto a uma cópia privada de segurança. Configurações Firebase, chaves Android, `.env`, bancos e backups são ignorados pelo Git. O verificador de segredos confere os arquivos elegíveis à publicação.

Cada rota privada valida a sessão e as permissões. Somente os participantes veem endereço, pedido e conversa; catálogos não expõem contato ou coordenadas exatas. Acesso sem sessão retorna 401; perfil/permissão insuficiente retorna 403. Validação e controle de abuso permanecem no servidor.

As operações do aplicativo não executam DELETE. Sessões são revogadas, vagas/endereços arquivados e pedidos conservam o estado final. Encerramento voluntário exige senha e pseudonimiza campos pessoais, preservando relacionamentos e histórico. O usuário pode consultar/revogar suas sessões.

A comunicação entre o app e a API usa HTTPS/WSS com TLS (`run_backend.ps1 -Https`, porta 8443). `python -m app.tls_setup` (ou `-Task tls`) cria em `backend/secrets/tls/` uma autoridade certificadora local e o certificado da API (ECDSA P-256, válido para `localhost`, `127.0.0.1` e `10.0.2.2`). O aplicativo recebe apenas o certificado público da AC (`API_CA_CERT_B64`) e confia **somente** nele, na REST e nos WebSockets: certificados de qualquer outra autoridade, inclusive instaladas no aparelho, são recusados. Com `REQUIRE_HTTPS=true`, requisições HTTP e WS sem TLS são recusadas, e respostas HTTPS enviam `Strict-Transport-Security`. O modo HTTP (`-Http`) existe só para compatibilidade local. A API escuta em `127.0.0.1` por padrão; não abra o banco ou os arquivos privados para o celular. O app só recebe JSON pela API.

Os logs omitem corpos, tokens e query strings. Além de `--no-access-log` nos scripts, a própria API remove a query string do log de acesso do uvicorn (`RedactQueryString`), para que latitude e longitude das buscas nunca sejam gravadas, mesmo se o servidor for iniciado sem essa opção. O cliente mostra mensagens controladas e espera confirmação antes de anunciar sucesso.

Testes: `backend/tests/test_transport_security.py` (certificados, HTTPS, recusa de HTTP, recusa de certificado falso e log sem localização) e `test/secure_transport_test.dart`. Relatório da Atividade 4: [atividade4/RELATORIO.md](atividade4/RELATORIO.md).

Recuperação e confirmação de email usam códigos temporários e SMTP real. Sem provedor configurado, não há entrega de email; esse fluxo não deve ser apresentado como envio realizado. Firebase push também depende da configuração e da conexão externa. Chat e avisos no app continuam via WebSocket local.

SQLite é a configuração de apresentação. O projeto não é entregue como serviço público implantado. Backups consistentes e restauração em outro arquivo estão documentados em [sqlite.md](sqlite.md).
