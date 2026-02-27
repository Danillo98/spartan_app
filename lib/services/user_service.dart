import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'auth_service.dart';
import 'cache_manager.dart';
import '../models/user_role.dart';

class UserService {
  static final SupabaseClient _client = SupabaseService.client;

  // Obter o contexto da academia do usuário logado
  // OTIMIZADO: Usa cache do AuthService em vez de 3-4 queries sequenciais
  static Future<Map<String, dynamic>> _getAcademyContext() async {
    // AuthService.getCurrentUserData() usa cache em memória - 0 queries se já carregado
    final userData = await AuthService.getCurrentUserData();
    if (userData == null) throw Exception('Usuário não autenticado');

    final role = userData['role'] as String? ?? 'trainer';
    final idAcademia = userData['id_academia'] ?? userData['id'];

    if (idAcademia == null) {
      throw Exception('Não foi possível vincular seu perfil a uma academia.');
    }

    return {
      'id_academia': idAcademia,
      'role': role,
      'academia_name': userData['academia'] ?? '',
      'cnpj_academia': userData['cnpj_academia'] ?? userData['cnpj'] ?? '',
    };
  }

  // Criar usuário pelo Admin (Nutricionista, Personal ou Aluno)
  static Future<Map<String, dynamic>> createUserByAdmin({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    String? birthDate,
    int? paymentDueDay, // Dia desejado (sistema somará +3 automaticamente)
    bool isPaidCurrentMonth = false, // Se já pagou o mês atual
    double? initialPaymentAmount, // Valor do pagamento inicial
  }) async {
    try {
      // 1. Obter dados do contexto da academia do usuário logado
      final academyContext = await _getAcademyContext();
      final idAcademia = academyContext['id_academia'];
      final academiaName = academyContext['academia_name'];
      final createdByAdminId =
          _client.auth.currentUser!.id; // ID do usuário logado que está criando
      final roleString = role.toString().split('.').last;

      print(
          '🔐 Cadastrando $roleString na academia $academiaName (Via RPC Direta)');

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
          'academia': academiaName,
          'cnpj_academia': academyContext['cnpj_academia'],
          'id_academia': idAcademia,
          'created_by_admin_id': createdByAdminId,
          if (birthDate != null) 'birthDate': birthDate,
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
            'id_academia': idAcademia,
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
        'user_id':
            response['user_id'], // Essencial para o popup facial no desktop
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
    if (user.containsKey('payment_due_day')) {
      normalized['payment_due_day'] = user['payment_due_day'];
    }
    // Novo status master do banco
    if (user.containsKey('status_financeiro')) {
      normalized['status_financeiro'] = user['status_financeiro'];
    }
    if (user.containsKey('data_nascimento')) {
      normalized['birth_date'] = user['data_nascimento'];
    }
    return normalized;
  }

  // Buscar todos os usuários da academia do admin logado
  // Helper para buscar todos os registros com paginação automática (Chunk Fetch)
  static Future<List<Map<String, dynamic>>> _fetchAll(
      String table, String idAcademia) async {
    List<Map<String, dynamic>> allData = [];
    int offset = 0;
    const int limit = 1000; // Limite padrão do Supabase
    bool hasMore = true;

    while (hasMore) {
      final response = await _client
          .from(table)
          .select()
          .eq('id_academia', idAcademia)
          .range(offset, offset + limit - 1);

      final List<Map<String, dynamic>> data =
          List<Map<String, dynamic>>.from(response);
      allData.addAll(data);

      if (data.length < limit) {
        hasMore = false;
      } else {
        offset += limit;
      }
    }
    return allData;
  }

  // Buscar todos os usuários da academia do admin logado
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final academyContext = await _getAcademyContext();
      final idAcademia = academyContext['id_academia'];

      // Buscar com paginação para superar limite de 1000 linhas
      // O admin da academia é o próprio idAcademia
      final adminsF = _client.from('users_adm').select().eq('id', idAcademia);
      final nutrisF = _fetchAll('users_nutricionista', idAcademia);
      final trainersF = _fetchAll('users_personal', idAcademia);
      final studentsF = _fetchAll('users_alunos', idAcademia);

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
      final academyContext = await _getAcademyContext();
      final idAcademia = academyContext['id_academia'];
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

      final response = await _fetchAll(tableName, idAcademia);

      // Ordenação precisa ser feita em memória agora, pois _fetchAll traz tudo
      response.sort((a, b) => (a['nome'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['nome'] ?? '').toString().toLowerCase()));

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
    int? paymentDueDay, // Novo parâmetro para dia de vencimento (somará +3)
    String? birthDate, // Nova data de nascimento
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) throw Exception('Admin não autenticado');

