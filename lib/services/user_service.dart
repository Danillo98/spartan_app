import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'registration_token_service.dart';
import '../models/user_role.dart';
import '../config/supabase_config.dart';

class UserService {
  static final SupabaseClient _client = SupabaseService.client;

  // Helper: Obter dados do admin atual para contexto (para pegar cnpj_academia)
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
  }) async {
    try {
      // 1. Obter dados do admin (Contexto da Academia)
      final adminDetails = await _getCurrentAdminDetails();
      final cnpjAcademia = adminDetails['cnpj_academia'];
      final academia = adminDetails['academia'];
      final adminId = adminDetails['id'];

      // 2. Criar token com dados do usuário usando RegistrationTokenService
      // Mapping:
      // cnpj -> cnpjAcademia
      // cpf -> academia
      // address -> role|created_by_admin_id
      final roleString = role.toString().split('.').last;

      final Map<String, dynamic> extraData = {};
      if (paymentDueDay != null) {
        extraData['paymentDueDay'] = paymentDueDay;
      }

      final tokenData = RegistrationTokenService.createToken(
        name: name,
        email: email,
        password: password,
        phone: phone,
        cnpj: cnpjAcademia, // Usar cnpj para armazenar CNPJ da Academia
        cpf: academia, // Usar cpf para armazenar Nome da Academia
        address: '$roleString|$adminId', // Role e Admin ID packeados no address
        birthDate: birthDate, // Data de nascimento
        extraData: extraData,
      );

      final token = tokenData['token'] as String;

      // 3. URL de confirmação com deep link
      final confirmationUrl =
          'https://spartan-app-f8a98.web.app/confirm.html?token=$token';

      print('🔐 Token criado para $roleString na academia $academia');
      print('🔗 URL: $confirmationUrl');

      // 4. Enviar email de confirmação via Supabase
      // IMPORTANTE: Usar um cliente temporário para NÃO alterar a sessão do Admin atual
      final tempClient = SupabaseClient(
        SupabaseConfig.supabaseUrl,
        SupabaseConfig.supabaseAnonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );

      try {
        await tempClient.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: confirmationUrl,
        );

        print('✅ Email enviado para: $email (Admin continua logado)');

        // Não é necessário fazer signOut no tempClient e nem no principal.
        // tempClient não persiste sessão por padrão no Flutter se não passar localStorage,
        // mas garante isolamento. Não precisamos fazer signOut no principal.

        return {
          'success': true,
          'message':
              'Usuário cadastrado! Um email de confirmação foi enviado para $email',
          'requiresVerification': true,
        };
      } catch (e) {
        print('❌ Erro ao enviar email: $e');
        return {
          'success': false,
          'message': 'Erro ao enviar email: ${e.toString()}',
        };
      }
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.message),
      };
    } catch (e) {
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
    return normalized;
  }

  // Buscar todos os usuários da academia do admin logado
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final adminDetails = await _getCurrentAdminDetails();
      final cnpjAcademia = adminDetails['cnpj_academia'];

      // Buscar em paralelo nas 4 tabelas filtrando por CNPJ da Academia
      final adminsF =
          _client.from('users_adm').select().eq('cnpj_academia', cnpjAcademia);
      final nutrisF = _client
          .from('users_nutricionista')
          .select()
          .eq('cnpj_academia', cnpjAcademia);
      final trainersF = _client
          .from('users_personal')
          .select()
          .eq('cnpj_academia', cnpjAcademia);
      final studentsF = _client
          .from('users_alunos')
          .select()
          .eq('cnpj_academia', cnpjAcademia);

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
      final cnpjAcademia = adminDetails['cnpj_academia'];
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
          .eq('cnpj_academia', cnpjAcademia)
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

      final Map<String, dynamic> updates = {};
      if (name != null) updates['nome'] = name; // Agora é 'nome' em todas
      if (email != null) updates['email'] = email;
      if (phone != null)
        updates['telefone'] = phone; // Agora é 'telefone' em todas

      // Se for aluno e tiver dia de vencimento, atualiza
      if (tableName == 'users_alunos' && paymentDueDay != null) {
        updates['payment_due_day'] = paymentDueDay;
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

  // Deletar usuário
  static Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      // Usar RPC segura para deletar do Auth e das tabelas públicas
      // Requer que o script CRIAR_RPC_DELETE_USER_COMPLETE.sql tenha sido executado no Supabase
      await _client
          .rpc('delete_user_complete', params: {'target_user_id': userId});

      return {'success': true, 'message': 'Usuário excluído com sucesso'};
    } catch (e) {
      print('Erro ao deletar usuário: $e');
      return {
        'success': false,
        'message': 'Erro ao excluir usuário: ${e.toString()}'
      };
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
  static Future<List<Map<String, dynamic>>> getStudentsForStaff() async {
    try {
      final List<dynamic> data = await _client.rpc('get_students_for_staff');

      // Normalizar campos (nome→name, telefone→phone) e adicionar role
      final students = data.map((d) {
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

      // Ensure Alphabetical Order
      students
          .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      return students;
    } catch (e) {
      print('❌ Erro ao buscar alunos via RPC: $e');
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

  // Mensagens de erro
  static String _getAuthErrorMessage(String error) {
    if (error.contains('User already registered')) {
      return 'Este email já está cadastrado';
    } else if (error.contains('Password should be at least 6 characters')) {
      return 'A senha deve ter no mínimo 6 caracteres';
    } else if (error.contains('Invalid email')) {
      return 'Email inválido';
    } else {
      return 'Erro: $error';
    }
  }
}
