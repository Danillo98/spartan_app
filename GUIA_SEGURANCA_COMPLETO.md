# 🔒 GUIA COMPLETO DE SEGURANÇA - TODAS AS TABELAS

**Data:** 2026-01-17  
**Objetivo:** Implementar segurança completa em TODAS as tabelas  
**Abordagem:** Multi-tenancy por administrador + RLS em todas as tabelas

---

## 📋 VISÃO GERAL DAS TABELAS

Baseado nas imagens, você tem **13 tabelas**:

1. ✅ `users` - Usuários do sistema
2. ✅ `diets` - Dietas criadas
3. ✅ `diet_days` - Dias da dieta
4. ✅ `meals` - Refeições
5. ✅ `workouts` - Treinos criados
6. ✅ `workout_days` - Dias do treino
7. ✅ `exercises` - Exercícios
8. ✅ `students_with_diet` - Relação aluno-dieta
9. ✅ `students_with_workout` - Relação aluno-treino
10. ✅ `email_verification_codes` - Códigos de verificação
11. ✅ `login_attempts` - Tentativas de login
12. ✅ `audit_logs` - Logs de auditoria
13. ✅ `active_sessions` - Sessões ativas

---

## 🎯 ESTRATÉGIA DE SEGURANÇA

### **Princípio Base: Multi-Tenancy por Administrador**

Cada administrador tem sua própria "academia" isolada:

```
Admin A (Academia X)
  ├── Nutricionistas
  ├── Personal Trainers
  ├── Alunos
  ├── Dietas
  ├── Treinos
  └── Dados relacionados

Admin B (Academia Y)
  ├── Nutricionistas
  ├── Personal Trainers
  ├── Alunos
  ├── Dietas
  ├── Treinos
  └── Dados relacionados
```

**Regra de Ouro:** Nenhum dado de Admin A pode ser visto/editado por Admin B

---

## 📊 TABELA 1: `users`

### **Propósito:**
Armazena todos os usuários do sistema (admins, nutricionistas, trainers, alunos)

### **Campos Necessários:**
```sql
- id (UUID) - PK
- name (TEXT)
- email (TEXT)
- phone (TEXT)
- role (TEXT) - 'admin', 'nutritionist', 'trainer', 'student'
- created_by_admin_id (UUID) ← CAMPO CHAVE para multi-tenancy
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

### **Regras de Acesso:**

**Admin:**
- ✅ Vê: Apenas usuários que ele criou
- ✅ Cria: Nutricionistas, trainers, alunos (com seu ID)
- ✅ Edita: Apenas usuários que ele criou
- ✅ Exclui: Apenas usuários que ele criou

**Nutricionista:**
- ✅ Vê: Seus próprios dados + alunos da mesma academia
- ❌ Não cria usuários
- ✅ Edita: Apenas seus próprios dados
- ❌ Não exclui

**Trainer:**
- ✅ Vê: Seus próprios dados + alunos da mesma academia
- ❌ Não cria usuários
- ✅ Edita: Apenas seus próprios dados
- ❌ Não exclui

**Aluno:**
- ✅ Vê: Apenas seus próprios dados
- ❌ Não cria usuários
- ✅ Edita: Apenas seus próprios dados
- ❌ Não exclui

### **Políticas RLS:**

```sql
-- SELECT
CREATE POLICY "users_select_policy" ON users FOR SELECT USING (
  -- Admin vê usuários que criou
  (created_by_admin_id = auth.uid())
  OR
  -- Usuário vê seus próprios dados
  (id = auth.uid())
);

-- INSERT (apenas admins)
CREATE POLICY "users_insert_policy" ON users FOR INSERT WITH CHECK (
  -- Verifica se quem está inserindo é admin
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  AND
  -- Garante que created_by_admin_id é o admin atual
  (created_by_admin_id = auth.uid() OR role = 'admin')
);

-- UPDATE
CREATE POLICY "users_update_policy" ON users FOR UPDATE USING (
  -- Admin atualiza usuários que criou
  (created_by_admin_id = auth.uid())
  OR
  -- Usuário atualiza seus próprios dados
  (id = auth.uid())
);

-- DELETE (apenas admins)
CREATE POLICY "users_delete_policy" ON users FOR DELETE USING (
  -- Admin deleta usuários que criou (exceto ele mesmo)
  created_by_admin_id = auth.uid() AND id != auth.uid()
);
```

---

## 📊 TABELA 2: `diets`

### **Propósito:**
Armazena as dietas criadas pelos nutricionistas

### **Campos Necessários:**
```sql
- id (UUID) - PK
- name (TEXT)
- description (TEXT)
- nutritionist_id (UUID) - FK para users
- created_by_admin_id (UUID) ← CAMPO CHAVE
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

