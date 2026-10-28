# Roteiro da apresentação

1. Inicie `scripts/run_backend.ps1`. Abra `/health` e `/docs`; mostre os recursos, validação e autenticação do contrato OpenAPI.
2. Conecte o celular por USB e execute `scripts/run_android_usb.ps1`. O banco permanece no Windows; o Flutter utiliza a API por HTTP/WebSocket.
3. Entre como prestador, complete categoria/cidade e valor fixo da visita, publique uma vaga futura e ative o recebimento de pedidos. Preços da descrição são informativos; a visita não representa o orçamento total do reparo.
4. Entre como cliente, busque por categoria/cidade ou GPS. Mostre o filtro de vagas nas próximas 24 horas, escolha o horário e envie o pedido. A tela precisa exibir que aguarda aceite.
5. Como prestador, aceite; mostre atualização do pedido, conversa e mensagens confirmadas. Depois inicie, conclua e avalie como cliente. Explique que cancelar/recusar/expirar libera a vaga e conserva histórico.
6. Demonstre endereço, alteração de senha e sessões. Sem SMTP real, não afirme que houve envio de recuperação de senha. Push depende de Firebase/rede; os avisos dentro do app são persistidos localmente.
7. Reinicie a API e consulte os dados novamente. Mostre o arquivo SQLite privado e explique SQLAlchemy, transações, relacionamentos e ausência de exclusões físicas nas operações do produto.

Use apenas dados fictícios. Contas e comandos estão no README. Valide previamente permissões de GPS, encaminhamento USB e conexão. No emulador use `10.0.2.2`; no celular físico por USB use o encaminhamento, nunca o endereço do emulador.

A apresentação é local. Não depende de domínio, Docker ou hospedagem. Os dados e chaves não devem ser enviados ao Git; backup/recuperação estão em [sqlite.md](sqlite.md). A fase de interface continua exigindo os links e evidências reais da equipe, conforme orientação do professor.
