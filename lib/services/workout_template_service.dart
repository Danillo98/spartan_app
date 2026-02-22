import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'cache_manager.dart';

class WorkoutTemplateService {
  static final _client = Supabase.instance.client;

  static Future<Map<String, dynamic>> _getContext() async {
    final userData = await AuthService.getCurrentUserData();
    if (userData == null) throw Exception('Usuário não autenticado');

    return {
      'role': userData['role'] == 'admin' ? 'admin' : 'personal',
      'id_academia': userData['id_academia'] ?? userData['id'],
    };
  }

  // Criar Modelo de Treino (Template)
  static Future<Map<String, dynamic>> createTemplate({
    required String name,
    String? description,
    String? goal,
    String? difficultyLevel,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final ctx = await _getContext();
      final idAcademia = ctx['id_academia'];
      final role = ctx['role'];

      final templateData = await _client
          .from('workout_templates')
          .insert({
            'personal_id': role == 'admin' ? null : user.id,
            'id_academia': idAcademia,
            'name': name,
            'description': description,
            'goal': goal,
            'difficulty_level': difficultyLevel,
          })
          .select()
          .single();

      await CacheManager().invalidatePattern('workout_templates_*');

      return {'success': true, 'template': templateData};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao criar modelo de treino: $e'
      };
    }
  }

  // Adicionar dia ao modelo
  static Future<Map<String, dynamic>> addTemplateDay({
    required String templateId,
    required String dayName,
    required int dayNumber,
    String? description,
  }) async {
    try {
      final dayData = await _client
          .from('workout_template_days')
          .insert({
            'template_id': templateId,
            'day_name': dayName,
            'day_number': dayNumber,
            'description': description,
          })
          .select()
          .single();

      return {'success': true, 'day': dayData};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao adicionar dia ao modelo: $e'
      };
    }
  }

  // Buscar todos os modelos
  static Future<List<Map<String, dynamic>>> getTemplates() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final ctx = await _getContext();
      final role = ctx['role'];
      final idAcademia = ctx['id_academia'];

      final cacheKey = 'workout_templates_${idAcademia}_${role}_${user.id}';
      final cached = await CacheManager().get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return List<Map<String, dynamic>>.from(cached);
      }

      var query = _client
          .from('workout_templates')
          .select('*')
          .eq('id_academia', idAcademia);

      if (role == 'personal') {
        query = query.eq('personal_id', user.id);
      }

      final response = await query.order('created_at', ascending: false);
      final result = List<Map<String, dynamic>>.from(response);

      await CacheManager().set(cacheKey, result);
      return result;
    } catch (e) {
      print('Erro ao buscar modelos de treino: $e');
      return [];
    }
  }

  // Buscar modelo por ID
  static Future<Map<String, dynamic>?> getTemplateById(
      String templateId) async {
    try {
      final template = await _client
          .from('workout_templates')
          .select('*, workout_template_days(*)')
          .eq('id', templateId)
          .single();

      return template;
    } catch (e) {
      print('Erro ao buscar dados do modelo: $e');
      return null;
    }
  }

  // Deletar Modelo
  static Future<Map<String, dynamic>> deleteTemplate(String templateId) async {
    try {
      await _client.from('workout_templates').delete().eq('id', templateId);
      await CacheManager().invalidatePattern('workout_templates_*');
      return {'success': true, 'message': 'Modelo excluído com sucesso!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao excluir modelo: $e'};
    }
  }

  // Atualizar Modelo
  static Future<Map<String, dynamic>> updateTemplate({
    required String templateId,
    required String name,
    String? description,
    String? goal,
    String? difficultyLevel,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      await _client.from('workout_templates').update({
        'name': name,
        'description': description,
        'goal': goal,
        'difficulty_level': difficultyLevel,
      }).eq('id', templateId);

      await CacheManager().invalidatePattern('workout_templates_*');

      return {'success': true, 'message': 'Modelo atualizado com sucesso!'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao atualizar modelo de treino: $e'
      };
    }
  }
}
