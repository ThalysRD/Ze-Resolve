# Agenda publicada e valor da visita

A partir da revisão de 16/10/2026, o profissional define um valor fixo para a visita e publica horários de atendimento. O cliente escolhe um desses horários e envia um pedido; o profissional ainda precisa aceitar. A descrição pública pode conter preços tabelados de serviços, sem que a aplicação transforme esse texto em cobrança automática.

## Preço

- `visit_fee_cents` é o valor da visita em centavos, definido pelo profissional. Zero é permitido quando ele oferece visita gratuita; não é um valor inserido silenciosamente para perfis incompletos.
- O valor da visita não representa o preço total do serviço. Escopo, materiais e serviços adicionais podem ser combinados entre as partes.
- O formulário envia `expected_visit_fee_cents`, o valor que o cliente viu. O servidor compara esse valor com o perfil e exige uma nova confirmação se houve mudança; o cliente não consegue definir o preço que será armazenado.
- O pedido guarda uma cópia do valor acordado. Alterações posteriores no perfil não mudam o histórico de pedidos existentes.
- A antiga tarifa por hora permanece somente como dado legado no banco. Ela não é convertida automaticamente em preço de visita. Perfis antigos precisam confirmar o novo valor antes de receber reservas.

## Horários e reserva

1. O profissional publica início e fim de um horário futuro. A janela deve ter entre 30 minutos e 8 horas, em minutos completos. Intervalos adjacentes são permitidos; sobreposições não.
2. O catálogo respeita a pausa geral do profissional, o valor da visita definido e os horários efetivamente livres. Ativar disponibilidade, sozinho, não cria horários.
3. O cliente consulta a agenda pública, escolhe um horário e preenche serviço, descrição e endereço. Não pode enviar um horário arbitrário ou alterar a duração da janela.
4. O pedido começa `pendente` e ocupa o horário enquanto aguarda o prestador. Esse estado é apresentado como “Aguardando resposta”, sem prometer confirmação imediata.
5. O prestador aceita ou recusa. O cliente pode cancelar enquanto pendente ou aceito. Recusa e cancelamento liberam a vaga, se ela continuar publicada e futura.
6. Um horário ocupado não pode ser arquivado. Retirar uma vaga livre da agenda apenas a inativa; não há exclusão física.
7. Aceite, início, conclusão, avaliações e acesso à conversa continuam sujeitos às permissões e à máquina de estados do servidor.

Desde 25/10/2026, novas pendências reservam a vaga por 30 minutos, limitados ao início do atendimento. `BOOKING_HOLD_MINUTES` permite configurar entre 5 e 1.440 minutos. Cada cliente pode manter até cinco pendências. A expiração registra cancelamento e motivo, libera a vaga e avisa os participantes; não apaga o pedido. Pendências legadas sem prazo mantêm seu histórico. O profissional também pode cancelar um pedido aceito, informando motivo de pelo menos cinco caracteres. O servidor não permite aceitar uma reserva vencida. O profissional deve publicar janelas que comportem visita e deslocamento. O sistema não calcula rotas nem promete a duração final do reparo.

## Próximas 24 horas

O filtro usa `available_within_hours=24`. Um profissional só corresponde quando tem pelo menos uma vaga livre com início posterior ao instante da consulta e até 24 horas depois, está recebendo pedidos e definiu o valor da visita. A comparação usa UTC; a interface apresenta o horário local.

Uma vaga que foi reservada deixa de contar. Recusar ou cancelar um pedido pode fazê-la reaparecer. Um perfil apenas marcado como disponível, sem vaga dentro da janela, não corresponde ao filtro. O filtro pode ser combinado com categoria, localização, cidade e avaliação. Ele indica opções para agendar; não garante atendimento imediato ou aceite pelo profissional.

## Integridade e privacidade

As mutações de agenda e pedidos são serializadas por profissional. Um índice único parcial impede dois pedidos ocupantes no mesmo horário, inclusive entre processos do servidor. Uma disputa recebe HTTP 409. Repetir o mesmo pedido do mesmo cliente para a mesma vaga, com os mesmos dados e valor, recupera o pedido existente em vez de criar outro.

A agenda pública retorna apenas as vagas livres e seus horários. Não inclui quem reservou, endereço, telefone, conteúdo de pedidos ou base geográfica exata. A agenda de gestão exige o perfil profissional proprietário. Migrações acrescentam tabelas e campos sem apagar usuários, sessões, solicitações ou mensagens.

Pedidos antigos continuam consultáveis e seguem suas transições permitidas. Eles não recebem um valor de visita inventado. Pendências antigas sem vaga vinculada não reservavam horários e mantêm esse comportamento; após aceite, também impedem que o profissional publique ou use um horário conflitante.

## Rotas principais

| Método | Rota | Uso |
| --- | --- | --- |
| PUT | `/professionals/me` | Define perfil e `visit_fee_cents`; somente o profissional |
| GET | `/professionals/me/availability` | Lista a agenda do próprio profissional, com indicação de ocupação |
| POST | `/professionals/me/availability` | Publica `{starts_at, ends_at}`; retorno 201 |
| POST | `/professionals/me/availability/{slot_id}/archive` | Inativa uma vaga livre |
| GET | `/professionals/{id}/availability` | Consulta vagas futuras disponíveis para clientes |
| GET | `/professionals?available_within_hours=24` | Busca profissionais com vaga nas próximas 24 horas |
| POST | `/requests` | Solicita o horário escolhido; começa pendente |

O contrato completo, tipos, permissões, limites, parâmetros e exemplos são gerados em `openapi.json`. O Swagger da API em execução está em `/docs`.
