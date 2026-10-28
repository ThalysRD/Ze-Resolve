abstract interface class UserFacingException implements Exception {
  String get message;
}

const unavailableMessage =
    'Não conseguimos acessar o serviço agora. Tente novamente em instantes.';
const unexpectedMessage = 'Não foi possível concluir agora. Tente novamente.';

String userErrorMessage(Object? error, {String fallback = unexpectedMessage}) =>
    error is UserFacingException ? error.message : fallback;
String serverErrorMessage(dynamic detail, int? statusCode) {
  if (statusCode != null && statusCode >= 500) return unavailableMessage;
  if (statusCode == 429) {
    return 'Muitas tentativas em pouco tempo. Aguarde um pouco e tente novamente.';
  }
  const messages = {
    'O prazo de resposta terminou. Consulte a agenda para solicitar outro horário.':
        'O prazo de resposta terminou. Escolha um novo horário na agenda.',
    'Confirme seu email antes de entrar.':
        'Confirme seu email para entrar. Use a opção Confirmar meu email.',
    'Código inválido ou expirado.':
        'O código está incorreto ou venceu. Solicite um novo código.',
    'Informe o motivo do cancelamento.': 'Informe o motivo do cancelamento.',
    'Você já possui cinco solicitações aguardando resposta. Cancele uma ou aguarde o prestador.': 'Você já tem cinco pedidos aguardando resposta. Aguarde ou cancele um deles.',
    'Conclua o atendimento em andamento antes de encerrar a conta.':
        'Conclua o atendimento em andamento antes de encerrar sua conta.',
    'Leia e aceite a versão atual dos termos e da política de privacidade.':
        'Leia e aceite a versão atual dos termos e da política de privacidade.',
    'Email ou senha inválidos.':
        'Email ou senha incorretos. Confira e tente novamente.',
    'Autenticação necessária ou sessão expirada.':
        'Entre novamente para continuar.',
    'Sessão inválida.': 'Entre novamente para continuar.',
    'Permissão insuficiente.':
        'Você não tem permissão para realizar esta ação.',
    'Você não participa desta solicitação.':
        'Você não tem acesso a esta solicitação.',
    'Seu perfil não pode executar esta etapa.':
        'Esta ação não está disponível para seu perfil.',
    'A senha atual está incorreta.': 'A senha atual está incorreta.',
    'Escolha uma senha diferente da atual.':
        'Escolha uma senha diferente da atual.',
    'Sua senha foi alterada. Entre novamente.':
        'Sua senha foi alterada. Entre novamente.',
    'Solicitação não encontrada.': 'Esta solicitação não está mais disponível.',
    'Endereço não encontrado.': 'Este endereço não está mais disponível.',
    'Mensagem recebida não encontrada.':
        'Esta mensagem não está mais disponível.',
    'Categoria não encontrada.': 'Esta categoria não está mais disponível.',
    'Profissional não encontrado.':
        'Este profissional não está mais disponível.',
    'Complete seu perfil profissional.':
        'Complete seu perfil profissional para continuar.',
    'Registro duplicado ou vínculo inválido.':
        'Não foi possível salvar estes dados. Confira e tente novamente.',
    'Você pode manter até 20 endereços. Arquive um antes de adicionar outro.': 'Você pode manter até 20 endereços. Arquive um antes de adicionar outro.',
    'Informe latitude e longitude juntas.':
        'Escolha sua localização novamente.',
    'Profissional indisponível para novas solicitações.':
        'Este profissional não está disponível para novos serviços agora.',
    'O valor da visita mudou. Atualize a agenda antes de confirmar.':
        'O valor da visita mudou. Confira o novo valor antes de confirmar.',
    'Horário não encontrado.': 'Este horário não está mais disponível.',
    'Horário não encontrado para este profissional.':
        'Este horário não está mais disponível para o profissional escolhido.',
    'Defina o valor da visita no seu perfil antes de publicar horários.':
        'Defina o valor da visita no seu perfil antes de publicar horários.',
    'Este horário já passou. Escolha um horário futuro.':
        'Este horário já passou. Escolha um horário futuro.',
    'Este horário conflita com sua agenda. Escolha outro intervalo.': 'Você já tem um horário ocupado nesse período. Escolha outro intervalo.',
    'Você já publicou 200 horários futuros. Remova um horário livre antes de adicionar outro.': 'Você atingiu o limite de 200 horários futuros. Retire um horário livre antes de adicionar outro.',
    'Este horário possui uma solicitação e não pode ser retirado.':
        'Este horário tem um pedido ativo e não pode ser retirado da agenda.',
    'Este horário já foi reservado. Escolha outro horário.':
        'Este horário acabou de ser reservado. Escolha outro.',
    'Este prestador ainda não definiu o valor da visita.':
        'O profissional ainda precisa definir o valor da visita.',
    'Este horário não está mais disponível. Escolha outro horário.':
        'Este horário não está mais disponível. Escolha outro.',
    'Este horário conflita com outra reserva. Escolha outro horário.':
        'Este horário já está ocupado. Escolha outro.',
    'Este horário conflita com outra reserva da sua agenda.':
        'Você já tem outro pedido reservado para esse horário.',
    'Informe datas com fuso horário.':
        'Confira as datas e os horários escolhidos.',
    'O fim da consulta deve ser posterior ao início.':
        'Escolha o fim do período depois do início.',
    'Transição de estado não permitida.':
        'Essa etapa não está disponível agora. Atualize a solicitação.',
    'Solicitação alterada por outra operação.':
        'Esta solicitação foi atualizada. Atualize a tela para continuar.',
    'Solicitação alterada por outra operação. Atualize a tela.':
        'Esta solicitação foi atualizada. Atualize a tela para continuar.',
    'O horário solicitado já passou. Peça ao cliente uma nova solicitação.':
        'O horário solicitado já passou. Peça ao cliente uma nova solicitação.',
    'Este horário conflita com outro serviço aceito na sua agenda.':
        'Você já tem um serviço confirmado neste horário.',
    'Conclua o serviço em andamento antes de iniciar outro.':
        'Conclua o serviço em andamento antes de iniciar outro.',
    'Somente serviços concluídos podem ser avaliados.':
        'Você poderá avaliar este serviço quando ele for concluído.',
    'Mensagem muito grande.': 'Sua mensagem deve ter até 2.000 caracteres.',
    'Use frames de texto JSON.': 'Não foi possível enviar a mensagem. Abra a conversa e tente novamente.',
    'Informe body (1 a 2.000 caracteres) e client_message_id (16 a 64 caracteres).':
        'Escreva uma mensagem de até 2.000 caracteres e tente novamente.',
    'Identificador já usado para outra mensagem.': 'Não foi possível enviar a mensagem. Abra a conversa e tente novamente.',
  };
  if (detail is String && messages.containsKey(detail)) {
    return messages[detail]!;
  }
  return switch (statusCode) {
    401 => 'Entre novamente para continuar.',
    403 => 'Você não tem permissão para realizar esta ação.',
    404 => 'O conteúdo solicitado não está mais disponível.',
    409 => 'As informações foram atualizadas. Confira e tente novamente.',
    400 || 422 => 'Confira os dados informados e tente novamente.',
    _ => unexpectedMessage,
  };
}
