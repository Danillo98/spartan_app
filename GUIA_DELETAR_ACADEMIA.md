# 🗑️ GUIA - Deletar Academia Completa

## 🎯 OBJETIVO:

Deletar TODOS os dados de uma academia específica do banco de dados, incluindo:
- ✅ Administradores
- ✅ Nutricionistas
- ✅ Personal Trainers
- ✅ Alunos
- ✅ Dados de autenticação (auth.users)

---

## ⚠️ ATENÇÃO:

**Esta ação é IRREVERSÍVEL!**

- ❌ Não há como recuperar os dados após deletar
- ❌ Todos os usuários da academia serão removidos
- ❌ Todos os dados relacionados serão perdidos

**SEMPRE faça backup antes de usar em produção!**

---

## 📋 PASSO A PASSO:

### **PASSO 1: Criar as Funções no Supabase**

1. Acesse: https://supabase.com/dashboard
2. Vá em **SQL Editor**
3. Clique em **"New query"**
4. Copie todo o conteúdo do arquivo `supabase/functions/delete_gym.sql`
5. Cole no editor
6. Clique em **"Run"**
7. Aguarde a confirmação: "Success. No rows returned"

---

### **PASSO 2: Listar Usuários da Academia (RECOMENDADO!)**

Antes de deletar, **SEMPRE** liste os usuários para confirmar:

```sql
-- Substituir pelo CNPJ da academia
SELECT * FROM list_gym_users('53870683000102');
```

**Resultado esperado:**
```
id                                   | name           | email                  | role         | created_at
-------------------------------------|----------------|------------------------|--------------|------------------
7649bfca-9b23-423e-b437-4da212294123 | Danillo Neto   | danilloneto98@gmail.com| admin        | 2026-01-16 22:10
a1b2c3d4-e5f6-7890-abcd-ef1234567890 | João Silva     | joao@example.com       | nutritionist | 2026-01-16 22:15
b2c3d4e5-f6a7-8901-bcde-f12345678901 | Maria Santos   | maria@example.com      | personal     | 2026-01-16 22:20
c3d4e5f6-a7b8-9012-cdef-123456789012 | Pedro Oliveira | pedro@example.com      | student      | 2026-01-16 22:25
```

---

### **PASSO 3: Deletar Academia**

Após confirmar que os usuários listados estão corretos:

```sql
-- Deletar pelo CNPJ
SELECT delete_gym_by_cnpj('53870683000102');
```

**OU**

```sql
-- Deletar pelo ID do Admin
SELECT delete_gym_by_admin_id('7649bfca-9b23-423e-b437-4da212294123');
```

---

### **PASSO 4: Verificar Resultado**

**Resultado esperado:**
```json
{
  "success": true,
  "message": "Academia deletada com sucesso",
  "cnpj": "53870683000102",
  "deleted": {
    "users": 15,      // Nutricionistas, Personals, Alunos
    "admins": 1,      // Administradores
    "auth_users": 16  // Total deletado do auth
  }
}
```

---

### **PASSO 5: Confirmar Deleção**

Verifique se realmente foi deletado:

```sql
-- Deve retornar 0 linhas
SELECT * FROM list_gym_users('53870683000102');
```

---

## 🔍 FUNÇÕES DISPONÍVEIS:

### **1. `list_gym_users(cnpj)`**

Lista todos os usuários de uma academia.

**Uso:**
```sql
SELECT * FROM list_gym_users('53870683000102');
```

**Retorna:**
- id
- name
- email
- role
- created_at

---

### **2. `delete_gym_by_cnpj(cnpj)`**

Deleta academia pelo CNPJ.

**Uso:**
```sql
SELECT delete_gym_by_cnpj('53870683000102');
```

**Retorna:**
- success (boolean)
- message (string)
- cnpj (string)
- deleted (object com contadores)

---

### **3. `delete_gym_by_admin_id(admin_id)`**

Deleta academia pelo ID do administrador.

**Uso:**
```sql
SELECT delete_gym_by_admin_id('7649bfca-9b23-423e-b437-4da212294123');
```

**Retorna:**
- Mesmo formato que `delete_gym_by_cnpj`

---

## 💡 CASOS DE USO:

### **Caso 1: Academia cancelou assinatura**

```sql
-- 1. Listar para confirmar
SELECT * FROM list_gym_users('53870683000102');

-- 2. Deletar
SELECT delete_gym_by_cnpj('53870683000102');

-- 3. Confirmar
SELECT * FROM list_gym_users('53870683000102');
```

