# 🗑️ GUIA - Deletar Academia Completa (V3 - Oficial)

## 🎯 OBJETIVO:

Deletar TODOS os dados de uma academia específica usando o **`id_academia`**, incluindo:
- ✅ Administrador (Dono da Academia)
- ✅ Nutricionistas
- ✅ Personal Trainers
- ✅ Alunos
- ✅ Dados de autenticação (auth.users)
- ✅ Dietas, Treinos e Avisos (Cascata)

---

## ⚠️ ATENÇÃO:

**Esta ação é IRREVERSÍVEL!**

- ❌ Não há como recuperar os dados após deletar
- ❌ Todos os usuários da academia serão removidos
- ❌ O login de todos os usuários será removido

**SEMPRE faça backup antes de usar em produção!**

---

## 📋 PASSO A PASSO:

### **PASSO 1: Criar as Funções no Supabase**

1. Acesse: https://supabase.com/dashboard
2. Vá em **SQL Editor**
3. Clique em **"New query"**
4. Copie todo o conteúdo do arquivo `supabase/functions/delete_gym_v3.sql`
5. Cole no editor
6. Clique em **"Run"**
7. Aguarde a confirmação: "Success. No rows returned"

---

### **PASSO 2: Obter o ID da Academia**

Você precisará do UUID da academia (que é o ID do administrador principal na tabela `users_adm`).

---

### **PASSO 3: Listar Usuários da Academia (RECOMENDADO!)**

Antes de deletar, **SEMPRE** liste os usuários para confirmar que está pegando a academia certa:

```sql
-- Substituir pelo UUID da academia
SELECT * FROM list_academia_users_v3('SEU_UUID_AQUI');
```

**Resultado esperado:**
```
output_user_id                       | output_name    | output_email           | output_role  | output_table_source
-------------------------------------|----------------|------------------------|--------------|------------------
7649bfca-9b23-423e-b437-4da212294123 | Danillo Neto   | admin@gmail.com        | admin        | users_adm
a1b2c3d4-e5f6-7890-abcd-ef1234567890 | João Silva     | joao@example.com       | nutritionist | users_nutricionista
b2c3d4e5-f6a7-8901-bcde-f12345678901 | Maria Santos   | maria@example.com      | personal     | users_personal
c3d4e5f6-a7b8-9012-cdef-123456789012 | Pedro Oliveira | pedro@example.com      | student      | users_alunos
```

---

### **PASSO 4: Deletar Academia**

Após confirmar, execute a deleção:

```sql
-- Deletar pelo ID_ACADEMIA
SELECT delete_academia_by_id_v3('SEU_UUID_AQUI');
```

---

### **PASSO 5: Verificar Resultado**

**Resultado esperado:**
```json
{
  "success": true,
  "message": "Academia e usuários deletados com sucesso",
  "id_academia": "SEU_UUID_AQUI",
  "deleted_counts": {
    "admins": 1,
    "nutritionists": 2,
    "personals": 5,
    "students": 50,
    "auth_users_total": 58
  }
}
```

---

## 🔍 FUNÇÕES DISPONÍVEIS (V3):

### **1. `list_academia_users_v3(id_academia)`**

Lista todos os usuários vinculados àquele ID de academia.

**Uso:**
```sql
SELECT * FROM list_academia_users_v3('uuid-da-academia');
```

---

### **2. `delete_academia_by_id_v3(id_academia)`**

Deleta tudo relacionado àquele ID.

**Uso:**
```sql
SELECT delete_academia_by_id_v3('uuid-da-academia');
```

---

## 🔒 SEGURANÇA:

### **Quem pode executar?**

- ✅ `service_role` (Supabase)
- ✅ `postgres` (Superadmin)
- ✅ Você no SQL Editor

---

## 📝 RESUMO TÉCNICO:

- O script varre as tabelas `users_adm`, `users_nutricionista`, `users_personal` e `users_alunos`.
- Coleta todos os IDs de usuários vinculados ao `id_academia` fornecido.
- Executa um `DELETE FROM auth.users` em lote para esses IDs.
- Graças às chaves estrangeiras com `ON DELETE CASCADE`, os dados das tabelas públicas e dados relacionados (dietas, treinos) são removidos automaticamente pelo banco de dados.

---

**Arquivo SQL:** `supabase/functions/delete_gym_v3.sql`

**Use com responsabilidade!** 🔒
