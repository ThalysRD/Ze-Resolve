# Status da versão atual

O Zé Resolve usa aplicativo Flutter, API própria em FastAPI e banco relacional SQLite com SQLAlchemy. Regras de negócio, persistência e controle de acesso ficam centralizados na API; o aplicativo se comunica com ela por HTTP/REST e WebSocket. Não é necessário iniciar um serviço de banco separado.

Funcionalidades disponíveis: cadastro e login com bcrypt, sessões de 30 dias, endereços, catálogo por categoria e proximidade, valor da visita, agenda publicada pelo profissional, reserva sujeita ao aceite, prazo de resposta, chat, notificações no app e avaliações vinculadas a serviços concluídos.

Notificações push e email dependem de integrações externas (Firebase e SMTP) e não são simulados. Sem elas, o restante do sistema funciona normalmente.

Antes de apresentar, execute o roteiro em [apresentacao_mvp.md](apresentacao_mvp.md) no celular.
