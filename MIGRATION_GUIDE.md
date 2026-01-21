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

## 📋 CHECKLIST DE MIGRAÇÃO

### 1. ✅ Migration SQL
- [x] Arquivo criado: `supabase/migrations/CRITICAL_CNPJ_TO_ID_ACADEMIA.sql`
- [x] Adiciona coluna `id_academia` em todas as tabelas
- [x] Migra dados existentes
- [x] Atualiza todas as RLS Policies
- [x] Cria índices para performance

### 2. 🔄 Services a Atualizar

#### user_service.dart
- [ ] `_getCurrentAdminDetails()` - Retornar `id` ao invés de `cnpj_academia`
- [ ] `createUserByAdmin()` - Usar `id_academia` no token
- [ ] `getAllUsers()` - Filtrar por `id_academia`
- [ ] `getUsersByRole()` - Filtrar por `id_academia`
- [ ] `_getAcademyAddress()` - Buscar por `id_academia`

#### auth_service.dart
- [ ] `confirmRegistration()` - Salvar `id_academia` ao criar usuário
- [ ] `getCurrentUserData()` - Retornar `id_academia`
- [ ] `_getAcademyAddress()` - Buscar por `id_academia`

#### diet_service.dart
- [ ] `_getContext()` - Retornar `id_academia`
- [ ] `getStudentsForDiet()` - Filtrar por `id_academia`
- [ ] `createDiet()` - Salvar `id_academia`

#### workout_service.dart (similar ao diet_service)
- [ ] Filtrar alunos por `id_academia`
- [ ] Salvar `id_academia` em workouts

#### notice_service.dart
- [ ] `_getCurrentUserCNPJ()` → `_getCurrentUserAcademyId()`
- [ ] Todas as queries: usar `id_academia`

#### physical_assessment_service.dart
- [ ] `_getCurrentNutritionistCNPJ()` → `_getCurrentNutritionistAcademyId()`
- [ ] Salvar `id_academia` em assessments

#### financial_service.dart
- [ ] `_getCurrentAdminCNPJ()` → `_getCurrentAdminId()`
- [ ] Todas as queries: usar `id_academia`

### 3. 🎨 Screens a Atualizar

#### role_login_screen.dart
- [ ] Remover referência a `cnpj_academia`

#### student_dashboard.dart
- [ ] Usar `id_academia` ao invés de `cnpj_academia`

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
