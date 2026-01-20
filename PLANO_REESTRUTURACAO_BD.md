# 🏗️ REESTRUTURAÇÃO DO BANCO DE DADOS - PLANO COMPLETO

**Data:** 2026-01-17 18:05  
**Status:** 📋 Planejamento

---

## 🎯 OBJETIVO

Separar a tabela `users` em 4 tabelas específicas por perfil e adicionar campo "academia" para identificação da academia de cada usuário.

---

## 📊 ESTRUTURA ATUAL vs NOVA

### **ATUAL:**
```
users (única tabela)
├── id
├── name
├── email
├── role (admin/nutritionist/trainer/student)
├── created_by_admin_id
└── ...
```

### **NOVA:**
```
users_adm
├── id
├── academia (NOVO!)
├── nome
├── email
├── cnpj
├── cpf
├── telefone
├── endereco
└── ...

users_nutricionista
├── id
├── academia (NOVO!)
├── nome
├── email
├── telefone
├── created_by_admin_id
└── ...

users_personal
├── id
├── academia (NOVO!)
├── nome
├── email
├── telefone
├── created_by_admin_id
└── ...

users_alunos
├── id
├── academia (NOVO!)
├── nome
├── email
├── telefone
├── created_by_admin_id
└── ...
```

---

## 🔐 MULTI-TENANCY ATUALIZADO

### **Antes:**
- Isolamento por `created_by_admin_id`

### **Agora:**
- Isolamento por **`academia`** (nome da academia)
- Cada admin pertence a uma academia
- Todos os usuários criados herdam a academia do admin

---

## 📝 MUDANÇAS NECESSÁRIAS

### **1. SQL - Criar Novas Tabelas** ✅
- [ ] Criar `users_adm`
- [ ] Criar `users_nutricionista`
- [ ] Criar `users_personal`
- [ ] Criar `users_alunos`
- [ ] Adicionar RLS em todas
- [ ] Criar triggers de auditoria
- [ ] Migrar dados existentes (se houver)

### **2. SQL - RLS (Row Level Security)** ✅
- [ ] Políticas de SELECT por academia
- [ ] Políticas de INSERT por academia
- [ ] Políticas de UPDATE por academia
- [ ] Políticas de DELETE por academia

### **3. Flutter - Models** ✅
- [ ] Criar `UserAdm` model
- [ ] Criar `UserNutricionista` model
- [ ] Criar `UserPersonal` model
- [ ] Criar `UserAluno` model

### **4. Flutter - Services** ✅
- [ ] Atualizar `AuthService`
- [ ] Atualizar `UserService`
- [ ] Criar métodos específicos por tabela

### **5. Flutter - Screens** ✅
- [ ] Adicionar campo "Academia" no registro de admin
- [ ] Atualizar telas de criação de usuários
- [ ] Atualizar telas de listagem

### **6. Flutter - Dietas** ✅
- [ ] Atualizar `DietService` para usar novas tabelas
- [ ] Manter compatibilidade com sistema de dietas

---

## 🗂️ ESTRUTURA DAS NOVAS TABELAS

