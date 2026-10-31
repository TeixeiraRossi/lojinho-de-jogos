
CREATE DATABASE IF NOT EXISTS lojinho
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE lojinho;

-- 1. Usuarios
CREATE TABLE usuarios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(190) NOT NULL UNIQUE,
    senha_hash VARCHAR(255) NOT NULL,
    perfil ENUM('usuario', 'administrador')
        NOT NULL DEFAULT 'usuario',
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Tokens de autenticacao
CREATE TABLE tokens_usuarios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario BIGINT UNSIGNED NOT NULL,
    token_hash CHAR(64) NOT NULL UNIQUE,
    data_expiracao DATETIME NOT NULL,
    data_revogacao DATETIME NULL,
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_tokens_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id)
        ON DELETE CASCADE,

    INDEX idx_tokens_usuario (id_usuario),
    INDEX idx_tokens_expiracao (data_expiracao)
) ENGINE=InnoDB;

-- 3. Jogos
CREATE TABLE jogos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    descricao TEXT NULL,
    preco DECIMAL(10, 2) NOT NULL,
    estoque INT UNSIGNED NOT NULL DEFAULT 0,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT chk_jogos_preco CHECK (preco >= 0)
) ENGINE=InnoDB;

-- 4. Carrinhos
CREATE TABLE carrinhos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario BIGINT UNSIGNED NOT NULL UNIQUE,
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_carrinhos_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5. Itens do carrinho
CREATE TABLE itens_carrinho (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_carrinho BIGINT UNSIGNED NOT NULL,
    id_jogo BIGINT UNSIGNED NOT NULL,
    quantidade INT UNSIGNED NOT NULL DEFAULT 1,
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_carrinho_jogo
        UNIQUE (id_carrinho, id_jogo),

    CONSTRAINT fk_itens_carrinho_carrinho
        FOREIGN KEY (id_carrinho) REFERENCES carrinhos(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_itens_carrinho_jogo
        FOREIGN KEY (id_jogo) REFERENCES jogos(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_itens_carrinho_quantidade
        CHECK (quantidade >= 1)
) ENGINE=InnoDB;

-- 6. Pedidos
CREATE TABLE pedidos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario BIGINT UNSIGNED NOT NULL,
    valor_total DECIMAL(10, 2) NOT NULL,
    status_pedido ENUM('pendente', 'pago', 'cancelado')
        NOT NULL DEFAULT 'pendente',
    status_pagamento ENUM('pendente', 'aprovado', 'recusado')
        NOT NULL DEFAULT 'pendente',
    data_criacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_pedidos_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_pedidos_valor CHECK (valor_total >= 0),

    INDEX idx_pedidos_usuario_data (id_usuario, data_criacao)
) ENGINE=InnoDB;

-- 7. Itens dos pedidos
CREATE TABLE itens_pedido (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_pedido BIGINT UNSIGNED NOT NULL,
    id_jogo BIGINT UNSIGNED NULL,
    titulo_jogo VARCHAR(150) NOT NULL,
    quantidade INT UNSIGNED NOT NULL,
    preco_unitario DECIMAL(10, 2) NOT NULL,

    CONSTRAINT fk_itens_pedido_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedidos(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_itens_pedido_jogo
        FOREIGN KEY (id_jogo) REFERENCES jogos(id)
        ON DELETE SET NULL,

    CONSTRAINT chk_itens_pedido_quantidade
        CHECK (quantidade >= 1),

    CONSTRAINT chk_itens_pedido_preco
        CHECK (preco_unitario >= 0),

    INDEX idx_itens_pedido_jogo (id_jogo)
) ENGINE=InnoDB;

-- 8. Biblioteca de jogos dos usuarios
CREATE TABLE biblioteca_jogos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_usuario BIGINT UNSIGNED NOT NULL,
    id_jogo BIGINT UNSIGNED NOT NULL,
    id_item_pedido BIGINT UNSIGNED NOT NULL,
    data_aquisicao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_biblioteca_usuario_jogo
        UNIQUE (id_usuario, id_jogo),

    CONSTRAINT fk_biblioteca_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_biblioteca_jogo
        FOREIGN KEY (id_jogo) REFERENCES jogos(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_biblioteca_item_pedido
        FOREIGN KEY (id_item_pedido) REFERENCES itens_pedido(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;
