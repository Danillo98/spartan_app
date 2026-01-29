# 🔧 Como Aplicar as Migrações Pendentes

## Problemas Identificados

### 1. Administrador não consegue alterar senha de outros perfis
**Causa:** A função RPC `admin_update_password` não existe no banco de dados.

### 2. Alunos criados com mensalidade paga ficam bloqueados
**Causa:** O campo `is_blocked` pode não estar sendo definido corretamente como `FALSE` ao criar novos usuários.

## Solução
Aplicar duas migrações SQL que criam a função RPC necessária e garantem que novos usuários sempre tenham `is_blocked = FALSE`.

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
