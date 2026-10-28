# Guia REST

Base local: `http://127.0.0.1:8000`. Swagger: `/docs`. Contrato:
`/openapi.json`, também disponível em [openapi.json](openapi.json).
Corpos JSON; IDs inteiros; datas ISO 8601 com fuso; preços em centavos.

| Método | Caminho | Permissão / dados |
| --- | --- | --- |
| GET | `/health` | Pública; disponibilidade e consulta ao banco. |
| POST | `/auth/register` | Pública; nome, email, telefone opcional, senha, perfil. `201`. |
| POST | `/auth/login` | Pública; email e senha. Sessão de 30 dias. |
| POST | `/auth/logout` | Autenticada; revogação da sessão atual sem exclusão. `204`. |
| GET | `/users/me` | Autenticada; meus dados. |
| PATCH | `/users/me` | Autenticada; nome e telefone. |
| POST | `/users/me/password` | Autenticada; senha atual/nova, revoga todas as sessões; 204. |
| GET/POST | `/users/me/addresses` | Autenticada; consulta e cadastro de endereços privados. |
| PUT | `/users/me/addresses/{address_id}` | Proprietário; edição e endereço padrão. |
| POST | `/users/me/addresses/{address_id}/archive` | Proprietário; desativa sem apagar; 204. |
| GET | `/notifications` | Autenticada; mensagens recebidas e estado de leitura. |
| POST | `/notifications/{message_id}/read` | Destinatário; marcação idempotente; 204. |
| PUT | `/users/me/push-device` | Autenticada; token FCM vinculado à sessão, sem devolvê-lo. |
| GET | `/users/me/notification-settings` | Autenticada; disponibilidade do envio push. |
| GET | `/categories` | Pública; catálogo do servidor. |
| GET | `/professionals` | Pública; `q`, `category_id`, `city`, `latitude`, `longitude`, `radius_km`, `available`, `available_within_hours`, `sort`, `limit`, `offset`. |
| GET | `/professionals/me` | Somente profissional autenticado; sua base de atendimento, incluindo coordenadas privadas. |
| PUT | `/professionals/me` | Profissional; categoria, bio, cidade, valor fixo da visita, pausa geral e coordenadas opcionais em par. |
| GET | `/professionals/me/availability` | Profissional proprietário; horários ativos futuros, inclusive ocupados. |
| POST | `/professionals/me/availability` | Profissional; publica início/fim futuros sem sobreposição. `201`. |
| POST | `/professionals/me/availability/{slot_id}/archive` | Profissional proprietário; inativa vaga livre sem apagá-la. |
| GET | `/professionals/{professional_id}/availability` | Público; vagas futuras livres, sem dados de clientes. |
| GET | `/professionals/{professional_id}` | Pública; perfil, média e quantidade de avaliações. |
| GET | `/professionals/{professional_id}/reviews` | Pública; avaliações com paginação. |
| POST | `/requests` | Cliente; profissional, vaga publicada, valor da visita visualizado, título, descrição e endereço. Horário/duração derivados pelo servidor. `201`, inicialmente pendente. |
| GET | `/requests` | Autenticada; próprias solicitações; `status`, `limit`, `offset`. |
| GET | `/requests/{request_id}` | Somente participantes. |
| PATCH | `/requests/{request_id}/status` | Participante autorizado à etapa; `status`. |
| POST | `/requests/{request_id}/review` | Cliente criador, após conclusão; nota e comentário. `201`. |
| GET | `/requests/{request_id}/messages` | Participantes; histórico com paginação. |
| POST | `/requests/{request_id}/messages` | Participantes; texto `body`. `201`. |

Listas paginadas retornam arrays. `limit`: 1 a 100; `offset`: inteiro a partir de
0. Leia páginas até retornar menos itens que o limite. O Swagger descreve os
tipos, validações e corpos de todas as operações. Não existem rotas DELETE.

Busca próxima de uma coordenada fictícia em Natal:
`GET /professionals?latitude=-5.7945&longitude=-35.211&radius_km=25&available=true`.
A busca utiliza uma base profissional aproximada para preservar sua coordenada privada.
As coordenadas da busca devem ser enviadas juntas. Resultados incluem `distance_km`,
ordenados antes da paginação. Sem coordenadas, a distância é `null`. Perfis sem
base cadastrada não aparecem na busca por GPS. `sort=rating` ordena por avaliação.
`available=true` exige vaga futura livre, valor de visita definido e recebimento
de pedidos ativo. `available_within_hours=24` restringe a vagas que começam nas
próximas 24 horas; aceita de 1 a 168 horas. Ambos podem ser combinados com os
demais filtros. Resultados incluem `visit_fee_cents` e `next_available_at`.

As listas de agenda aceitam `from` e `to` ISO 8601 com fuso, além de `limit` e
`offset`. O profissional publica janelas entre 30 e 480 minutos, até 180 dias no
futuro, com limite de 200 vagas futuras ativas. `POST /requests` ocupa a vaga
escolhida enquanto aguarda aceite. Recusa ou cancelamento a libera. Veja
[agenda e valor da visita](agenda_visitas.md) para o contrato do fluxo.

## Login

```http
POST /auth/login
Content-Type: application/json

{"email":"cliente@example.com","password":"Demo12345!"}
```

