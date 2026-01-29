# 🔧 Como Aplicar as Migrações Pendentes

## Problemas Identificados

### 1. Administrador não consegue alterar senha de outros perfis
**Causa:** A função RPC `admin_update_password` não existe no banco de dados.

### 2. Alunos criados com mensalidade paga ficam bloqueados
**Causa:** O campo `is_blocked` pode não estar sendo definido corretamente como `FALSE` ao criar novos usuários.

### 3. Erro ao Deletar/Editar (Erro Crítico)
**Causa:** A tabela `audit_logs` está sem a coluna `target_table`, quebrando as triggers de auditoria em operações de update/delete.

### 4. Transações Financeiras sendo excluídas com o usuário
**Causa:** O banco de dados está configurado para deletar "em cascata" (CASCADE). Isso significa que ao apagar um usuário, tudo dele some.
**Correção:** Alterar a regra para `SET NULL` (Manter o registro financeiro, apenas remover o vínculo com o usuário).

## Solução
Aplicar quatro migrações SQL que corrigem a RPC, os triggers de bloqueio, a tabela de auditoria e protegem o histórico financeiro.

---

## 📋 Passos para Aplicar as Migrações

### 1. Acesse o Supabase Dashboard
1. Vá para: https://supabase.com/dashboard
2. Faça login na sua conta
3. Selecione o projeto **Spartan App**

### 2. Abra o SQL Editor
1. No menu lateral esquerdo, clique em **SQL Editor**
2. Clique em **New Query** (Nova Consulta)

### 3. Aplique a Primeira Migração: admin_update_password

#### Cole o Script SQL
Copie e cole o conteúdo do arquivo:
```
supabase/migrations/20260129_admin_update_password.sql
```

Ou copie diretamente daqui:

```sql
-- FUNÇÃO PARA ADMINISTRADOR ALTERAR SENHA DE QUALQUER USUÁRIO
-- Permite que o admin redefina senha sem enviar email

CREATE OR REPLACE FUNCTION public.admin_update_password(
    target_user_id uuid,
    new_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admin_role text;
BEGIN
    -- Verificar se o usuário atual é administrador
    SELECT role INTO v_admin_role
    FROM public.users
    WHERE id = auth.uid();
    
    IF v_admin_role IS NULL OR v_admin_role != 'Administrador' THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Apenas administradores podem alterar senhas de outros usuários.'
        );
    END IF;
    
    -- Validar senha (mínimo 6 caracteres)
    IF length(new_password) < 6 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'A senha deve ter no mínimo 6 caracteres.'
        );
    END IF;
    
    -- Verificar se o usuário alvo existe
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = target_user_id) THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Usuário não encontrado.'
        );
    END IF;
    
    -- Atualizar senha no auth.users
    UPDATE auth.users
    SET 
        encrypted_password = crypt(new_password, gen_salt('bf')),
        updated_at = now()
    WHERE id = target_user_id;
    
    -- Verificar se a atualização foi bem-sucedida
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Erro ao atualizar senha.'
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Senha alterada com sucesso!'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false, 
        'message', 'Erro ao alterar senha: ' || SQLERRM
    );
END;
$$;

-- Grant de execução para usuários autenticados
GRANT EXECUTE ON FUNCTION public.admin_update_password(uuid, text) TO authenticated;

-- Comentário da função
COMMENT ON FUNCTION public.admin_update_password(uuid, text) IS 
'Permite que administradores alterem a senha de qualquer usuário sem enviar email de confirmação.';
```

### 4. Execute o Script
1. Clique no botão **Run** (Executar) ou pressione `Ctrl + Enter`
2. Aguarde a confirmação de sucesso

### 5. Verifique a Criação
Execute esta query para confirmar que a função foi criada:

```sql
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'admin_update_password';
```

Você deve ver um resultado mostrando a função `admin_update_password`.

---

### 6. Aplique a Segunda Migração: fix_is_blocked_default

#### Abra uma Nova Query
1. Clique em **New Query** (Nova Consulta) novamente
2. Cole o script da segunda migração

#### Cole o Script SQL
Copie e cole o conteúdo do arquivo:
```
supabase/migrations/20260129_fix_is_blocked_default.sql
```

Ou copie diretamente daqui:

