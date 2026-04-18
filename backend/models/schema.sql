CREATE TABLE IF NOT EXISTS usuarios (
  id SERIAL PRIMARY KEY,
  nome TEXT NOT NULL,
  tipo VARCHAR(30) NOT NULL CHECK (tipo IN ('Usuario', 'Agente de Viagem')),
  email TEXT NOT NULL UNIQUE,
  senha TEXT NOT NULL,
  status VARCHAR(20) NOT NULL CHECK (status IN ('Ativa', 'Cancelada', 'Finalizada')) DEFAULT 'Ativa',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS agente_clientes (
  agente_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  cliente_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  PRIMARY KEY (agente_id, cliente_id)
);

CREATE TABLE IF NOT EXISTS viagens (
  id SERIAL PRIMARY KEY,
  descricao TEXT NOT NULL,
  data_inicial DATE NOT NULL,
  data_final DATE NOT NULL,
  situacao VARCHAR(20) NOT NULL CHECK (situacao IN ('Ativa', 'Cancelada', 'Finalizada')),
  user_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS viagem_membros (
  id SERIAL PRIMARY KEY,
  viagem_id INTEGER NOT NULL REFERENCES viagens(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
  status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'accepted', 'declined')) DEFAULT 'accepted',
  invited_by INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE (viagem_id, user_id)
);

CREATE TABLE IF NOT EXISTS convites_viagem (
  id SERIAL PRIMARY KEY,
  viagem_id INTEGER NOT NULL REFERENCES viagens(id) ON DELETE CASCADE,
  invited_email TEXT NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('editor', 'viewer')),
  token TEXT NOT NULL UNIQUE,
  status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'accepted', 'expired', 'cancelled')) DEFAULT 'pending',
  invited_by INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cidades (
  id SERIAL PRIMARY KEY,
  descricao TEXT NOT NULL,
  latitude DECIMAL(10, 7),
  longitude DECIMAL(10, 7),
  viagem_id INTEGER NOT NULL REFERENCES viagens(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS hoteis (
  id SERIAL PRIMARY KEY,
  nome TEXT NOT NULL,
  data_checkin DATE,
  data_checkout DATE,
  endereco TEXT,
  status_reserva VARCHAR(10) NOT NULL CHECK (status_reserva IN ('A Pagar', 'Pago')),
  hora_checkin TIME,
  hora_checkout TIME,
  cancelamento_gratuito BOOLEAN,
  latitude DECIMAL(10, 7),
  longitude DECIMAL(10, 7),
  observacoes TEXT,
  cidade_id INTEGER NOT NULL REFERENCES cidades(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS restaurantes (
  id SERIAL PRIMARY KEY,
  nome TEXT NOT NULL,
  tipo_comida TEXT,
  valor_medio DECIMAL(10, 2),
  moeda VARCHAR(10),
  endereco TEXT,
  reservado BOOLEAN,
  data_reserva DATE,
  hora_reserva TIME,
  latitude DECIMAL(10, 7),
  longitude DECIMAL(10, 7),
  observacoes TEXT,
  cidade_id INTEGER NOT NULL REFERENCES cidades(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS passeios (
  id SERIAL PRIMARY KEY,
  nome TEXT NOT NULL,
  tipo_passeio TEXT,
  valor DECIMAL(10, 2),
  moeda VARCHAR(10),
  situacao VARCHAR(20) NOT NULL CHECK (situacao IN ('A Pagar', 'Pago Parcial', 'Pago', 'Gratuito')),
  endereco TEXT,
  reservado BOOLEAN,
  data_reserva DATE,
  hora_reserva TIME,
  latitude DECIMAL(10, 7),
  longitude DECIMAL(10, 7),
  permissao_cancelamento BOOLEAN,
  observacoes TEXT,
  cidade_id INTEGER NOT NULL REFERENCES cidades(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS roteiro_blocos (
  id SERIAL PRIMARY KEY,
  viagem_id INTEGER NOT NULL REFERENCES viagens(id) ON DELETE CASCADE,
  titulo TEXT NOT NULL,
  tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('Evento Fixo', 'Tempo Livre')),
  data DATE NOT NULL,
  hora_inicio TIME,
  hora_fim TIME,
  local TEXT,
  link_url TEXT,
  descricao TEXT,
  created_by INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE roteiro_blocos
ADD COLUMN IF NOT EXISTS link_url TEXT;

CREATE INDEX IF NOT EXISTS idx_viagens_user_id ON viagens(user_id);
CREATE INDEX IF NOT EXISTS idx_viagem_membros_viagem_id ON viagem_membros(viagem_id);
CREATE INDEX IF NOT EXISTS idx_viagem_membros_user_id ON viagem_membros(user_id);
CREATE INDEX IF NOT EXISTS idx_convites_viagem_token ON convites_viagem(token);
CREATE INDEX IF NOT EXISTS idx_cidades_viagem_id ON cidades(viagem_id);
CREATE INDEX IF NOT EXISTS idx_hoteis_cidade_id ON hoteis(cidade_id);
CREATE INDEX IF NOT EXISTS idx_restaurantes_cidade_id ON restaurantes(cidade_id);
CREATE INDEX IF NOT EXISTS idx_passeios_cidade_id ON passeios(cidade_id);
CREATE INDEX IF NOT EXISTS idx_roteiro_blocos_viagem_id ON roteiro_blocos(viagem_id);
CREATE INDEX IF NOT EXISTS idx_roteiro_blocos_data ON roteiro_blocos(data);

CREATE TABLE IF NOT EXISTS wishlist_itens (
  id SERIAL PRIMARY KEY,
  viagem_id INTEGER NOT NULL REFERENCES viagens(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  categoria VARCHAR(20) NOT NULL CHECK (categoria IN ('Comer', 'Visitar', 'Comprar', 'Outras')),
  nome TEXT NOT NULL,
  endereco TEXT,
  latitude DECIMAL(10, 7),
  longitude DECIMAL(10, 7),
  fonte TEXT,
  nota TEXT,
  link_url TEXT,
  rating DECIMAL(3, 2),
  foto_url TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'nao_visitado' CHECK (status IN ('nao_visitado', 'planejado', 'concluido', 'descartado')),
  created_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE wishlist_itens
ADD COLUMN IF NOT EXISTS link_url TEXT;

CREATE INDEX IF NOT EXISTS idx_wishlist_viagem_id ON wishlist_itens(viagem_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_categoria ON wishlist_itens(categoria);
CREATE INDEX IF NOT EXISTS idx_wishlist_status ON wishlist_itens(status);

CREATE TABLE IF NOT EXISTS travel_preferences (
  id SERIAL PRIMARY KEY,
  viagem_id INTEGER NOT NULL UNIQUE REFERENCES viagens(id) ON DELETE CASCADE,
  user_id INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
  prefer_categorias TEXT,
  dietary TEXT,
  budget_level VARCHAR(30),
  pace VARCHAR(30),
  touristic_level VARCHAR(30),
  mobility_pref VARCHAR(30),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_travel_prefs_viagem ON travel_preferences(viagem_id);

CREATE TABLE IF NOT EXISTS viagem_meios_transporte (
  id SERIAL PRIMARY KEY,
  viagem_id INTEGER NOT NULL REFERENCES viagens(id) ON DELETE CASCADE,
  tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('voo', 'carro', 'trem')),
  companhia TEXT,
  codigo_localizador TEXT,
  ponto_a TEXT,
  ponto_b TEXT,
  data_a DATE,
  hora_a TIME,
  data_b DATE,
  hora_b TIME,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS viagem_meio_transporte_assentos (
  id SERIAL PRIMARY KEY,
  meio_transporte_id INTEGER NOT NULL REFERENCES viagem_meios_transporte(id) ON DELETE CASCADE,
  numero_assento TEXT NOT NULL,
  nome_passageiro TEXT NOT NULL,
  classe VARCHAR(30) NOT NULL CHECK (classe IN ('economica', 'economica_premium', 'executiva', 'primeira'))
);

CREATE INDEX IF NOT EXISTS idx_viagem_meios_transporte_viagem ON viagem_meios_transporte(viagem_id);
CREATE INDEX IF NOT EXISTS idx_viagem_meio_assentos_meio ON viagem_meio_transporte_assentos(meio_transporte_id);

-- Migração: bases criadas antes (TIMESTAMPTZ + sem companhia)
ALTER TABLE viagem_meios_transporte ADD COLUMN IF NOT EXISTS companhia TEXT;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'viagem_meios_transporte'
      AND column_name = 'horario_a' AND udt_name = 'timestamptz'
  ) THEN
    ALTER TABLE viagem_meios_transporte
      ALTER COLUMN horario_a TYPE TEXT USING (
        CASE WHEN horario_a IS NULL THEN NULL
        ELSE to_char(horario_a, 'DD/MM/YYYY HH24:MI') END
      );
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'viagem_meios_transporte'
      AND column_name = 'horario_b' AND udt_name = 'timestamptz'
  ) THEN
    ALTER TABLE viagem_meios_transporte
      ALTER COLUMN horario_b TYPE TEXT USING (
        CASE WHEN horario_b IS NULL THEN NULL
        ELSE to_char(horario_b, 'DD/MM/YYYY HH24:MI') END
      );
  END IF;
END $$;

-- Migração: horario_a / horario_b (TEXT) → data_a, hora_a, data_b, hora_b
ALTER TABLE viagem_meios_transporte ADD COLUMN IF NOT EXISTS data_a DATE;
ALTER TABLE viagem_meios_transporte ADD COLUMN IF NOT EXISTS hora_a TIME;
ALTER TABLE viagem_meios_transporte ADD COLUMN IF NOT EXISTS data_b DATE;
ALTER TABLE viagem_meios_transporte ADD COLUMN IF NOT EXISTS hora_b TIME;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'viagem_meios_transporte'
      AND column_name = 'horario_a'
  ) THEN
    UPDATE viagem_meios_transporte SET
      data_a = CASE
        WHEN horario_a IS NULL OR trim(horario_a::text) = '' THEN NULL
        WHEN horario_a::text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN left(horario_a::text, 10)::date
        WHEN horario_a::text ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}' THEN to_date(substring(horario_a::text from '^([0-9]{2}/[0-9]{2}/[0-9]{4})'), 'DD/MM/YYYY')
        ELSE NULL
      END,
      hora_a = CASE
        WHEN horario_a IS NULL OR trim(horario_a::text) = '' THEN NULL
        WHEN horario_a::text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T]' THEN (horario_a::text::timestamptz)::time
        WHEN horario_a::text ~ '[0-2][0-9]:[0-5][0-9]' THEN (substring(horario_a::text from '([0-2][0-9]:[0-5][0-9])'))::time
        ELSE NULL
      END
    WHERE data_a IS NULL OR hora_a IS NULL;

    UPDATE viagem_meios_transporte SET
      data_b = CASE
        WHEN horario_b IS NULL OR trim(horario_b::text) = '' THEN NULL
        WHEN horario_b::text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN left(horario_b::text, 10)::date
        WHEN horario_b::text ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}' THEN to_date(substring(horario_b::text from '^([0-9]{2}/[0-9]{2}/[0-9]{4})'), 'DD/MM/YYYY')
        ELSE NULL
      END,
      hora_b = CASE
        WHEN horario_b IS NULL OR trim(horario_b::text) = '' THEN NULL
        WHEN horario_b::text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T]' THEN (horario_b::text::timestamptz)::time
        WHEN horario_b::text ~ '[0-2][0-9]:[0-5][0-9]' THEN (substring(horario_b::text from '([0-2][0-9]:[0-5][0-9])'))::time
        ELSE NULL
      END
    WHERE data_b IS NULL OR hora_b IS NULL;

    ALTER TABLE viagem_meios_transporte DROP COLUMN horario_a;
    ALTER TABLE viagem_meios_transporte DROP COLUMN horario_b;
  END IF;
END $$;
