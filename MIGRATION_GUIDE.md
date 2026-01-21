# GUIA DE MIGRAÇÃO: CNPJ_ACADEMIA → ID_ACADEMIA

## 🔴 PROBLEMA CRÍTICO IDENTIFICADO

Múltiplas academias estão compartilhando dados porque o sistema usa `cnpj_academia` como identificador único.
Isso é **INCORRETO** pois:
- Um mesmo CNPJ pode ter múltiplas filiais/franquias
- Academias diferentes com mesmo CNPJ veem dados umas das outras
- **VIOLAÇÃO GRAVE DE PRIVACIDADE E SEGURANÇA**

## ✅ SOLUÇÃO

Usar `id_academia` (que é o `id` do administrador na tabela `users_adm`) como identificador único.

### Por que `id_academia` = `users_adm.id`?
- Cada administrador tem um ID único (UUID)
- Esse ID representa UMA academia específica
- É imutável e garante isolamento total

### 4. Correção de Erros de Nulo (CRÍTICO)
Se você encontrar erros como `null value in column "cnpj_academia"`, execute o script:
`supabase/migrations/FIX_NULL_CNPJ_ERRORS.sql`

Isso tornará a coluna antiga opcional, permitindo que o sistema funcione apenas com `id_academia`.

### 5. Otimização de Performance (NOVO)
Para corrigir lentidão no carregamento e salvamento de dados, execute o script:
`supabase/migrations/PERFORMANCE_INDEXES.sql`

Isso criará índices essenciais para o campo `id_academia` e chaves estrangeiras.

## 📋 CHECKLIST DE MIGRAÇÃO

### 1. ✅ Migration SQL
- [x] Arquivo criado: `supabase/migrations/CRITICAL_CNPJ_TO_ID_ACADEMIA.sql`
- [x] Adiciona coluna `id_academia` em todas as tabelas
- [x] Migra dados existentes
- [x] Atualiza todas as RLS Policies
- [x] Cria índices para performance

### 2. 🔄 Services a Atualizar (✅ CONCLUÍDO)

#### user_service.dart
- [x] `_getCurrentAdminDetails()` - Retornar `id` ao invés de `cnpj_academia`
- [x] `createUserByAdmin()` - Usar `id_academia` no token
- [x] `getAllUsers()` - Filtrar por `id_academia`
- [x] `getUsersByRole()` - Filtrar por `id_academia`
- [x] `_getAcademyAddress()` - Buscar por `id_academia`

#### auth_service.dart
- [x] `confirmRegistration()` - Salvar `id_academia` ao criar usuário
- [x] `getCurrentUserData()` - Retornar `id_academia`
- [x] `_getAcademyAddress()` - Buscar por `id_academia`

#### diet_service.dart
- [x] `_getContext()` - Retornar `id_academia`
- [x] `getStudentsForDiet()` - Filtrar por `id_academia`
- [x] `createDiet()` - Salvar `id_academia`

#### workout_service.dart
- [x] `createWorkout` - Salvar `id_academia`
- [x] `getWorkouts` - Validado

#### notice_service.dart
- [x] `_getCurrentUserCNPJ()` → `_getCurrentUserAcademyId()`
- [x] Todas as queries: usar `id_academia`

#### physical_assessment_service.dart
- [x] `_getCurrentNutritionistCNPJ()` → `_getCurrentNutritionistAcademyId()`
- [x] Salvar `id_academia` em assessments

#### financial_service.dart
- [x] `_getCurrentAdminCNPJ()` → `_getCurrentAdminId()`
- [x] Todas as queries: usar `id_academia`

### 3. 🎨 Screens a Atualizar (✅ CONCLUÍDO)

#### role_login_screen.dart
- [x] Remover referência a `cnpj_academia` (Atualizado para usar `id_academia` na verificação de pendência)

#### student_dashboard.dart
- [x] Usar `id_academia` ao invés de `cnpj_academia` na verificação de pendência

### 4. 🧪 Testes Necessários

Após migração, testar:
- [ ] Admin A não vê usuários do Admin B
- [ ] Nutricionista A não vê alunos da Academia B
- [ ] Personal A não vê treinos da Academia B
- [ ] Avisos são isolados por academia
- [ ] Dietas são isoladas por academia
- [ ] Avaliações físicas são isoladas por academia

## 🚀 ORDEM DE EXECUÇÃO

1. **BACKUP DO BANCO** (CRÍTICO!)
2. Executar migration SQL no Supabase
3. Atualizar services (começar por auth_service e user_service)
4. Atualizar screens
5. Testar isolamento
6. Commit e deploy

## ⚠️ ATENÇÃO

- **NÃO DELETAR** a coluna `cnpj_academia` ainda (manter para referência)
- Após confirmar que tudo funciona, podemos remover `cnpj_academia`
- Fazer backup antes de executar a migration!
