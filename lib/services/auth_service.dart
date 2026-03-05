import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'registration_token_service.dart';
import '../models/user_role.dart';
import 'notification_service.dart';
import 'financial_service.dart';
import 'cache_manager.dart'; // Adicionado
import 'control_id_service.dart'; // Import ControliD Sync

class AuthService {
  static final SupabaseClient _client = SupabaseService.client;
  static Map<String, dynamic>? _cachedUserData;
  static const String version = '2.6.3';

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
          .select() // Changed from select('email')
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
            'id_academia':
                null, // Será preenchido pelo trigger com o ID do user
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
          .select() // Changed from select('email')
          .eq('email', email)
          .maybeSingle();
      if (existingUser == null)
        existingUser = await _client
            .from('users_nutricionista')
            .select() // Changed from select('email')
            .eq('email', email)
            .maybeSingle();
      if (existingUser == null)
        existingUser = await _client
            .from('users_personal')
            .select() // Changed from select('email')
            .eq('email', email)
            .maybeSingle();
      if (existingUser == null)
        existingUser = await _client
            .from('users_alunos')
            .select() // Changed from select('email')
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

            if (role == 'student') {
              ControlIdService.syncStudentRealtime(loginTest.user!.id,
                  forcedName: name);
            }
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

        if (role == 'student') {
          ControlIdService.syncStudentRealtime(authResponse.user!.id,
              forcedName: name);
        }
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

