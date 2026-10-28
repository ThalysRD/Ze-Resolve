# Zé Resolve

Projeto Integrador II de Sistemas para Internet do IFRN.

Aplicativo Flutter que conecta clientes a profissionais de serviços locais, com API própria em FastAPI e banco relacional SQLite (ORM SQLAlchemy). O aplicativo consome a API por HTTP/REST e WebSocket; somente a API acessa o banco.

- Arquitetura, modelo de dados, justificativa do banco e REST × SOAP: [docs/arquitetura.md](docs/arquitetura.md)
- Contrato REST: [docs/api.md](docs/api.md) e [docs/openapi.json](docs/openapi.json) (Swagger em `/docs` com a API em execução)

## Requisitos

- Python 3.12 ou superior (o SQLite já acompanha o Python)
- Flutter compatível com o `pubspec.yaml` e Android SDK, para o aplicativo

## 1. Preparar e iniciar a API

### Windows (PowerShell, na raiz do projeto)

```powershell
python -m venv backend/.venv
.\backend\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
Copy-Item backend/.env.example backend/.env
Push-Location backend
.\.venv\Scripts\python.exe -m app.setup_secrets
Pop-Location
.\scripts\run_backend.ps1 -Task seed
.\scripts\run_backend.ps1
```

### Linux ou macOS (terminal, na pasta `backend`)

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
.venv/bin/python -m app.setup_secrets
set -a; . ./.env; set +a
.venv/bin/python -m app.seed
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

A preparação é feita uma vez; depois basta o último comando. Com a API em execução:

- [Swagger](http://127.0.0.1:8000/docs)
- [OpenAPI](http://127.0.0.1:8000/openapi.json)
- [Saúde da API](http://127.0.0.1:8000/health)

O banco fica em `backend/data/apresentacao.db`, é criado automaticamente e mantém os dados após reiniciar a API. Não é preciso instalar serviço de banco nem Docker.

## 2. Contas de demonstração

O seed cria dados fictícios e três contas, todas com a senha `Demo12345!`. Ele pode ser executado novamente sem duplicar dados.

| Perfil | Email |
| --- | --- |
| Cliente | cliente@example.com |
| Eletricista | profissional@example.com |
| Encanador | encanador@example.com |

## 3. Executar o aplicativo

Com a API em execução, em outro terminal na raiz do projeto:

```sh
flutter pub get
```

Emulador Android:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Celular por cabo USB, com depuração USB autorizada:

```sh
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

No Windows, `.\scripts\run_android_usb.ps1` faz esses dois passos. No Android Studio, use a configuração **Ze Resolve - Android USB** depois do `adb reverse`. Ao reconectar o cabo, repita o `adb reverse`.

Celular por Wi-Fi: computador e celular na mesma rede. Inicie a API com `--host 0.0.0.0` (no Windows, `.\scripts\run_backend.ps1 -BindAddress 0.0.0.0`) e use `flutter run --dart-define=API_BASE_URL=http://IP_DO_COMPUTADOR:8000`.

Trocar o endereço da API exige parar e iniciar o aplicativo; o hot reload não altera `--dart-define`.

## Arquivos que ficam fora do Git

Chaves, banco, `.env` e configurações privadas não são versionados; os passos acima recriam tudo o que é necessário.

- `backend/.env`: copiado de `backend/.env.example`.
- `backend/secrets/data-encryption.key`: gerada por `app.setup_secrets`. Ao copiar um banco existente, copie também a chave dele.
- `android/app/google-services.json` (Firebase): opcional. Sem ele o aplicativo compila e funciona normalmente, apenas sem notificações push.
- `android/key.properties`: necessário somente para gerar o APK de release assinado.

## Funcionalidades

Busca por categoria, cidade e proximidade, localização opcional, valor fixo da visita, agenda publicada pelo profissional, filtro de vagas nas próximas 24 horas e pedido sujeito ao aceite do profissional. Reservas pendentes expiram após o prazo configurado. O chat usa WebSocket e confirma o envio após gravar no banco. Notificações push dependem do Firebase; o histórico e os avisos dentro do app ficam no banco.

Autenticação real com bcrypt, sessões de 30 dias, permissões verificadas no servidor e dados privados protegidos com AES-GCM. Recuperação e validação de email exigem um servidor SMTP real, opcional para a apresentação.

## Documentação

`.\scripts\run_backend.ps1 -Task docs` (Windows) ou `.venv/bin/python -m app.export_docs` (na pasta `backend`) regenera `docs/openapi.json` e `docs/schema.sql` a partir do código.

Veja também [SQLite e backup](docs/sqlite.md), [regras da agenda](docs/agenda_visitas.md), [WebSocket](docs/websocket.md), [segurança](docs/seguranca.md), [regras de negócio](docs/regras_negocio.md) e [roteiro de apresentação](docs/apresentacao_mvp.md).
