# Zé Resolve

Protótipo acadêmico de aplicativo para conectar clientes a profissionais de serviços. Desenvolvido em Flutter/Dart no contexto do Projeto Integrador II de Sistemas para Internet do IFRN.

## O que está no repositório

- Navegação com perfis de cliente e profissional.
- Telas de busca, categorias, perfil profissional e solicitação de serviço.
- Telas de agenda, solicitações recebidas, avaliações e mensagens.
- Componentes compartilhados para navegação e notificações.

As telas representam fluxos de interface. `AppSession` mantém o perfil e o estado de login em memória: não há autenticação real, backend, chat em tempo real ou persistência de serviços nesta versão.

## Executar

Use Flutter com Dart compatível com `sdk: ^3.13.0`, conforme `pubspec.yaml`, e um dispositivo/emulador configurado:

```sh
flutter pub get
flutter run
```

O projeto contém diretórios Android e macOS. O suporte a outras plataformas não está preparado nesta cópia.

## Organização

| Caminho | Responsabilidade |
|---|---|
| `lib/main.dart` | Tema, tela inicial e rotas |
| `lib/features/auth` | Telas de acesso e sessão local |
| `lib/features/client` | Fluxos do cliente |
| `lib/features/professional` | Fluxos do profissional |
| `lib/features/shared` | Componentes e utilitários compartilhados |

## Verificação e próximos passos

`flutter analyze` e `flutter test` são os comandos de verificação. O arquivo `test/widget_test.dart` deve ser conferido ao evoluir a interface; a presença do arquivo não comprova cobertura dos fluxos. A aplicação não foi executada nesta revisão documental.

Próximas entregas: contrato de API, persistência, autenticação e testes de solicitação de serviço. O PDF acadêmico na raiz registra o contexto do projeto; não representa experiência de cliente ou produto comercial em operação.
