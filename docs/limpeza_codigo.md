# Limpeza e formatação da versão local

SQLite é o único banco aceito em execução. Foram removidos o driver externo, branches de SQL específicos, integração de testes externa, containers, proxy e scripts de iniciar/parar banco separado. Backup/restauração agora usam a API nativa do SQLite; OpenAPI e DDL são exportados para o banco atual.

O código anterior de infraestrutura e os documentos substituídos foram preservados em `entregas/arquivo-postgresql-2026-10-25/`, ignorado pelo Git. A instalação e os dados privados anteriores foram preservados. Essa pasta não faz parte da aplicação utilizada.

EditorConfig, Dart format e Black mantêm a indentação por linguagem. Na validação desta versão, **64 testes do backend passaram usando SQLite**, incluindo autenticação, permissões, agenda, concorrência, persistência e backup em arquivos temporários. A limpeza posterior removeu um módulo intermediário redundante, deixando 37 arquivos Python de aplicação/testes/scripts; o Flutter tem 49 arquivos verificados pelo formatador.

Também foram conferidos catálogo, login, consulta autenticada, logout e rejeição 401 na API real, após desligar o banco anterior. A sessão criada para essa conferência foi revogada. Backup e restauração do SQLite real foram verificados em outro arquivo, sem apagar usuários ou sobrescrever dados. Nenhum commit ou push foi realizado.

Foram removidos 78 comentários redundantes dos fontes e testes, comentários de template do Gradle e uma exceção do verificador de segredos que servia apenas à documentação antiga. Na remoção de comentários Python, a equivalência da AST foi conferida antes de formatar. Textos de documentação da API, docstrings funcionais e licenças permanecem. O registro WebSocket agora é importado diretamente, sem arquivo que apenas reexportava a mesma função.

Após a limpeza, **111 testes Flutter passaram**, Flutter analyze não encontrou problemas e cinco regressões WebSocket passaram novamente. A auditoria estática dos imports Python não identificou importações sem referência. A atualização real do SQLite também foi executada com sucesso após simplificar os imports. O índice do Git permaneceu intacto.