### **Regras de Acesso:**

**Admin:**
- ✅ Vê: Todas as dietas da sua academia
- ❌ Não cria dietas (apenas nutricionistas)
- ✅ Edita: Todas as dietas da sua academia
- ✅ Exclui: Todas as dietas da sua academia

**Nutricionista:**
- ✅ Vê: Apenas dietas que ele criou
- ✅ Cria: Dietas (automaticamente vinculadas ao admin)
- ✅ Edita: Apenas dietas que ele criou
- ✅ Exclui: Apenas dietas que ele criou

**Trainer:**
- ✅ Vê: Dietas dos alunos que ele treina
- ❌ Não cria/edita/exclui

**Aluno:**
- ✅ Vê: Apenas dietas atribuídas a ele
- ❌ Não cria/edita/exclui

### **Políticas RLS:**

```sql
-- SELECT
CREATE POLICY "diets_select_policy" ON diets FOR SELECT USING (
  -- Admin vê todas as dietas da sua academia
  created_by_admin_id = auth.uid()
  OR
  -- Nutricionista vê dietas que criou
  nutritionist_id = auth.uid()
  OR
  -- Aluno vê dietas atribuídas a ele
  id IN (
    SELECT diet_id FROM students_with_diet WHERE student_id = auth.uid()
  )
);

-- INSERT (apenas nutricionistas)
CREATE POLICY "diets_insert_policy" ON diets FOR INSERT WITH CHECK (
  -- Verifica se é nutricionista
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'nutritionist')
  AND
  -- Garante que nutritionist_id é o usuário atual
  nutritionist_id = auth.uid()
  AND
  -- Garante que created_by_admin_id é o admin que criou o nutricionista
  created_by_admin_id = (SELECT created_by_admin_id FROM users WHERE id = auth.uid())
);

-- UPDATE
CREATE POLICY "diets_update_policy" ON diets FOR UPDATE USING (
  -- Admin atualiza dietas da sua academia
  created_by_admin_id = auth.uid()
  OR
  -- Nutricionista atualiza suas próprias dietas
  nutritionist_id = auth.uid()
);

-- DELETE
CREATE POLICY "diets_delete_policy" ON diets FOR DELETE USING (
  -- Admin deleta dietas da sua academia
  created_by_admin_id = auth.uid()
  OR
  -- Nutricionista deleta suas próprias dietas
  nutritionist_id = auth.uid()
);
```

---

## 📊 TABELA 3: `diet_days`

### **Propósito:**
Armazena os dias de cada dieta

### **Campos Necessários:**
```sql
- id (UUID) - PK
- diet_id (UUID) - FK para diets
- day_name (TEXT) - 'Segunda', 'Terça', etc
- created_at (TIMESTAMP)
```

### **Regras de Acesso:**
Herda as permissões da dieta pai

### **Políticas RLS:**

```sql
-- SELECT
CREATE POLICY "diet_days_select_policy" ON diet_days FOR SELECT USING (
  -- Pode ver se pode ver a dieta pai
  diet_id IN (
    SELECT id FROM diets WHERE
      created_by_admin_id = auth.uid()
      OR nutritionist_id = auth.uid()
      OR id IN (SELECT diet_id FROM students_with_diet WHERE student_id = auth.uid())
  )
);

-- INSERT (apenas nutricionistas donos da dieta)
CREATE POLICY "diet_days_insert_policy" ON diet_days FOR INSERT WITH CHECK (
  diet_id IN (SELECT id FROM diets WHERE nutritionist_id = auth.uid())
);

-- UPDATE
CREATE POLICY "diet_days_update_policy" ON diet_days FOR UPDATE USING (
  diet_id IN (
    SELECT id FROM diets WHERE
      created_by_admin_id = auth.uid()
      OR nutritionist_id = auth.uid()
  )
);

-- DELETE
CREATE POLICY "diet_days_delete_policy" ON diet_days FOR DELETE USING (
  diet_id IN (
    SELECT id FROM diets WHERE
      created_by_admin_id = auth.uid()
      OR nutritionist_id = auth.uid()
  )
);
```

---

## 📊 TABELA 4: `meals`

### **Propósito:**
Armazena as refeições de cada dia da dieta

### **Campos Necessários:**
```sql
- id (UUID) - PK
- diet_day_id (UUID) - FK para diet_days
- meal_name (TEXT) - 'Café da manhã', 'Almoço', etc
- foods (TEXT) - Alimentos
- calories (INTEGER)
- created_at (TIMESTAMP)
```

### **Regras de Acesso:**
Herda as permissões do diet_day pai

