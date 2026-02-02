import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'registration_token_service.dart';
import '../models/user_role.dart';
import 'notification_service.dart';
import 'financial_service.dart';

class AuthService {
  static final SupabaseClient _client = SupabaseService.client;

  /// Retorna o usuário autenticado atualmente (se houver)
  static User? get currentUser => _client.auth.currentUser;

  // ============================================
  // CADASTRO COM TOKEN CRIPTOGRAFADO
  // ============================================

  /// Inicia cadastro de administrador
  /// NÃO cria conta ainda - apenas gera token e envia email
  static Future<Map<String, dynamic>> registerAdmin({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String cnpjAcademia,
    required String academia,
    required String cnpj,
    required String cpf,
    required String address,
    required String plan, // NOVO: Plano selecionado
  }) async {
    try {
      // Verificar se email já existe em users_adm
      final existingUser = await _client
          .from('users_adm')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (existingUser != null) {
        return {
          'success': false,
          'message': 'Este email já está cadastrado',
        };
      }

      // Criar token com dados criptografados (SEM salvar no banco!)
      // Usar campos cnpj e cpf para armazenar cnpjAcademia e academia
      // Address carrega dados extras: role|cnpj_pessoal|cpf_pessoal|endereco|plano
      final tokenData = RegistrationTokenService.createToken(
        name: name,
        email: email,
        password: password,
        phone: phone,
        cnpj: cnpjAcademia, // CNPJ da academia
        cpf: academia, // Nome da academia
        address: 'admin|$cnpj|$cpf|$address|$plan', // Dados packeados
      );

      final token = tokenData['token'] as String;

      // URL de confirmação com deep link para abrir o app
      final confirmationUrl =
          'https://spartanapp.com.br/confirm.html?token=$token';

      print('🔐 Token criado: ${token.substring(0, 20)}...');
      print('🔗 URL de confirmação: $confirmationUrl');

      try {
        print('📧 Tentando enviar email para: $email');

        final response = await _client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: confirmationUrl,
          data: {
            'role': 'admin',
            'name': name,
            'phone': phone,
            'academia': academia,
            'cnpj_academia': cnpjAcademia,
            'plano_mensal': plan, // Agora enviamos o plano para o trigger
          },
        );

        print('✅ SignUp executado com sucesso');
        print('📧 User ID: ${response.user?.id}');
        print('📧 Email confirmado: ${response.user?.emailConfirmedAt}');

        // Fazer logout imediatamente (não queremos que o usuário fique logado)
        await _client.auth.signOut();
        print('✅ Logout realizado');

        return {
          'success': true,
          'email': email,
          'message': 'Verifique seu email para confirmar o cadastro.',
          'requiresVerification': true,
        };
      } catch (e) {
        print('❌ Erro ao enviar email: $e');
        // Se falhar, retornar token para teste manual
        return {
          'success': true,
          'email': email,
          'token': token, // Para testes
          'message': 'Cadastro iniciado! Use o token para testar: $token',
          'requiresVerification': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao iniciar cadastro: ${e.toString()}',
      };
    }
  }

