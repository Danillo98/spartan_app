# 🔧 CORREÇÃO: Erro de Login de Usuários Criados pelo Admin

## 🔴 Problema
Quando o administrador cria um usuário (nutricionista, personal trainer ou aluno), esse usuário não consegue fazer login e recebe o erro:
```
*code*: unexpected, failure *message*: Database error querying schema
```

## 🎯 Causa Raiz
A função SQL `create_user_v4` que o código Flutter chama não existe no banco de dados do Supabase.

## ✅ Solução

### Passo 1: Executar Script SQL no Supabase

1. Acesse o **Supabase Dashboard**: https://supabase.com/dashboard
2. Selecione seu projeto: `spartan-app-f8a98`
3. No menu lateral, clique em **SQL Editor**
4. Clique em **New Query**
5. Copie TODO o conteúdo do arquivo: `supabase/migrations/FIX_USER_LOGIN.sql`
6. Cole na query e clique em **Run** (ou pressione Ctrl+Enter)
7. Aguarde a mensagem: "✅ Função create_user_v4 criada e políticas RLS verificadas!"

### Passo 2: Testar Criação de Usuário

1. No app (admin), crie um novo usuário de teste (nutricionista, por exemplo)
2. Anote o email e senha que você definiu
3. Faça logout do admin
4. Tente fazer login com as credenciais do novo usuário

### Resultado Esperado
✅ O usuário deve conseguir fazer login normalmente
✅ Deve ser redirecionado para a tela apropriada (nutricionista, personal, aluno)
✅ Sem erros de "Database error querying schema"

## 🔍 O Que o Script Faz

1. **Cria a função `create_user_v4`**:
   - Insere o usuário no `auth.users` com email já confirmado
   - Cria o registro na tabela pública apropriada (`users_nutricionista`, `users_personal` ou `users_alunos`)
   - Marca `email_verified = TRUE` para permitir login imediato
   - Retorna sucesso ou erro detalhado

2. **Garante Permissões**:
   - Permite que usuários autenticados executem a função
   - Permite que o service_role execute a função

3. **Verifica Políticas RLS**:
   - Garante que nutricionistas podem ver seu próprio perfil
   - Garante que personal trainers podem ver seu próprio perfil
   - Garante que alunos podem ver seu próprio perfil

## 📝 Notas Importantes

- **Não precisa rebuild do app**: A correção é no banco de dados
- **Usuários já criados**: Se já criou usuários antes, eles podem não ter sido inseridos corretamente. Será necessário deletá-los e recriá-los após aplicar o script
- **Backup**: O script usa `CREATE OR REPLACE` e `DROP POLICY IF EXISTS`, então é seguro executar múltiplas vezes

## 🐛 Debug (Se Ainda Houver Erro)

Se mesmo após rodar o script o erro persistir, verifique:

1. **Função existe?**
   ```sql
   SELECT routine_name 
   FROM information_schema.routines 
   WHERE routine_name = 'create_user_v4';
   ```

2. **Usuário foi criado no Auth?**
   ```sql
   SELECT id, email, email_confirmed_at 
   FROM auth.users 
   WHERE email = 'email_do_usuario_teste@exemplo.com';
   ```

3. **Usuário foi criado na tabela pública?**
   ```sql
   -- Para nutricionista
   SELECT id, nome, email, email_verified 
   FROM public.users_nutricionista 
   WHERE email = 'email_do_usuario_teste@exemplo.com';
   
   -- Ou para personal
   SELECT id, nome, email, email_verified 
   FROM public.users_personal 
   WHERE email = 'email_do_usuario_teste@exemplo.com';
   
   -- Ou para aluno
   SELECT id, nome, email, email_verified 
   FROM public.users_alunos 
   WHERE email = 'email_do_usuario_teste@exemplo.com';
   ```

4. **Políticas RLS estão ativas?**
   ```sql
   SELECT schemaname, tablename, policyname 
   FROM pg_policies 
   WHERE tablename IN ('users_nutricionista', 'users_personal', 'users_alunos');
   ```