```sql
-- GARANTIR QUE NOVOS USUÁRIOS SEMPRE TENHAM is_blocked = FALSE
-- Trigger para garantir que o campo is_blocked seja sempre FALSE ao criar um novo usuário

-- Função para garantir is_blocked = FALSE
CREATE OR REPLACE FUNCTION ensure_is_blocked_false()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Se is_blocked for NULL ou não definido, definir como FALSE
    IF NEW.is_blocked IS NULL THEN
        NEW.is_blocked := FALSE;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Trigger para users_alunos
DROP TRIGGER IF EXISTS ensure_is_blocked_false_alunos ON users_alunos;
CREATE TRIGGER ensure_is_blocked_false_alunos
    BEFORE INSERT ON users_alunos
    FOR EACH ROW
    EXECUTE FUNCTION ensure_is_blocked_false();

-- Trigger para users_nutricionista
DROP TRIGGER IF EXISTS ensure_is_blocked_false_nutri ON users_nutricionista;
CREATE TRIGGER ensure_is_blocked_false_nutri
    BEFORE INSERT ON users_nutricionista
    FOR EACH ROW
    EXECUTE FUNCTION ensure_is_blocked_false();

-- Trigger para users_personal
DROP TRIGGER IF EXISTS ensure_is_blocked_false_personal ON users_personal;
CREATE TRIGGER ensure_is_blocked_false_personal
    BEFORE INSERT ON users_personal
    FOR EACH ROW
    EXECUTE FUNCTION ensure_is_blocked_false();

-- Trigger para users_adm
DROP TRIGGER IF EXISTS ensure_is_blocked_false_adm ON users_adm;
CREATE TRIGGER ensure_is_blocked_false_adm
    BEFORE INSERT ON users_adm
    FOR EACH ROW
    EXECUTE FUNCTION ensure_is_blocked_false();

-- Atualizar todos os usuários existentes que possam ter is_blocked = NULL
UPDATE users_alunos SET is_blocked = FALSE WHERE is_blocked IS NULL;
UPDATE users_nutricionista SET is_blocked = FALSE WHERE is_blocked IS NULL;
UPDATE users_personal SET is_blocked = FALSE WHERE is_blocked IS NULL;
UPDATE users_adm SET is_blocked = FALSE WHERE is_blocked IS NULL;

COMMENT ON FUNCTION ensure_is_blocked_false() IS 
'Garante que o campo is_blocked seja sempre FALSE ao criar um novo usuário, evitando bloqueios acidentais.';
```

#### Execute o Script
1. Clique no botão **Run** (Executar) ou pressione `Ctrl + Enter`
2. Aguarde a confirmação de sucesso

#### Verifique a Criação
Execute esta query para confirmar que os triggers foram criados:

```sql
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_name LIKE 'ensure_is_blocked_false%'
ORDER BY event_object_table;
```

Você deve ver 4 triggers (um para cada tabela de usuários).

---

### 7. Aplique a Terceira Migração: fix_audit_logs_critical (MUITO IMPORTANTE)

Esta correção resolve os erros de "column target_table does not exist" ao tentar deletar ou editar registros.

#### Abra uma Nova Query
1. Clique em **New Query** (Nova Consulta) novamente
2. Cole o script da terceira migração

#### Cole o Script SQL
Copie e cole o conteúdo do arquivo:
```
supabase/migrations/20260129_fix_audit_logs_critical.sql
```

Ou copie diretamente daqui:

```sql
-- CORREÇÃO CRÍTICA DE AUDITORIA
-- Corrige erro: column "target_table" of relation "audit_logs" does not exist

-- 1. Adicionar coluna target_table se não existir (para compatibilidade com triggers de security_hardening)
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS target_table TEXT;

-- 2. Garantir que outras colunas esperadas também existam
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS target_id UUID;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS details JSONB;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS action TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS user_id UUID;

-- 3. Sincronizar dados entre table_name (legado) e target_table (novo)
UPDATE public.audit_logs 
SET target_table = table_name 
WHERE target_table IS NULL AND table_name IS NOT NULL;

-- 4. Opcional: Se table_name não existir, criar como alias de target_table
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS table_name TEXT;
UPDATE public.audit_logs 
SET table_name = target_table 
WHERE table_name IS NULL AND target_table IS NOT NULL;

-- 5. Atualizar a função de auditoria para ser mais resiliente
CREATE OR REPLACE FUNCTION process_audit_log() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.audit_logs (
        user_id, 
        action, 
        target_table, 
        table_name,   
        target_id, 
        record_id,    
        details
    )
    VALUES (
        auth.uid(),
        TG_OP,
        TG_TABLE_NAME,
        TG_TABLE_NAME, 
        CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
        CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
        jsonb_build_object('old_data', OLD, 'new_data', NEW)
    );
    RETURN NULL; 
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Recriar Trigger para Transações Financeiras
DROP TRIGGER IF EXISTS audit_financial_transactions ON public.financial_transactions;
CREATE TRIGGER audit_financial_transactions
AFTER UPDATE OR DELETE ON public.financial_transactions
FOR EACH ROW EXECUTE FUNCTION process_audit_log();

-- 7. Grant permissões necessárias
GRANT ALL ON public.audit_logs TO postgres;
GRANT ALL ON public.audit_logs TO service_role;
GRANT SELECT, INSERT ON public.audit_logs TO authenticated;
```

