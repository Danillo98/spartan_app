# 🚀 GUIA DE IMPLEMENTAÇÃO: MULTI-TENANCY

**Data:** 2026-01-17  
**Status:** ✅ Código Flutter Atualizado | 🟡 Aguardando SQL no Supabase

---

## 📋 Resumo

Este guia orienta a implementação completa do sistema **multi-tenancy** para garantir que cada administrador veja e gerencie **APENAS** os usuários que ele mesmo criou.

---

## ✅ O QUE JÁ FOI FEITO

### **1. Código Flutter Atualizado**

Os seguintes arquivos foram modificados:

- ✅ `lib/services/user_service.dart` - Adiciona `created_by_admin_id` ao criar usuários
- ✅ `lib/services/auth_service.dart` - Admins se auto-referenciam como criadores
- ✅ Comentários explicativos sobre RLS em todos os métodos

### **2. Arquivos de Documentação Criados**

- ✅ `MULTI_TENANCY_IMPLEMENTATION.md` - Documentação completa
- ✅ `supabase_multi_tenancy.sql` - Script SQL pronto para executar
- ✅ `GUIA_IMPLEMENTACAO_MULTI_TENANCY.md` - Este arquivo

---

## 🔧 O QUE VOCÊ PRECISA FAZER AGORA

### **PASSO 1: Executar Script SQL no Supabase** 🔴 OBRIGATÓRIO

1. **Acesse o Supabase Dashboard:**
   - Vá para: https://app.supabase.com
   - Selecione seu projeto

2. **Abra o SQL Editor:**
   - No menu lateral, clique em **SQL Editor**
   - Clique em **New Query**

3. **Cole o Script SQL:**
   - Abra o arquivo: `supabase_multi_tenancy.sql`
   - Copie **TODO** o conteúdo
   - Cole no editor SQL do Supabase

4. **Execute o Script:**
   - Clique em **Run** (ou pressione Ctrl+Enter)
   - Aguarde a execução completa
   - Verifique se não há erros

5. **Verifique a Execução:**
   - Você deve ver mensagens de sucesso
   - Verifique se a coluna `created_by_admin_id` foi criada
   - Verifique se as políticas RLS foram criadas

---

### **PASSO 2: Verificar Dados Existentes**

Se você já tem usuários no banco de dados:

#### **Opção A: Atribuir ao Primeiro Admin**

O script já faz isso automaticamente. Todos os usuários existentes serão atribuídos ao primeiro admin cadastrado.

#### **Opção B: Distribuir Manualmente**

Se você quiser distribuir os usuários entre diferentes admins:

```sql
-- Exemplo: Atribuir usuários específicos a um admin específico
UPDATE public.users 
SET created_by_admin_id = 'ID_DO_ADMIN_AQUI'
WHERE id IN ('ID_USUARIO_1', 'ID_USUARIO_2', ...);
```

---

### **PASSO 3: Testar o Sistema**

#### **Teste 1: Criar Dois Admins**

1. Registre Admin A (admin1@teste.com)
2. Registre Admin B (admin2@teste.com)
3. Confirme ambos os emails

#### **Teste 2: Criar Usuários**

1. **Login como Admin A:**
   - Crie Nutricionista N1
   - Crie Personal P1
   - Crie Aluno A1

2. **Logout e Login como Admin B:**
   - Crie Nutricionista N2
   - Crie Personal P2
   - Crie Aluno A2

#### **Teste 3: Verificar Isolamento**

1. **Login como Admin A:**
   - Deve ver: N1, P1, A1
   - **NÃO** deve ver: N2, P2, A2

2. **Login como Admin B:**
   - Deve ver: N2, P2, A2
   - **NÃO** deve ver: N1, P1, A1

#### **Teste 4: Tentar Editar/Excluir**

1. **Login como Admin A:**
   - Tente editar N1 ✅ (deve funcionar)
   - Tente excluir P1 ✅ (deve funcionar)

2. **Verificar Proteção RLS:**
   - Admin A não consegue ver usuários do Admin B
   - Portanto, não consegue nem tentar editar/excluir

---

### **PASSO 4: Verificar no Banco de Dados**

Execute estas queries no SQL Editor para verificar:

```sql
-- Ver todos os usuários e seus criadores
SELECT 
  u.name,
  u.email,
  u.role,
  u.created_by_admin_id,
  admin.name as criado_por
FROM public.users u
LEFT JOIN public.users admin ON u.created_by_admin_id = admin.id
ORDER BY u.created_at DESC;

-- Contar usuários por admin
SELECT 
  admin.name as admin_nome,
  admin.email as admin_email,
  COUNT(*) as total_usuarios
FROM public.users u
JOIN public.users admin ON u.created_by_admin_id = admin.id
GROUP BY admin.id, admin.name, admin.email;

-- Verificar políticas RLS ativas
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'users';
```

