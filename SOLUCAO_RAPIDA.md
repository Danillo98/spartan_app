# 🚀 SOLUÇÃO RÁPIDA: Usuário Não Consegue Logar

## ⚡ **AÇÃO IMEDIATA**

### **Passo 1: Limpar Usuário Problemático**

Execute no **SQL Editor do Supabase**:

```sql
-- Deletar usuário do auth.users (para poder cadastrar novamente)
DELETE FROM auth.users
WHERE email = 'danilloneto98@gmail.com';
```

### **Passo 2: Cadastrar Novamente**

1. Abra o app
2. Vá para tela de cadastro
3. Preencha todos os dados
4. Clique em "CADASTRAR"

### **Passo 3: Confirmar Email**

1. Abra seu email
2. Procure email do Supabase
3. **IMPORTANTE:** Clique no link de confirmação
4. Aguarde o app abrir e processar

### **Passo 4: Fazer Login**

1. Digite email e senha
2. Clique em "ENTRAR"
3. ✅ Deve funcionar!

---

## 🔍 **SE O PROBLEMA PERSISTIR**

### **Diagnóstico Rápido:**

Execute no SQL Editor:

```sql
-- Verificar se usuário existe
SELECT 
    'auth.users' as local,
    id, email, email_confirmed_at
FROM auth.users
WHERE email = 'danilloneto98@gmail.com'

UNION ALL

SELECT 
    'public.users' as local,
    id, email, NULL as email_confirmed_at
FROM public.users
WHERE email = 'danilloneto98@gmail.com';
```

### **Resultado Esperado:**

```
✅ CORRETO:
- 1 linha em auth.users (email confirmado)
- 1 linha em public.users (mesmo ID)

❌ PROBLEMA:
- 1 linha em auth.users
- 0 linhas em public.users
```

---

## 🛠️ **SOLUÇÃO MANUAL (Se necessário)**

Se o usuário existe no `auth.users` mas não no `public.users`:

```sql
-- 1. Pegar ID do usuário
SELECT id FROM auth.users WHERE email = 'danilloneto98@gmail.com';

-- 2. Criar registro manualmente (PREENCHA OS DADOS!)
INSERT INTO public.users (
    id,
    name,
    email,
    phone,
    password_hash,
    role,
    cnpj,
    cpf,
    address,
    email_verified
) VALUES (
    'ID_DO_PASSO_1',              -- Cole o ID aqui
    'Seu Nome Completo',
    'danilloneto98@gmail.com',
    '11999999999',
    'managed_by_supabase_auth',
    'admin',
    '12345678901234',
    '12345678901',
    'Seu Endereço Completo',
    true
);
```

---

## 📱 **TESTAR NO APP**

### **Teste Completo:**

1. **Limpar dados do app:**
   ```
   - Desinstale o app
   - Reinstale o app
   ```

2. **Cadastrar:**
   ```
   - Abra o app
   - Cadastre-se
   - Aguarde email
   ```

3. **Confirmar:**
   ```
   - Abra email
   - Clique no link
   - Aguarde processamento
   ```

4. **Login:**
   ```
   - Digite email e senha
   - Clique em ENTRAR
   - ✅ Sucesso!
   ```

---

## 🎯 **CHECKLIST DE VERIFICAÇÃO**

Antes de tentar novamente, verifique:

- [ ] Usuário foi deletado do `auth.users`
- [ ] Usuário foi deletado do `public.users`
- [ ] App foi atualizado com as correções
- [ ] Email de confirmação está chegando
- [ ] Link do email está funcionando
- [ ] Deep links estão configurados no AndroidManifest

---

## 📞 **AINDA COM PROBLEMA?**

Execute o script de diagnóstico completo:

```sql
-- Copie e cole o conteúdo de: diagnostico_usuarios.sql
```

E me envie os resultados!

---

**Última Atualização:** 2026-01-16  
**Status:** ✅ Correções Implementadas
