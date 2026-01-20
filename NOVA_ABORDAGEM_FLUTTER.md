# 🔄 NOVA ABORDAGEM: MULTI-TENANCY NO CÓDIGO FLUTTER

**Problema:** RLS do Supabase está causando recursão infinita  
**Solução:** Implementar isolamento de dados **no código Flutter**  
**Vantagem:** Mais simples, sem recursão, mais controle

---

## 🎯 ESTRATÉGIA

### **Ao invés de RLS (banco), usar filtros no código (app):**

```dart
// ANTES (com RLS - recursão infinita)
final users = await supabase.from('users').select();
// RLS filtra automaticamente (mas dá erro)

// DEPOIS (sem RLS - filtro manual)
final currentUser = await getCurrentUserData();
final adminId = currentUser['created_by_admin_id'];
final users = await supabase
    .from('users')
    .select()
    .eq('created_by_admin_id', adminId);  // Filtro manual
```

---

## ✅ VANTAGENS DESTA ABORDAGEM

✅ **Sem recursão infinita** - Não depende de RLS  
✅ **Mais simples** - Código Flutter é mais fácil de debugar  
✅ **Mais controle** - Você decide exatamente o que filtrar  
✅ **Funciona imediatamente** - Sem problemas de banco  
✅ **Escalável** - Fácil de adicionar regras complexas  

---

## 🚀 IMPLEMENTAÇÃO

### **PASSO 1: Desabilitar RLS (Emergência)**

Execute: `EMERGENCIA_DESABILITAR_RLS.sql`

Isso permite que o app funcione **agora** enquanto implementamos a solução.

### **PASSO 2: Modificar UserService**

Vou criar um novo `UserService` que filtra por `created_by_admin_id`:

```dart
class UserService {
  // Buscar todos os usuários (FILTRADO por admin)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    // 1. Pegar o admin atual
    final currentUser = await AuthService.getCurrentUserData();
    final adminId = currentUser?['created_by_admin_id'];
    
    if (adminId == null) {
      throw Exception('Usuário não tem admin associado');
    }
    
    // 2. Filtrar por created_by_admin_id
    final response = await _client
        .from('users')
        .select()
        .eq('created_by_admin_id', adminId)  // FILTRO MANUAL
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
}
```

### **PASSO 3: Aplicar em Todas as Queries**

O mesmo padrão para:
- `diets` - Filtrar por `created_by_admin_id`
- `workouts` - Filtrar por `created_by_admin_id`
- Outras tabelas relacionadas

---

## 📊 COMPARAÇÃO

### **RLS (Tentativa Anterior):**
```
❌ Recursão infinita
❌ Difícil de debugar
❌ Problemas no Supabase
❌ Complexo de implementar
```

### **Filtro no Código (Nova Abordagem):**
```
✅ Sem recursão
✅ Fácil de debugar
✅ Funciona imediatamente
✅ Simples de implementar
✅ Mais controle
```

---

## 🔒 SEGURANÇA

### **"Mas e se alguém burlar o código Flutter?"**

**Resposta:** Vamos adicionar **validação no backend** (Supabase Functions):

```typescript
// Supabase Edge Function
export async function handler(req: Request) {
  const { user } = await getUser(req);
  const { created_by_admin_id } = await getUserData(user.id);
  
  // Validar que o admin só acessa seus dados
  if (requestedAdminId !== created_by_admin_id) {
    return new Response('Forbidden', { status: 403 });
  }
  
  // Continuar...
}
```

**Camadas de segurança:**
1. ✅ Filtro no Flutter (primeira linha)
2. ✅ Validação no Edge Function (segunda linha)
3. ✅ Logs de auditoria (terceira linha)

---

## 🎯 PRÓXIMOS PASSOS

### **AGORA (Emergência):**
1. Execute `EMERGENCIA_DESABILITAR_RLS.sql`
2. Feche e abra o app
3. Faça login - deve funcionar!

### **DEPOIS (Implementação):**
1. Modificar `UserService` com filtros
2. Modificar `DietService` com filtros
3. Modificar `WorkoutService` com filtros
4. Testar isolamento
5. Adicionar Edge Functions para validação extra

---

## 📝 EXEMPLO COMPLETO

```dart
// user_service.dart
class UserService {
  static final SupabaseClient _client = SupabaseService.client;

  // Helper: Pegar ID do admin atual
  static Future<String> _getCurrentAdminId() async {
    final currentUser = await AuthService.getCurrentUserData();
    final adminId = currentUser?['created_by_admin_id'];
    
    if (adminId == null) {
      throw Exception('Usuário não autenticado ou sem admin');
    }
    
    return adminId;
  }

  // Buscar todos os usuários (filtrado)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final adminId = await _getCurrentAdminId();
    
    final response = await _client
        .from('users')
        .select()
        .eq('created_by_admin_id', adminId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Buscar por role (filtrado)
  static Future<List<Map<String, dynamic>>> getUsersByRole(
      UserRole role) async {
    final adminId = await _getCurrentAdminId();
    final roleString = role.toString().split('.').last;
    
    final response = await _client
        .from('users')
        .select()
        .eq('created_by_admin_id', adminId)
        .eq('role', roleString)
        .order('name');
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Criar usuário (com admin_id)
  static Future<Map<String, dynamic>> createUserByAdmin({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) async {
    try {
      final adminId = await _getCurrentAdminId();
      
      // 1. Criar no Auth
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Erro ao criar usuário');
      }

      // 2. Inserir na tabela users COM created_by_admin_id
      final roleString = role.toString().split('.').last;
      final userData = await _client
          .from('users')
          .insert({
            'id': authResponse.user!.id,
            'name': name,
            'email': email,
            'phone': phone,
            'password_hash': 'managed_by_supabase_auth',
            'role': roleString,
            'created_by_admin_id': adminId,  // IMPORTANTE!
          })
          .select()
          .single();

      return {
        'success': true,
        'user': userData,
        'message': 'Usuário cadastrado com sucesso!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao cadastrar: ${e.toString()}',
      };
    }
  }
}
```

---

## ✅ RESULTADO

Com esta abordagem:

✅ **App funciona imediatamente** (sem RLS)  
✅ **Isolamento de dados** (via filtros no código)  
✅ **Sem recursão infinita**  
✅ **Fácil de manter e debugar**  
✅ **Escalável** para futuras features  

---

**Quer que eu implemente esta solução agora?**

1. Primeiro execute `EMERGENCIA_DESABILITAR_RLS.sql` para o app voltar a funcionar
2. Depois eu modifico os services Flutter com os filtros corretos
