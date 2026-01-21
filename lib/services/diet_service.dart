import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'notification_service.dart';

class DietService {
  static final SupabaseClient _client = SupabaseService.client;

  // Helper: Obter detalhes do usuário atual (Nutricionista ou Admin)
  static Future<Map<String, dynamic>> _getContext() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // Tentar como Nutricionista
    final nutri = await _client
        .from('users_nutricionista')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (nutri != null) {
      return {
        'admin_id': nutri['created_by_admin_id'],
        'cnpj': nutri['cnpj_academia'],
        'academia': nutri['academia'],
        'id_academia': nutri['id_academia'], // Add id_academia
      };
    }

    // Tentar como Admin
    final admin = await _client
        .from('users_adm')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (admin != null) {
      return {
        'admin_id': admin['id'],
        'cnpj': admin['cnpj_academia'],
        'academia': admin['academia'],
        'id_academia': admin['id'], // Admin ID is id_academia
      };
    }

    throw Exception('Usuário sem permissão para gerenciar dietas');
  }

  // Buscar todas as dietas (Admin)
  static Future<List<Map<String, dynamic>>> getAllDiets() async {
    try {
      final context = await _getContext();
      final response = await _client
          .from('diets')
          .select()
          .eq('id_academia', context['id_academia']) // Use id_academia filter
          .order('created_at', ascending: false);

      return await _populateUsers(response);
    } catch (e) {
      print('Erro ao buscar todas dietas: $e');
      return [];
    }
  }

  // Criar nova dieta
  static Future<Map<String, dynamic>> createDiet({
    required String name,
    required String description,
    required String studentId,
    required String nutritionistId,
    required String goal,
    required int totalCalories,
    required String startDate,
    String? endDate,
    List<Map<String, dynamic>>? dietDays,
  }) async {
    try {
      final context = await _getContext();

      // Extrair mês e ano da data de início
      final startDateTime = DateTime.parse(startDate);
      final month = startDateTime.month;
      final year = startDateTime.year;

      final dietData = await _client
          .from('diets')
          .insert({
            'name_diet': name,
            'description': description,
            'student_id': studentId,
            'nutritionist_id': nutritionistId,
            'created_by_admin_id': context['admin_id'],
            'cnpj_academia': context['cnpj'],
            'academia': context['academia'],
            'id_academia': context['id_academia'], // Insert id_academia
            'objective_diet': goal,
            'total_calories': totalCalories,
            'start_date': startDate,
            'end_date': endDate,
            'month': month,
            'year': year,
            'status': 'active',
          })
          .select()
          .single();

      if (dietDays != null && dietDays.isNotEmpty) {
        for (var day in dietDays) {
          final dayData = await _client
              .from('diet_days')
              .insert({
                'diet_id': dietData['id'],
                'day_name': day['day_name'],
                'day_number': day['day_number'],
                'total_calories': day['total_calories'],
              })
              .select()
              .single();

          if (day['meals'] != null && (day['meals'] as List).isNotEmpty) {
            for (var meal in day['meals']) {
              await _client.from('meals').insert({
                'diet_day_id': dayData['id'],
                'meal_time': meal['meal_time'],
                'meal_name': meal['meal_name'],
                'foods': meal['foods'],
                'calories': meal['calories'],
                'protein': meal['protein'],
                'carbs': meal['carbs'],
                'fats': meal['fats'],
                'instructions': meal['instructions'],
              });
            }
          }
        }
      }

      // --- NOTIFICATION ---
      try {
        final nutritionist = await _client
            .from('users_nutricionista')
            .select('nome')
            .eq('id', nutritionistId)
            .maybeSingle();
        final nutriName = nutritionist?['nome'] ?? 'Seu Nutricionista';

        await NotificationService.notifyNewDiet(studentId, nutriName);
      } catch (e) {
        print('Erro ao enviar push de dieta: $e');
      }
      // --------------------

      return {
        'success': true,
        'diet': dietData,
        'message': 'Dieta criada com sucesso!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao criar dieta: ${e.toString()}',
      };
    }
  }

  // Atualizar dieta
  static Future<Map<String, dynamic>> updateDiet({
    required String dietId,
    String? nameDiet,
    String? description,
    String? objectiveDiet,
    int? totalCalories,
    String? startDate,
    String? endDate,
    String? status,
    String? studentId,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (nameDiet != null) updates['name_diet'] = nameDiet;
      if (description != null) updates['description'] = description;
      if (objectiveDiet != null) updates['objective_diet'] = objectiveDiet;
      if (totalCalories != null) updates['total_calories'] = totalCalories;
      if (startDate != null) updates['start_date'] = startDate;
      if (endDate != null) updates['end_date'] = endDate;
      if (status != null) updates['status'] = status;
      if (studentId != null) updates['student_id'] = studentId;

      final response = await _client
          .from('diets')
          .update(updates)
          .eq('id', dietId)
          .select()
          .single();

      return {
        'success': true,
        'diet': response,
        'message': 'Dieta atualizada com sucesso!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao atualizar dieta: ${e.toString()}',
      };
    }
  }

  // Deletar dieta
  static Future<Map<String, dynamic>> deleteDiet(String dietId) async {
    try {
      await _client.from('diets').delete().eq('id', dietId);
      return {'success': true, 'message': 'Dieta excluída com sucesso!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao excluir dieta: $e'};
    }
  }

  // Helper para popular dados do aluno e nutricionista
  static Future<List<Map<String, dynamic>>> _populateUsers(
      List<dynamic> diets) async {
    if (diets.isEmpty) return [];

    final dietList = List<Map<String, dynamic>>.from(diets);
    final studentIds =
        dietList.map((d) => d['student_id'].toString()).toSet().toList();
    final nutriIds =
        dietList.map((d) => d['nutritionist_id'].toString()).toSet().toList();

    Map<String, dynamic> studentsMap = {};
    if (studentIds.isNotEmpty) {
      final students = await _client
          .from('users_alunos')
          .select('id, nome, email')
          .inFilter('id', studentIds);
      // Normalizar nome→name
      studentsMap = {
        for (var s in students)
          s['id']: {
            'id': s['id'],
            'name': s['nome'],
            'email': s['email'],
          }
      };
    }

    Map<String, dynamic> nutrisMap = {};
    if (nutriIds.isNotEmpty) {
      final nutris = await _client
          .from('users_nutricionista')
          .select('id, nome, email')
          .inFilter('id', nutriIds);
      // Normalizar nome→name
      nutrisMap = {
        for (var n in nutris)
          n['id']: {
            'id': n['id'],
            'name': n['nome'],
            'email': n['email'],
          }
      };
    }

    return dietList.map((d) {
      return {
        ...d,
        'student': studentsMap[d['student_id']] ??
            {'name': 'Desconhecido', 'email': ''},
        'nutritionist': nutrisMap[d['nutritionist_id']] ??
            {'name': 'Desconhecido', 'email': ''},
      };
    }).toList();
  }

  // Buscar dietas por nutricionista
  static Future<List<Map<String, dynamic>>> getDietsByNutritionist(
      String nutritionistId) async {
    try {
      final response = await _client
          .from('diets')
          .select()
          .eq('nutritionist_id', nutritionistId)
          .order('created_at', ascending: false);

      return await _populateUsers(response);
    } catch (e) {
      print('Erro ao buscar dietas: $e');
      return [];
    }
  }

  // Buscar dietas por aluno
  static Future<List<Map<String, dynamic>>> getDietsByStudent(
      String studentId) async {
    try {
      final response = await _client
          .from('diets')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      return await _populateUsers(response);
    } catch (e) {
      print('Erro ao buscar dietas aluno: $e');
      return [];
    }
  }

  // Buscar dieta por ID
  static Future<Map<String, dynamic>?> getDietById(String dietId) async {
    try {
      // Buscar dieta
      final response =
          await _client.from('diets').select().eq('id', dietId).maybeSingle();

      if (response == null) return null;

      // Buscar dias da dieta
      print('DEBUG: Buscando dias para diet_id: $dietId'); // Debug
      final dietDays = await _client
          .from('diet_days')
          .select()
          .eq('diet_id', dietId)
          .order('day_number');

      print('DEBUG: Dias encontrados: ${dietDays.length}'); // Debug
      print('DEBUG: Dias data: $dietDays'); // Debug

      // Para cada dia, buscar as refeições
      for (var day in dietDays) {
        print('DEBUG: Buscando refeições para day_id: ${day['id']}'); // Debug
        final meals =
            await _client.from('meals').select().eq('diet_day_id', day['id']);

        print('DEBUG: Refeições encontradas: ${meals.length}'); // Debug

        // Ordenar refeições por horário (convertendo para minutos)
        final mealsList = List<Map<String, dynamic>>.from(meals);
        mealsList.sort((a, b) {
          final timeA = _parseTimeToMinutes(a['meal_time']);
          final timeB = _parseTimeToMinutes(b['meal_time']);
          return timeA.compareTo(timeB);
        });

        day['meals'] = mealsList;
      }

      // Adicionar dias à dieta
      response['diet_days'] = dietDays;

      final populated = await _populateUsers([response]);
      return populated.first;
    } catch (e) {
      print('Erro ao buscar dieta: $e');
      return null;
    }
  }

  // Buscar dia da dieta por número
  static Future<Map<String, dynamic>?> getDietDay(
      String dietId, int dayNumber) async {
    try {
      final response = await _client
          .from('diet_days')
          .select()
          .eq('diet_id', dietId)
          .eq('day_number', dayNumber)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Erro ao buscar dia: $e');
      return null;
    }
  }

  // Adicionar dia
  static Future<Map<String, dynamic>> addDietDay({
    required String dietId,
    required String dayName,
    required int dayNumber,
    int? totalCalories,
  }) async {
    try {
      final dayData = await _client
          .from('diet_days')
          .insert({
            'diet_id': dietId,
            'day_name': dayName,
            'day_number': dayNumber,
            'total_calories': totalCalories ?? 0,
          })
          .select()
          .single();
      return {'success': true, 'day': dayData, 'message': 'Dia adicionado!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro: $e'};
    }
  }

  // Adicionar refeição
  static Future<Map<String, dynamic>> addMeal({
    required String dietDayId,
    required String mealTime,
    required String mealName,
    required String foods,
    required int calories,
    int? protein,
    int? carbs,
    int? fats,
    String? instructions,
  }) async {
    try {
      final mealData = await _client
          .from('meals')
          .insert({
            'diet_day_id': dietDayId,
            'meal_time': mealTime,
            'meal_name': mealName,
            'foods': foods,
            'calories': calories,
            'protein': protein,
            'carbs': carbs,
            'fats': fats,
            'instructions': instructions,
          })
          .select()
          .single();
      return {
        'success': true,
        'meal': mealData,
        'message': 'Refeição adicionada!'
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro: $e'};
    }
  }

  // Atualizar refeição
  static Future<Map<String, dynamic>> updateMeal({
    required String mealId,
    String? mealTime,
    String? mealName,
    String? foods,
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
    String? instructions,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (mealTime != null) updates['meal_time'] = mealTime;
      if (mealName != null) updates['meal_name'] = mealName;
      if (foods != null) updates['foods'] = foods;
      if (calories != null) updates['calories'] = calories;
      if (protein != null) updates['protein'] = protein;
      if (carbs != null) updates['carbs'] = carbs;
      if (fats != null) updates['fats'] = fats;
      if (instructions != null) updates['instructions'] = instructions;

      final response = await _client
          .from('meals')
          .update(updates)
          .eq('id', mealId)
          .select()
          .single();
      return {
        'success': true,
        'meal': response,
        'message': 'Refeição atualizada!'
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro: $e'};
    }
  }

  // Deletar refeição
  static Future<Map<String, dynamic>> deleteMeal(String mealId) async {
    try {
      await _client.from('meals').delete().eq('id', mealId);

      return {
        'success': true,
        'message': 'Refeição excluída com sucesso!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao excluir refeição: ${e.toString()}',
      };
    }
  }

  // Deletar dia da dieta (e todas as refeições associadas)
  static Future<Map<String, dynamic>> deleteDietDay(String dietDayId) async {
    try {
      await _client.from('diet_days').delete().eq('id', dietDayId);

      return {
        'success': true,
        'message': 'Dia excluído com sucesso!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao excluir dia: ${e.toString()}',
      };
    }
  }

  // Ordenar dias da semana na ordem correta
  static List<Map<String, dynamic>> sortDaysByWeekOrder(List days) {
    final dayOrder = {
      'Segunda-feira': 1,
      'Terça-feira': 2,
      'Quarta-feira': 3,
      'Quinta-feira': 4,
      'Sexta-feira': 5,
      'Sábado': 6,
      'Domingo': 7,
    };

    final sortedDays = List<Map<String, dynamic>>.from(days);
    sortedDays.sort((a, b) {
      final aName = a['day_name'] ?? '';
      final bName = b['day_name'] ?? '';
      final aOrder = dayOrder[aName] ?? 999;
      final bOrder = dayOrder[bName] ?? 999;
      return aOrder.compareTo(bOrder);
    });

    return sortedDays;
  }

  // Buscar alunos do nutricionista que têm dietas
  static Future<List<Map<String, dynamic>>> getMyStudents() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      // Buscar dietas do nutricionista logado
      final diets = await _client
          .from('diets')
          .select('student_id')
          .eq('nutritionist_id', user.id);

      // Extrair IDs únicos de alunos
      final studentIds = diets
          .map((d) => d['student_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (studentIds.isEmpty) return [];

      // Buscar informações dos alunos
      final students = await _client
          .from('users_alunos')
          .select('id, nome, email')
          .inFilter('id', studentIds)
          .order('nome');

      // Contar dietas por aluno
      final studentsWithCount = students.map((student) {
        final dietCount =
            diets.where((d) => d['student_id'] == student['id']).length;

        return {
          'id': student['id'],
          'name': student['nome'],
          'email': student['email'],
          'diet_count': dietCount,
        };
      }).toList();

      return studentsWithCount;
    } catch (e) {
      print('Erro ao buscar alunos: $e');
      return [];
    }
  }

  // Enviar alerta para alunos selecionados
  static Future<Map<String, dynamic>> sendAlertToStudents({
    required List<String> studentIds,
    required String message,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Usuário não autenticado'};
      }

      // Buscar informações do nutricionista
      final nutritionist = await _client
          .from('users_nutricionista')
          .select('nome')
          .eq('id', user.id)
          .maybeSingle();

      final nutritionistName = nutritionist?['nome'] ?? 'Nutricionista';

      // Inserir notificações para cada aluno
      final notifications = studentIds
          .map((studentId) => {
                'user_id': studentId,
                'title': 'Mensagem do seu Nutricionista',
                'message': message,
                'sender_name': nutritionistName,
                'type': 'alert',
                'is_read': false,
                'created_at': DateTime.now().toIso8601String(),
              })
          .toList();

      await _client.from('notifications').insert(notifications);

      // --- PUSH NOTIFICATIONS ---
      for (var studentId in studentIds) {
        await NotificationService.notifyNotice(
          message,
          'Seu Nutricionista',
          targetStudentId: studentId,
        );
      }
      // --------------------------

      return {
        'success': true,
        'message': 'Alerta enviado para ${studentIds.length} aluno(s)!'
      };
    } catch (e) {
      print('Erro ao enviar alerta: $e');
      return {'success': false, 'message': 'Erro ao enviar alerta: $e'};
    }
  }

  // Helper para converter horário em minutos (para ordenação)
  static int _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0;

    try {
      // Remove espaços
      final time = timeStr.trim();

      // Tenta extrair horas e minutos de formatos como "07:00", "19h", "12:30"
      final regex = RegExp(r'(\d{1,2})[h:]?(\d{0,2})');
      final match = regex.firstMatch(time);

      if (match != null) {
        final hours = int.parse(match.group(1) ?? '0');
        final minutes =
            match.group(2)?.isNotEmpty == true ? int.parse(match.group(2)!) : 0;
        return hours * 60 + minutes;
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }
}