### **Políticas RLS:**

```sql
-- SELECT
CREATE POLICY "meals_select_policy" ON meals FOR SELECT USING (
  diet_day_id IN (
    SELECT dd.id FROM diet_days dd
    JOIN diets d ON dd.diet_id = d.id
    WHERE d.created_by_admin_id = auth.uid()
       OR d.nutritionist_id = auth.uid()
       OR d.id IN (SELECT diet_id FROM students_with_diet WHERE student_id = auth.uid())
  )
);

-- INSERT
CREATE POLICY "meals_insert_policy" ON meals FOR INSERT WITH CHECK (
  diet_day_id IN (
    SELECT dd.id FROM diet_days dd
    JOIN diets d ON dd.diet_id = d.id
    WHERE d.nutritionist_id = auth.uid()
  )
);

-- UPDATE
CREATE POLICY "meals_update_policy" ON meals FOR UPDATE USING (
  diet_day_id IN (
    SELECT dd.id FROM diet_days dd
    JOIN diets d ON dd.diet_id = d.id
    WHERE d.created_by_admin_id = auth.uid()
       OR d.nutritionist_id = auth.uid()
  )
);

-- DELETE
CREATE POLICY "meals_delete_policy" ON meals FOR DELETE USING (
  diet_day_id IN (
    SELECT dd.id FROM diet_days dd
    JOIN diets d ON dd.diet_id = d.id
    WHERE d.created_by_admin_id = auth.uid()
       OR d.nutritionist_id = auth.uid()
  )
);
```

---

## 📊 TABELA 5: `workouts`

### **Propósito:**
Armazena os treinos criados pelos personal trainers

### **Campos Necessários:**
```sql
- id (UUID) - PK
- name (TEXT)
- description (TEXT)
- trainer_id (UUID) - FK para users
- created_by_admin_id (UUID) ← CAMPO CHAVE
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

### **Políticas RLS:**

```sql
-- SELECT
CREATE POLICY "workouts_select_policy" ON workouts FOR SELECT USING (
  created_by_admin_id = auth.uid()
  OR trainer_id = auth.uid()
  OR id IN (SELECT workout_id FROM students_with_workout WHERE student_id = auth.uid())
);

-- INSERT (apenas trainers)
CREATE POLICY "workouts_insert_policy" ON workouts FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'trainer')
  AND trainer_id = auth.uid()
  AND created_by_admin_id = (SELECT created_by_admin_id FROM users WHERE id = auth.uid())
);

-- UPDATE
CREATE POLICY "workouts_update_policy" ON workouts FOR UPDATE USING (
  created_by_admin_id = auth.uid()
  OR trainer_id = auth.uid()
);

-- DELETE
CREATE POLICY "workouts_delete_policy" ON workouts FOR DELETE USING (
  created_by_admin_id = auth.uid()
  OR trainer_id = auth.uid()
);
```

---

## 📊 TABELAS 6-7: `workout_days` e `exercises`

Seguem a mesma lógica de `diet_days` e `meals`, mas para treinos.

---

## 📊 TABELAS 8-9: `students_with_diet` e `students_with_workout`

### **Propósito:**
Relacionam alunos com suas dietas/treinos

### **Políticas RLS:**

```sql
-- Para students_with_diet:
CREATE POLICY "students_with_diet_select" ON students_with_diet FOR SELECT USING (
  -- Admin vê todas as atribuições da sua academia
  EXISTS (SELECT 1 FROM users WHERE id = student_id AND created_by_admin_id = auth.uid())
  OR
  -- Nutricionista vê atribuições de suas dietas
  diet_id IN (SELECT id FROM diets WHERE nutritionist_id = auth.uid())
  OR
  -- Aluno vê suas próprias atribuições
  student_id = auth.uid()
);

-- Similar para students_with_workout
```

---

## 📊 TABELAS 10-13: Tabelas de Segurança

### **`email_verification_codes`:**
- Sem RLS (gerenciada pelo sistema)

### **`login_attempts`:**
- Sem RLS (gerenciada pelo sistema)

### **`audit_logs`:**
- SELECT apenas para admins
- INSERT automático via trigger

### **`active_sessions`:**
- SELECT apenas para o próprio usuário
- INSERT/UPDATE/DELETE automático

---

## 🚀 PRÓXIMOS PASSOS

Vou criar um script SQL completo que:

1. ✅ Adiciona `created_by_admin_id` em TODAS as tabelas necessárias
2. ✅ Cria triggers para preencher automaticamente
3. ✅ Implementa RLS em TODAS as tabelas
4. ✅ Migra dados existentes
5. ✅ Testa as políticas

**Quer que eu crie este script agora?**
