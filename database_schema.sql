-- ============================================
-- SCHEMA DO BANCO DE DADOS - SPARTAN APP
-- ============================================

-- 1. TABELA DE USUÁRIOS
-- Armazena todos os tipos de usuários (Admin, Nutricionista, Personal, Aluno)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT NOT NULL,
  password_hash TEXT NOT NULL, -- Senha será hasheada pelo Supabase Auth
  role TEXT NOT NULL CHECK (role IN ('admin', 'nutritionist', 'trainer', 'student')),
  
  -- Campos específicos para Admin (dados do estabelecimento)
  cnpj TEXT, -- CNPJ do estabelecimento (apenas para admin)
  cpf TEXT, -- CPF do responsável (apenas para admin)
  address TEXT, -- Endereço do estabelecimento (apenas para admin)
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para melhorar performance de busca
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_name ON users(name);

-- ============================================
-- 2. TABELA DE DIETAS
-- Armazena as dietas criadas pelos nutricionistas para os alunos
CREATE TABLE diets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  nutritionist_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12), -- Mês da dieta (1-12)
  year INTEGER NOT NULL, -- Ano da dieta
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Garante que um aluno tenha apenas uma dieta por mês/ano de um nutricionista
  UNIQUE(student_id, nutritionist_id, month, year)
);

-- Índices para busca rápida
CREATE INDEX idx_diets_student ON diets(student_id);
CREATE INDEX idx_diets_nutritionist ON diets(nutritionist_id);
CREATE INDEX idx_diets_month_year ON diets(month, year);

-- ============================================
-- 3. TABELA DE DIAS DA DIETA
-- Cada dieta tem 30-31 dias, cada dia tem várias refeições
CREATE TABLE diet_days (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  diet_id UUID NOT NULL REFERENCES diets(id) ON DELETE CASCADE,
  day_number INTEGER NOT NULL CHECK (day_number BETWEEN 1 AND 31), -- Dia do mês (1-31)
  notes TEXT, -- Observações opcionais do dia
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Garante que cada dia apareça apenas uma vez por dieta
  UNIQUE(diet_id, day_number)
);

CREATE INDEX idx_diet_days_diet ON diet_days(diet_id);

-- ============================================
-- 4. TABELA DE REFEIÇÕES
-- Cada dia da dieta tem várias refeições (café, almoço, lanche, jantar, etc)
CREATE TABLE meals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  diet_day_id UUID NOT NULL REFERENCES diet_days(id) ON DELETE CASCADE,
  meal_time TIME NOT NULL, -- Horário da refeição (ex: 08:00, 12:00, 19:00)
  meal_name TEXT NOT NULL, -- Nome da refeição (ex: "Café da Manhã", "Almoço")
  description TEXT NOT NULL, -- Descrição detalhada da refeição
  calories INTEGER, -- Calorias opcionais
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_meals_diet_day ON meals(diet_day_id);
CREATE INDEX idx_meals_time ON meals(meal_time);

-- ============================================
-- 5. TABELA DE TREINOS
-- Armazena os treinos criados pelos personals para os alunos
CREATE TABLE workouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trainer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL, -- Título do treino (ex: "Treino Semanal - Janeiro")
  start_date DATE NOT NULL, -- Data de início do treino
  end_date DATE, -- Data de fim (opcional)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_workouts_student ON workouts(student_id);
CREATE INDEX idx_workouts_trainer ON workouts(trainer_id);
CREATE INDEX idx_workouts_dates ON workouts(start_date, end_date);

-- ============================================
-- 6. TABELA DE DIAS DE TREINO
-- Cada treino tem treinos específicos para cada dia da semana
CREATE TABLE workout_days (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Domingo, 1=Segunda, ..., 6=Sábado
  day_name TEXT NOT NULL, -- Nome do dia (ex: "Segunda-feira", "Terça-feira")
  notes TEXT, -- Observações do dia
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Garante que cada dia da semana apareça apenas uma vez por treino
  UNIQUE(workout_id, day_of_week)
);

