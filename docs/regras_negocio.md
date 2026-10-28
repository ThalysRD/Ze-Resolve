# Regras de negócio e fundamentação do MVP

## Problema e hipótese

O Zé Resolve conecta clientes a profissionais de serviços locais. O problema a testar é a dificuldade de encontrar alguém que atenda a região, tenha disponibilidade e apresente histórico de trabalhos concluídos. A hipótese do MVP é que categoria, proximidade, agenda e avaliações verificadas reduzam o esforço de contratação. Essa hipótese ainda precisa ser validada com clientes e profissionais; o software funcionando não comprova impacto social, demanda ou qualidade dos prestadores.

## Regras implementadas

| ID | Regra | Aplicação no servidor |
|---|---|---|
| RN01 | Cadastro distingue cliente e profissional. O perfil não pode ser trocado pela interface. | Perfil no usuário; ID e permissões extraídos do token. |
| RN02 | Senhas ficam em bcrypt; login cria uma sessão de 30 dias. | Hash com salt e custo 12. Token aleatório; apenas seu digest fica no banco. Logout invalida a sessão sem apagar o registro. |
| RN03 | O profissional define categoria, cidade e valor fixo da visita. Pode publicar preços tabelados na descrição. | Valor inteiro em centavos; não representa o orçamento total do serviço. Perfis legados precisam confirmar o novo valor, sem converter tarifa por hora. |
| RN04 | Localização é opcional. O cliente escolhe GPS ou cidade. | Cliente não tem histórico de localização gravado. Base do profissional é cadastrada voluntariamente; sua coordenada exata só aparece em `/professionals/me`, autenticada. |
| RN05 | Proximidade exige latitude e longitude válidas e raio de até 200 km. | Haversine sobre a base pública aproximada, corte pelo raio e ordenação antes de paginar. Distância exibida é em linha reta, não trajeto nem tempo de viagem. |
| RN06 | Categoria, texto, cidade, disponibilidade e próximas 24 horas são filtros combináveis. | “Próximas 24h” exige início de uma vaga realmente livre dentro da janela; não basta a pausa geral estar desativada. Perfil sem coordenadas fica fora da busca por GPS, mas continua na busca por cidade/catálogo. |
| RN07 | O profissional publica vagas com início e fim e pode pausar o recebimento de pedidos. | Sem vaga livre, sem valor da visita definido ou com perfil pausado não é possível reservar. Vagas livres podem ser arquivadas; uma vaga ocupada não pode ser retirada. |
| RN08 | O cliente escolhe uma vaga publicada e envia serviço, descrição e endereço. O pedido começa pendente e exige aceite. | Horário, duração da janela, cliente, valor da visita e estado inicial são definidos pelo servidor. O valor visto pelo cliente deve conferir com o perfil. |
| RN09 | Pedidos novos pendentes ocupam a vaga até o prazo de resposta; recusa, cancelamento e expiração a liberam. | Janelas de 30 a 480 minutos inteiros, publicadas até 180 dias no futuro; intervalos adjacentes permitidos. Pedidos legados sem vaga não ocupam enquanto pendentes; após aceite continuam respeitando conflitos de agenda. |
| RN10 | Duas reservas concorrentes não podem ocupar a mesma vaga. | Mutações serializadas por profissional e índice único parcial de vaga ocupada. Reenvio idêntico do mesmo cliente recupera o pedido existente; concorrente ou dados diferentes recebem 409. Só um serviço pode estar em execução por profissional. |
| RN11 | Cliente cancela enquanto pendente ou aceita. Profissional aceita/recusa, inicia, conclui e pode cancelar aceite com motivo. | Máquina de estados validada no servidor; estados finais não reabrem. Cancelamento libera a reserva. Antecipação de execução depende da confirmação manual do profissional. |
| RN12 | Só os participantes acessam endereço, solicitação e conversa. | Acesso sem sessão: 401; usuário externo/perfil inadequado: 403. |
| RN13 | Somente o cliente daquele serviço concluído pode avaliar, uma vez. | Nota inteira 1–5; duplicata ou serviço não concluído: 409. Média e quantidade são calculadas de avaliações reais. |
| RN14 | Mensagem só é confirmada depois de persistir. | WebSocket autenticado; ACK após commit, identificador para deduplicação e recuperação do histórico ao reconectar. Sessão vencida/revogada interrompe o acesso. |
| RN15 | Não há exclusão física nas operações da aplicação. | Sessões são invalidadas; solicitações guardam seus estados finais. Migrações adicionam colunas e preservam registros existentes. |
| RN16 | O valor da visita combinado permanece no pedido. | Mudanças futuras de preço não alteram pedidos existentes. Se o preço muda antes da reserva, o cliente precisa revisar e confirmar novamente. |

As janelas são publicadas pelo profissional e escolhidas pelo cliente. Não representam garantia de duração do reparo. Não há planejamento de rota entre atendimentos neste MVP; por isso, a ausência de sobreposição não é uma garantia de deslocamento viável. Os participantes devem combinar deslocamento e escopo no chat antes do aceite. Veja [a especificação da agenda](agenda_visitas.md).

## Fundamentação e decisões de produto