---

## 🔍 COMO FUNCIONA

### **1. Campo `created_by_admin_id`**

- Cada usuário tem um campo que aponta para o admin que o criou
- Para admins: `created_by_admin_id = seu próprio ID`
- Para outros usuários: `created_by_admin_id = ID do admin que criou`

### **2. Row Level Security (RLS)**

O Supabase automaticamente filtra os dados:

```
SELECT * FROM users
↓
Supabase aplica RLS automaticamente
↓
SELECT * FROM users WHERE created_by_admin_id = auth.uid()
```

### **3. Trigger Automático**

Ao inserir um novo usuário, o trigger preenche automaticamente:

```sql
-- Se for admin
created_by_admin_id = novo_usuario.id

-- Se for outro role
created_by_admin_id = auth.uid() (ID do admin logado)
```

---

## ⚠️ PROBLEMAS COMUNS

### **Problema 1: "Não consigo ver nenhum usuário"**

**Causa:** RLS está bloqueando tudo

**Solução:**
```sql
-- Verificar se você está logado
SELECT auth.uid();

-- Verificar seus usuários
SELECT * FROM users WHERE created_by_admin_id = auth.uid();

-- Temporariamente desabilitar RLS para debug (NÃO FAZER EM PRODUÇÃO!)
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
```

### **Problema 2: "Erro ao criar usuário"**

**Causa:** Trigger não está funcionando ou RLS bloqueando

**Solução:**
```sql
-- Verificar se trigger existe
SELECT * FROM information_schema.triggers WHERE event_object_table = 'users';

-- Verificar políticas
SELECT * FROM pg_policies WHERE tablename = 'users';
```

### **Problema 3: "Usuários antigos não aparecem"**

**Causa:** `created_by_admin_id` está NULL

**Solução:**
```sql
-- Atribuir ao primeiro admin
UPDATE public.users 
SET created_by_admin_id = (SELECT id FROM public.users WHERE role = 'admin' LIMIT 1)
WHERE created_by_admin_id IS NULL;
```

---

## 🔐 SEGURANÇA

### **O que está protegido:**

✅ Admin A não vê usuários do Admin B  
✅ Admin A não pode editar usuários do Admin B  
✅ Admin A não pode excluir usuários do Admin B  
✅ Proteção no nível do banco (não depende do app)  
✅ Impossível burlar via API direta  

### **O que NÃO está protegido:**

⚠️ Super Admin do Supabase vê tudo (normal)  
⚠️ Queries SQL diretas no dashboard (esperado)  

---

## 📊 MONITORAMENTO

### **Queries Úteis:**

```sql
-- Usuários sem admin (órfãos)
SELECT * FROM users WHERE created_by_admin_id IS NULL;

-- Admins e quantos usuários cada um criou
SELECT 
  admin.name,
  COUNT(*) as total
FROM users u
JOIN users admin ON u.created_by_admin_id = admin.id
WHERE admin.role = 'admin'
GROUP BY admin.id, admin.name;

-- Últimos usuários criados
SELECT 
  u.name,
  u.role,
  u.created_at,
  admin.name as criado_por
FROM users u
JOIN users admin ON u.created_by_admin_id = admin.id
ORDER BY u.created_at DESC
LIMIT 10;
```

---

## 🎯 CHECKLIST FINAL

Antes de considerar a implementação completa:

- [ ] Script SQL executado sem erros
- [ ] Coluna `created_by_admin_id` existe na tabela `users`
- [ ] Trigger `trigger_set_created_by_admin` está ativo
- [ ] 4 políticas RLS estão ativas (SELECT, INSERT, UPDATE, DELETE)
- [ ] Teste com 2 admins diferentes realizado
- [ ] Isolamento de dados confirmado
- [ ] Usuários antigos têm `created_by_admin_id` preenchido
- [ ] App Flutter compilando sem erros
- [ ] Testes de criação/edição/exclusão funcionando

---

## 📞 PRÓXIMOS PASSOS

Após implementação bem-sucedida:

1. **Documentar** para a equipe
2. **Treinar** usuários sobre o novo sistema
3. **Monitorar** logs de acesso
4. **Considerar** adicionar campo `academia_id` para futuras expansões
5. **Implementar** auditoria de ações (quem criou/editou/excluiu o quê)

---

## 🆘 SUPORTE

Se encontrar problemas:

1. Verifique os logs do Supabase
2. Execute as queries de verificação acima
3. Revise a documentação em `MULTI_TENANCY_IMPLEMENTATION.md`
4. Verifique se o script SQL foi executado completamente

---

**Status Atual:** 🟡 Aguardando execução do SQL no Supabase  
**Próxima Ação:** Executar `supabase_multi_tenancy.sql` no SQL Editor  
**Tempo Estimado:** 5-10 minutos
