# Zé Resolve

Projeto Integrador II de Sistemas para Internet do IFRN.

Aplicativo Flutter, API própria FastAPI e banco relacional SQLite com ORM SQLAlchemy. Esta versão é preparada para apresentação local no Windows. O Flutter continua consumindo HTTP/REST e WebSocket; somente a API abre o banco.

## Executar neste computador

Na raiz, em PowerShell:

```powershell
.\scripts\run_backend.ps1
```

O banco persistente fica em `backend/data/apresentacao.db` e é criado/atualizado automaticamente. Não é preciso iniciar serviço de banco, Docker ou container. Os dados anteriores foram transferidos e verificados; os arquivos originais permanecem privados como backup.

- [Swagger](http://127.0.0.1:8000/docs)
- [OpenAPI](http://127.0.0.1:8000/openapi.json)
- [Saúde da API](http://127.0.0.1:8000/health)

Em outro terminal, com celular conectado e depuração USB autorizada:

```powershell
.\scripts\run_android_usb.ps1
```

O script configura `adb reverse tcp:8000 tcp:8000` para HTTP e WebSocket e inicia Flutter. No Android Studio use **Ze Resolve - Android USB** após configurar o encaminhamento. Depois de reconectar o cabo, repita o encaminhamento.

Para emulador Android:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

No celular físico por Wi-Fi, ambos precisam estar na mesma rede. Inicie a API com `-BindAddress 0.0.0.0` e use `flutter run --dart-define=API_BASE_URL=http://IP_DO_COMPUTADOR:8000`. O endereço `10.0.2.2` é exclusivo do emulador. Trocar o endereço exige parar e iniciar o aplicativo; hot reload não altera `--dart-define`.

## Preparar outro computador

Requer Python 3.12+, Flutter compatível com `pubspec.yaml` e Android SDK para o app Android. SQLite já acompanha o Python.

```powershell
python -m venv backend/.venv
.\backend\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
Copy-Item backend/.env.example backend/.env
Push-Location backend
.\.venv\Scripts\python.exe -m app.setup_secrets
Pop-Location
flutter pub get
.\scripts\run_backend.ps1 -Task seed
```

Preserve a chave `backend/secrets/data-encryption.key` ao copiar um banco existente. Não gere outra chave para dados já cifrados. Chaves, bancos, sessões e configurações preenchidas ficam fora do Git. Para compilar Android, a configuração Firebase do projeto fica privadamente em `android/app/google-services.json`.

O seed é explícito e idempotente. Cria dados fictícios e três contas de demonstração, todas com senha `Demo12345!`:

| Perfil | Email |
| --- | --- |
| Cliente | cliente@example.com |
| Eletricista | profissional@example.com |
| Encanador | encanador@example.com |

Perfis históricos sem valor da visita precisam defini-lo e publicar horários; valores antigos por hora não são convertidos automaticamente. Não use contas de demonstração para uma operação pública.

## Funcionalidades mantidas

Busca por categoria/cidade/proximidade, localização opcional, valor fixo da visita, agenda publicada, filtro de vagas nas próximas 24 horas e pedido sujeito ao aceite do profissional. Reservas pendentes expiram após o prazo configurado. Chat utiliza WebSocket e confirma envio após persistência. Notificações push dependem do Firebase e da conexão externa; o histórico e os avisos dentro do app ficam no SQLite.

Autenticação real com bcrypt, sessões de 30 dias, permissões no servidor, endereços e dados privados protegidos com AES-GCM continuam funcionando. Recuperação/validação de email exige SMTP real, opcional para a apresentação; o sistema não simula entrega de email.

## Verificar e documentar

```powershell
flutter analyze --no-pub
.\scripts\run_backend.ps1 -Task docs
```

O segundo comando regenera `docs/openapi.json` e `docs/schema.sql` a partir do código. Dart format, Black e EditorConfig padronizam a formatação. Veja [SQLite local e backup](docs/sqlite.md), [arquitetura e justificativas](docs/arquitetura.md), [contrato REST](docs/api.md), [regras da agenda](docs/agenda_visitas.md), [segurança](docs/seguranca.md), [roteiro de apresentação](docs/apresentacao_mvp.md) e [status atual](docs/status_mvp.md).

Esta versão substitui a configuração anterior de servidor externo. Os pacotes antigos em `entregas/` não representam a configuração atual; não os aplique sobre este projeto.