**Proximidade como contexto.** Ye et al. (SIGIR, 2011) estudaram a influência geográfica em recomendações de pontos de interesse. Isso motiva considerar localização como atributo explícito, mas o estudo não trata da contratação de prestadores nem comprova que ordenar por distância seja a melhor política aqui. O MVP utiliza raio e distância como uma regra simples cuja utilidade será medida no piloto. [Registro do artigo na HKUST, DOI 10.1145/2009916.2009962](https://researchportal.hkust.edu.hk/en/publications/exploiting-geographical-influence-for-collaborative-point-of-inte-2/).

**Reputação verificável.** Abrahao et al. (2017), em um experimento com usuários do Airbnb, encontraram que reputação pode reduzir vieses nas decisões de confiança. Isso sustenta a escolha de mostrar histórico e avaliações vinculadas a serviços, sem usar aparência, gênero ou outros atributos pessoais para recomendar. A extrapolação para serviços domésticos é uma hipótese de produto, não uma conclusão do artigo. [Artigo, PNAS](https://web.stanford.edu/~pparigi/PNAS-2017-Abrahao-9848-53.pdf).

**Qualidade de informação.** Benson, Sojourner e Umyarov estudaram reputação de empregadores no Mechanical Turk e seus efeitos sobre a decisão dos trabalhadores. Isso motiva investigar confiança nos dois lados do mercado; não comprova a eficácia de avaliar prestadores neste aplicativo nem estabelece pesos para seu ranking. No MVP, mostrar média junto com quantidade é uma decisão de transparência, não um resultado desse artigo. [Management Science, DOI 10.1287/mnsc.2019.3303](https://pubsonline.informs.org/doi/10.1287/mnsc.2019.3303).

**Início sem histórico.** O trabalho de Zhu et al. sobre cold start discute a dificuldade de recomendar itens novos sem interações. Como o projeto ainda não tem volume de dados, usa atributos explícitos — categoria, localização e disponibilidade — e mantém novos profissionais elegíveis mesmo sem avaliações. Não implementa o algoritmo desse artigo nem afirma seus resultados para o Zé Resolve. [Addressing the Item Cold-start Problem by Attribute-driven Active Learning](https://arxiv.org/abs/1805.09023).

**Minimização de dados.** O NIST Privacy Framework orienta gestão de riscos e minimização de dados. A implementação evita rastreamento contínuo, pede localização durante o uso e oferece busca manual. A base cadastrada fica privada; a resposta pública entrega somente distância aproximada. O framework é orientação técnica, não certificação nem parecer de conformidade legal. [NIST Privacy Framework](https://www.nist.gov/privacy-framework/privacy-framework).

O raio inicial de 25 km, as janelas de 30 a 480 minutos, o horizonte de 180 dias e o limite de 200 vagas futuras são parâmetros operacionais do MVP. Não foram derivados desses artigos e precisam ser calibrados em entrevistas e no piloto.

## Política de recomendação

1. Eliminar categorias incompatíveis e aplicar filtros escolhidos pelo cliente.
2. Quando há GPS, remover perfis sem base cadastrada ou fora do raio e ordenar por distância crescente.
3. Usar avaliações como desempate; sem GPS, ordenar por média e ID. O usuário pode escolher “Mais bem avaliados”.
4. Mostrar valor da visita, próxima vaga livre, quantidade de avaliações e distância aproximada, permitindo decisão informada.

Essa política é transparente e testável. Não há pontuação de IA nem alegação de recomendação ótima. Um ranking futuro deve ser avaliado quanto a conversão, cobertura de novos profissionais e concentração de exposição antes de substituir essas regras.

## Validação do problema no piloto

Entrevistar clientes que contrataram serviços recentemente e profissionais locais. Registrar, com consentimento, tempo para encontrar opções, dificuldade de combinar horário, principais motivos de recusa e problemas de confiança. Testar protótipos e o fluxo completo com ambos os perfis.

Medir resultados agregados: proporção de buscas sem resultado, tempo entre solicitação e aceite, taxa de aceite, cancelamentos, conclusão e quantidade de serviços de profissionais novos. Fixar critérios de sucesso após conhecer a linha de base; não anunciar redução de tempo ou aumento de eficiência sem comparação observada. Erros e tempos de resposta devem ser medidos sem registrar senhas, tokens, coordenadas exatas ou conteúdo das conversas.

## Escalabilidade: atual e próxima etapa

O MVP usa FastAPI, API independente da interface e SQLite local persistente com SQLAlchemy. Na busca, um índice e limite de latitude reduzem candidatos; avaliações são agregadas por consulta, evitando uma consulta de reputação por candidato. A ordenação geográfica ainda ocorre em Python e o catálogo pode trazer muitos candidatos na mesma latitude. A consulta periódica do chat atende uma demonstração e um piloto pequeno; a capacidade para produção não foi comprovada por teste de carga.

Esta versão está limitada à apresentação local. Uma futura operação pública exigiria medir carga, rever a infraestrutura de banco e a distribuição de eventos antes de ampliar o número de usuários. Essas integrações não fazem parte da configuração atual. Paginação, autorização no servidor e recuperação de backups continuam implementadas.

Para a apresentação, a API permanece local. Recuperação/validação de email depende de SMTP configurado; não é simulada. Limites de autenticação, permissões, proteção de campos privados e logs sem query strings continuam ativos. A publicação para público real não está no escopo desta versão.

O MVP não inclui pagamentos, garantia de qualificação técnica, verificação documental, moderação/disputas, roteamento viário nem contratação trabalhista. Deve ser apresentado como intermediação de solicitações entre clientes e prestadores independentes.

## Controles acrescentados em 25/10/2026

Novas pendências têm prazo padrão de 30 minutos, até o início da vaga, e limite de cinco por cliente. Expiração conserva o pedido cancelado e seu motivo. Avisos de mudanças de etapa são persistidos para os participantes. Produção exige confirmação de email e aceite dos termos vigentes; recuperação de senha invalida sessões. Encerramento voluntário exige senha e pseudonimiza campos pessoais próprios, sem apagar linhas. Essas regras são verificadas no servidor, não apenas na interface.