  /// Confirmar cadastro usando token do email
  /// AGORA SIM cria a conta no Supabase
  static Future<Map<String, dynamic>> confirmRegistration(String token) async {
    try {
      print('🔄 Iniciando confirmação de cadastro...');
      print('🔑 Token recebido: ${token.substring(0, 20)}...');

      // Validar e decodificar token
      final data = RegistrationTokenService.validateToken(token);

      if (data == null) {
        print('❌ Token inválido ou expirado');
        return {
          'success': false,
          'message': 'Link inválido ou expirado. Tente cadastrar novamente.',
        };
      }

      print('✅ Token válido!');

      // Extrair dados do token
      final name = data['name'] as String;
      final email = data['email'] as String;
      final password = data['password'] as String;
      final phone = data['phone'] as String;
      final cnpj = data['cnpj'] as String;
      final cpf = data['cpf'] as String;
      final address = data['address'] as String;
      final birthDate = data['birthDate'] as String?;

      print('📧 Email: $email');

      // Verificar se email já foi cadastrado em qualquer tabela
      var existingUser = await _client
          .from('users_adm')
          .select('email')
          .eq('email', email)
          .maybeSingle();
      if (existingUser == null)
        existingUser = await _client
            .from('users_nutricionista')
            .select('email')
            .eq('email', email)
            .maybeSingle();
      if (existingUser == null)
        existingUser = await _client
            .from('users_personal')
            .select('email')
            .eq('email', email)
            .maybeSingle();
      if (existingUser == null)
        existingUser = await _client
            .from('users_alunos')
            .select('email')
            .eq('email', email)
            .maybeSingle();

      if (existingUser != null) {
        print('⚠️ Usuário já existe na tabela users');
        return {
          'success': false,
          'message': 'Este email já está cadastrado. Faça login.',
        };
      }

      print('🔍 Verificando se existe usuário temporário no auth.users...');

      // Verificar se existe usuário temporário no auth.users
      // (criado pelo signUp inicial para enviar email)
      try {
        // Tentar fazer login com as credenciais para verificar se existe
        final loginTest = await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (loginTest.user != null) {
          print('✅ Usuário temporário encontrado: ${loginTest.user!.id}');
          print('📝 Criando registro na tabela correta...');

          // Extrair dados do token
          final cnpjAcademia = cnpj;
          final academia = cpf;

          final addressParts = address.split('|');
          final role = addressParts.isNotEmpty ? addressParts[0] : 'student';

          print('📦 Debug Address Parsing:');
          print('CreateString: $address');
          print('Parts: ${addressParts.length}');
          addressParts.asMap().forEach((i, v) => print('[$i]: $v'));

          if (role == 'admin') {
            final personalCpf = addressParts.length > 2 ? addressParts[2] : '';
            final personalAddress =
                addressParts.length > 3 ? addressParts[3] : '';
            // PEGAR O PLANO COMSEGURANÇA
            final plan = addressParts.length > 4 ? addressParts[4] : 'Standard';

            print('🏆 PLANO IDENTIFICADO: $plan');

            await _client.from('users_adm').upsert({
              'id': loginTest.user!.id,
              'cnpj_academia': cnpjAcademia,
              'academia': academia,
              'nome': name,
              'email': email,
              'telefone': phone,
              'cpf': personalCpf,
              'endereco': personalAddress,
              'plano_mensal': plan,
              'email_verified': true,
            });

            // Garantia extra: Atualizar metadados do usuário para persistência
            await _client.auth
                .updateUser(UserAttributes(data: {'plano_mensal': plan}));
          } else {
            final createdByAdminId =
                addressParts.length > 1 ? addressParts[1] : loginTest.user!.id;

            String tableName = 'users_alunos';
            if (role == 'nutritionist')
              tableName = 'users_nutricionista';
            else if (role == 'trainer')
              tableName = 'users_personal';
            else if (role == 'student') tableName = 'users_alunos';

            final insertData = {
              'id': loginTest.user!.id,
              'cnpj_academia': cnpjAcademia,
              'academia': academia,
              'nome': name,
              'email': email,
              'telefone': phone,
              'created_by_admin_id': createdByAdminId,
              'id_academia': createdByAdminId, // ID do admin = ID da academia
              'email_verified': true,
              if (birthDate != null) 'data_nascimento': birthDate,
            };

            if (role == 'student' && data.containsKey('paymentDueDay')) {
              insertData['payment_due_day'] = data['paymentDueDay'];
            }

            await _client.from(tableName).insert(insertData);

            // REGISTRAR PAGAMENTO SE HOUVER FLAG
            if (role == 'student' && data['isPaidCurrentMonth'] == true) {
              try {
                await FinancialService.addTransaction(
                  description: 'Mensalidade (Cadastro)',
                  amount: 0.0, // Valor simbólico pois já foi pago externamente
                  type: 'income',
                  date: DateTime.now(),
                  category: 'Mensalidade',
                  relatedUserId: loginTest.user!.id,
                  relatedUserRole: 'student',
                );
                print('💰 Pagamento inicial registrado!');
              } catch (e) {
                print('⚠️ Erro ao registrar pagamento inicial: $e');
              }
            }
          }

          print('✅ Usuário criado na tabela $role!');

          // Fazer logout
          await _client.auth.signOut();

          return {
            'success': true,
            'userId': loginTest.user!.id,
            'email': email,
            'message': 'Conta criada com sucesso! Você já pode fazer login.',
          };
        }
      } catch (e) {
        print('⚠️ Usuário temporário não encontrado ou erro no login: $e');
        // Usuário não existe, criar novo
      }

      print('📝 Criando novo usuário no auth.users...');

      // EXTRAIR PLANO DO ADMIN ANTES DO SIGNUP
      final addressParts = address.split('|');
      final role = addressParts.isNotEmpty ? addressParts[0] : 'student';
      String? adminPlan;
      if (role == 'admin' && addressParts.length > 4) {
        adminPlan = addressParts[4];
      }

      // Criar novo usuário no Supabase Auth
      final authResponse =
          await _client.auth.signUp(email: email, password: password, data: {
        'role': role,
        'name': name,
        'phone': phone,
        'academia': cpf, // CPF aqui é academia no token
        'cnpj_academia': cnpj, // CNPJ aqui é cnpj_academia no token
        if (adminPlan != null) 'plano_mensal': adminPlan,
      });

      if (authResponse.user == null) {
        throw Exception('Erro ao criar usuário no Supabase Auth');
      }

      print('✅ Usuário criado no auth.users: ${authResponse.user!.id}');
      print('📝 Criando registro na tabela correta...');

      // Extrair dados do token
      final cnpjAcademia = cnpj;
      final academia = cpf;

      // Address contém dados packeados: role|dados_extras
      // final addressParts = address.split('|'); // Já feito acima
      // final role = addressParts.isNotEmpty ? addressParts[0] : 'student'; // Já feito acima

      print('🔍 Role identificado: $role');
      print('🔍 Academia: $academia ($cnpjAcademia)');

      print('📦 Debug Address Parsing (Novo User):');
      print('CreateString: $address');
      print('Parts: ${addressParts.length}');
      addressParts.asMap().forEach((i, v) => print('[$i]: $v'));

      // Inserir na tabela correta
      if (role == 'admin') {
        // Admin: admin|cnpj_pessoal|cpf_pessoal|endereco|plano

        final personalCpf = addressParts.length > 2 ? addressParts[2] : '';
        final personalAddress = addressParts.length > 3 ? addressParts[3] : '';
        final plan = addressParts.length > 4 ? addressParts[4] : 'Standard';

        print('🏆 PLANO IDENTIFICADO (Novo User): $plan');

        await _client.from('users_adm').upsert({
          'id': authResponse.user!.id,
          'cnpj_academia': cnpjAcademia,
          'academia': academia,
          'nome': name,
          'email': email,
          'telefone': phone,
          'cpf': personalCpf,
          'endereco': personalAddress,
          'plano_mensal': plan,
          'email_verified': true,
        });

        // Garantia extra
        await _client.auth
            .updateUser(UserAttributes(data: {'plano_mensal': plan}));
      } else {
        // Outros: role|created_by_admin_id
        final createdByAdminId =
            addressParts.length > 1 ? addressParts[1] : authResponse.user!.id;

        String tableName = 'users_alunos';
        if (role == 'nutritionist')
          tableName = 'users_nutricionista';
        else if (role == 'trainer')
          tableName = 'users_personal';
        else if (role == 'student') tableName = 'users_alunos';

        final insertData = {
          'id': authResponse.user!.id,
          'cnpj_academia': cnpjAcademia,
          'academia': academia,
          'nome': name,
          'email': email,
          'telefone': phone,
          'created_by_admin_id': createdByAdminId,
          'id_academia': createdByAdminId, // ID do admin = ID da academia
          'email_verified': true,
          if (birthDate != null) 'data_nascimento': birthDate,
        };

        // Adicionar dia de vencimento se disponível e for aluno
        if (role == 'student' && data.containsKey('paymentDueDay')) {
          insertData['payment_due_day'] = data['paymentDueDay'];
        }

        await _client.from(tableName).insert(insertData);

        // REGISTRAR PAGAMENTO SE HOUVER FLAG
        if (role == 'student' && data['isPaidCurrentMonth'] == true) {
          try {
            await FinancialService.addTransaction(
              description: 'Mensalidade (Cadastro)',
              amount: 0.0, // Valor simbólico
              type: 'income',
              date: DateTime.now(),
              category: 'Mensalidade',
              relatedUserId: authResponse.user!.id,
              relatedUserRole: 'student',
            );
            print('💰 Pagamento inicial registrado!');
          } catch (e) {
            print('⚠️ Erro ao registrar pagamento inicial: $e');
          }
        }
      }

      print('✅ Usuário criado na tabela $role com sucesso!');

      // Fazer logout
      await _client.auth.signOut();

      return {
        'success': true,
        'userId': authResponse.user!.id,
        'email': email,
        'message': 'Conta criada com sucesso! Você já pode fazer login.',
      };
    } on AuthException catch (e) {
      print('❌ AuthException: ${e.message}');
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.message),
      };
    } catch (e) {
      print('❌ Erro geral: $e');
      return {
        'success': false,
        'message': 'Erro ao confirmar cadastro: ${e.toString()}',
      };
    }
  }

  // ============================================
  // LOGIN
  // ============================================

  // Método auxiliar para buscar endereço da academia
  static Future<String?> _getAcademyAddress(String cnpjAcademia) async {
    try {
      final admin = await _client
          .from('users_adm')
          .select('endereco')
          .eq('cnpj_academia', cnpjAcademia)
          .maybeSingle();
      return admin?['endereco'] as String?;
    } catch (_) {
      return null;
    }
  }

  // Método auxiliar para buscar usuário em todas as tabelas
  static Future<Map<String, dynamic>?> _findUserInTables(String userId) async {
    try {
      // 1. Verificar users_adm
      final admin = await _client
          .from('users_adm')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (admin != null) {
        // Admin já tem o próprio endereço
        return {
          ...admin,
          'role': 'admin',
          'endereco_academia':
              admin['endereco'], // Mapear para usar a mesma chave
        };
      }

      // 2. Verificar users_nutricionista
      final nutri = await _client
          .from('users_nutricionista')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (nutri != null) {
        String? address;
        if (nutri['cnpj_academia'] != null) {
          address = await _getAcademyAddress(nutri['cnpj_academia']);
        }
        return {
          ...nutri,
          'role': 'nutritionist',
          'endereco_academia': address,
        };
      }

      // 3. Verificar users_personal
      final personal = await _client
          .from('users_personal')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (personal != null) {
        String? address;
        if (personal['cnpj_academia'] != null) {
          address = await _getAcademyAddress(personal['cnpj_academia']);
        }
        return {
          ...personal,
          'role': 'trainer',
          'endereco_academia': address,
        };
      }

      // 4. Verificar users_alunos
      final aluno = await _client
          .from('users_alunos')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (aluno != null) {
        String? address;
        if (aluno['cnpj_academia'] != null) {
          address = await _getAcademyAddress(aluno['cnpj_academia']);
        }
        return {
          ...aluno,
          'role': 'student',
          'endereco_academia': address,
        };
      }

      return null;
    } catch (e) {
      print('Erro ao buscar usuário nas tabelas: $e');
      rethrow;
    }
  }

  // Login com email e senha
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return {
          'success': false,
          'message': 'Erro ao fazer login',
        };
      }

      // Buscar dados completos do usuário em todas as tabelas
      final userData = await _findUserInTables(response.user!.id);

      if (userData == null) {
        // Usuário autenticado mas sem registro nas tabelas
        // Isso pode acontecer se o cadastro falhou na etapa de inserção no banco
        await _client.auth.signOut();
        return {
          'success': false,
          'message': 'Cadastro incompleto. Entre em contato com o suporte.',
        };
      }

      // ===============================================
      // VERIFICAÇÃO DE BLOQUEIO E ACESSO FINANCEIRO
      // ===============================================

      // 1. Bloqueio Manual (is_blocked = true) tem prioridade absoluta
      if (userData['is_blocked'] == true) {
        await _client.auth.signOut();
        return {
          'success': false,
          'message':
              'Conta bloqueada. Entre em contato com a administração da academia.',
        };
      }

      // 2. Bloqueio Financeiro (Apenas para Alunos)
      // Se não pagou no mês atual e já passou da data de vencimento -> BLOQUEIA
      if (userData['role'] == 'student') {
        final paymentDueDay = userData['payment_due_day'] as int?;
        // Tentar obter id_academia de várias formas possíveis (id_academia ou created_by_admin_id)
        final idAcademia = userData['id_academia'] as String? ??
            userData['created_by_admin_id'] as String?;

        if (idAcademia != null && paymentDueDay != null) {
          final isOverdue = await FinancialService.isStudentOverdue(
            studentId: userData['id'],
            idAcademia: idAcademia,
            paymentDueDay: paymentDueDay,
          );

          if (isOverdue) {
            await _client.auth.signOut();
            return {
              'success': false,
              'message':
                  'Mensalidade vencida. Realize o pagamento para restaurar o acesso.',
            };
          }
        }
      }

      // 🔔 Configurar Notificações (Tópico da Academia)
      try {
        await NotificationService.loginUser(userData['cnpj_academia']);
        print(
            "🔔 Notificações configuradas para academia: ${userData['cnpj_academia']}");
      } catch (e) {
        print("Erro ao configurar notificações no login: $e");
      }

      return {
        'success': true,
        'user': userData,
        'session': response.session,
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.message),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao fazer login: ${e.toString()}',
      };
    }
  }

  // Logout
  // Logout
  static Future<void> logout() async {
    // Desinscrever do tópico da academia antes de dar signOut
    // Isso evita que o dispositivo continue recebendo push para a academia antiga
    try {
      // Precisamos dos dados antes de sair
      final userData = await getCurrentUserData();
      if (userData != null && userData['cnpj_academia'] != null) {
        await NotificationService.logoutUser(userData['cnpj_academia']);
      }
    } catch (e) {
      print("Erro ao desinscrever notificações: $e");
    }

    await _client.auth.signOut();
  }

  // Alias para compatibilidade
  static Future<void> signOut() async {
    await logout();
  }

  // Alias para compatibilidade com signIn
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    return await login(email: email, password: password);
  }

  // Verificar se usuário está logado
  static bool isLoggedIn() {
    return _client.auth.currentUser != null;
  }

  // Obter usuário atual
  static User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  // Obter dados completos do usuário atual
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = getCurrentUser();
    if (user == null) return null;

    return await _findUserInTables(user.id);
  }

  // Obter role do usuário atual
  static Future<UserRole?> getCurrentUserRole() async {
    final userData = await getCurrentUserData();
    if (userData == null) return null;

    final roleString = userData['role'] as String?;
    if (roleString == null) return null;

    return UserRole.values.firstWhere(
      (role) => role.toString().split('.').last == roleString,
      orElse: () => UserRole.student,
    );
  }

  // ============================================
  // RECUPERAÇÃO DE SENHA
  // ============================================

  /// Enviar email de recuperação de senha
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      print('📧 Enviando email de recuperação para: $email');

      // Enviar email de recuperação usando Edge Function + Resend
      print('📧 Chamando Edge Function send-password-reset...');

      final response = await _client.functions.invoke(
        'send-password-reset',
        body: {'email': email},
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Erro desconhecido';
        throw AuthException('Erro ao enviar email: $error');
      }

      final data = response.data;
      if (data != null && data['success'] == true) {
        print('✅ ${data['message']}');
      } else {
        throw AuthException('Falha ao enviar email');
      }
    } on AuthException catch (e) {
      print('❌ Erro ao enviar email: ${e.message}');
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      print('❌ Erro geral: $e');
      throw Exception('Erro ao enviar email de recuperação');
    }
  }

  /// Redefinir senha usando token do email
  static Future<void> resetPassword(
      String accessToken, String newPassword) async {
    try {
      print('🔐 Redefinindo senha...');

      // Validar senha
      if (newPassword.length < 6) {
        throw Exception('A senha deve ter no mínimo 6 caracteres');
      }

      // Atualizar senha usando o token de acesso
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        throw Exception('Erro ao redefinir senha');
      }

      print('✅ Senha redefinida com sucesso');

      // Fazer logout para forçar novo login
      await _client.auth.signOut();
    } on AuthException catch (e) {
      print('❌ Erro ao redefinir senha: ${e.message}');
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      print('❌ Erro geral: $e');
      throw Exception('Erro ao redefinir senha: ${e.toString()}');
    }
  }

  // ============================================
  // MENSAGENS DE ERRO
  // ============================================

  static String _getAuthErrorMessage(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Email ou senha incorretos';
    } else if (error.contains('Email not confirmed')) {
      return 'Por favor, confirme seu email antes de fazer login';
    } else if (error.contains('User already registered')) {
      return 'Este email já está cadastrado';
    } else if (error.contains('Invalid email')) {
      return 'Email inválido';
    } else if (error.contains('Password should be at least 6 characters')) {
      return 'A senha deve ter pelo menos 6 caracteres';
    } else {
      return error;
    }
  }
}
