# 🔒 IMPLEMENTAÇÃO DE MULTI-TENANCY

**Data:** 2026-01-17  
**Prioridade:** 🔴 CRÍTICA - Segurança e Privacidade de Dados

---

## 📋 Problema Identificado

Atualmente, **todos os administradores têm acesso a TODOS os usuários** do banco de dados, independentemente de quem os criou. Isso significa que:

- ❌ Admin da Academia A vê usuários da Academia B
- ❌ Admin da Academia A pode editar/excluir usuários da Academia B
- ❌ Violação grave de privacidade (LGPD)
- ❌ Risco de perda de dados entre academias

---

## ✅ Solução: Sistema Multi-Tenancy

Cada administrador deve gerenciar **APENAS** os usuários que ele mesmo criou:

- ✅ Admin só vê seus próprios nutricionistas, personals e alunos
- ✅ Isolamento completo de dados entre academias
- ✅ Conformidade com LGPD
- ✅ Segurança de dados garantida

---

## 🏗️ Arquitetura da Solução

### **1. Modificação na Tabela `users`**

Adicionar campo `created_by_admin_id` para rastrear qual admin criou cada usuário:

```sql
-- Adicionar coluna para rastrear o administrador que criou o usuário
ALTER TABLE public.users 
ADD COLUMN created_by_admin_id UUID REFERENCES auth.users(id);

-- Criar índice para melhorar performance
CREATE INDEX idx_users_created_by_admin ON public.users(created_by_admin_id);

-- Atualizar usuários existentes (IMPORTANTE: executar antes de ativar RLS)
-- Opção 1: Atribuir todos os usuários existentes ao primeiro admin
UPDATE public.users 
SET created_by_admin_id = (
  SELECT id FROM public.users WHERE role = 'admin' LIMIT 1
)
WHERE created_by_admin_id IS NULL;

-- Opção 2: Criar um admin "sistema" para usuários órfãos
-- (Recomendado para produção)
```

### **2. Row Level Security (RLS) - Políticas de Segurança**

```sql
-- Habilitar RLS na tabela users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Política 1: Admins só veem usuários que criaram
CREATE POLICY "Admins veem apenas seus usuários"
ON public.users
FOR SELECT
USING (
  -- Se for admin, só vê usuários que ele criou
  (auth.jwt() ->> 'role' = 'admin' AND created_by_admin_id = auth.uid())
  OR
  -- Se for o próprio usuário, pode ver seus dados
  (id = auth.uid())
  OR
  -- Nutricionistas veem seus alunos (via diet_plans)
  (auth.jwt() ->> 'role' = 'nutritionist' AND id IN (
    SELECT student_id FROM diet_plans WHERE nutritionist_id = auth.uid()
  ))
  OR
  -- Trainers veem seus alunos (via workout_plans)
  (auth.jwt() ->> 'role' = 'trainer' AND id IN (
    SELECT student_id FROM workout_plans WHERE trainer_id = auth.uid()
  ))
);

-- Política 2: Admins só podem inserir usuários com seu ID
CREATE POLICY "Admins criam usuários com seu ID"
ON public.users
FOR INSERT
WITH CHECK (
  auth.jwt() ->> 'role' = 'admin' 
  AND created_by_admin_id = auth.uid()
);

-- Política 3: Admins só podem atualizar seus usuários
CREATE POLICY "Admins atualizam apenas seus usuários"
ON public.users
FOR UPDATE
USING (
  (auth.jwt() ->> 'role' = 'admin' AND created_by_admin_id = auth.uid())
  OR
  (id = auth.uid()) -- Usuário pode atualizar seus próprios dados
);

-- Política 4: Admins só podem deletar seus usuários
CREATE POLICY "Admins deletam apenas seus usuários"
ON public.users
FOR DELETE
USING (
  auth.jwt() ->> 'role' = 'admin' AND created_by_admin_id = auth.uid()
);
```

### **3. Trigger para Auto-preencher `created_by_admin_id`**

```sql
-- Função para auto-preencher created_by_admin_id
CREATE OR REPLACE FUNCTION set_created_by_admin()
RETURNS TRIGGER AS $$
BEGIN
  -- Se o usuário sendo criado não for admin, preenche com o ID do admin atual
  IF NEW.role != 'admin' THEN
    NEW.created_by_admin_id := auth.uid();
  END IF;
  
  -- Se o usuário sendo criado FOR admin, ele é seu próprio "criador"
  IF NEW.role = 'admin' THEN
    NEW.created_by_admin_id := NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Criar trigger
DROP TRIGGER IF EXISTS trigger_set_created_by_admin ON public.users;
CREATE TRIGGER trigger_set_created_by_admin
  BEFORE INSERT ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION set_created_by_admin();
```