CREATE INDEX idx_workout_days_workout ON workout_days(workout_id);

-- ============================================
-- 7. TABELA DE EXERCÍCIOS
-- Cada dia de treino tem vários exercícios com tempo definido
CREATE TABLE exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_day_id UUID NOT NULL REFERENCES workout_days(id) ON DELETE CASCADE,
  exercise_name TEXT NOT NULL, -- Nome do exercício (ex: "Supino Reto")
  duration_minutes INTEGER NOT NULL, -- Tempo em minutos
  sets INTEGER, -- Número de séries (opcional)
  reps TEXT, -- Repetições (ex: "12-15", "até a falha")
  weight_kg DECIMAL(5,2), -- Peso em kg (opcional)
  description TEXT, -- Descrição/observações do exercício
  order_index INTEGER NOT NULL DEFAULT 0, -- Ordem do exercício no treino
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_exercises_workout_day ON exercises(workout_day_id);
CREATE INDEX idx_exercises_order ON exercises(order_index);

-- ============================================
-- TRIGGERS PARA ATUALIZAR updated_at AUTOMATICAMENTE
-- ============================================

-- Função para atualizar o campo updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para users
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger para diets
CREATE TRIGGER update_diets_updated_at
    BEFORE UPDATE ON diets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger para workouts
CREATE TRIGGER update_workouts_updated_at
    BEFORE UPDATE ON workouts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- POLÍTICAS DE SEGURANÇA (RLS - Row Level Security)
-- ============================================

-- Habilita RLS em todas as tabelas
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE diets ENABLE ROW LEVEL SECURITY;
ALTER TABLE diet_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;

-- Política: Admin pode fazer tudo
CREATE POLICY "Admin full access" ON users
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'admin');

-- Política: Usuários podem ver seus próprios dados
CREATE POLICY "Users can view own data" ON users
    FOR SELECT
    USING (auth.uid() = id);

-- Política: Nutricionistas podem ver suas dietas
CREATE POLICY "Nutritionists can manage their diets" ON diets
    FOR ALL
    USING (nutritionist_id = auth.uid());

-- Política: Alunos podem ver suas dietas
CREATE POLICY "Students can view their diets" ON diets
    FOR SELECT
    USING (student_id = auth.uid());

-- Política: Personals podem ver seus treinos
CREATE POLICY "Trainers can manage their workouts" ON workouts
    FOR ALL
    USING (trainer_id = auth.uid());

-- Política: Alunos podem ver seus treinos
CREATE POLICY "Students can view their workouts" ON workouts
    FOR SELECT
    USING (student_id = auth.uid());

-- ============================================
-- DADOS INICIAIS (SEED)
-- ============================================

-- Inserir usuário administrador padrão
-- IMPORTANTE: Altere a senha após o primeiro login!
INSERT INTO users (name, email, phone, password_hash, role)
VALUES (
  'Administrador',
  'admin@spartan.com',
  '(00) 00000-0000',
  'senha_temporaria_123', -- ALTERAR DEPOIS!
  'admin'
);

-- ============================================
-- VIEWS ÚTEIS
-- ============================================

-- View: Listar todos os alunos com suas dietas ativas
CREATE VIEW students_with_diets AS
SELECT 
    u.id as student_id,
    u.name as student_name,
    u.email as student_email,
    d.id as diet_id,
    d.month,
    d.year,
    n.name as nutritionist_name
FROM users u
LEFT JOIN diets d ON u.id = d.student_id
LEFT JOIN users n ON d.nutritionist_id = n.id
WHERE u.role = 'student';

-- View: Listar todos os alunos com seus treinos ativos
CREATE VIEW students_with_workouts AS
SELECT 
    u.id as student_id,
    u.name as student_name,
    u.email as student_email,
    w.id as workout_id,
    w.title as workout_title,
    w.start_date,
    w.end_date,
    t.name as trainer_name
FROM users u
LEFT JOIN workouts w ON u.id = w.student_id
LEFT JOIN users t ON w.trainer_id = t.id
WHERE u.role = 'student';