  // Método auxiliar para buscar informações da academia (Nome e Endereço)
  static Future<Map<String, String>?> _getAcademyInfo(String idAcademia) async {
    try {
      final info = await _client
          .from('users_adm')
          .select()
          .eq('id', idAcademia)
          .maybeSingle();
      if (info == null) return null;
      return {
        'nome': info['academia'] as String? ?? 'Academia Não Informada',
        'endereco': info['endereco'] as String? ?? '',
      };
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
        // Admin já tem o próprio endereço e nome da academia
        return {
          ...admin,
          'role': 'admin',
          'endereco_academia':
              admin['endereco'], // Mapear para usar a mesma chave
          // 'academia' já vem do banco
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
        String? academyName;

        if (nutri['id_academia'] != null) {
          final info = await _getAcademyInfo(nutri['id_academia']);
          if (info != null) {
            address = info['endereco'];
            academyName = info['nome'];
          }
        }
        return {
          ...nutri,
          'role': 'nutritionist',
          'endereco_academia': address,
          'academia': academyName ?? 'Academia Não Informada',
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
        String? academyName;

        if (personal['id_academia'] != null) {
          final info = await _getAcademyInfo(personal['id_academia']);
          if (info != null) {
            address = info['endereco'];
            academyName = info['nome'];
          }
        }
        return {
          ...personal,
          'role': 'trainer',
          'endereco_academia': address,
          'academia': academyName ?? 'Academia Não Informada',
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
        String? academyName;

        if (aluno['id_academia'] != null) {
          final info = await _getAcademyInfo(aluno['id_academia']);
          if (info != null) {
            address = info['endereco'];
            academyName = info['nome'];
          }
        }
        return {
          ...aluno,
          'role': 'student',
          'endereco_academia': address,
          'academia': academyName ?? 'Academia Não Informada',
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
    // CRÍTICO: Limpar cache ANTES de qualquer coisa.
    // Sem isso, usuário B que loga depois de A vê os dados de A.
    _cachedUserData = null;

    try {
      print('🔐 [DEBUG] Tentando autenticação Auth com email: $email');
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print(
          '✅ [DEBUG] Autenticação Auth bem sucedida! User ID: ${response.user?.id}');

      if (response.user == null) {
        return {
          'success': false,
          'message': 'Erro ao fazer login',
        };
      }

      // Buscar dados completos do usuário em todas as tabelas
      print('🔍 [DEBUG] Buscando dados complementares em _findUserInTables...');
      final userData = await _findUserInTables(response.user!.id);
      print('✅ [DEBUG] Dados encontrados: ${userData != null ? "Sim" : "Não"}');

      // CRÍTICO: Popular o cache imediatamente após login.
      // Sem isso, getCurrentUserData() chamaria _findUserInTables novamente
      // em cada tela (prefetch, dashboard, workout, diets) = N queries extras.
      if (userData != null) {
        _cachedUserData = userData;
      }

      if (userData == null) {
        // Usuário autenticado mas sem registro nas tabelas (Lead Pendente)
        // Em vez de dar erro, retornamos como um papel "visitor" para o app lidar
        print(
            '⚠️ [DEBUG] Usuário não encontrado nas tabelas. Tratando como VISITANTE pendente.');
        final visitorData = {
          'id': response.user!.id,
          'email': email,
          'nome': response.user?.userMetadata?['name'] ?? 'Visitante',
          'role': 'visitor',
          'is_blocked': false,
        };

        return {
          'success': true,
          'user': visitorData,
          'session': response.session,
        };
      }

      // Limpar caches antigos para garantir dados novos de multitenancy
      try {
        await CacheManager().invalidatePattern('*Students*');
        await CacheManager().invalidatePattern('*students*');
        print('🧹 Caches de alunos invalidados no login');
      } catch (e) {
        print('⚠️ Erro ao limpar cache no login: $e');
      }

      // ===============================================
      // VERIFICAÇÃO DE BLOQUEIO E ACESSO FINANCEIRO
      // ===============================================

      // 1. Bloqueio Manual (is_blocked = true)
      // Para ADMINS: Permite login, mas será redirecionado para tela de assinatura no SplashScreen
      // Para SUBORDINADOS: Bloqueia completamente
      if (userData['is_blocked'] == true && userData['role'] != 'admin') {
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
        final idAcademia =
            userData['id_academia'] ?? userData['created_by_admin_id'] ?? '';

        if (idAcademia != null && paymentDueDay != null) {
          final isOverdue = await FinancialService.isStudentOverdue(
            studentId: userData['id'],
            idAcademia: idAcademia,
            paymentDueDay: paymentDueDay,
            createdAtStr: userData['created_at'],
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
        await NotificationService.loginUser(
            userData['id_academia'] ?? userData['id']);
        debugPrint(
            "🔔 Notificações configuradas para academia: ${userData['id_academia'] ?? userData['id']}");
      } catch (e) {
        debugPrint("Erro ao configurar notificações no login: $e");
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
    _cachedUserData = null;
    // Desinscrever do tópico da academia antes de dar signOut
    // Isso evita que o dispositivo continue recebendo push para a academia antiga
    try {
      // Precisamos dos dados antes de sair (com timeout para não travar o logout)
      final userData =
          await getCurrentUserData().timeout(const Duration(seconds: 3));
      if (userData != null) {
        await NotificationService.logoutUser(
            userData['id_academia'] ?? userData['id']);
      }
    } catch (e) {
      debugPrint(
          "Aviso: Falha ao desinscrever notificações no logout (prosseguindo): $e");
    }

    await _client.auth.signOut();
  }

  // ============================================
  // VERIFICAÇÃO DE STATUS DE ASSINATURA (NO LOGIN)
  // ============================================
  /// Verifica e atualiza o status da assinatura do admin
  /// Retorna: { 'status': 'active'|'grace_period'|'suspended'|'deleted', 'message': ... }
  static Future<Map<String, dynamic>> verificarStatusAssinatura(
      String adminId) async {
    try {
      // Buscar dados do admin
      final admin = await _client
          .from('users_adm')
          .select()
          .eq('id', adminId)
          .maybeSingle();

      if (admin == null) {
        return {'status': 'not_found', 'message': 'Admin não encontrado'};
      }

      final statusAtual = admin['assinatura_status'] ?? 'active';
      final isBlocked = admin['is_blocked'] ?? false;

      // =============================================
      // BLOQUEIO RÍGIDO - SEM TOLERÂNCIA
      // =============================================

      // 1. Verificar EXCLUSÃO (Pending Deletion - 60 dias)
      if (admin['assinatura_deletada'] != null) {
        final deletadaEm = DateTime.parse(admin['assinatura_deletada']);
        final now = DateTime.now();

        if (now.isAfter(deletadaEm)) {
          // Passou do prazo de exclusão (manter pending_deletion ou excluir?)
          // Manter como está
        } else {
          // Ainda não deletou, mas está marcado?
          // Se statusAtual for pending_deletion, ok.
        }

        if (statusAtual == 'pending_deletion') {
          int diasRestantes = deletadaEm.difference(now).inDays;
          if (diasRestantes < 0) diasRestantes = 0;
          return {
            'status': 'pending_deletion',
            'message': 'Conta marcada para exclusão.',
            'deletada_em': admin['assinatura_deletada'],
            'dias_para_exclusao': diasRestantes,
          };
        }
      }

      // 2. Verificar BLOQUEIO/SUSPENSÃO (Status ou Data)
      if (statusAtual == 'suspended' ||
          statusAtual == 'canceled' ||
          isBlocked == true) {
        // Calcular se deve ir para exclusão (60 dias após expiração? ou após bloqueio?)
        // Mantendo simples por enquanto conforme solicitado.
        return {
          'status': 'suspended',
          'message': 'Assinatura suspensa. Renove para continuar acessando.',
          'dias_para_exclusao': 60, // Fallback visual
        };
      }

      // 3. Verificar DATA DE EXPIRAÇÃO (Auto-Block)
      if (admin['assinatura_expirada'] != null) {
        final expirada = DateTime.parse(admin['assinatura_expirada']);
        final now = DateTime.now();

        if (now.isAfter(expirada)) {
          // EXPIROU! Bloqueio Imediato.
          if (statusAtual != 'suspended') {
            await _client.from('users_adm').update({
              'assinatura_status': 'suspended',
              'is_blocked': true,
              'updated_at': now.toIso8601String(),
            }).eq('id', adminId);
          }

          return {
            'status': 'suspended',
            'message': 'Sua assinatura expirou. Renove para continuar.',
            'dias_para_exclusao': 60,
          };
        }

        // 4. AVISO DE VENCIMENTO (24h)
        final warningThreshold = expirada.subtract(const Duration(hours: 24));
        if (now.isAfter(warningThreshold)) {
          return {
            'status': 'warning',
            'message': 'Atenção: Sua assinatura vence em menos de 24 horas.',
            'aviso_expiracao': true,
            'horas_restantes': expirada.difference(now).inHours,
          };
        }
      }

      // Se passou por tudo, está ativo
      return {
        'status': 'active',
        'message': 'Assinatura ativa',
        'expira_em': admin['assinatura_expirada'],
      };
    } catch (e) {
      debugPrint('Erro ao verificar assinatura: $e');
      // Fail Safe: Bloquear se der erro? Não, Fail Open.
      return {
        'status': 'active',
        'message': 'Verificação falhou, acesso liberado (Fail Open)'
      };
    }
  }

  /// Verifica se a academia de um subordinado está suspensa
  static Future<Map<String, dynamic>> verificarAcademiaSuspensa(
      String idAcademia) async {
    try {
      final admin = await _client
          .from('users_adm')
          .select()
          .eq('id', idAcademia)
          .maybeSingle();

      if (admin == null) {
        return {'suspended': false, 'message': 'Academia não encontrada'};
      }

      final status = admin['assinatura_status'] ?? 'active';

      // BLOQUEIO RÍGIDO - REPLICADO PARA SUBORDINADOS
      bool isDataExpirada = false;
      if (admin['assinatura_expirada'] != null) {
        try {
          final expirada = DateTime.parse(admin['assinatura_expirada']);
          if (DateTime.now().isAfter(expirada)) {
            isDataExpirada = true;
          }
        } catch (_) {}
      }

      // Se status for suspenso OU data expirada, bloqueia.
      // Ignora grace_period (não existe mais).
      final isSuspended = status == 'suspended' ||
          status == 'pending_deletion' ||
          status == 'canceled' ||
          isDataExpirada;

      return {
        'suspended': isSuspended,
        'status': isSuspended ? 'suspended' : status,
        'academia': admin['academia'] ?? 'Academia',
        'message': isSuspended
            ? 'O acesso ao sistema está temporariamente suspenso. Sendo necessária a renovação da Assinatura Spartan!'
            : 'Academia ativa',
      };
    } catch (e) {
      debugPrint('Erro ao verificar academia: $e');
      return {'suspended': false, 'message': 'Erro na verificação'};
    }
  }

  /// Verificação RÁPIDA de status de assinatura (lê do banco sem atualizar)
  /// Retorna: { 'ativo': bool, 'status': string, 'message': string }
  /// Use antes de ações críticas: criar usuário, acessar financeiro, etc.
  static Future<Map<String, dynamic>> verificarAssinaturaAtiva() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return {'ativo': false, 'message': 'Usuário não logado'};
      }

      final userData = await getCurrentUserData();
      if (userData == null || userData['role'] != 'admin') {
        // Se não é admin, considera ativo (verificação feita via academia para subs)
        return {'ativo': true, 'status': 'active', 'message': 'Usuário ativo'};
      }

      final admin = await _client
          .from('users_adm')
          .select()
          .eq('id', userData['id'])
          .single();

      final status = admin['assinatura_status'] ?? 'active';
      final isBlocked = admin['is_blocked'] ?? false;

      // BLOQUEIO RÍGIDO - SEM TOLERÂNCIA
      if (admin['assinatura_expirada'] != null) {
        final expirada = DateTime.parse(admin['assinatura_expirada']);
        final now = DateTime.now();

        // 1. Falta menos de 24h -> AVISO (E data ainda não passou)
        final warningThreshold = expirada.subtract(const Duration(hours: 24));
        if (now.isAfter(warningThreshold) && now.isBefore(expirada)) {
          return {
            'ativo': true,
            'status': 'warning', // Status especial para mostrar aviso laranja
            'message':
                'Atenção: Sua assinatura vence em menos de 24 horas. Renove para evitar bloqueio.',
            'aviso': true,
          };
        }

        // 2. Passou da Data -> BLOQUEIO TOTAL
        if (now.isAfter(expirada)) {
          // AUTO-FIX: Se expirou e ainda não está suspended
          if (status != 'suspended') {
            try {
              await _client.from('users_adm').update({
                'assinatura_status': 'suspended',
                'is_blocked': true
              }).eq('id', userData['id']);
            } catch (_) {}
          }

          return {
            'ativo': false,
            'status': 'suspended',
            'message': 'Sua assinatura está suspensa. Renove para continuar.',
          };
        }
      }

      // 3. Status Explícito no Banco
      if (status == 'suspended' ||
          status == 'pending_deletion' ||
          isBlocked == true) {
        return {
          'ativo': false,
          'status': 'suspended',
          'message': 'Sua assinatura está suspensa. Renove para continuar.',
        };
      }

      return {'ativo': true, 'status': 'active', 'message': 'Assinatura ativa'};
    } catch (e) {
      print('Erro ao verificar assinatura: $e');
      return {'ativo': false, 'message': 'Erro na verificação'};
    }
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
  static Future<Map<String, dynamic>?> getCurrentUserData(
      {bool forceRefresh = false}) async {
    final user = getCurrentUser();
    if (user == null) {
      _cachedUserData = null;
      return null;
    }

    if (_cachedUserData != null && !forceRefresh) {
      return _cachedUserData;
    }

    final userData = await _findUserInTables(user.id);
    if (userData != null) {
      _cachedUserData = userData;
      return userData;
    }

    // Se não achou nas tabelas mas está logado, trata como visitante
    _cachedUserData = {
      'id': user.id,
      'email': user.email,
      'nome': user.userMetadata?['name'] ?? 'Visitante',
      'role': 'visitor',
      'is_blocked': false,
    };
    return _cachedUserData;
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
  /// Enviar email de recuperação de senha (Via Edge Function Customizada)
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      print('📧 Enviando email de recuperação via Edge Function para: $email');

      // Invocar a Edge Function que usa Resend e gera token customizado (sem PKCE restritivo)
      final response =
          await _client.functions.invoke('send-password-reset', body: {
        'email': email,
      });

      if (response.status != 200) {
        print('❌ Erro na Edge Function: ${response.status} - ${response.data}');
        final errorMsg = response.data is Map && response.data['error'] != null
            ? response.data['error']
            : 'Erro ao processar envio';
        throw Exception(errorMsg);
      }

      print('✅ Email de recuperação enviado com sucesso via Edge Function');
    } on FunctionException catch (e) {
      print('❌ Erro FunctionException: $e');
      throw Exception('Erro na função de envio: ${e.details ?? e.toString()}');
    } catch (e) {
      print('❌ Erro inesperado ao enviar password reset: $e');
      throw Exception('Erro ao enviar email de recuperação: ${e.toString()}');
    }
  }

  /// Redefinir senha usando token do email
  static Future<void> resetPassword(
      String accessToken, String newPassword) async {
    try {
      print('🔐 Redefinindo senha (Iniciando Fluxo Nativo)...');

      // 1. Validar senha
      if (newPassword.length < 6) {
        throw Exception('A senha deve ter no mínimo 6 caracteres');
      }

      // 2. Tentar Fluxo Nativo (Set Session -> Update User)
      // Se o token for um access_token válido de recovery, isso vai funcionar
      try {
        await _client.auth.setSession(accessToken);
        final userResponse = await _client.auth.updateUser(
          UserAttributes(password: newPassword),
        );

        if (userResponse.user != null) {
          print('✅ Senha redefinida com sucesso via Fluxo Nativo');
          await _client.auth.signOut();
          return;
        }
      } catch (nativeError) {
        print('⚠️ Fluxo Nativo falhou, tentando RPC Customizada: $nativeError');
      }

      // 3. Fallback: Chamar a RPC customizada (para tokens manuais se houver)
      final response = await _client.rpc('reset_password_with_token', params: {
        'reset_token': accessToken,
        'new_password': newPassword,
      });

      if (response != null && response['success'] == true) {
        print('✅ Senha redefinida com sucesso via RPC');
        if (_client.auth.currentSession != null) {
          await _client.auth.signOut();
        }
      } else {
        final errorMsg = response?['message'] ??
            'Erro ao redefinir senha. Link inválido ou expirado.';
        throw Exception(errorMsg);
      }
    } on AuthException catch (e) {
      print('❌ Erro AuthException ao redefinir: ${e.message}');
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      print('❌ Erro inesperado ao redefinir: $e');
      throw Exception(e.toString());
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

  /// Verifica se o usuário atual está bloqueado e força logout se necessário
  static Future<void> checkBlockedStatus(BuildContext context) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final data = await _findUserInTables(user.id);
      if (data == null) return;

      bool shouldBlock = false;
      String message =
          'Sua conta foi bloqueada temporariamente. Entre em contato com a administração da academia.';

      if (data['role'] == 'admin') {
        final status = data['assinatura_status'];
        final isBlocked = data['is_blocked'] ?? false;

        // BLOQUEIO RÍGIDO - SEM TOLERÂNCIA
        bool isDataExpirada = false;
        if (data['assinatura_expirada'] != null) {
          try {
            final expirada = DateTime.parse(data['assinatura_expirada']);
            if (DateTime.now().isAfter(expirada)) {
              isDataExpirada = true;
            }
          } catch (_) {}
        }

        if (status == 'suspended' ||
            status == 'pending_deletion' ||
            status == 'canceled' ||
            isBlocked == true ||
            isDataExpirada == true) {
          shouldBlock = true;
          message = 'Sua assinatura está suspensa. Renove para continuar.';

          // Auto-Fix: Atualizar banco se necessário (SÍNCRONO)
          if (isDataExpirada && status != 'suspended') {
            try {
              await _client.from('users_adm').update({
                'assinatura_status': 'suspended',
                'is_blocked': true
              }).eq('id', user.id);
            } catch (e) {
              print('Erro no auto-update de status: $e');
            }
          }
        }
      } else {
        // Subordinados (Student, Trainer, Nutritionist)
        // 1. Bloqueio Individual
        if (data['is_blocked'] == true) {
          shouldBlock = true;
        }
        // 2. Bloqueio da Academia (Cascata RÍGIDA)
        else if (data['id_academia'] != null) {
          final academiaStatus =
              await verificarAcademiaSuspensa(data['id_academia']);
          if (academiaStatus['suspended'] == true) {
            shouldBlock = true;
            message = academiaStatus['message'] ??
                'O acesso a conta está interrompido por falta de pagamento da assinatura da academia!';
          }
        }
      }

      if (shouldBlock) {
        if (!context.mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red[700], size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Acesso Bloqueado',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  await logout();
                  if (context.mounted) {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sair'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Erro ao verificar status de bloqueio: $e');
    }
  }
}
