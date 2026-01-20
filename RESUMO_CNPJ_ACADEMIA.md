# ✅ SCRIPT SQL ATUALIZADO COM CNPJ_ACADEMIA

**Data:** 2026-01-17 18:14  
**Arquivo:** `REESTRUTURACAO_BD_COMPLETA.sql`

---

## 📊 ESTRUTURA FINAL DAS TABELAS

### **1. users_adm**
```sql
CREATE TABLE users_adm (
  id UUID PRIMARY KEY,
  cnpj_academia TEXT NOT NULL,  -- ✅ NOVO! CNPJ da academia
  academia TEXT NOT NULL,        -- Nome da academia
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  cnpj TEXT,                     -- CNPJ do administrador (pessoa)
  cpf TEXT,
  endereco TEXT,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### **2. users_nutricionista**
```sql
CREATE TABLE users_nutricionista (
  id UUID PRIMARY KEY,
  cnpj_academia TEXT NOT NULL,  -- ✅ NOVO! Herda do admin
  academia TEXT NOT NULL,        -- Herda do admin
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  created_by_admin_id UUID NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### **3. users_personal**
```sql
CREATE TABLE users_personal (
  id UUID PRIMARY KEY,
  cnpj_academia TEXT NOT NULL,  -- ✅ NOVO! Herda do admin
  academia TEXT NOT NULL,        -- Herda do admin
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  created_by_admin_id UUID NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### **4. users_alunos**
```sql
CREATE TABLE users_alunos (
  id UUID PRIMARY KEY,
  cnpj_academia TEXT NOT NULL,  -- ✅ NOVO! Herda do admin
  academia TEXT NOT NULL,        -- Herda do admin
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  created_by_admin_id UUID NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### **5. diets (atualizada)**
```sql
ALTER TABLE diets ADD COLUMN cnpj_academia TEXT;  -- ✅ NOVO!
ALTER TABLE diets ADD COLUMN academia TEXT;
```

---

## 🔑 DIFERENÇA ENTRE CNPJ_ACADEMIA E CNPJ

### **cnpj_academia:**
- CNPJ da **academia** (empresa)
- Mesmo para todos os usuários da mesma academia
- Usado para multi-tenancy
- Exemplo: "12.345.678/0001-90"

### **cnpj (apenas em users_adm):**
- CNPJ do **administrador** (pessoa jurídica)
- Pode ser diferente do CNPJ da academia
- Opcional
- Exemplo: "98.765.432/0001-10"

---

## 🔄 FLUXO DE CADASTRO

### **1. Admin se cadastra:**
```
Formulário:
├── CNPJ da Academia (NOVO!)  ← "12.345.678/0001-90"
├── Nome da Academia          ← "Academia Fitness Pro"
├── Nome                      ← "João Silva"
├── Email                     ← "joao@academia.com"
├── Telefone                  ← "11999999999"
├── CNPJ (pessoa)            ← "98.765.432/0001-10" (opcional)
├── CPF                       ← "123.456.789-00"
└── Endereço                  ← "Rua X, 123"

Resultado em users_adm:
├── cnpj_academia: "12.345.678/0001-90"
├── academia: "Academia Fitness Pro"
├── nome: "João Silva"
├── cnpj: "98.765.432/0001-10"
└── ...
```

### **2. Admin cria Nutricionista:**
```
Formulário:
├── Nome      ← "Maria Nutricionista"
├── Email     ← "maria@academia.com"
├── Telefone  ← "11988888888"
└── Senha     ← "123456"

Sistema automaticamente:
├── Pega cnpj_academia do admin: "12.345.678/0001-90"
├── Pega academia do admin: "Academia Fitness Pro"
└── Define created_by_admin_id

Resultado em users_nutricionista:
├── cnpj_academia: "12.345.678/0001-90" (herdado)
├── academia: "Academia Fitness Pro" (herdado)
├── nome: "Maria Nutricionista"
└── ...
```

---

## 🔐 MULTI-TENANCY

### **Isolamento por CNPJ da Academia:**

Cada academia tem um CNPJ único, garantindo isolamento total:

```sql
-- Exemplo: Ver apenas nutricionistas da mesma academia
SELECT * FROM users_nutricionista
WHERE cnpj_academia = (
  SELECT cnpj_academia FROM users_adm WHERE id = auth.uid()
);
```

### **Benefícios:**
- ✅ Isolamento por CNPJ (mais seguro que nome)
- ✅ Suporte para múltiplas academias
- ✅ Fácil auditoria e relatórios
- ✅ Compliance com LGPD

---

## 📋 ÍNDICES CRIADOS

```sql
-- users_adm
idx_users_adm_cnpj_academia  -- ✅ NOVO!
idx_users_adm_academia
idx_users_adm_email

-- users_nutricionista
idx_users_nutricionista_academia
idx_users_nutricionista_admin
idx_users_nutricionista_email

-- users_personal
idx_users_personal_academia
idx_users_personal_admin
idx_users_personal_email

-- users_alunos
idx_users_alunos_academia
idx_users_alunos_admin
idx_users_alunos_email

-- diets
idx_diets_cnpj_academia  -- ✅ NOVO!
idx_diets_academia
```

---

## ✅ PRÓXIMOS PASSOS

1. **Executar script SQL no Supabase** ✅
2. **Criar Models Flutter** (próximo)
3. **Atualizar Services** (próximo)
4. **Atualizar Screens** (próximo)
5. **Testar** (próximo)

---

## 🎯 EXECUTE O SCRIPT

**Copie todo o conteúdo de `REESTRUTURACAO_BD_COMPLETA.sql` e execute no Supabase SQL Editor!**

Depois me avise para continuar com os Models Flutter.

---

**Criado em:** 2026-01-17 18:14  
**Atualizado:** Adicionado cnpj_academia em todas as tabelas  
**Status:** ✅ Pronto para executar no Supabase