### **1. users_adm**
```sql
CREATE TABLE users_adm (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  academia TEXT NOT NULL,  -- Nome da academia
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  cnpj TEXT,
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
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  academia TEXT NOT NULL,  -- Herda do admin
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  created_by_admin_id UUID NOT NULL REFERENCES users_adm(id),
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### **3. users_personal**
```sql
CREATE TABLE users_personal (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  academia TEXT NOT NULL,  -- Herda do admin
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  created_by_admin_id UUID NOT NULL REFERENCES users_adm(id),
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### **4. users_alunos**
```sql
CREATE TABLE users_alunos (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  academia TEXT NOT NULL,  -- Herda do admin
  nome TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  telefone TEXT,
  created_by_admin_id UUID NOT NULL REFERENCES users_adm(id),
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 🔒 RLS (Row Level Security)

### **Política Geral:**
Cada usuário só vê dados da **sua academia**.

### **Exemplo para users_nutricionista:**
```sql
-- SELECT: Ver apenas nutricionistas da mesma academia
CREATE POLICY "nutricionista_select_policy" ON users_nutricionista
FOR SELECT
USING (
  academia = (
    SELECT academia FROM users_adm WHERE id = auth.uid()
    UNION ALL
    SELECT academia FROM users_nutricionista WHERE id = auth.uid()
    UNION ALL
    SELECT academia FROM users_personal WHERE id = auth.uid()
  )
);

-- INSERT: Apenas admin pode criar
CREATE POLICY "nutricionista_insert_policy" ON users_nutricionista
FOR INSERT
WITH CHECK (
  EXISTS (SELECT 1 FROM users_adm WHERE id = auth.uid())
);
```

---

## 🔄 FLUXO DE CADASTRO ATUALIZADO

### **1. Admin se cadastra:**
```
Formulário:
├── Nome
├── Email
├── Senha
├── Telefone
├── CNPJ
├── CPF
├── Endereço
└── Academia (NOVO!)  ← Nome da academia

Resultado:
└── Cria em users_adm com campo 'academia'
```

### **2. Admin cria Nutricionista:**
```
Formulário:
├── Nome
├── Email
├── Senha
└── Telefone

Sistema automaticamente:
├── Pega 'academia' do admin logado
├── Define created_by_admin_id
└── Cria em users_nutricionista
```

### **3. Admin cria Personal:**
```
Formulário:
├── Nome
├── Email
├── Senha
└── Telefone

Sistema automaticamente:
├── Pega 'academia' do admin logado
├── Define created_by_admin_id
└── Cria em users_personal
```

### **4. Admin cria Aluno:**
```
Formulário:
├── Nome
├── Email
├── Senha
└── Telefone

Sistema automaticamente:
├── Pega 'academia' do admin logado
├── Define created_by_admin_id
└── Cria em users_alunos
```

---

## 🎯 BENEFÍCIOS

1. **Organização:** Dados separados por perfil
2. **Performance:** Queries mais rápidas (tabelas menores)
3. **Segurança:** RLS por academia
4. **Escalabilidade:** Fácil adicionar campos específicos por perfil
5. **Multi-academia:** Suporte nativo para múltiplas academias

---

## ⚠️ PONTOS DE ATENÇÃO

### **1. Migração de Dados:**
- Se já existem usuários na tabela `users`, precisamos migrar
- Criar script de migração

### **2. Compatibilidade:**
- Atualizar TODAS as queries no código
- Atualizar sistema de dietas
- Atualizar sistema de treinos (futuro)

### **3. Confirmação de Email:**
- Manter funcionando para todos os perfis
- Atualizar token para incluir 'academia'

---

## 📋 ORDEM DE IMPLEMENTAÇÃO

### **Fase 1: Banco de Dados** (30 min)
1. Criar script SQL com novas tabelas
2. Adicionar RLS completo
3. Criar triggers de auditoria
4. Testar no Supabase

### **Fase 2: Models Flutter** (15 min)
1. Criar models para cada tabela
2. Adicionar campo 'academia'

### **Fase 3: Services Flutter** (45 min)
1. Atualizar AuthService
2. Atualizar UserService
3. Atualizar DietService
4. Criar métodos específicos

### **Fase 4: Screens Flutter** (30 min)
1. Adicionar campo "Academia" no registro admin
2. Atualizar criação de usuários
3. Testar fluxo completo

### **Fase 5: Testes** (30 min)
1. Testar cadastro de admin
2. Testar criação de nutricionista
3. Testar criação de personal
4. Testar criação de aluno
5. Testar sistema de dietas

**TEMPO TOTAL ESTIMADO:** ~2h30min

---

## ✅ CHECKLIST DE IMPLEMENTAÇÃO

- [ ] Criar SQL com novas tabelas
- [ ] Adicionar RLS completo
- [ ] Criar models Flutter
- [ ] Atualizar AuthService
- [ ] Atualizar UserService
- [ ] Adicionar campo "Academia" no registro
- [ ] Testar cadastro admin
- [ ] Testar criação nutricionista
- [ ] Testar criação personal
- [ ] Testar criação aluno
- [ ] Testar sistema de dietas
- [ ] Documentar mudanças

---

## 🚀 PRÓXIMO PASSO

**Você confirma essa estrutura?**

Se sim, vou começar criando:
1. Script SQL completo com as 4 tabelas + RLS
2. Models Flutter
3. Atualização dos Services
4. Atualização das Screens

**Posso começar?** 🎯

---

**Criado em:** 2026-01-17 18:05  
**Status:** Aguardando confirmação  
**Tempo estimado:** 2h30min
