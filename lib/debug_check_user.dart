import 'package:supabase_flutter/supabase_flutter.dart';

/// Script de debug para verificar se usuário foi criado
/// Execute: dart run lib/debug_check_user.dart
void main() async {
  // Inicializar Supabase (use suas credenciais)
  await Supabase.initialize(
    url: 'SUA_SUPABASE_URL',
    anonKey: 'SUA_ANON_KEY',
  );

  final supabase = Supabase.instance.client;

  print('🔍 Verificando usuário: samara@gmail.com\n');

  // 1. Tentar buscar na tabela pública (como service_role ou admin)
  try {
    final response = await supabase
        .from('users_nutricionista')
        .select()
        .eq('email', 'samara@gmail.com')
        .maybeSingle();

    if (response == null) {
      print('❌ PROBLEMA: Usuário NÃO encontrado em users_nutricionista');
      print('   → O usuário foi criado no Auth mas não na tabela pública');
      print('   → A função create_user_v4 não funcionou corretamente\n');
    } else {
      print('✅ Usuário encontrado em users_nutricionista:');
      print('   ID: ${response['id']}');
      print('   Nome: ${response['nome']}');
      print('   Email: ${response['email']}');
      print('   Academia: ${response['academia']}');
      print('   ID Academia: ${response['id_academia']}');
      print('   Email Verified: ${response['email_verified']}');
      print('   Data Nascimento: ${response['data_nascimento']}\n');
    }
  } catch (e) {
    print('❌ Erro ao buscar usuário: $e\n');
  }

  // 2. Verificar se a função create_user_v4 existe
  try {
    final functionTest = await supabase.rpc('create_user_v4', params: {
      'p_email': 'teste@teste.com',
      'p_password': '123456',
      'p_metadata': {
        'role': 'nutritionist',
        'name': 'Teste',
        'phone': '11999999999',
        'academia': 'Academia Teste',
        'id_academia': '00000000-0000-0000-0000-000000000000',
        'cnpj_academia': '00000000000000',
      }
    });

    print('✅ Função create_user_v4 existe e respondeu:');
    print('   $functionTest\n');
  } catch (e) {
    if (e.toString().contains('not found')) {
      print('❌ PROBLEMA CRÍTICO: Função create_user_v4 NÃO EXISTE no banco!');
      print('   → Você precisa criar a função no Supabase SQL Editor\n');
    } else {
      print('⚠️ Função existe mas retornou erro: $e\n');
    }
  }

  print('=' * 60);
  print('DIAGNÓSTICO:');
  print('=' * 60);
  print('Se o usuário NÃO foi encontrado na tabela pública,');
  print('significa que a função create_user_v4 não está funcionando.');
  print('\nSOLUÇÃO:');
  print('1. Restaure o acesso ao Supabase Dashboard');
  print('2. Execute o script SQL que criei em FIX_USER_LOGIN.sql');
  print('3. Tente cadastrar novamente o usuário\n');
}
