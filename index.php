<?php

declare(strict_types=1);

// 1. Respostas e cabeçalhos.
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

function responder(int $status, array $conteudo): never
{
    http_response_code($status);
    echo json_encode($conteudo, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    exit;
}

function lerJogo(): array
{
    $tipo = strtolower(trim(explode(';', $_SERVER['CONTENT_TYPE'] ?? '')[0]));
    if ($tipo !== 'application/json') {
        responder(415, ['erro' => 'Use Content-Type: application/json.']);
    }
    try {
        $dados = json_decode(file_get_contents('php://input'), false, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $e) {
        responder(400, ['erro' => 'JSON inválido.']);
    }
    if (!$dados instanceof stdClass) {
        responder(400, ['erro' => 'O corpo deve ser um objeto JSON.']);
    }
    $dados = (array) $dados;
    $extras = array_diff(array_keys($dados), ['titulo', 'descricao', 'preco']);
    if ($extras) {
        responder(400, ['erro' => 'Campos desconhecidos.', 'campos' => array_values($extras)]);
    }
    $titulo = $dados['titulo'] ?? null;
    if (!is_string($titulo) || trim($titulo) === '' || preg_match_all('/./us', trim($titulo)) > 150) {
        responder(400, ['erro' => 'Título obrigatório, com até 150 caracteres.']);
    }
    $descricao = $dados['descricao'] ?? null;
    if ($descricao !== null && (!is_string($descricao) || strlen($descricao) > 65535)) {
        responder(400, ['erro' => 'Descrição deve ser texto com até 65535 bytes, ou null.']);
    }
    $preco = $dados['preco'] ?? null;
    if ((!is_string($preco) && !is_int($preco) && !is_float($preco))
        || !preg_match('/^(0|[1-9][0-9]{0,7})(\.[0-9]{1,2})?$/D', (string) $preco)) {
        responder(400, ['erro' => 'Preço obrigatório entre 0 e 99999999.99, com até duas casas decimais e ponto como separador.']);
    }
    // Envia o preço como texto ao DECIMAL, sem cálculos com ponto flutuante.
    $partes = explode('.', (string) $preco);
    return ['titulo' => trim($titulo), 'descricao' => $descricao,
        'preco' => $partes[0] . '.' . str_pad($partes[1] ?? '', 2, '0')];
}

// 2. Roteamento e validação antes da conexão.
$metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($metodo === 'OPTIONS') {
    http_response_code(204);
    exit;
}
if (!in_array($metodo, ['GET', 'POST', 'PUT', 'DELETE'], true)) {
    header('Allow: GET, POST, PUT, DELETE, OPTIONS');
    responder(405, ['erro' => 'Método HTTP não suportado.']);
}
if (($_GET['recurso'] ?? 'jogos') !== 'jogos') {
    responder(404, ['erro' => 'Recurso não encontrado.']);
}
$id = null;
if (array_key_exists('id', $_GET)) {
    $id = filter_var($_GET['id'], FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    if ($id === false) {
        responder(400, ['erro' => 'O ID deve ser um inteiro positivo.']);
    }
}
if (in_array($metodo, ['PUT', 'DELETE'], true) && $id === null) {
    responder(400, ['erro' => 'Informe o ID do jogo.']);
}
if ($metodo === 'POST' && $id !== null) {
    responder(400, ['erro' => 'Não informe ID ao cadastrar.']);
}
$dados = in_array($metodo, ['POST', 'PUT'], true) ? lerJogo() : null;

// 3. Configuração por variáveis de ambiente.
$host = getenv('DB_HOST') ?: 'localhost';
$porta = getenv('DB_PORT') ?: '3306';
$banco = getenv('DB_NAME') ?: 'lojinho';
$usuario = getenv('DB_USER') ?: 'root';
$senha = getenv('DB_PASSWORD');

try {
    $conexao = new PDO("mysql:host=$host;port=$porta;dbname=$banco;charset=utf8mb4",
        $usuario, $senha === false ? '' : $senha, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);

    // 4. CRUD. O catálogo mostra apenas jogos ativos.
    switch ($metodo) {
        case 'GET':
            $colunas = 'id, titulo, descricao, preco, ativo, data_criacao, data_atualizacao';
            if ($id === null) {
                $stmt = $conexao->query("SELECT $colunas FROM jogos WHERE ativo = 1 ORDER BY id");
                responder(200, ['dados' => $stmt->fetchAll()]);
            }
            $stmt = $conexao->prepare("SELECT $colunas FROM jogos WHERE id = :id AND ativo = 1");
            $stmt->execute(['id' => $id]);
            $jogo = $stmt->fetch();
            if ($jogo === false) {
                responder(404, ['erro' => 'Jogo não encontrado.']);
            }
            responder(200, ['dados' => $jogo]);

        case 'POST':
            $stmt = $conexao->prepare('INSERT INTO jogos (titulo, descricao, preco) VALUES (:titulo, :descricao, :preco)');
            $stmt->execute($dados);
            $novoId = (int) $conexao->lastInsertId();
            header('Location: index.php?recurso=jogos&id=' . $novoId);
            responder(201, ['mensagem' => 'Jogo cadastrado.', 'dados' => ['id' => $novoId] + $dados]);

        case 'PUT':
        case 'DELETE':
            // Evita que outra requisição desative o jogo entre a busca e a alteração.
            $conexao->beginTransaction();
            $stmt = $conexao->prepare('SELECT id FROM jogos WHERE id = :id AND ativo = 1 FOR UPDATE');
            $stmt->execute(['id' => $id]);
            if ($stmt->fetch() === false) {
                $conexao->rollBack();
                responder(404, ['erro' => 'Jogo não encontrado.']);
            }
            if ($metodo === 'PUT') {
                $stmt = $conexao->prepare('UPDATE jogos SET titulo = :titulo, descricao = :descricao, preco = :preco WHERE id = :id');
                $stmt->execute($dados + ['id' => $id]);
                $conexao->commit();
                responder(200, ['mensagem' => 'Jogo atualizado.', 'dados' => ['id' => $id] + $dados]);
            }
            $stmt = $conexao->prepare('UPDATE jogos SET ativo = 0 WHERE id = :id');
            $stmt->execute(['id' => $id]);
            $conexao->commit();
            responder(200, ['mensagem' => 'Jogo desativado.']);
    }
} catch (PDOException $e) {
    if (isset($conexao) && $conexao->inTransaction()) {
        $conexao->rollBack();
    }
    error_log('Erro de banco na API: ' . $e->getMessage());
    responder(500, ['erro' => 'Não foi possível realizar a operação no banco de dados.']);
}