#### Execute o Script
1. Clique no botão **Run** (Executar) ou pressione `Ctrl + Enter`
2. Aguarde a confirmação de sucesso

---

### 8. Aplique a Quarta Migração: fix_delete_rpc_history (DEFINITIVA)

Esta migração é completa: protege o banco de dados (FK) e atualiza a função de exclusão do sistema para garantir que o dinheiro nunca seja apagado.

#### Abra uma Nova Query
1. Clique em **New Query** (Nova Consulta) novamente
2. Cole o script da correção definitiva

#### Cole o Script SQL
Copie e cole o conteúdo do arquivo:
```
supabase/migrations/20260129_fix_delete_rpc_history.sql
```

Ou copie diretamente daqui:

```sql
-- CORREÇÃO DEFINITIVA DE EXCLUSÃO DE USUÁRIO E HISTÓRICO FINANCEIRO
-- 1. Assegura que constraints de deleção na tabela financeira sejam SET NULL
-- 2. Atualiza a função RPC de deleção para garantir o desligamento do vínculo financeiro antes da exclusão

-- PARTE 1: Garantir Schema do Banco (Foreign Key Segura)
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Remover qualquer FK em related_user_id (para recriar corretamente)
    FOR r IN 
        SELECT tc.constraint_name 
        FROM information_schema.table_constraints AS tc 
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' 
          AND tc.table_name = 'financial_transactions' 
          AND kcu.column_name = 'related_user_id'
    LOOP
        EXECUTE 'ALTER TABLE public.financial_transactions DROP CONSTRAINT ' || quote_ident(r.constraint_name);
    END LOOP;
END $$;

-- Recriar FK com SET NULL
ALTER TABLE public.financial_transactions
ADD CONSTRAINT fk_financial_transactions_user_v2
FOREIGN KEY (related_user_id)
REFERENCES auth.users(id)
ON DELETE SET NULL;


-- PARTE 2: Atualizar Função RPC de Deleção (delete_user_complete)
-- Esta função é chamada pelo App para deletar usuários
CREATE OR REPLACE FUNCTION delete_user_complete(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role text;
  v_user_name text;
BEGIN
  -- Identificar Role e Nome (para preservar no histórico)
  IF EXISTS (SELECT 1 FROM users_alunos WHERE id = target_user_id) THEN
    v_role := 'Aluno';
    SELECT nome INTO v_user_name FROM users_alunos WHERE id = target_user_id;
  ELSIF EXISTS (SELECT 1 FROM users_nutricionista WHERE id = target_user_id) THEN
    v_role := 'Nutricionista';
    SELECT nome INTO v_user_name FROM users_nutricionista WHERE id = target_user_id;
  ELSIF EXISTS (SELECT 1 FROM users_personal WHERE id = target_user_id) THEN
    v_role := 'Personal';
    SELECT nome INTO v_user_name FROM users_personal WHERE id = target_user_id;
  ELSIF EXISTS (SELECT 1 FROM users_adm WHERE id = target_user_id) THEN
    v_role := 'Admin';
    SELECT nome INTO v_user_name FROM users_adm WHERE id = target_user_id;
  ELSE
    v_role := 'Usuário';
    v_user_name := 'Desconhecido';
  END IF;

  v_user_name := COALESCE(v_user_name, 'Sem Nome');

  -- 1. PROTEGER DADOS FINANCEIROS (CRÍTICO)
  -- Atualizar transações para remover o vínculo, mas preservando o NOME na descrição de forma inteligente
  UPDATE public.financial_transactions
  SET 
    related_user_id = NULL,
    description = CASE 
        WHEN position(v_user_name in description) > 0 THEN description || ' (' || v_role || ' Excluído)'
        ELSE description || ' - ' || v_user_name || ' (' || v_role || ' Excluído)'
    END
  WHERE related_user_id = target_user_id;

  -- 2. LIMPEZA DE DADOS RELACIONADOS (Agendamentos, Treinos, etc)
  
  -- Dietas
  UPDATE diets SET nutritionist_id = NULL WHERE nutritionist_id = target_user_id;
  DELETE FROM diets WHERE student_id = target_user_id;

  -- Treinos
  DELETE FROM workouts WHERE student_id = target_user_id;
  DELETE FROM physical_assessments WHERE student_id = target_user_id;

  -- Agendamentos
  DELETE FROM appointments WHERE student_id = target_user_id;

  -- Notificações
  DELETE FROM notifications WHERE user_id = target_user_id;

  -- 3. DELETAR PERFIL (Tabelas públicas)
  DELETE FROM users_alunos WHERE id = target_user_id;
  DELETE FROM users_nutricionista WHERE id = target_user_id;
  DELETE FROM users_personal WHERE id = target_user_id;
  DELETE FROM users_adm WHERE id = target_user_id;

  -- 4. DELETAR CONTA DE AUTENTICAÇÃO (Auth.Users)
  DELETE FROM auth.users WHERE id = target_user_id;

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Erro fatal ao excluir usuário: %', SQLERRM;
END;
$$;
```

