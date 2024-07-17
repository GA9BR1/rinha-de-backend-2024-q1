CREATE USER app1 WITH PASSWORD 'postgres';
CREATE USER app2 WITH PASSWORD 'postgres';

ALTER USER app1 WITH SUPERUSER;
ALTER USER app2 WITH SUPERUSER;

CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    account_limit INTEGER NOT NULL,
    balance INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL REFERENCES clients(id),
    amount INTEGER NOT NULL,
    operation CHAR(1) NOT NULL,
    description VARCHAR(10) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO clients (account_limit, balance) VALUES
    (100000, 0),
    (80000, 0),
    (1000000, 0),
    (10000000, 0),
    (500000, 0);

CREATE OR REPLACE FUNCTION credit_amount(client_id INTEGER, credit_amount INTEGER, description VARCHAR(10))
RETURNS TABLE(success BOOLEAN, new_balance INTEGER, account_limit INTEGER) AS $$
DECLARE
    new_balance INTEGER;
BEGIN
    UPDATE clients
    SET balance = balance + credit_amount
    WHERE clients.id = client_id
    RETURNING balance, clients.account_limit INTO new_balance, account_limit;

    INSERT INTO transactions (client_id, amount, operation, description)
    VALUES (client_id, credit_amount, 'c', description);

    RETURN QUERY SELECT true, new_balance, account_limit;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION debit_amount(client_id INTEGER, debit_amount INTEGER, description VARCHAR(10))
RETURNS TABLE(success BOOLEAN, new_balance INTEGER, account_limit INTEGER) AS $$
DECLARE
    current_balance INTEGER;
BEGIN
    SELECT clients.balance, clients.account_limit INTO current_balance, account_limit
    FROM clients
    WHERE clients.id = client_id
    FOR UPDATE;

    IF current_balance - debit_amount < -account_limit THEN
        RETURN QUERY SELECT false, current_balance, account_limit;
    ELSE
        UPDATE clients
        SET balance = balance - debit_amount
        WHERE clients.id = client_id
        RETURNING balance INTO new_balance;

        INSERT INTO transactions (client_id, amount, operation, description)
        VALUES (client_id, debit_amount, 'd', description);

        RETURN QUERY SELECT true, new_balance, account_limit;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION client_extract(p_client_id INTEGER)
RETURNS JSONB AS $$
DECLARE
    statement JSONB;
BEGIN
    WITH saldo AS (
        SELECT
            balance AS total,
            account_limit AS limite,
            current_timestamp AT TIME ZONE 'UTC' AS data_extrato
        FROM clients
        WHERE clients.id = p_client_id
    ),
    ultimas_transacoes AS (
        SELECT
            amount,
            operation,
            description,
            created_at AT TIME ZONE 'UTC' AS realizado_em
        FROM transactions
        WHERE p_client_id = transactions.client_id
        ORDER BY created_at DESC
        LIMIT 10
    )
    SELECT
        jsonb_build_object(
            'saldo', jsonb_build_object(
                'total', (SELECT total FROM saldo),
                'data_extrato', to_char((SELECT data_extrato FROM saldo), 'YYYY-MM-DD"T"HH24:MI:SS.USZ'),
                'limite', (SELECT limite FROM saldo)
            ),
            'ultimas_transacoes', jsonb_agg(jsonb_build_object(
                'valor', amount,
                'tipo', operation,
                'descricao', description,
                'realizada_em', to_char(realizado_em, 'YYYY-MM-DD"T"HH24:MI:SS.USZ')
            ))
        ) INTO statement
    FROM ultimas_transacoes;

    RETURN statement;
END;
$$ LANGUAGE plpgsql;
