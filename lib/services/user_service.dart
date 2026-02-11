import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/user_role.dart';

class UserService {
  static final SupabaseClient _client = SupabaseService.client;

  // Helper: Obter dados do admin atual para contexto (para pegar id_academia)
  static Future<Map<String, dynamic>> _getCurrentAdminDetails() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    // Tentar buscar na tabela de admins
    final admin = await _client
        .from('users_adm')
        .select()
        .eq('id', currentUser.id)
        .maybeSingle();

    if (admin != null) return admin;

    throw Exception('Apenas administradores podem realizar esta operação');
  }

  // Criar usuário pelo Admin (Nutricionista, Personal ou Aluno)
  static Future<Map<String, dynamic>> createUserByAdmin({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    String? birthDate,
    int? paymentDueDay, // Dia de vencimento (1-31, apenas para alunos)
    bool isPaidCurrentMonth = false, // Se já pagou o mês atual
    double? initialPaymentAmount, // Valor do pagamento inicial
  }) async {
    try {
      // 1. Obter dados do admin (Contexto da Academia)
      final adminDetails = await _getCurrentAdminDetails();
      final cnpjAcademia = adminDetails['cnpj_academia']; // Manter para o token
      final academia = adminDetails['academia'];
      final adminId = adminDetails['id']; // ID do admin = ID da academia
      final roleString = role.toString().split('.').last;

      print(
          '🔐 Cadastrando $roleString na academia $academia (Via RPC Direta)');

      // 4. Criar usuário via RPC (Direto no Banco)
      // Isso evita o envio de email automático do Supabase e já confirma o usuário
      // A Trigger do banco cuidará das tabelas públicas
      final response = await _client.rpc('create_user_v4', params: {
        'p_email': email.trim(),
        'p_password': password,
        'p_metadata': {
          'role': roleString,
          'name': name.trim(),
          'phone': phone.trim(),
          'academia': academia,
          'id_academia': adminId, // ID da academia = ID do admin
          'cnpj_academia': cnpjAcademia,
          'created_by_admin_id': adminId,
          if (paymentDueDay != null) 'paymentDueDay': paymentDueDay,
          if (isPaidCurrentMonth) 'isPaidCurrentMonth': true,
        }
      });

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Erro desconhecido na RPC');
      }

      // Se marcou como "Pago este mês", criar transação para liberar acesso imediatamente
      if (isPaidCurrentMonth && role == UserRole.student) {
        try {
          final newUserId = response['user_id'];
          final amount = initialPaymentAmount ?? 0.0;

          await _client.from('financial_transactions').insert({
            'id_academia': adminId,
            'description':
                'Mensalidade Inicial - $name', // Incluindo nome do aluno
            'amount': amount,
            'type': 'income',
            'category': 'Mensalidade',
            'transaction_date': DateTime.now().toIso8601String().split('T')[0],
            'related_user_id': newUserId,
            'related_user_role': 'student',
          });
          print('💰 Transação inicial registrada: R\$ $amount - Aluno: $name');
        } catch (e) {
          print('⚠️ Erro ao registrar pagamento inicial: $e');
        }
      }

      print('✅ Usuário criado via RPC (Sem email disparado)');

      return {
        'success': true,
        'message': 'Usuário cadastrado com sucesso! Acesso liberado.',
        'requiresVerification': false,
      };
    } catch (e) {
      print('❌ Erro no cadastro RPC: $e');
      return {
        'success': false,
        'message': 'Erro ao cadastrar: ${e.toString()}',
      };
    }
  }

  // Helper: Normalizar dados do usuário (mapear colunas PT -> EN)
  static Map<String, dynamic> _normalizeUser(
      Map<String, dynamic> user, String role) {
    final normalized = Map<String, dynamic>.from(user);
    normalized['role'] = role;
    if (user.containsKey('nome')) normalized['name'] = user['nome'];
    if (user.containsKey('telefone')) normalized['phone'] = user['telefone'];
    normalized['is_blocked'] = user['is_blocked'] ?? false;
    if (user.containsKey('payment_due')) {
      normalized['payment_due_day'] = user['payment_due'];
    }
    if (user.containsKey('payment_due_day')) {
      normalized['payment_due_day'] = user['payment_due_day'];
    }
    return normalized;
  }

  // Buscar todos os usuários da academia do admin logado
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final adminDetails = await _getCurrentAdminDetails();
      final idAcademia = adminDetails['id']; // ID do admin = ID da academia

      // Buscar em paralelo nas 4 tabelas filtrando por ID da Academia
      final adminsF = _client.from('users_adm').select().eq('id', idAcademia);
      final nutrisF = _client
          .from('users_nutricionista')
          .select()
          .eq('id_academia', idAcademia);
      final trainersF =
          _client.from('users_personal').select().eq('id_academia', idAcademia);
      final studentsF =
          _client.from('users_alunos').select().eq('id_academia', idAcademia);

      final results =
          await Future.wait([adminsF, nutrisF, trainersF, studentsF]);

      // Combinar e normalizar
      final allUsers = [
        ...results[0].map((u) => _normalizeUser(u, 'admin')),
        ...results[1].map((u) => _normalizeUser(u, 'nutritionist')),
        ...results[2].map((u) => _normalizeUser(u, 'trainer')),
        ...results[3].map((u) => _normalizeUser(u, 'student')),
      ];

      // Ordenar por data de criação (mais recente primeiro)
      allUsers.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      return allUsers;
    } catch (e) {
      print('Erro ao buscar usuários: $e');
      return [];
    }
  }

  // Buscar usuário por ID (varre todas as tabelas)
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      // 1. Admin
      final admin = await _client
          .from('users_adm')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (admin != null) return _normalizeUser(admin, 'admin');

      // 2. Nutri
      final nutri = await _client
          .from('users_nutricionista')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (nutri != null) return _normalizeUser(nutri, 'nutritionist');

      // 3. Personal
      final personal = await _client
          .from('users_personal')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (personal != null) return _normalizeUser(personal, 'trainer');

      // 4. Aluno
      final aluno = await _client
          .from('users_alunos')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (aluno != null) return _normalizeUser(aluno, 'student');

      return null;
    } catch (e) {
      print('Erro ao buscar usuário: $e');
      return null;
    }
  }

  // Buscar usuários por role
  static Future<List<Map<String, dynamic>>> getUsersByRole(
      UserRole role) async {
    try {
      final adminDetails = await _getCurrentAdminDetails();
      final idAcademia = adminDetails['id']; // ID do admin = ID da academia
      final roleString = role.toString().split('.').last;

      String tableName;
      if (role == UserRole.admin)
        tableName = 'users_adm';
      else if (role == UserRole.nutritionist)
        tableName = 'users_nutricionista';
      else if (role == UserRole.trainer)
        tableName = 'users_personal';
      else
        tableName = 'users_alunos';

      final response = await _client
          .from(tableName)
          .select()
          .eq('id_academia', idAcademia)
          .order('nome'); // Campo 'nome' existe em todas agora

      return List<Map<String, dynamic>>.from(
          response.map((u) => _normalizeUser(u, roleString)));
    } catch (e) {
      print('Erro ao buscar usuários por role: $e');
      return [];
    }
  }

  // Atualizar usuário
  static Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? name,
    String? email,
    String? phone,
    UserRole?
        role, // Role vindo para saber qual tabela usar (ou opcional se buscarmos antes)
    int? paymentDueDay, // Novo parâmetro para dia de vencimento
  }) async {
    try {
      // Se o role não foi passado, precisamos descobrir quem é o usuário
      String? roleString;
      if (role != null) {
        roleString = role.toString().split('.').last;
      } else {
        final existingUser = await getUserById(userId);
        if (existingUser == null) throw Exception('Usuário não encontrado');
        roleString = existingUser['role'];
      }

      String tableName;
      if (roleString == 'admin')
        tableName = 'users_adm';
      else if (roleString == 'nutritionist')
        tableName = 'users_nutricionista';
      else if (roleString == 'trainer')
        tableName = 'users_personal';
      else
        tableName = 'users_alunos';

      // Se o email foi alterado, atualizar em auth.users também
      if (email != null) {
        print('📧 [DEBUG] Atualizando email em auth.users via RPC...');
        await _client.rpc('admin_update_user_credentials', params: {
          'target_user_id': userId,
          'new_email': email,
          'new_password': null,
        });
      }

      final Map<String, dynamic> updates = {};
      if (name != null) updates['nome'] = name; // Agora é 'nome' em todas
      if (email != null) updates['email'] = email;
      if (phone != null)
        updates['telefone'] = phone; // Agora é 'telefone' em todas

      // Se for aluno e tiver dia de vencimento, atualiza
      if (tableName == 'users_alunos' && paymentDueDay != null) {
        updates['payment_due'] = paymentDueDay;
      }

      final response = await _client
          .from(tableName)
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return {
        'success': true,
        'user': response,
        'message': 'Usuário atualizado com sucesso',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao atualizar usuário: ${e.toString()}',
      };
    }
  }

  // Deletar usuário (Via RPC Segura)
  static Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      print('🗑️ Excluindo usuário via RPC direto: $userId');

      // A função delete_user_complete tem 'security definer',
      // então ela consegue deletar de auth.users mesmo chamada pelo app.
      await _client
          .rpc('delete_user_complete', params: {'target_user_id': userId});

      return {'success': true, 'message': 'Usuário excluído com sucesso!'};
    } catch (e) {
      print('❌ Erro ao deletar usuário: $e');
      return {'success': false, 'message': 'Erro ao excluir: ${e.toString()}'};
    }
  }

  // Buscar alunos de um nutricionista (Corrigido para nova estrutura)
  static Future<List<Map<String, dynamic>>> getStudentsByNutritionist(
      String nutritionistId) async {
    try {
      // 1. Buscar dietas deste nutricionista
      final diets = await _client
          .from('diets') // Tabela diets
          .select('student_id')
          .eq('nutritionist_id', nutritionistId);

      // 2. Extrair IDs dos alunos
      final List<String> studentIds = List<String>.from((diets as List)
          .map((d) => d['student_id'].toString())
          .toSet()
          .toList());

      if (studentIds.isEmpty) return [];

      // 3. Buscar alunos na tabela users_alunos
      // Nota: 'in' filter espera uma lista separada por vírgula em string para o SDK antigo, ou lista no novo
      final students = await _client
          .from('users_alunos')
          .select()
          .inFilter('id', studentIds)
          .order('nome'); // Ordenação alfabética

      return List<Map<String, dynamic>>.from(
          students.map((s) => {...s, 'role': 'student'}));
    } catch (e) {
      print('Erro getStudentsByNutritionist: $e');
      return [];
    }
  }

  // Buscar alunos para staff (usando RPC segura)
  // Buscar alunos para staff (Lógica Manual para garantir filtro por id_academia)
  static Future<List<Map<String, dynamic>>> getStudentsForStaff() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      String? idAcademia;

      // 1. Tentar encontrar como Admin
      final admin = await _client
          .from('users_adm')
          .select('id') // Admin ID é o id_academia
          .eq('id', user.id)
          .maybeSingle();
      if (admin != null) {
        idAcademia = admin['id'];
      }

      // 2. Tentar encontrar como Nutricionista
      if (idAcademia == null) {
        final nutri = await _client
            .from('users_nutricionista')
            .select('id_academia')
            .eq('id', user.id)
            .maybeSingle();
        if (nutri != null) {
          idAcademia = nutri['id_academia'];
        }
      }

      // 3. Tentar encontrar como Personal
      if (idAcademia == null) {
        final personal = await _client
            .from('users_personal')
            .select('id_academia')
            .eq('id', user.id)
            .maybeSingle();
        if (personal != null) {
          idAcademia = personal['id_academia'];
        }
      }

      if (idAcademia == null) {
        print('⚠️ Usuário não encontrado em nenhuma tabela de staff.');
        return [];
      }

      // 4. Buscar alunos desta academia
      final data = await _client
          .from('users_alunos')
          .select('id, nome, email, telefone, cnpj_academia')
          .eq('id_academia', idAcademia)
          .order('nome');

      // Normalizar campos (nome→name, telefone→phone) e adicionar role
      final students = (data as List).map((d) {
        final Map<String, dynamic> student =
            Map<String, dynamic>.from(d as Map);
        return {
          'id': student['id'],
          'name': student['nome'], // Normalizar
          'email': student['email'],
          'phone': student['telefone'], // Normalizar
          'cnpj_academia': student['cnpj_academia'],
          'role': 'student',
        };
      }).toList();

      return students;
    } catch (e) {
      print('❌ Erro ao buscar alunos (Manual): $e');
      return [];
    }
  }

  // Alternar status de bloqueio do usuário
  static Future<Map<String, dynamic>> toggleUserBlockStatus(
      String userId, String role, bool currentStatus) async {
    try {
      String tableName;
      if (role == 'admin')
        tableName = 'users_adm';
      else if (role == 'nutritionist')
        tableName = 'users_nutricionista';
      else if (role == 'trainer')
        tableName = 'users_personal';
      else
        tableName = 'users_alunos';

      final newStatus = !currentStatus;

      await _client
          .from(tableName)
          .update({'is_blocked': newStatus}).eq('id', userId);

      return {
        'success': true,
        'message':
            'Usuário ${newStatus ? "bloqueado" : "desbloqueado"} com sucesso',
        'is_blocked': newStatus
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao alterar status: ${e.toString()}'
      };
    }
  }

  // Admin altera senha de um usuário manualmente
  static Future<Map<String, dynamic>> adminUpdateUserPassword(
      String userId, String newPassword) async {
    try {
      print('🔐 Admin alterando senha do usuário: $userId');

      // Chama RPC para atualizar senha no auth.users sem enviar email
      await _client.rpc('admin_update_user_credentials', params: {
        'target_user_id': userId,
        'new_email': null,
        'new_password': newPassword,
      });

      return {'success': true, 'message': 'Senha alterada com sucesso!'};
    } catch (e) {
      print('❌ Erro ao alterar senha: $e');
      return {'success': false, 'message': 'Erro ao alterar senha: $e'};
    }
  }

  // Verificar status de limite do plano (para exibir alertas)
  static Future<Map<String, dynamic>> checkPlanLimitStatus() async {
    try {
      final adminDetails = await _getCurrentAdminDetails();
      final idAcademia = adminDetails['id'];
      final plan = adminDetails['plano_mensal']?.toString() ?? 'Prata';

      // Definir limites
      int limit = 200; // Prata default
      if (plan.toLowerCase() == 'ouro') limit = 500;
      if (plan.toLowerCase() == 'platina') limit = 999999;

      final count = await _client
          .from('users_alunos')
          .count(CountOption.exact)
          .eq('id_academia', idAcademia);

      print('📊 Status Plano: $plan | Alunos: $count | Limite: $limit');

      return {
        'count': count,
        'limit': limit,
        'isAtLimit': count >= limit,
        'plan': plan,
      };
    } catch (e) {
      print('Erro ao verificar limite: $e');
      return {'count': 0, 'limit': 200, 'isAtLimit': false, 'plan': 'Prata'};
    }
  }

  // Buscar status de assinatura do administrador
  static Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final adminDetails = await _getCurrentAdminDetails();

      return {
        'success': true,
        'plano': adminDetails['plano_mensal'] ?? 'Prata',
        'status': adminDetails['assinatura_status'] ?? 'active',
        'iniciada': adminDetails['assinatura_iniciada'],
        'expirada': adminDetails['assinatura_expirada'],
        'tolerancia': adminDetails['assinatura_tolerancia'],
        'deletada': adminDetails['assinatura_deletada'],
        'stripeCustomerId': adminDetails['stripe_customer_id'],
      };
    } catch (e) {
      print('Erro ao buscar status de assinatura: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