Resposta `200`, com token ilustrativo:

```json
{
  "access_token":"TOKEN_ALEATORIO_RECEBIDO_DO_SERVIDOR",
  "token_type":"bearer","expires_at":"2026-11-06T15:00:00Z",
  "user":{"id":1,"name":"Maria Souza","email":"cliente@example.com","phone":"84999990000","role":"cliente"}
}
```

Envie `Authorization: Bearer TOKEN` nas operações autenticadas. No botão
**Authorize** do Swagger, cole somente o token. Cada login cria sessão independente
com duração absoluta de 30 dias, sem renovação automática.

## Criar solicitação

Primeiro publique uma vaga pelo perfil profissional, com início/fim futuros, e
consulte `/professionals/{id}/availability`. Use o `slot_id` retornado e o valor
da visita mostrado no perfil. Os IDs e datas dos exemplos abaixo são ilustrativos.

```http
POST /requests
Authorization: Bearer TOKEN
Content-Type: application/json

{
  "professional_id":2,"slot_id":5,"expected_visit_fee_cents":8000,
  "title":"Instalação de tomadas",
  "description":"Preciso instalar três tomadas na sala.",
  "address":"Rua das Flores, 123 — Natal, RN"
}
```

Resposta `201`:

```json
{
  "id":3,"client_id":1,"client_name":"Maria Souza",
  "professional_id":2,"professional_name":"João Silva",
  "slot_id":5,"visit_fee_cents":8000,
  "title":"Instalação de tomadas",
  "description":"Preciso instalar três tomadas na sala.",
  "address":"Rua das Flores, 123 — Natal, RN",
  "scheduled_at":"2026-10-17T17:00:00Z","duration_minutes":60,
  "status":"pendente","created_at":"2026-10-16T15:00:00Z","review_id":null
}
```

Somente o profissional atribuído aceita/recusa/inicia/conclui; somente o cliente
criador cancela, enquanto pendente ou aceito. Confira [os estados](arquitetura.md).

## Erros

| HTTP | Situação | Exemplo |
| --- | --- | --- |
| `401` | Sem autenticação, sessão inválida ou expirada | `{ "detail": "Autenticação necessária ou sessão expirada." }` |
| `403` | Perfil sem permissão ou terceiro | `{ "detail": "Você não participa desta solicitação." }` |
| `404` | ID inexistente | `{ "detail": "Solicitação não encontrada." }` |
| `409` | Duplicata, estado inválido ou concorrência | `{ "detail": "Transição de estado não permitida." }` |
| `422` | Validação | Array `detail` com `loc`, `msg` e `type`, ou mensagem `detail` para regras de negócio. |
| `429` | Limite de tentativas | Mensagem genérica e `Retry-After`. |

Exemplo `422`:

```json
{"detail":[{"type":"greater_than_equal","loc":["body","rating"],"msg":"Input should be greater than or equal to 1"}]}
```

Timeout e falha de rede não significam sucesso. A interface mantém o formulário
e permite tentar novamente. Reenviar a mesma reserva, pelo mesmo cliente para
a mesma vaga, com dados e valor idênticos, recupera o pedido existente. Uma
mudança de preço antes da criação retorna 409 para nova confirmação. No chat, o ID idempotente
torna a repetição segura. Veja [o contrato WebSocket](websocket.md).

Consulte [perfil e notificações](perfil_notificacoes.md) para exemplos dos novos recursos e o protocolo `/ws/notifications`, e [segurança](seguranca.md) para criptografia, proteção de chaves e requisitos de HTTPS/WSS.

## Contrato complementar de 25/10/2026

| Método | Recurso | Acesso/resultado |
| --- | --- | --- |
| POST | `/auth/password/reset-request` | Público, limitado; 202 genérico e código somente por email. |
| POST | `/auth/password/reset` | Email, código temporário e nova senha; uso único e revogação de sessões. |
| POST | `/auth/email/verification-request` | Público, limitado; 202 genérico. |
| POST | `/auth/email/verify` | Email e código; confirma contato. |
| GET | `/users/me/sessions` | Próprio usuário; datas/estado, sem token ou digest. |
| POST | `/users/me/sessions/revoke-all` | Autenticado, senha; revoga sessões. |
| POST | `/users/me/closure` | Autenticado, senha e confirmação da interface; encerramento sem apagar linhas. |
| GET/POST | `/account/closure` | Página pública; submissão exige email, senha e confirmação explícita. |
| GET | `/legal/documents/{kind}` | Documento público JSON com versão. |
| GET | `/legal/{kind}` | Documento público HTML. |
| GET | `/requests/summary` | Resumo do próprio usuário; totais por estado e prévia limitada. |

As rotas de eventos, formatos exatos e permissões estão no OpenAPI exportado. `/requests?agenda=true` filtra agenda no servidor; listas têm paginação. `/messages?before_id=...` busca mensagens anteriores, somente por participante. Novos pedidos expõem `hold_expires_at`; cancelamentos registram motivo/autor. HTTP 413 indica corpo acima de 64 KiB, 429 limite de uso e 503 indisponibilidade controlada. O envio REST legado de mensagens retorna 410 em produção: o contrato atual usa WebSocket. Exemplos de datas futuras do Swagger são renovados ao gerar o documento.