#### Execute o Script
Executar da mesma forma.

---

## ✅ Teste as Funcionalidades

### Teste 1: Redefinição de Senha pelo Administrador

1. **Faça logout** do app (se estiver logado)
2. **Faça login** como Administrador
3. Vá para **Gerenciar Usuários**
4. Selecione um usuário (Nutricionista, Personal Trainer ou Aluno)
5. Clique em **REDEFINIR SENHA**
6. Digite uma nova senha (mínimo 6 caracteres)
7. Clique em **Salvar Senha**

Você deve ver a mensagem: **"Senha alterada com sucesso!"** ✅

### Teste 2: Criação de Aluno com Mensalidade Paga

1. Como Administrador, vá para **Gerenciar Usuários**
2. Clique em **Adicionar Usuário**
3. Selecione o tipo **Aluno**
4. Preencha os dados do aluno
5. **Marque a opção "Mensalidade Paga"** (se disponível)
6. Defina o valor da mensalidade
7. Clique em **Cadastrar**
8. **Faça logout** e tente fazer login com o novo aluno

O aluno deve conseguir fazer login normalmente **SEM bloqueio** ✅

### Teste 3: Verificar Usuários Existentes

Execute esta query no SQL Editor para verificar se todos os usuários têm `is_blocked = FALSE`:

```sql
SELECT 'Alunos' as tipo, COUNT(*) as total, COUNT(*) FILTER (WHERE is_blocked = FALSE) as desbloqueados
FROM users_alunos
UNION ALL
SELECT 'Nutricionistas', COUNT(*), COUNT(*) FILTER (WHERE is_blocked = FALSE)
FROM users_nutricionista
UNION ALL
SELECT 'Personal Trainers', COUNT(*), COUNT(*) FILTER (WHERE is_blocked = FALSE)
FROM users_personal
UNION ALL
SELECT 'Administradores', COUNT(*), COUNT(*) FILTER (WHERE is_blocked = FALSE)
FROM users_adm;
```

Os números de `total` e `desbloqueados` devem ser iguais para cada tipo ✅

### Teste 4: Deletar/Editar Registros (Correção Crítica)

Este teste confirma que o erro de auditoria foi resolvido.

1. Vá para o **Financeiro**
2. Crie uma nova transação de teste (ex: Receita de R$ 1,00)
3. Tente **Deletar** essa transação
4. A transação deve ser removida com sucesso **sem erro vermelho** ✅

5. (Opcional) Tente **Deletar um Usuário** (Crie um usuário de teste antes!)
6. A deleção deve ocorrer com sucesso ✅

### Teste 5: Proteção de Histórico Financeiro

1. Crie um aluno de teste
2. Registre uma transação financeira para ele (ex: Pagamento de R$ 50,00)
3. **Delete o aluno** pelo painel de admin
4. Vá para o **Controle Financeiro**
5. A transação de R$ 50,00 **AINDA DEVE ESTAR LÁ**, mas sem o nome do aluno (ou com nome genérico se o app tratar) ✅
6. O sistema não pode apagar dinheiro do caixa só porque o aluno saiu!

---

## 🔒 Segurança Implementada

A função possui as seguintes validações:

✅ **Verificação de Permissão**: Apenas usuários com role "Administrador" podem executar
✅ **Validação de Senha**: Mínimo de 6 caracteres
✅ **Verificação de Existência**: Confirma que o usuário alvo existe
✅ **Tratamento de Erros**: Retorna mensagens claras em caso de falha
✅ **Security Definer**: Executa com privilégios elevados de forma segura

---

## 📝 Observações

- Esta função **NÃO envia email** ao usuário
- A alteração é **imediata**
- O usuário pode fazer login com a nova senha imediatamente
- Apenas **Administradores** têm permissão para usar esta função

---

## 🆘 Problemas?

Se encontrar algum erro ao executar o script:

1. Verifique se você está no projeto correto
2. Confirme que tem permissões de administrador no Supabase
3. Verifique se a extensão `pgcrypto` está habilitada (geralmente já vem habilitada)
4. Me avise o erro exato para que eu possa ajudar!
