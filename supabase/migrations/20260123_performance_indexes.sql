-- ============================================
-- PERFORMANCE OPTIMIZATION: Strategic Indexes & Missing Tables
-- Created: 2026-01-23
-- Purpose: Improve query performance & ensure schema integrity
-- ============================================

-- 1. DIETS TABLE INDEXES
CREATE INDEX IF NOT EXISTS idx_diets_student_academy 
ON diets(student_id, id_academia);

CREATE INDEX IF NOT EXISTS idx_diets_nutritionist_academy 
ON diets(nutritionist_id, id_academia);

CREATE INDEX IF NOT EXISTS idx_diets_created_at 
ON diets(created_at DESC);

-- Composite index
CREATE INDEX IF NOT EXISTS idx_diets_academy_status 
ON diets(id_academia, status, created_at DESC);

-- 2. DIET_DAYS TABLE INDEXES
CREATE INDEX IF NOT EXISTS idx_diet_days_diet_number 
ON diet_days(diet_id, day_number);

-- 3. MEALS TABLE INDEXES
CREATE INDEX IF NOT EXISTS idx_meals_diet_day 
ON meals(diet_day_id);

CREATE INDEX IF NOT EXISTS idx_meals_diet_day_time 
ON meals(diet_day_id, meal_time);

-- 4. WORKOUTS TABLE INDEXES
CREATE INDEX IF NOT EXISTS idx_workouts_student_academy 
ON workouts(student_id, id_academia);

CREATE INDEX IF NOT EXISTS idx_workouts_personal_academy 
ON workouts(personal_id, id_academia);

CREATE INDEX IF NOT EXISTS idx_workouts_created_at 
ON workouts(created_at DESC);

-- Composite index
CREATE INDEX IF NOT EXISTS idx_workouts_academy_active 
ON workouts(id_academia, is_active, created_at DESC);

-- 5. WORKOUT_DAYS TABLE INDEXES
CREATE INDEX IF NOT EXISTS idx_workout_days_workout_number 
ON workout_days(workout_id, day_number);

-- 6. WORKOUT_EXERCISES TABLE INDEXES
CREATE INDEX IF NOT EXISTS idx_workout_exercises_day 
ON workout_exercises(day_id);

CREATE INDEX IF NOT EXISTS idx_workout_exercises_muscle 
ON workout_exercises(muscle_group);

-- 7. USERS TABLES INDEXES
CREATE INDEX IF NOT EXISTS idx_users_alunos_academy 
ON users_alunos(id_academia);

CREATE INDEX IF NOT EXISTS idx_users_alunos_email 
ON users_alunos(email);

CREATE INDEX IF NOT EXISTS idx_users_nutricionista_academy 
ON users_nutricionista(id_academia);

CREATE INDEX IF NOT EXISTS idx_users_personal_academy 
ON users_personal(id_academia);

-- 8. NOTIFICATIONS TABLE (Create if missing + Indexes)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL, -- Aluno que recebe
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    sender_name TEXT,
    type TEXT DEFAULT 'alert', -- 'alert', 'diet', 'workout'
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read 
ON notifications(user_id, is_read, created_at DESC);

-- 9. NOTICES TABLE (Create if missing + Indexes)
-- Tabela para avisos gerais do mural
CREATE TABLE IF NOT EXISTS notices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    id_academia UUID,
    title TEXT,
    content TEXT,
    created_by UUID, -- Quem criou (Nutri/Personal)
    target_audience TEXT DEFAULT 'all', -- 'all', 'students', 'staff'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notices_academy_created 
ON notices(id_academia, created_at DESC);

-- 10. STATISTICS
ANALYZE diets;
ANALYZE diet_days;
ANALYZE meals;
ANALYZE workouts;
ANALYZE workout_days;
ANALYZE workout_exercises;
ANALYZE users_alunos;
ANALYZE users_nutricionista;
ANALYZE users_personal;
ANALYZE notifications;
