# 🚀 PLANO DE IMPLEMENTAÇÃO - FASES RESTANTES

**Status Atual:** ✅ SQL executado | ✅ Models criados  
**Próximo:** Services, Screens e Testes

---

## ✅ CONCLUÍDO

- [x] **FASE 1:** Script SQL com 4 tabelas + RLS ✅
- [x] **FASE 2:** Models Flutter (4 models) ✅

---

## 🔜 PRÓXIMAS FASES

### **FASE 3: Atualizar AuthService** (30 min)

**Arquivo:** `lib/services/auth_service.dart`

**Mudanças necessárias:**

1. **Método `register` (Admin):**
   - Adicionar campo `cnpjAcademia`
   - Adicionar campo `academia`
   - Salvar em `users_adm` ao invés de `users`

2. **Método `confirmRegistration`:**
   - Extrair `cnpj_academia` e `academia` do token
   - Salvar na tabela correta baseado no role
   - `admin` → `users_adm`
   - `nutritionist` → `users_nutricionista`
   - `trainer` → `users_personal`
   - `student` → `users_alunos`

3. **Método `getCurrentUserData`:**
   - Buscar em todas as 4 tabelas
   - Retornar dados da tabela correta

---

### **FASE 4: Atualizar UserService** (45 min)

**Arquivo:** `lib/services/user_service.dart`

**Mudanças necessárias:**

1. **Método `createUserByAdmin`:**
   - Pegar `cnpj_academia` e `academia` do admin logado
   - Passar no token para confirmação de email
   - Salvar na tabela correta:
     - `nutritionist` → `users_nutricionista`
     - `trainer` → `users_personal`
     - `student` → `users_alunos`

2. **Método `getAllUsers`:**
   - Buscar de todas as 4 tabelas
   - Filtrar por `cnpj_academia` do usuário logado
   - Combinar resultados

3. **Método `getUsersByRole`:**
   - Buscar da tabela específica do role
   - Filtrar por `cnpj_academia`

4. **Método `getUserById`:**
   - Buscar em todas as 4 tabelas
   - Retornar da tabela que encontrar

---

### **FASE 5: Atualizar DietService** (15 min)

**Arquivo:** `lib/services/diet_service.dart`

**Mudanças necessárias:**

1. **Método `createDiet`:**
   - Adicionar `cnpj_academia` e `academia` do nutricionista
   - Salvar na tabela `diets`

2. **Método `getDietsByNutritionist`:**
   - Filtrar por `cnpj_academia` também

---

### **FASE 6: Atualizar Screens** (30 min)

**Arquivos a modificar:**

1. **`lib/screens/register_screen.dart`:**
   - Adicionar campo "CNPJ da Academia"
   - Adicionar campo "Nome da Academia"
   - Passar para `AuthService.register`

2. **`lib/screens/admin/create_user_screen.dart`:**
   - Não precisa adicionar campos (herda do admin)
   - Apenas atualizar chamada do service

3. **`lib/screens/nutritionist/create_diet_screen.dart`:**
   - Não precisa mudar (service já pega academia)

---

### **FASE 7: Testes** (30 min)

**Fluxo de teste completo:**

1. **Cadastrar Admin:**
   - CNPJ Academia: "12.345.678/0001-90"
   - Academia: "Academia Fitness Pro"
   - Nome: "João Admin"
   - Email: admin@academia.com
   - Confirmar email
   - Fazer login

2. **Admin cria Nutricionista:**
   - Nome: "Maria Nutri"
   - Email: nutri@academia.com
   - Confirmar email
   - Fazer login

3. **Nutricionista cria Dieta:**
   - Selecionar aluno
   - Criar dieta
   - Verificar que tem cnpj_academia e academia

4. **Verificar isolamento:**
   - Criar outro admin (outra academia)
   - Verificar que não vê dados da primeira academia

---

## 📋 CHECKLIST COMPLETO

### **Banco de Dados:**
- [x] Criar 4 tabelas
- [x] Adicionar cnpj_academia
- [x] Adicionar RLS
- [x] Executar no Supabase

### **Models:**
- [x] UserAdm
- [x] UserNutricionista
- [x] UserPersonal
- [x] UserAluno

### **Services:**
- [ ] AuthService.register (adicionar cnpj_academia)
- [ ] AuthService.confirmRegistration (salvar em tabela correta)
- [ ] AuthService.getCurrentUserData (buscar em 4 tabelas)
- [ ] UserService.createUserByAdmin (passar academia)
- [ ] UserService.getAllUsers (buscar de 4 tabelas)
- [ ] UserService.getUsersByRole (tabela específica)
- [ ] DietService.createDiet (adicionar academia)

### **Screens:**
- [ ] RegisterScreen (adicionar campos academia)
- [ ] CreateUserScreen (atualizar chamada)
- [ ] CreateDietScreen (já funciona)

### **Testes:**
- [ ] Cadastro de admin
- [ ] Confirmação de email admin
- [ ] Login admin
- [ ] Criação de nutricionista
- [ ] Confirmação de email nutricionista
- [ ] Login nutricionista
- [ ] Criação de dieta
- [ ] Isolamento por academia

---

## 🎯 PRÓXIMOS PASSOS IMEDIATOS

1. **Atualizar AuthService:**
   - Modificar `register` para incluir cnpj_academia e academia
   - Modificar `confirmRegistration` para salvar em tabela correta

2. **Atualizar UserService:**
   - Modificar `createUserByAdmin` para passar academia
   - Modificar queries para usar tabelas específicas

3. **Atualizar RegisterScreen:**
   - Adicionar campos de academia

4. **Testar tudo!**

---

## ⚠️ IMPORTANTE

**Confirmação de Email:**
- Precisa funcionar para TODOS os perfis
- Token deve incluir: cnpj_academia, academia, role
- Deep link deve abrir app corretamente

**Multi-tenancy:**
- Filtrar SEMPRE por cnpj_academia
- Nunca mostrar dados de outras academias

**Segurança:**
- RLS está ativo
- Policies estão configuradas
- Audit logs funcionando

---

## 📚 ARQUIVOS DE REFERÊNCIA

**Ponto de Restauração:**
- `PONTO_RESTAURACAO_MACACO.md` 🐵

**SQL:**
- `REESTRUTURACAO_BD_COMPLETA.sql`

**Documentação:**
- `RESUMO_CNPJ_ACADEMIA.md`
- `PLANO_REESTRUTURACAO_BD.md`

---

**Status:** 40% completo (2/5 fases)  
**Tempo restante estimado:** ~2 horas  
**Próximo:** Atualizar Services
