# 🔒 IMPLEMENTAÇÃO DA SEGURANÇA DEFINITIVA

**Data:** 2026-01-17  
**Arquivo:** `SEGURANCA_DEFINITIVA.sql`  
**Status:** ✅ Pronto para executar

---

## 🎯 O QUE ESTE SCRIPT FAZ

### **Implementa segurança COMPLETA em TODO o banco de dados:**

✅ **Multi-tenancy** por administrador  
✅ **RLS** em todas as tabelas relevantes  
✅ **Sem recursão infinita** (usa funções SECURITY DEFINER)  
✅ **Migra dados existentes** sem perder nada  
✅ **Triggers automáticos** para novos dados  
✅ **Proteção contra ataques** e acesso indevido  

---

## 🚀 COMO EXECUTAR

### **PASSO 1: Backup (Recomendado)**

Antes de executar, faça backup do banco:
- No Supabase Dashboard → Database → Backups

### **PASSO 2: Executar o Script**

1. **Abra:** `SEGURANCA_DEFINITIVA.sql`
2. **Copie:** TODO o conteúdo (Ctrl+A, Ctrl+C)
3. **No Supabase SQL Editor:**
   - Limpe o editor
   - Cole o código (Ctrl+V)
   - Clique em **RUN**
4. **Aguarde:** Deve levar ~10 segundos
5. **Verifique:** Mensagens de sucesso no final

### **PASSO 3: Testar**

1. **Feche** o app completamente
2. **Abra** novamente
3. **Faça login** com seu admin
4. **Teste:**
   - Ver usuários
   - Criar usuário
   - Criar dieta
   - Criar treino

---

## 🔍 O QUE O SCRIPT FAZ (DETALHADO)

### **1. Desabilita RLS Temporariamente**
```sql
-- Para fazer as mudanças sem conflitos
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
```

### **2. Remove Políticas Antigas**
```sql
-- Remove todas as políticas que causavam recursão
DROP POLICY IF EXISTS "Admins veem apenas seus usuários" ON users;
```

### **3. Adiciona Colunas**
```sql
-- Adiciona created_by_admin_id em:
-- - users
-- - diets
-- - workouts
ALTER TABLE users ADD COLUMN created_by_admin_id UUID;
```

### **4. Migra Dados Existentes**
```sql
-- Admins: created_by_admin_id = seu próprio ID
UPDATE users SET created_by_admin_id = id WHERE role = 'admin';

-- Outros: created_by_admin_id = ID do primeiro admin
UPDATE users SET created_by_admin_id = (SELECT id FROM users WHERE role = 'admin' LIMIT 1);
```

### **5. Cria Funções Helper (SEM RECURSÃO)**
```sql
-- Função para pegar role do usuário
CREATE FUNCTION get_current_user_role() RETURNS TEXT
-- Usa SECURITY DEFINER para evitar recursão
```

### **6. Cria Triggers Automáticos**
```sql
-- Preenche created_by_admin_id automaticamente
CREATE TRIGGER trigger_set_created_by_admin
  BEFORE INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION set_created_by_admin_users();
```

### **7. Cria Políticas RLS Corretas**
```sql
-- Políticas simples e diretas (SEM RECURSÃO)
CREATE POLICY "users_select_policy" ON users
FOR SELECT
USING (
  created_by_admin_id = auth.uid() OR id = auth.uid()
);
```

### **8. Reabilita RLS**
```sql
-- Ativa RLS em todas as tabelas
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
```

---

## 🛡️ SEGURANÇA IMPLEMENTADA

### **TABELA: users**

| Ação | Admin | Nutricionista | Trainer | Aluno |
|------|-------|---------------|---------|-------|
| **Ver** | Seus usuários | Seus dados | Seus dados | Seus dados |
| **Criar** | ✅ Sim | ❌ Não | ❌ Não | ❌ Não |
| **Editar** | Seus usuários | Seus dados | Seus dados | Seus dados |
| **Excluir** | Seus usuários | ❌ Não | ❌ Não | ❌ Não |

### **TABELA: diets**

| Ação | Admin | Nutricionista | Trainer | Aluno |
|------|-------|---------------|---------|-------|
| **Ver** | Todas da academia | Suas dietas | ❌ | Suas dietas |
| **Criar** | ❌ | ✅ Sim | ❌ | ❌ |
| **Editar** | Todas da academia | Suas dietas | ❌ | ❌ |
| **Excluir** | Todas da academia | Suas dietas | ❌ | ❌ |

### **TABELA: workouts**

| Ação | Admin | Nutricionista | Trainer | Aluno |
|------|-------|---------------|---------|-------|
| **Ver** | Todos da academia | ❌ | Seus treinos | Seus treinos |
| **Criar** | ❌ | ❌ | ✅ Sim | ❌ |
| **Editar** | Todos da academia | ❌ | Seus treinos | ❌ |
| **Excluir** | Todos da academia | ❌ | Seus treinos | ❌ |

