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

      // Sanitizar endereço para evitar quebra do token (remover pipes)
      final safeAddress = address.replaceAll('|', ' ');

      // Criar token com dados criptografados (SEM salvar no banco!)
      // Usar campos cnpj e cpf para armazenar cnpjAcademia e academia
      // Address carrega dados extras: role|plano|cnpj_pessoal|cpf_pessoal|endereco
      // MUDANÇA: Plano movido para o início para evitar perda por truncamento
      final tokenData = RegistrationTokenService.createToken(
        name: name,
        email: email,
        password: password,
        phone: phone,
        cnpj: cnpjAcademia, // CNPJ da academia
        cpf: academia, // Nome da academia
        address: 'admin|$plan|$cnpj|$cpf|$safeAddress', // NOVA ORDEM
      );

      final token = tokenData['token'] as String;

      // URL de confirmação com deep link para abrir o app
      final confirmationUrl =
          'https://spartanapp.com.br/confirm.html?token=$token';

      print('🔐 Token criado: ${token.substring(0, 20)}...');
      print('🔗 URL de confirmação: $confirmationUrl');

      try {
        print('📧 Tentando enviar email para: $email');

        // SIGNUP INICIAL: Envia TODOS os dados via metadata
        // O Trigger V4 vai capturar isso imediatamente.
        final response = await _client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: confirmationUrl,
          data: {
            'role': 'admin',
            'name': name,
            'phone': phone,
            'academia': academia,
            'cnpj': cnpjAcademia, // Trigger usa 'cnpj' ou 'cnpj_academia'
            'cnpj_academia': cnpjAcademia,
            'plano_mensal': plan,
            'plan': plan,

            // DADOS QUE FALTAVAM:
            'cpf': cpf,
            'meta_cpf': cpf,
            'cpf_pessoal': cpf,

            'address': address,
            'meta_endereco': address,
            'endereco_pessoal': address,
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

      // MUDANÇA: Se o token for numérico de 6 dígitos, tratamos como fluxo de Registro Manual
      if (RegExp(r'^\d{6}$').hasMatch(token)) {
        print('🔢 Token numérico detectado. Verificando fluxo manual...');
        final success = await _verifyManualVerificationToken(token);
        if (success) {
          return {
            'success': true,
            'message':
                'Email verificado com sucesso! Volte para a tela de cadastro.',
          };
        } else {
          return {
            'success': false,
            'message': 'Código inválido ou já utilizado.',
          };
        }
      }

      // Validar e decodificar token padrão (JWT-like)
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
      try {
        final loginTest = await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (loginTest.user != null) {
          print('✅ Usuário temporário encontrado: ${loginTest.user!.id}');
          print('📝 Criando registro na tabela correta...');

          final cnpjAcademia = cnpj;
          final academia = cpf;

          final addressParts = address.split('|');
          final role = addressParts.isNotEmpty ? addressParts[0] : 'student';

          if (role == 'admin') {
            // Admin: admin|plano|cnpj_pessoal|cpf_pessoal|endereco
            String plan = addressParts.length > 1 ? addressParts[1] : '';
            if (plan.isEmpty || plan == 'null') {
              plan = loginTest.user?.userMetadata?['plano_mensal'] ?? 'Prata';
            }
            if (plan.isEmpty) plan = 'Prata';

            final personalCpf = addressParts.length > 3 ? addressParts[3] : '';
            final personalAddress =
                addressParts.length > 4 ? addressParts[4] : '';

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

            await _client.auth
                .updateUser(UserAttributes(data: {'plano_mensal': plan}));

            // 🔥 FORÇAR GRAVAÇÃO DO PLANO VIA RPC 🔥
            try {
              await _client.rpc('set_admin_plan', params: {
                'user_id': loginTest.user!.id,
                'new_plan': plan,
              });
              print('✅ Plano gravado via RPC blindada!');
            } catch (e) {
              print('⚠️ Erro RPC: $e');
            }
          } else {
            // Outros roles
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
              'id_academia': createdByAdminId,
              'email_verified': true,
              if (birthDate != null) 'data_nascimento': birthDate,
            };

            if (role == 'student' && data.containsKey('paymentDueDay')) {
              insertData['payment_due_day'] = data['paymentDueDay'];
            }

            await _client.from(tableName).insert(insertData);
          }

          print('✅ Usuário criado com sucesso (Login Existente)!');
          await _client.auth.signOut();

          return {
            'success': true,
            'userId': loginTest.user!.id,
            'email': email,
            'message': 'Conta criada com sucesso! Faça login.',
          };
        }
      } catch (e) {
        print('⚠️ Usuário temporário não encontrado (criar novo): $e');
      }

      print('📝 Criando novo usuário no auth.users...');
      // FORCING COMMIT TO GITHUB

      // DEBUG CRÍTICO
      print('🔥 DEBUG TOKEN RAW ADDRESS: "$address"');

      // EXTRAIR PLANO, CPF E ENDEREÇO DO TOKEN (NOVA ORDEM)
      final addressParts = address.split('|');
      print('🔥 DEBUG PARTS COUNT: ${addressParts.length}');
      print('🔥 DEBUG PARTS: $addressParts');

      final role = addressParts.isNotEmpty ? addressParts[0] : 'student';

      String? adminPlan;
      String? personalCpf;
      String? personalAddress;

      if (role == 'admin') {
        adminPlan = addressParts.length > 1 ? addressParts[1] : null;
        personalCpf = addressParts.length > 3 ? addressParts[3] : '';
        personalAddress = addressParts.length > 4 ? addressParts[4] : '';
      }

      // GARANTIA: Nunca enviar metadata null para o signUp
      if (adminPlan == null || adminPlan.isEmpty) adminPlan = 'Prata';

      // Criar novo usuário no Supabase Auth
      final authResponse =
          await _client.auth.signUp(email: email, password: password, data: {
        'role': role,
        'name': name,
        'phone': phone,
        // 'academia' recebe o valor da variável 'cpf' (que na verdade é o nome da academia neste contexto legado?)
        // NÃO, espera. A variável 'cpf' vinda dos argumentos é o que?
        // Em registerAdmin (chamador), cpf é passado.
        // Mas aqui dentro de confirmRegistration, os argumentos são nomeados.
        // Se olharmos a assinatura (que não vi agora), 'cpf' e 'cnpj' são argumentos.
        // Vou manter o mapeamento existente para não quebrar: 'academia': cpf
        'academia': cpf,
        'cnpj_academia': cnpj,
        'plano_mensal': adminPlan,
        // NOVOS CAMPOS PARA O TRIGGER V4
        'cpf_pessoal': personalCpf,
        'endereco_pessoal': personalAddress,
      });

      if (authResponse.user == null) {
        throw Exception('Erro ao criar usuário no Supabase Auth');
      }

      print('✅ Usuário auth criado: ${authResponse.user!.id}');
      print('📝 Inserindo na tabela pública...');

      final cnpjAcademia = cnpj;
      final academia = cpf;

      if (role == 'admin') {
        // Admin: admin|plano|cnpj_pessoal|cpf_pessoal|endereco
        // Tentar extrair do token (Nova Ordem: index 1)
        String plan = addressParts.length > 1 ? addressParts[1] : '';

        // Se vier vazio, tenta pegar do metadata (backup do signUp)
        if (plan.isEmpty || plan == 'null') {
          plan = authResponse.user?.userMetadata?['plano_mensal'] ?? '';
        }

        // Default apenas se realmente não tiver nada
        if (plan.isEmpty) plan = 'Prata';

        final personalCpfRaw = addressParts.length > 3 ? addressParts[3] : '';
        final personalAddressRaw =
            addressParts.length > 4 ? addressParts[4] : '';

        print(
            '📦 SETUP ORIGINAL: CPF="$personalCpfRaw", Endereco="$personalAddressRaw"');
        print('📦 ARRAY COMPLETO: $addressParts');

        String finalCpf = personalCpfRaw;
        String finalAddress = personalAddressRaw;

        // LÓGICA DE RECUPERAÇÃO INTELIGENTE (Smart Fix)
        // Se CPF está vazio, mas Endereço parece um CPF (11 digitos numericos)
        if (finalCpf.isEmpty &&
            RegExp(r'^\d{11}$')
                .hasMatch(finalAddress.replaceAll(RegExp(r'\D'), ''))) {
          print(
              '⚠️ DETECTADO SHIFT: CPF estava no campo Endereço. Corrigindo...');
          finalCpf = finalAddress;
          // Tentar pegar endereço do próximo indice se existir
          finalAddress = addressParts.length > 5 ? addressParts[5] : '';
        }
        // Se Endereço parece CPF e CPF parece algo estranho
        else if (RegExp(r'^\d{11}$')
            .hasMatch(finalAddress.replaceAll(RegExp(r'\D'), ''))) {
          print('⚠️ DETECTADO CPF NO CAMPO ENDEREÇO. Ajustando...');
          // Se o campo CPF atual não parece CPF, assume que endereço é o CPF real
          if (!RegExp(r'^\d{11}$')
              .hasMatch(finalCpf.replaceAll(RegExp(r'\D'), ''))) {
            finalCpf = finalAddress;
            finalAddress = addressParts.length > 5 ? addressParts[5] : '';
          }
        }

        print('✅ DADOS FINAIS: CPF="$finalCpf", Endereço="$finalAddress"');

        final personalCpf = finalCpf;
        final personalAddress = finalAddress;

        print('🏆 PLANO DEFINITIVO PARA GRAVAÇÃO: $plan');

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

        // 🔥 FORÇAR GRAVAÇÃO DO PLANO VIA RPC 🔥
        try {
          await _client.rpc('set_admin_plan', params: {
            'user_id': authResponse.user!.id,
            'new_plan': plan,
          });
          print('✅ Plano gravado via RPC blindada!');
        } catch (e) {
          print('⚠️ Erro RPC: $e');
        }
      } else {
        // Outros roles
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
          'id_academia': createdByAdminId,
          'email_verified': true,
          if (birthDate != null) 'data_nascimento': birthDate,
        };

        if (role == 'student' && data.containsKey('paymentDueDay')) {
          insertData['payment_due_day'] = data['paymentDueDay'];
        }

        await _client.from(tableName).insert(insertData);
      }

      print('✅ Usuário finalizado com sucesso!');
      await _client.auth.signOut();

      return {
        'success': true,
        'userId': authResponse.user!.id,
        'email': email,
        'message': 'Conta criada com sucesso! Faça login.',
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
      print('📧 Enviando email de recuperação customizado para: $email');

      // Chamar Edge Function que usa o sistema customizado (RPC + Resend)
      final response = await _client.functions.invoke(
        'send-password-reset',
        body: {'email': email},
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Erro desconhecido';
        print('❌ Erro na Edge Function: $error');
        throw AuthException('Erro ao enviar email customizado: $error');
      }

      print('✅ Email de recuperação enviado com sucesso via Edge Function');
    } on AuthException catch (e) {
      print('❌ Erro AuthException: ${e.message}');
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      print('❌ Erro inesperado ao enviar password reset: $e');
      throw Exception('Erro ao enviar email de recuperação: ${e.toString()}');
    }
  }

  /// Redefinir senha usando token do email
  static Future<void> resetPassword(
      String accessToken, String newPassword) async {
    try {
      print('🔐 Redefinindo senha via RPC customizada...');

      // Validar senha
      if (newPassword.length < 6) {
        throw Exception('A senha deve ter no mínimo 6 caracteres');
      }

      // Chamar a RPC customizada (mesma usada no HTML)
      final response = await _client.rpc('reset_password_with_token', params: {
        'reset_token': accessToken,
        'new_password': newPassword,
      });

      // A RPC retorna um JSON {success: bool, message: string}
      if (response != null && response['success'] == true) {
        print('✅ Senha redefinida com sucesso via RPC');
        // Opcional: Fazer logout se houver sessão
        if (_client.auth.currentSession != null) {
          await _client.auth.signOut();
        }
      } else {
        final errorMsg = response?['message'] ?? 'Erro desconhecido na RPC';
        throw Exception(errorMsg);
      }
    } on AuthException catch (e) {
      print('❌ Erro AuthException ao redefinir: ${e.message}');
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      print('❌ Erro inesperado ao redefinir: $e');
      throw Exception('Erro ao redefinir senha: ${e.toString()}');
    }
  }

  // ============================================
  // MENSAGENS DE ERRO
  // ============================================

  static Future<bool> _verifyManualVerificationToken(String code) async {
    try {
      // 1. Buscar o token na tabela customizada
      final response = await _client
          .from('email_verification_codes')
          .select()
          .eq('code', code)
          .eq('verified', false)
          .maybeSingle();

      if (response == null) return false;

      final userId = response['user_id'];
      final expiresAt = DateTime.parse(response['expires_at']);

      if (DateTime.now().isAfter(expiresAt)) {
        print('❌ Código expirado');
        return false;
      }

      // 2. Marcar como verificado
      await _client
          .from('email_verification_codes')
          .update({'verified': true}).eq('code', code);

      // 3. ATUALIZAR STATUS DO LEAD (Isso é o que detrava o Realtime no Flutter)
      await _client
          .from('pending_registrations')
          .update({'status': 'verified'}).eq('id', userId);

      print('✅ Registro manual verificado e lead atualizado para: $userId');

      return true;
    } catch (e) {
      print('❌ Erro ao verificar token manual: $e');
      return false;
    }
  }

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
