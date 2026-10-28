# Status da apresentação local

A versão atual usa Flutter + FastAPI + SQLAlchemy + SQLite persistente no Windows. As regras do aplicativo e a comunicação HTTP/WebSocket permanecem centralizadas na API. Não é necessário iniciar um serviço de banco separado.

Foram removidos da árvore ativa os arquivos de containers/proxy/implantação e scripts/migrações/testes específicos do banco anterior. Configuração privada e dados anteriores foram preservados; os registros foram transferidos e conferidos no SQLite.

Mantidos: login bcrypt, sessões de 30 dias, endereços, catálogo por categoria/proximidade, valor da visita, agenda publicada, reserva com aceite, prazo de resposta, chat, notificações no app e avaliações vinculadas a serviços concluídos. Push e email exigem suas integrações externas; não são simulados.

Os testes atuais usam SQLite temporário, incluindo concorrência de reservas e backup/restauração. O resultado desta execução está em [limpeza_codigo.md](limpeza_codigo.md). O aplicativo Flutter não teve mudança de design nesta adaptação.

Antes de apresentar, execute o roteiro em [apresentacao_mvp.md](apresentacao_mvp.md) no celular. Os pacotes antigos em `entregas/` descrevem uma configuração anterior e não devem ser reaplicados. Nenhum commit ou push foi realizado para esta mudança.
