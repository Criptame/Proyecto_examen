CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    done BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO tasks (title, done)
VALUES
    ('Configurar pipeline CI/CD', TRUE),
    ('Desplegar en ECS Fargate', FALSE),
    ('Grabar video de defensa', FALSE)
ON CONFLICT DO NOTHING;