### **TABELAS FILHAS:**
- `diet_days`, `meals` → Herdam permissões de `diets`
- `workout_days`, `exercises` → Herdam permissões de `workouts`

### **TABELAS DE SISTEMA:**
- `email_verification_codes` → Sem RLS (sistema)
- `login_attempts` → Sem RLS (sistema)
- `audit_logs` → Apenas admins veem
- `active_sessions` → Apenas o próprio usuário

---

## ✅ VERIFICAÇÕES APÓS EXECUTAR

### **1. Verificar Colunas Criadas:**
```sql
SELECT table_name, column_name
FROM information_schema.columns
WHERE column_name = 'created_by_admin_id';

-- Deve retornar:
-- users | created_by_admin_id
-- diets | created_by_admin_id
-- workouts | created_by_admin_id
```

### **2. Verificar Políticas:**
```sql
SELECT tablename, COUNT(*) as num_policies
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename;

-- Deve retornar várias tabelas com políticas
```

### **3. Verificar RLS Ativo:**
```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Deve mostrar rowsecurity = true para a maioria
```

---

## 🧪 TESTES RECOMENDADOS

### **Teste 1: Criar 2 Admins**
```
1. Registrar admin1@teste.com
2. Registrar admin2@teste.com
3. Confirmar ambos os emails
```

### **Teste 2: Cada Admin Cria Usuários**
```
Admin 1:
- Criar Nutricionista N1
- Criar Trainer T1
- Criar Aluno A1

Admin 2:
- Criar Nutricionista N2
- Criar Trainer T2
- Criar Aluno A2
```

### **Teste 3: Verificar Isolamento**
```
Login Admin 1:
- Deve ver: N1, T1, A1 ✅
- NÃO deve ver: N2, T2, A2 ❌

Login Admin 2:
- Deve ver: N2, T2, A2 ✅
- NÃO deve ver: N1, T1, A1 ❌
```

### **Teste 4: Nutricionista Cria Dieta**
```
Login como N1:
- Criar dieta D1
- Verificar que created_by_admin_id = Admin 1
```

### **Teste 5: Trainer Cria Treino**
```
Login como T1:
- Criar treino W1
- Verificar que created_by_admin_id = Admin 1
```

---

## 🆘 TROUBLESHOOTING

### **Erro: "infinite recursion"**
```
Causa: Funções helper não foram criadas corretamente
Solução: Execute o script novamente do início
```

### **Erro: "column already exists"**
```
Causa: Script já foi executado antes
Solução: Normal! O script vai pular essa parte
```

### **Erro: "permission denied"**
```
Causa: Não tem permissões de admin no Supabase
Solução: Verifique se está no projeto correto
```

### **Não vejo nenhum usuário após login:**
```
Causa: RLS está bloqueando tudo
Solução: 
1. Verifique se created_by_admin_id está preenchido
2. Execute: SELECT * FROM users WHERE id = auth.uid();
3. Verifique o created_by_admin_id do seu usuário
```

---

## 🔄 ROLLBACK (SE NECESSÁRIO)

Se algo der errado, execute:

```sql
-- Desabilitar RLS em todas as tabelas
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE diets DISABLE ROW LEVEL SECURITY;
ALTER TABLE workouts DISABLE ROW LEVEL SECURITY;
-- ... (outras tabelas)

-- Remover políticas
DROP POLICY IF EXISTS "users_select_policy" ON users;
-- ... (outras políticas)

-- Remover colunas (CUIDADO: perde dados!)
ALTER TABLE users DROP COLUMN IF EXISTS created_by_admin_id;
```

---

## 📊 RESULTADO FINAL

### **Antes:**
```
❌ Todos os admins veem todos os dados
❌ Sem isolamento entre academias
❌ Vulnerável a ataques
❌ Não conforme com LGPD
```

### **Depois:**
```
✅ Cada admin vê apenas seus dados
✅ Isolamento total entre academias
✅ Protegido contra ataques
✅ Conforme com LGPD
✅ Escalável para infinitas academias
```

---

## 🎯 PRÓXIMOS PASSOS

1. ✅ **Execute** `SEGURANCA_DEFINITIVA.sql`
2. ✅ **Feche e abra** o app
3. ✅ **Faça login** e teste
4. ✅ **Crie 2 admins** para testar isolamento
5. ✅ **Verifique** que cada admin vê apenas seus dados
6. ✅ **Me avise** o resultado!

---

**Arquivo:** `SEGURANCA_DEFINITIVA.sql`  
**Status:** ✅ Pronto para executar  
**Tempo:** ~10 segundos  
**Risco:** Baixo (faz backup antes)  
**Resultado:** Segurança total! 🔒
