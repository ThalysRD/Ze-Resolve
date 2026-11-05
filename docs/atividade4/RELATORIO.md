# Atividade 4 – Segurança da Informação no Aplicativo Zé Resolve

**Projeto Integrador II** · Aplicativo Flutter + API FastAPI · Branch `feat/seguranca-https`

O Zé Resolve conecta clientes a profissionais de serviços. O app troca com a API dados pessoais (nome, telefone, endereço, localização), o token de sessão e as mensagens do chat. A análise partiu do que o projeto já tinha (senhas com bcrypt, campos privados cifrados com AES-GCM, token guardado só como hash SHA-256, limite de tentativas de login, backups conferidos por SHA-256) e buscou o que ainda ficava exposto.

## Etapa 1 – Riscos identificados

### Risco 1 – Comunicação sem criptografia entre o app e a API

| | |
|---|---|
| **Ameaça** | Alguém na mesma rede do usuário (Wi-Fi público, da faculdade) intercepta o tráfego ou se coloca entre o app e a API ("homem no meio"). |
| **Vulnerabilidade** | A API só funcionava em HTTP e o WebSocket em `ws://`, sem TLS. A opção `REQUIRE_HTTPS` apenas recusava conexões; o servidor não sabia servir HTTPS. O app de desenvolvimento permite tráfego em texto claro (`usesCleartextTraffic="true"`). |
| **Impacto** | **Confidencialidade:** o token Bearer vale 30 dias; quem o captura entra na conta e lê endereço, pedidos e conversas. **Integridade:** um intermediário pode alterar respostas (preço, horário, status do pedido). |

### Risco 2 – Localização dos usuários gravada nos logs do servidor

| | |
|---|---|
| **Ameaça** | Quem tem acesso aos logs (outro usuário do computador, um backup, um print ou gravação de tela) descobre onde os clientes estão. |
| **Vulnerabilidade** | A busca por proximidade envia `latitude` e `longitude` na URL. A proteção dependia de lembrar a opção `--no-access-log`: o script do Windows a usava, mas o comando do README para Linux/macOS não. Sem ela, o uvicorn grava a URL completa. O próprio vídeo de demonstração do grupo mostra a linha `GET /professionals?latitude=...&longitude=...` no terminal. |
| **Impacto** | **Confidencialidade** de um dado pessoal (localização) protegido pela LGPD; contradiz a política do próprio projeto, que diz que os logs omitem query strings. |

## Etapa 2 – Mecanismos implementados

### 1. HTTPS/WSS com fixação de certificado (certificate pinning)

- **Autoridade certificadora local** (`backend/app/tls_setup.py`): gera uma AC do Zé Resolve e o certificado da API (ECDSA P-256, assinatura SHA-256), válido para `localhost`, `127.0.0.1` e `10.0.2.2` (emulador). As chaves privadas ficam em `backend/secrets/tls/`, fora do Git.
- **API em TLS** (`scripts/run_backend.ps1 -Https`): o uvicorn serve HTTPS e WSS na porta 8443 e liga `REQUIRE_HTTPS=true`. Requisições sem TLS são recusadas, e as respostas HTTPS enviam `Strict-Transport-Security`.
- **Fixação no aplicativo** (`lib/core/api/secure_transport.dart`): o app recebe só o certificado **público** da AC (`--dart-define=API_CA_CERT_B64`) e cria um `SecurityContext(withTrustedRoots: false)`, ou seja, confia **somente** nessa AC. O mesmo cliente é usado na API REST e nos dois WebSockets (chat e avisos). Um certificado de qualquer outra autoridade é recusado, mesmo que um atacante instale sua AC no celular.
- **Execução no aparelho** (`scripts/run_android_usb.ps1`): o modo HTTPS passou a ser o padrão; `-Http` mantém o modo antigo só para compatibilidade.

### 2. Correção da vulnerabilidade do log

- `RedactQueryString` (`backend/app/http_controls.py`) é instalado pela própria API no logger de acesso do uvicorn e remove tudo depois do `?`. O caminho continua registrado (`GET /professionals`), mas latitude e longitude nunca chegam ao log, **mesmo que o servidor seja iniciado sem `--no-access-log`**.
- O comando do README para Linux/macOS também recebeu `--no-access-log`.

## Etapa 3 – Testes e validação

### Testes automatizados (`backend/tests/test_transport_security.py`)

Cada teste sobe a API real com o uvicorn. Resultado: **6 de 6 aprovados**; a suíte completa da API passou com **70 testes**, e a do app com **114 testes**.

| Teste | Objetivo | Resultado |
|---|---|---|
| Certificado assinado pela AC | O certificado da API é emitido pela AC, não é uma AC, e vale para `127.0.0.1` e `10.0.2.2` | Aprovado |
| HTTPS com AC fixada | Cliente que confia só na AC do projeto conecta, recebe `200` e o cabeçalho HSTS | Aprovado |
| HTTP recusado | Conexão sem TLS na porta HTTPS é derrubada | Aprovado |
| HTTPS obrigatório | API com `REQUIRE_HTTPS=true` responde `400` a HTTP comum | Aprovado |
| Certificado de atacante | Servidor com certificado de outra AC é rejeitado com `SSLCertVerificationError` | Aprovado |
| Log sem localização | `GET /professionals?latitude=...` aparece no log só como `GET /professionals` | Aprovado. **Contraprova:** com a correção desligada, o teste falha e mostra a latitude no log. |

### Teste prático no aplicativo (emulador Android)

**Objetivo:** verificar que o app só conversa com a API verdadeira e recusa um servidor falso.

**Procedimento:**
1. Gerar a AC (`run_backend.ps1 -Task tls`), subir a API com `-Https` e instalar o app compilado com a AC fixada.
2. Fazer login no app e observar o log da API.
3. Desligar a API e subir, na mesma porta, um **servidor impostor** com certificado de outra AC ("AC do atacante"), simulando um ataque "homem no meio".
4. Tentar o login de novo e observar o app e o log do impostor.

**Resultado:**
- Com a API verdadeira, a requisição `POST /auth/login` chegou ao servidor por HTTPS (evidência: `01-login-https-chega-na-api.png` e o log da API).
- Com o impostor, o app exibiu "Não foi possível concluir agora. Tente novamente" e o **impostor não recebeu nenhuma requisição**: a conexão foi encerrada no handshake TLS, antes de o email e a senha saírem do aparelho (evidência: `02-certificado-falso-recusado.png`).
- Verificação direta na API real: HTTPS com a AC → `200 {"status":"ok"}` com HSTS; HTTP → conexão derrubada; cliente que não conhece a AC → `SSLCertVerificationError`.

**Análise:** o TLS cifra token, dados pessoais e mensagens em trânsito (confidencialidade) e impede alterações no caminho (integridade). A fixação vai além do HTTPS comum: mesmo com uma AC falsa instalada no celular, o app recusa o servidor impostor e não envia nenhum dado a ele. A correção do log elimina o vazamento de localização na origem, sem depender da disciplina de quem inicia o servidor.

## Limitações

- O certificado é de uma AC local, adequada à apresentação. Em produção, a API usaria um certificado público (por exemplo, Let's Encrypt) e o app fixaria a chave pública desse certificado.
- O modo HTTP continua disponível em desenvolvimento por compatibilidade; o HTTPS é o padrão dos scripts.