      String roleString;
      if (role != null) {
        roleString = role.toString().split('.').last;
      } else {
        final existingUser = await getUserById(userId);
        if (existingUser == null) throw Exception('Usuário não encontrado');
        roleString = existingUser['role'];
      }

      print('🚀 [UserService] Editando usuário via v3: $userId ($roleString)');

      final response = await _client.rpc('admin_update_user_v3', params: {
        'p_admin_id': currentUser.id,
        'p_user_id': userId,
        'p_role': roleString,
        'p_name': name,
        'p_email': email,
        'p_phone': phone,
        'p_birth_date': birthDate,
        'p_due_day': paymentDueDay,
      });

      // Se a resposta vier como lista (SETOF/TABLE), pegamos o primeiro. Se vier como objeto (JSONB), usamos direto.
      final result = (response is List) ? response.first : response;

      if (result != null && result['success'] == true) {
        await CacheManager().invalidatePattern('user_$userId');
        return {
          'success': true,
          'message': result['message'] ?? 'Usuário atualizado com sucesso',
        };
      } else {
        return {
          'success': false,
          'message':
              result?['message'] ?? 'Erro ao processar atualização no servidor',
        };
      }
    } catch (e) {
      print('❌ Erro Crítico no updateUser: $e');

      String msg = e.toString();
      if (msg.contains('PGRST116')) {
        msg =
            'Erro de comunicação (PGRST116). Você aplicou o SQL da função "admin_update_user_v3" no painel do Supabase?';
      }

      return {
        'success': false,
        'message': 'Erro ao atualizar: $msg',
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
          .select()
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
          .range(0, 4999)
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
      final academyContext = await _getAcademyContext();
      final idAcademia = academyContext['id_academia'];

      // 4. Buscar alunos desta academia com paginação
      final data = await _fetchAll('users_alunos', idAcademia);

      // Ordenar em memória
      data.sort((a, b) => (a['nome'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['nome'] ?? '').toString().toLowerCase()));

      // Normalizar campos (nome→name, telefone→phone) e adicionar role
      final List<dynamic> responseList = data as List<dynamic>;
      return responseList.map((d) {
        final student = Map<String, dynamic>.from(d as Map);
        return {
          'id': student['id'],
          'name': student['nome'] ?? 'Sem Nome',
          'email': student['email'] ?? '',
          'phone': student['telefone'] ?? '',
          'birth_date': student['data_nascimento'],
          'role': 'student',
        };
      }).toList();
    } catch (e) {
      print('❌ Erro ao buscar alunos (Manual): $e');
      return [];
    }
  }

  // Alternar status de bloqueio do usuário via RPC (Seguro)
  static Future<Map<String, dynamic>> toggleUserBlockStatus(
      String userId, String role, bool currentStatus) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) throw Exception('Admin não autenticado');

      print('🔒 [UserService] Alternando bloqueio para: $userId (Role: $role)');

      final response = await _client.rpc('admin_toggle_user_block', params: {
        'p_admin_id': currentUser.id,
        'p_user_id': userId,
        'p_role': role,
      });

      if (response != null && response['success'] == true) {
        // Invalidar cache do usuário para refletir o status imediatamente
        await CacheManager().invalidatePattern('user_$userId');

        return {
          'success': true,
          'message': response['message'] ?? 'Status alterado com sucesso',
          'is_blocked': response['is_blocked']
        };
      } else {
        return {
          'success': false,
          'message':
              response?['message'] ?? 'Erro ao alterar status de bloqueio',
        };
      }
    } catch (e) {
      print('❌ Erro no toggleUserBlockStatus: $e');
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
      final academyContext = await _getAcademyContext();
      final idAcademia = academyContext['id_academia'];

      // Buscar dados do admin para ver o plano
      final adminDetails = await _client
          .from('users_adm')
          .select()
          .eq('id', idAcademia)
          .single();
      final plan = adminDetails['plano_mensal']?.toString() ?? 'Prata';

      // Definir limites
      int limit = 300; // Prata default
      if (plan.toLowerCase() == 'ouro') limit = 600;
      if (plan.toLowerCase() == 'platina') limit = 900;
      if (plan.toLowerCase() == 'diamante') limit = 999999;

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
      return {'count': 0, 'limit': 300, 'isAtLimit': false, 'plan': 'Prata'};
    }
  }

  // Buscar status de assinatura do administrador
  static Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final academyContext = await _getAcademyContext();
      final idAcademia = academyContext['id_academia'];

      final adminDetails = await _client
          .from('users_adm')
          .select()
          .eq('id', idAcademia)
          .single();

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