---

### **Caso 2: Limpar dados de teste**

```sql
-- Deletar academia de teste
SELECT delete_gym_by_cnpj('00000000000000');
```

---

### **Caso 3: Admin solicitou remoção de dados (LGPD)**

```sql
-- 1. Listar
SELECT * FROM list_gym_users('53870683000102');

-- 2. Fazer backup (exportar CSV)

-- 3. Deletar
SELECT delete_gym_by_cnpj('53870683000102');

-- 4. Confirmar
SELECT * FROM list_gym_users('53870683000102');
```

---

## 🔒 SEGURANÇA:

### **Quem pode executar?**

- ✅ `service_role` (Supabase)
- ✅ Você no SQL Editor
- ❌ Usuários do app (não têm permissão)

### **Como proteger?**

1. **Nunca** exponha essas funções via API pública
2. **Sempre** use via SQL Editor ou backend seguro
3. **Considere** adicionar autenticação extra
4. **Implemente** logs de auditoria

---

## 📊 EXEMPLO COMPLETO:

```sql
-- ============================================
-- EXEMPLO: Deletar Academia "Spartan Gym"
-- ============================================

-- 1. Buscar CNPJ da academia
SELECT cnpj, name, email 
FROM public.users 
WHERE role = 'admin' AND name LIKE '%Spartan%';

-- Resultado: cnpj = '53870683000102'

-- 2. Listar todos os usuários
SELECT * FROM list_gym_users('53870683000102');

-- Resultado:
-- 1 admin
-- 3 nutricionistas
-- 5 personals
-- 20 alunos
-- Total: 29 usuários

-- 3. Confirmar que quer deletar
-- ATENÇÃO: Isso vai deletar 29 usuários!

-- 4. Executar deleção
SELECT delete_gym_by_cnpj('53870683000102');

-- Resultado:
-- {
--   "success": true,
--   "message": "Academia deletada com sucesso",
--   "cnpj": "53870683000102",
--   "deleted": {
--     "users": 28,
--     "admins": 1,
--     "auth_users": 29
--   }
-- }

-- 5. Verificar
SELECT * FROM list_gym_users('53870683000102');

-- Resultado: 0 linhas (deletado com sucesso!)
```

---

## ⚠️ PROBLEMAS COMUNS:

### **Erro: "Nenhuma academia encontrada"**

**Causa:** CNPJ não existe ou está incorreto

**Solução:**
```sql
-- Verificar CNPJs cadastrados
SELECT DISTINCT cnpj, COUNT(*) as total_users
FROM public.users
WHERE role = 'admin'
GROUP BY cnpj;
```

---

### **Erro: "Permission denied"**

**Causa:** Usuário sem permissão

**Solução:**
- Use o SQL Editor do Supabase
- Ou use `service_role` key

---

### **Erro: "Function does not exist"**

**Causa:** Função não foi criada

**Solução:**
1. Execute o script `delete_gym.sql` no SQL Editor
2. Verifique se não houve erros

---

## 🎯 MELHORIAS FUTURAS:

### **1. Soft Delete**

Ao invés de deletar permanentemente, marcar como "deletado":

```sql
-- Adicionar coluna deleted_at
ALTER TABLE public.users ADD COLUMN deleted_at TIMESTAMPTZ;

-- Função de soft delete
CREATE FUNCTION soft_delete_gym(cnpj TEXT) ...
```

### **2. Logs de Auditoria**

Registrar quem deletou e quando:

```sql
CREATE TABLE gym_deletion_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cnpj TEXT,
  deleted_by UUID,
  deleted_at TIMESTAMPTZ DEFAULT NOW(),
  users_count INTEGER
);
```

### **3. Confirmação de Segurança**

Exigir confirmação antes de deletar:

```sql
-- Gerar código de confirmação
SELECT generate_deletion_code('53870683000102');

-- Deletar com código
SELECT delete_gym_with_code('53870683000102', 'ABC123');
```

---

## 📝 RESUMO:

- ✅ Funções criadas para deletar academia completa
- ✅ Suporte para deletar por CNPJ ou Admin ID
- ✅ Função de listagem para verificar antes
- ✅ Retorna contadores de quantos foram deletados
- ⚠️ **IRREVERSÍVEL** - Use com cuidado!

---

**Arquivo SQL:** `supabase/functions/delete_gym.sql`

**Use com responsabilidade!** 🔒
