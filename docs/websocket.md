# Contrato WebSocket do chat

URL: `ws://127.0.0.1:8000/ws/requests/{request_id}`; em HTTPS, use `wss://`.
Somente os participantes do serviço podem conectar. O OpenAPI documenta HTTP;
este documento e a extensão `x-websocket` complementam o contrato do canal.

## Autenticar

Após `POST /auth/login`, abra o socket e envie em até 10 segundos:

```json
{"type":"auth","token":"TOKEN_RECEBIDO_NO_LOGIN","after":0}
```

`after` é inteiro não negativo. Use `0` para todo o histórico ou o último ID de
mensagem recebido para retomar. O servidor envia as mensagens faltantes e então:

```json
{"type":"ready","request_id":1}
```

O token não deve ir na URL. A sessão é revalidada durante a conexão; expiração ou
logout fecha o socket. O Origin do browser deve constar em `CORS_ORIGINS`.

## Enviar

```json
{"type":"message","body":"Podemos confirmar o horário?","client_message_id":"a6a52b3418484d02ad9c28ff8a010601"}
```

`body`: 1 a 2.000 caracteres, retirando espaços nas extremidades.
`client_message_id`: 16 a 64 caracteres, letras, números, `_` ou `-`.
Crie um ID para cada envio. Após timeout, reutilize o mesmo ID e conteúdo; a
confirmação existente é devolvida sem inserir uma cópia. Campos desconhecidos
são rejeitados. O remetente é determinado pela sessão.

Após commit, o emissor recebe:

```json
{
  "type":"ack",
  "client_message_id":"a6a52b3418484d02ad9c28ff8a010601",
  "message":{"id":3,"request_id":1,"sender_id":1,"body":"Podemos confirmar o horário?","created_at":"2026-10-07T15:00:00Z"}
}
```

Ambos os participantes recebem o evento persistido:

```json
{
  "type":"message",
  "message":{"id":3,"request_id":1,"sender_id":1,"body":"Podemos confirmar o horário?","created_at":"2026-10-07T15:00:00Z"}
}
```

Uma mensagem pode chegar pelo ACK e pelo evento; deduplique por `message.id`.
O Flutter faz isso, preserva o texto até confirmação e permite reconectar.
Seu chat usa WebSocket para envio e atualizações; as rotas REST de mensagens
continuam disponíveis para consulta e consumidores HTTP independentes.

## Erros

```json
{"type":"error","status":422,"detail":"Informe body (1 a 2.000 caracteres) e client_message_id (16 a 64 caracteres)."}
```

`409` indica reutilização de ID com outro texto ou solicitação. Não é confirmação
de envio. Esses erros mantêm a conexão aberta para corrigir os dados.

| Código de fechamento | Significado |
| --- | --- |
| `4401` | Autenticação ausente, inválida, expirada ou revogada. |
| `4403` | Usuário não participa, ou Origin do browser não permitido. |
| `4404` | Solicitação inexistente. |
| `1000` | Encerramento normal. |

Clientes nativos podem omitir Origin, mas precisam autenticar e participar do
serviço. IDs de mensagens são globais; saltos entre IDs são normais.

## Controles da revisão de produção

O chat entrega inicialmente até 50 mensagens recentes; o histórico anterior pode ser paginado por `before_id` na API. Reconexão usa cursor. As operações SQL síncronas executam fora do loop assíncrono, com sessões curtas. Há limite de seis conexões por usuário, lease renovável e até 30 mensagens/minuto; sessão inválida encerra acesso. O servidor limita frames a 16 KiB na configuração fornecida.

Notificações incluem `request_event`, com cursor independente `events_after`, além das mensagens. Identificadores dos dois recursos não devem ser confundidos. A interface usa IDs locais negativos apenas para eventos de pedido e positivos para mensagens. Leitura automática exige conversa visível e aplicativo em primeiro plano. Filas de entrega persistem no banco; os workers usam leases para coordenar tentativas. A implementação ainda consulta eventos periodicamente; broker/pub-sub é uma evolução para escala maior, não uma infraestrutura já implantada.
