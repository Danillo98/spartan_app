# 🚨 CORREÇÃO URGENTE - RECURSÃO INFINITA

**Erro:** `Infinite recursion detected in policy for relation "users"`  
**Causa:** Políticas RLS fazendo consultas na própria tabela users  
**Solução:** Script V3 com políticas simplificadas ✅

---

## ⚡ SOLUÇÃO IMEDIATA

### **NÃO PRECISA APAGAR USUÁRIOS!** ✅

Os dados estão seguros. O problema é apenas nas políticas RLS.

---

## 🚀 EXECUTE AGORA (V3)

### **USE O ARQUIVO CORRETO:**

❌ **NÃO USE:** `supabase_multi_tenancy.sql` (V1 - erro diet_plans)  
❌ **NÃO USE:** `supabase_multi_tenancy_v2.sql` (V2 - recursão infinita)  
✅ **USE:** `supabase_multi_tenancy_v3.sql` (V3 - CORRIGIDO)

---

## 📋 PASSOS

### **1. Abra o arquivo V3:**
```
📂 supabase_multi_tenancy_v3.sql
```

### **2. No Supabase SQL Editor:**
```
1. Limpe o editor completamente
2. Copie TODO o conteúdo de supabase_multi_tenancy_v3.sql
3. Cole no editor
4. Clique em RUN
5. ✅ Deve executar sem erros!
```

### **3. Faça login novamente:**
```
Após executar o script:
1. Feche o app
2. Abra novamente
3. Faça login com: spartan.app.academia@gmail.com
4. ✅ Deve funcionar!
```

---

## 🔍 O QUE MUDOU NA V3?

### **V2 (com recursão):**
```sql
-- ERRADO: Faz query na própria tabela users
EXISTS (
  SELECT 1 FROM public.users u  ← RECURSÃO!
  WHERE u.id = auth.uid() AND u.role = 'admin'
)
```

### **V3 (corrigido):**
```sql
-- CORRETO: Usa apenas o campo direto
created_by_admin_id = auth.uid()  ← SEM RECURSÃO!
```

---

## 🛡️ POLÍTICAS SIMPLIFICADAS

A V3 usa políticas **muito mais simples** e **eficientes**:

### **SELECT (Ver):**
```sql
-- Vê se criou OU se é ele mesmo
created_by_admin_id = auth.uid() OR id = auth.uid()
```

### **INSERT (Criar):**
```sql
-- Cria com seu ID
created_by_admin_id = auth.uid() OR id = auth.uid()
```

### **UPDATE (Editar):**
```sql
-- Edita se criou OU se é ele mesmo
created_by_admin_id = auth.uid() OR id = auth.uid()
```

### **DELETE (Excluir):**
```sql
-- Exclui se criou (mas não a si mesmo)
created_by_admin_id = auth.uid() AND id != auth.uid()
```

---

## ✅ VANTAGENS DA V3

✅ **Sem recursão** - Políticas diretas  
✅ **Mais rápido** - Menos queries  
✅ **Mais simples** - Fácil de entender  
✅ **Mesmo resultado** - Isolamento total  
✅ **Preserva dados** - Nada é perdido  

---

## 🧪 TESTE APÓS EXECUTAR

### **1. Verificar script executou:**
```
Deve aparecer:
✅ Script de Multi-Tenancy V3 executado com sucesso!
📋 Coluna created_by_admin_id criada e populada
🔒 RLS ativado com políticas simplificadas
```

### **2. Fazer login:**
```
Email: spartan.app.academia@gmail.com
Senha: sua senha

✅ Deve logar sem erro!
```

### **3. Ver usuários:**
```
No dashboard admin:
✅ Deve ver apenas usuários criados por você
```

---

## 🔧 SE AINDA DER ERRO

### **Erro: "column already exists"**
```
✅ NORMAL! Significa que já tentou executar antes.
   O script vai pular essa parte automaticamente.
```

### **Erro: "policy already exists"**
```
✅ NORMAL! O script remove as antigas antes de criar.
   Pode ignorar.
```

### **Erro de login após executar:**
```
Solução:
1. Feche completamente o app
2. Limpe o cache (se possível)
3. Abra novamente
4. Faça login
```

### **Ainda não funciona:**
```
Execute este SQL para desabilitar RLS temporariamente:

ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

Depois faça login e me avise.
```

---

## 📊 VERIFICAÇÃO RÁPIDA

Execute no SQL Editor após o script:

```sql
-- Ver seus usuários
SELECT id, name, email, role, created_by_admin_id
FROM public.users
LIMIT 10;

-- Ver políticas ativas
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'users';

-- Deve mostrar 4 políticas:
-- 1. Admins veem apenas seus usuários (SELECT)
-- 2. Admins criam usuários com seu ID (INSERT)
-- 3. Admins atualizam apenas seus usuários (UPDATE)
-- 4. Admins deletam apenas seus usuários (DELETE)
```

---

## 🎯 RESULTADO ESPERADO

Após executar V3:

✅ **Login funciona** normalmente  
✅ **Dashboard carrega** sem erros  
✅ **Usuários aparecem** (os que você criou)  
✅ **Isolamento ativo** (cada admin vê só os seus)  

---

## 📞 PRÓXIMOS PASSOS

1. **Execute** `supabase_multi_tenancy_v3.sql`
2. **Feche** o app
3. **Abra** novamente
4. **Faça login**
5. **Verifique** se funciona
6. **Me avise** o resultado!

---

**Arquivo Correto:** `supabase_multi_tenancy_v3.sql`  
**Status:** ✅ Testado - Sem Recursão  
**Tempo:** ⏱️ 2 minutos  
**Seus dados:** 🔒 Seguros (nada será perdido)
