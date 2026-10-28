# Perfil e notificações

## Funcionalidades disponíveis

- Meus endereços: Casa, Trabalho ou outro apelido; CEP, rua, número, complemento, bairro, cidade e UF. O primeiro é padrão; outro pode assumir. Máximo de 20 ativos.
- Editar e remover da lista. A remoção arquiva (`is_active=false`), sem DELETE. O endereço já combinado em um serviço permanece no histórico.
- Escolher endereço salvo ao solicitar um serviço. O texto continua editável para instruções específicas daquela visita.
- Nome do cadastro exibido como informação; telefone editável. Email e perfil não são alterados nessa tela.
- Alterar senha: exige senha atual e confirmação da nova senha na interface. Backend valida bcrypt e o limite UTF-8, altera o hash e revoga todas as sessões sem apagar registros. Novo login obrigatório.
- Novas mensagens geram avisos dentro do app mesmo fora da conversa. Notificações ficam na central com indicação de leitura; tocar abre a conversa. Abrir uma conversa marca mensagens recebidas como lidas.

## Contrato

Todas as rotas exigem Bearer e restringem dados ao proprietário:

| Método | Rota | Resultado |
| --- | --- | --- |
| GET | `/users/me/addresses` | Endereços ativos, padrão primeiro |
| POST | `/users/me/addresses` | Cria endereço; 201 |
| PUT | `/users/me/addresses/{id}` | Edita; 200 |
| POST | `/users/me/addresses/{id}/archive` | Desativa; 204 |
| POST | `/users/me/password` | Troca senha e revoga sessões; 204 |
| GET | `/notifications` | Mensagens recebidas; paginação offset/limit |
| POST | `/notifications/{message_id}/read` | Leitura idempotente; 204 |

Exemplo de cadastro de endereço:

```json
{"label":"Casa","postal_code":"59000000","street":"Rua das Flores","number":"123","complement":"Apto 10","neighborhood":"Centro","city":"Natal","state":"RN","is_default":true}
```

Resposta 201 contém os campos acima, `id` e `is_active`. Campos desconhecidos ou inválidos: 422; endereço inexistente, arquivado ou de outro usuário: 404; sessão inválida: 401. CEP é validado por formato, sem comprovação de existência postal. O endereço formatado deve caber em 300 caracteres.

Senha: `{"current_password":"SenhaAtual123!","new_password":"NovaSenha123!"}`. Senha atual incorreta: 403, sem encerrar a sessão; senha igual à atual ou fora dos limites: 422. Campos de senha nunca aparecem em respostas ou erros de validação.

`/ws/notifications` recebe primeiro `{"type":"auth","token":"TOKEN","after":0}`. Emite eventos `{"type":"notification","notification":{"id":1,"request_id":1,"sender_name":"Maria","body":"Olá","created_at":"2026-10-07T20:00:00+00:00","is_read":false}}` em ordem de ID, seguidos de `{"type":"ready"}`. O cliente não mostra banners durante o histórico inicial. Em reconexão, utiliza o último ID recebido, recuperando mensagens perdidas sem repetir avisos. Sessão revalidada a cada ciclo; encerramento 4401 para sessão inválida. Origin validado para navegadores. Mesmo armazenamento persistente do chat; não cria mensagens falsas.

## Push Android com Firebase Cloud Messaging

A configuração Android está em `android/app/google-services.json`, para o pacote `com.zeresolve.ze_resolve` e projeto `ze-resolve-2eced`. Gradle aplica Google services 4.5.0; `firebase_core` e `firebase_messaging` gerenciam as dependências nativas.

O responsável forneceu a credencial de serviço. Ela foi salva em `backend/data/firebase-admin.json`, pasta ignorada pelo Git, e nunca pertence ao app. Pode-se substituir por `GOOGLE_APPLICATION_CREDENTIALS` apontando para um arquivo privado; em infraestrutura gerenciada, `FCM_USE_ADC=true` habilita Application Default Credentials. Variáveis são lidas do ambiente; o servidor não carrega `.env` automaticamente. Depois de configurar, reinicie o servidor.

No celular: **Meu perfil → Notificações de mensagens** solicita a permissão do Android e registra o dispositivo na API. A opção indica quando os avisos estão ativos ou indisponíveis. Um login restaurado renova o cadastro se a permissão já foi concedida. A troca de token FCM também atualiza o cadastro.

| Método | Rota | Resultado |
| --- | --- | --- |
| PUT | `/users/me/push-device` | Registra token FCM na sessão atual, 204; corpo `{"token":"TOKEN_FCM_DO_DISPOSITIVO"}` |
| GET | `/users/me/notification-settings` | `{"push_available":true}` quando o envio foi inicializado no servidor |

As rotas exigem Bearer. Os tokens de dispositivo não são devolvidos nas respostas; logout, expiração e troca de senha impedem envios posteriores pela sessão. Ao trocar de conta no mesmo celular, um envio pendente da conta anterior é cancelado.

A mensagem e os registros `push_deliveries` são gravados na mesma transação, antes da confirmação REST/WebSocket. Um trabalhador consulta a fila persistente, faz reserva temporária de cada envio e tenta novamente com espera crescente, até 8 tentativas. Mensagens já lidas, dispositivos sem sessão válida, mudanças de proprietário e avisos mais antigos que 24 horas cancelam o envio. Tokens rejeitados como inexistentes são inativados. Os registros concluídos ou cancelados permanecem no banco. Sem credencial configurada, o chat funciona normalmente e a fila permanece disponível para processamento posterior.

Push usa título “Zé Resolve” e texto discreto “Você recebeu uma nova mensagem.”; não inclui texto da conversa ou endereço na tela bloqueada. O payload contém os IDs de mensagem, solicitação e destinatário. Tocar abre a conversa somente para a conta destinatária autenticada, e a API revalida o acesso. Tanto a abertura com o app encerrado quanto em segundo plano são tratadas. Em primeiro plano, a central combina WebSocket e FCM sem repetir banners.

Ao criar a aplicação com um banco diferente do padrão, o envio externo fica desabilitado por padrão; a habilitação explícita usa `create_app(url, enable_push=True)`.

Entrega efetiva depende de permissão, conectividade e do sistema operacional. A fila usa tag por mensagem no Android para reduzir avisos repetidos em uma tentativa após resposta incerta do provedor; não promete exatamente uma entrega. Histórico e leitura continuam sendo responsabilidade da API e do banco. O chat continua via WebSocket. Esta implementação cobre Android; push para outras plataformas precisa de configuração específica.

Referências oficiais: [configuração Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [recebimento e abertura de mensagens](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [credenciais do servidor](https://firebase.google.com/docs/admin/setup).
