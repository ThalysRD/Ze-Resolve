# SQLite local no Windows

A API utiliza SQLAlchemy com SQLite. O arquivo padrão é `backend/data/apresentacao.db`, resolvido por caminho absoluto a partir do backend, independentemente do diretório do terminal. Uma `DATABASE_URL` explícita pode selecionar outro arquivo SQLite; drivers de outros bancos são rejeitados.

SQLite é um banco relacional persistente, com transações, chaves estrangeiras, índices e constraints. É adequado à apresentação local porque dispensa um processo de banco separado. Não é uma proposta de infraestrutura para um marketplace público com vários servidores concorrentes.

O Flutter não lê esse arquivo. O fluxo permanece **Flutter → FastAPI/HTTP + WebSocket → SQLAlchemy → SQLite**. O banco é atualizado por migrações aditivas, sem exclusão de registros. Chaves estrangeiras são ativadas em cada conexão; WAL permite leitura durante escrita e há espera limitada para concorrência. As reservas continuam protegidas por transação e índice único parcial.

## Comandos

```powershell
.\scripts\run_backend.ps1
.\scripts\run_backend.ps1 -Task seed
.\scripts\run_backend.ps1 -Task upgrade
```

`seed` cria somente dados fictícios de demonstração, explicitamente. `upgrade` prepara categorias e atualiza o schema sem criar contas fictícias. Reiniciar a API mantém os dados. SQLite acompanha o Python: não se instala serviço nem cliente separado.

## Backup

```powershell
.\backend\.venv\Scripts\python.exe scripts/database_backup.py backup --file backend/data/backups/apresentacao-copia.db
.\backend\.venv\Scripts\python.exe scripts/database_backup.py restore --file backend/data/backups/apresentacao-copia.db --target-file backend/data/restaurado.db
```

Escolha nomes novos. O utilitário usa a API de backup do SQLite, incluindo o conteúdo do WAL; não copie apenas o `.db` enquanto a API está escrevendo. Ele verifica integridade, relacionamentos, chave AES e manifesto SHA-256 e recusa sobrescrever arquivos. Preserve o `.db`, o manifesto `.db.json` e uma cópia privada da chave original. Os dados do banco continuam cifrados; a chave fica fora dele.

## Dados anteriores

Os dados do banco anterior foram transferidos para `apresentacao.db`, com conferência das contagens, chaves estrangeiras e leitura de todos os campos cifrados. A origem não foi alterada nem apagada. A instalação e os backups anteriores ficam privados e fora do código utilizado na apresentação.
