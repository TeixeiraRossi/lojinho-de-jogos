# Lojinho de jogos — etapa 1

API de estudo concentrada em `index.php`. Requer PHP 8.1+ com PDO MySQL e o banco de `database.sql` importado no MySQL.

## Executar no PowerShell

Configure as credenciais no mesmo terminal que iniciará o servidor:

```powershell
$env:DB_HOST = 'localhost'
$env:DB_PORT = '3306'
$env:DB_NAME = 'lojinho'
$env:DB_USER = 'root'
$env:DB_PASSWORD = 'sua-senha'
php -S localhost:8000
```

O código não carrega arquivos `.env`. Os padrões são localhost, porta 3306, banco lojinho, usuário root e senha vazia.

## Operações

| Método | URL | Resultado |
|---|---|---|
| GET | /index.php?recurso=jogos | Lista jogos ativos; lista vazia retorna 200 |
| GET | /index.php?recurso=jogos&id=1 | Busca um jogo ativo |
| POST | /index.php?recurso=jogos | Cadastra jogo ativo e retorna 201 |
| PUT | /index.php?recurso=jogos&id=1 | Substitui título, descrição e preço |
| DELETE | /index.php?recurso=jogos&id=1 | Desativa o jogo, preservando o registro |

`recurso=jogos` pode ser omitido. Jogos desativados retornam 404 na busca, edição e nova exclusão. Ainda não existe reativação.

POST e PUT exigem `Content-Type: application/json`, título e preço. Descrição omitida ou null fica null, inclusive no PUT. Exemplo:

```json
{
  "titulo": "Hollow Knight",
  "descricao": "Uma aventura de exploração.",
  "preco": "46.99"
}
```

Preço aceita zero, ponto decimal e até duas casas; recomenda-se enviá-lo como string. O GET também retorna o DECIMAL como string. Não são aceitos campos além de titulo, descricao e preco. Estoque permanece no banco, com seu padrão zero, mas não participa desta etapa.

Exemplo no PowerShell:

```powershell
$base = 'http://localhost:8000/index.php?recurso=jogos'
$corpo = @{ titulo = 'Jogo de estudo'; descricao = 'Exemplo'; preco = '0.00' } | ConvertTo-Json
$criado = Invoke-RestMethod -Method Post -Uri $base -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($corpo))
$idJogo = $criado.dados.id
Invoke-RestMethod -Uri "$base&id=$idJogo"
Invoke-RestMethod -Method Put -Uri "$base&id=$idJogo" -ContentType 'application/json; charset=utf-8' -Body '{"titulo":"Novo titulo","preco":"19.90"}'
Invoke-RestMethod -Method Delete -Uri "$base&id=$idJogo"
Invoke-RestMethod -Uri $base
```

Erros retornam `erro`: 400 para entradas inválidas, 404 para recurso/jogo inexistente, 405 para método não suportado, 415 para tipo de conteúdo incorreto e 500 para falhas do banco. Detalhes do banco ficam no log do PHP.

Esta etapa ainda não implementa autenticação: criação, edição e desativação estão abertas no servidor de estudo. Use localmente até a etapa de permissões.