---

## 🔧 Modificações no Código Flutter

### **Arquivos que serão modificados:**

1. ✅ `lib/services/user_service.dart` - Adicionar filtro por admin
2. ✅ `lib/services/auth_service.dart` - Registrar created_by_admin_id
3. ✅ `lib/screens/admin/admin_dashboard.dart` - Já está correto (usa UserService)

---

## 📝 Passos de Implementação

### **Passo 1: Executar SQL no Supabase**

1. Acesse o Supabase Dashboard
2. Vá em **SQL Editor**
3. Execute os scripts SQL acima **NA ORDEM**:
   - Primeiro: ALTER TABLE (adicionar coluna)
   - Segundo: UPDATE (atualizar usuários existentes)
   - Terceiro: Políticas RLS
   - Quarto: Trigger

### **Passo 2: Atualizar Código Flutter**

Os arquivos serão atualizados automaticamente pelo assistente.

### **Passo 3: Testar**

1. Criar dois admins diferentes
2. Cada admin criar seus próprios usuários
3. Verificar que Admin A não vê usuários do Admin B

---

## 🧪 Casos de Teste

### **Teste 1: Isolamento de Dados**
```
1. Login como Admin A
2. Criar Nutricionista N1
3. Logout
4. Login como Admin B
5. Verificar que N1 NÃO aparece na lista
```

### **Teste 2: Criação de Usuários**
```
1. Login como Admin A
2. Criar Personal P1
3. Verificar que P1 tem created_by_admin_id = Admin A
```

### **Teste 3: Edição/Exclusão**
```
1. Login como Admin A
2. Tentar editar usuário do Admin B (deve falhar)
3. Tentar excluir usuário do Admin B (deve falhar)
```

---

## ⚠️ Considerações Importantes

### **Migração de Dados Existentes**

Se já existem usuários no banco:

**Opção A - Atribuir ao Primeiro Admin:**
```sql
UPDATE public.users 
SET created_by_admin_id = (SELECT id FROM public.users WHERE role = 'admin' LIMIT 1)
WHERE created_by_admin_id IS NULL;
```

**Opção B - Criar Admin "Sistema":**
```sql
-- Criar um admin especial para usuários órfãos
INSERT INTO auth.users (id, email) VALUES 
  ('00000000-0000-0000-0000-000000000000', 'sistema@academia.com');

UPDATE public.users 
SET created_by_admin_id = '00000000-0000-0000-0000-000000000000'
WHERE created_by_admin_id IS NULL;
```

### **Administradores Existentes**

Admins que já existem devem ter `created_by_admin_id = seu próprio ID`:

```sql
UPDATE public.users 
SET created_by_admin_id = id 
WHERE role = 'admin' AND created_by_admin_id IS NULL;
```

---

## 🔐 Segurança Adicional

### **Validação no Backend**

As políticas RLS garantem que:
- ✅ Mesmo que o app Flutter tenha bugs, o banco protege os dados
- ✅ Impossível burlar via API direta
- ✅ Auditoria automática de quem criou cada usuário

### **Logs de Auditoria**

Considere adicionar:
```sql
CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  action TEXT,
  table_name TEXT,
  record_id UUID,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 📊 Impacto da Mudança

### **Antes:**
- ❌ 1 banco compartilhado
- ❌ Todos os admins veem tudo
- ❌ Risco de conflito de dados

### **Depois:**
- ✅ Multi-tenancy implementado
- ✅ Cada admin vê apenas seus dados
- ✅ Conformidade com LGPD
- ✅ Escalável para múltiplas academias

---

## 🚀 Próximos Passos

Após implementação:

1. **Testar exaustivamente** com múltiplos admins
2. **Documentar** para novos desenvolvedores
3. **Monitorar** logs de acesso
4. **Considerar** adicionar campo "academia_id" para futuras expansões

---

**Status:** 🟡 Aguardando Implementação  
**Responsável:** Desenvolvedor  
**Prazo:** URGENTE - Crítico para Segurança
