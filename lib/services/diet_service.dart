import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'notification_service.dart';
import 'cache_manager.dart';
import 'auth_service.dart';

class DietService {
  static final SupabaseClient _client = SupabaseService.client;

  // Helper: Obter detalhes do usuário atual
  static Future<Map<String, dynamic>> _getContext() async {
    final userData = await AuthService.getCurrentUserData();
    if (userData == null) throw Exception('Usuário não autenticado');

    return {
      'role': userData['role'] == 'admin' ? 'admin' : 'nutritionist',
      'admin_id': userData['created_by_admin_id'] ?? userData['id'],
      'academia': userData['academia'] ?? 'Academia Não Informada',
      'id_academia': userData['id_academia'] ?? userData['id'],
      'cnpj': userData['cpf'] ?? '',
    };
  }

  // Buscar todas as dietas (Admin)
  static Future<List<Map<String, dynamic>>> getAllDiets() async {
    try {
      final context = await _getContext();
      final idAcademia = context['id_academia'];
      final role = context['role'];
      final userId = _client.auth.currentUser!.id;

      // Cache Key
      final cacheKey = role == 'admin'
          ? CacheKeys.allDiets(idAcademia)
          : CacheKeys.dietsByNutritionist(userId);
      final cached = await CacheManager().get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return List<Map<String, dynamic>>.from(cached);
      }

      var query = _client.from('diets').select().eq('id_academia', idAcademia);

      if (role != 'admin') {
        query = query.eq('nutritionist_id', userId);
      }

      final response = await query.order('created_at', ascending: false);

      final populated = await _populateUsers(response);

      // Salvar no cache
      await CacheManager().set(cacheKey, populated);

      return populated;
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

      // --------------------------------------

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
            .select()
            .eq('id', nutritionistId)
            .maybeSingle();
        final nutriName = nutritionist?['nome'] ?? 'Seu Nutricionista';

        await NotificationService.notifyNewDiet(studentId, nutriName);
      } catch (e) {
        print('Erro ao enviar push de dieta: $e');
      }
      // --------------------

      // Invalidar caches relacionados
      await CacheManager().invalidatePattern('diets_*');
      await CacheManager().invalidatePattern('students_*');

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

      // Invalidar caches relacionados
      await CacheManager().invalidatePattern('diets_*');
      await CacheManager().invalidatePattern('diet_detail_$dietId');

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

      // Invalidar caches relacionados
      await CacheManager().invalidatePattern('diets_*');
      await CacheManager().invalidatePattern('diet_detail_$dietId');

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
          .select()
          .inFilter('id', studentIds);
      // Normalizar nome→name
      studentsMap = {
        for (var s in students)
          s['id']: {
            'id': s['id'],
            'name': s['nome'],
            'nome': s['nome'],
            'email': s['email'],
          }
      };
    }

    Map<String, dynamic> nutrisMap = {};
    if (nutriIds.isNotEmpty) {
      // 1. Tentar Nutricionistas
      final nutris = await _client
          .from('users_nutricionista')
          .select()
          .inFilter('id', nutriIds);

      for (var n in nutris) {
        nutrisMap[n['id']] = {
          'id': n['id'],
          'name': n['nome'],
          'nome': n['nome'],
          'email': n['email'],
        };
      }

      // 2. Fallback para Personais
      final missingFromNutri =
          nutriIds.where((id) => !nutrisMap.containsKey(id)).toList();
      if (missingFromNutri.isNotEmpty) {
        final personals = await _client
            .from('users_personal')
            .select()
            .inFilter('id', missingFromNutri);
        for (var p in personals) {
          nutrisMap[p['id']] = {
            'id': p['id'],
            'name': p['nome'],
            'nome': p['nome'],
            'email': p['email'],
          };
        }
      }

      // 3. Fallback para Admins
      final missingFromPersonal =
          nutriIds.where((id) => !nutrisMap.containsKey(id)).toList();
      if (missingFromPersonal.isNotEmpty) {
        final adms = await _client
            .from('users_adm')
            .select()
            .inFilter('id', missingFromPersonal);
        for (var a in adms) {
          nutrisMap[a['id']] = {
            'id': a['id'],
            'name': a['nome'] ?? 'Administrador',
            'nome': a['nome'] ?? 'Administrador',
            'email': a['email'] ?? '',
          };
        }
      }
    }

    return dietList.map((d) {
      return {
        ...d,
        'student': studentsMap[d['student_id']] ??
            {'name': 'Desconhecido', 'nome': 'Desconhecido', 'email': ''},
        'nutritionist': nutrisMap[d['nutritionist_id']] ??
            {'name': 'N/A', 'nome': 'N/A', 'email': ''},
      };
    }).toList();
  }

  // Buscar dietas por nutricionista
  static Future<List<Map<String, dynamic>>> getDietsByNutritionist(
      String nutritionistId) async {
    try {
      // Cache Key
      final cacheKey = CacheKeys.dietsByNutritionist(nutritionistId);
      final cached = await CacheManager().get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return List<Map<String, dynamic>>.from(cached);
      }

      final response = await _client
          .from('diets')
          .select()
          .eq('nutritionist_id', nutritionistId)
          .order('created_at', ascending: false);

      final populated = await _populateUsers(response);

      // Salvar no cache
      await CacheManager().set(cacheKey, populated);

      return populated;
    } catch (e) {
      print('Erro ao buscar dietas: $e');
      return [];
    }
  }

  // Buscar dietas por aluno
  static Future<List<Map<String, dynamic>>> getDietsByStudent(
      String studentId) async {
    try {
      // Cache Key
      final cacheKey = CacheKeys.dietsByStudent(studentId);
      final cached = await CacheManager().get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return List<Map<String, dynamic>>.from(cached);
      }

      final response = await _client
          .from('diets')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      final populated = await _populateUsers(response);

      // Salvar no cache
      await CacheManager().set(cacheKey, populated);

      return populated;
    } catch (e) {
      print('Erro ao buscar dietas aluno: $e');
      return [];
    }
  }

  // Buscar dieta por ID
  static Future<Map<String, dynamic>?> getDietById(String dietId) async {
    try {
      // Cache Key
      final cacheKey = CacheKeys.dietDetail(dietId);
      final cached = await CacheManager().get<Map<String, dynamic>>(cacheKey);
      if (cached != null) return cached;

      // Buscar dieta
      final response =
          await _client.from('diets').select().eq('id', dietId).maybeSingle();

      if (response == null) return null;

      // Buscar dias da dieta
      final dietDays = await _client
          .from('diet_days')
          .select()
          .eq('diet_id', dietId)
          .order('day_number');

      // OTIMIZAÇÃO: Buscar todas as refeições de uma vez (Batch Query)
      if (dietDays.isNotEmpty) {
        final dayIds = dietDays.map((d) => d['id']).toList();
        final allMeals = await _client
            .from('meals')
            .select()
            .inFilter('diet_day_id', dayIds);

        final allMealsList = List<Map<String, dynamic>>.from(allMeals);

        // Distribuir refeições para os dias
        for (var day in dietDays) {
          final dayMeals =
              allMealsList.where((m) => m['diet_day_id'] == day['id']).toList();

          // Ordenar refeições
          dayMeals.sort((a, b) {
            final timeA = _parseTimeToMinutes(a['meal_time']);
            final timeB = _parseTimeToMinutes(b['meal_time']);
            return timeA.compareTo(timeB);
          });

          day['meals'] = dayMeals;
        }
      }

      // Adicionar dias à dieta
      response['diet_days'] = dietDays;

      final populated = await _populateUsers([response]);
      final result = populated.first;

      // Salvar no cache (Detalhes duram mais tempo, mas invalidam em write)
      await CacheManager()
          .set(cacheKey, result, customTTL: const Duration(minutes: 10));

      return result;
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

      // Invalidar cache de detalhes da dieta
      await CacheManager().invalidatePattern('diet_detail_$dietId');

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

      // Invalidar cache de detalhes da dieta (precisamos saber o dietId, mas dietDayId nos dá indiretamente.
      // Como não temos dietId direto aqui, podemos invalidar TODOS os diet_details ou buscar o ID antes.
      // Para performance, ideal seria invalidar tudo de dietas ou aceitar que o detalhe expire.
      // Vamos tentar invalidar via pattern global por segurança agora.
      await CacheManager().invalidatePattern('diet_detail_*');

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

      await CacheManager().invalidatePattern('diet_detail_*');

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

      await CacheManager().invalidatePattern('diet_detail_*');

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

      await CacheManager().invalidatePattern('diet_detail_*');

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
  // Buscar TODOS os alunos do nutricionista (da mesma academia)
  static Future<List<Map<String, dynamic>>> getMyStudents() async {
    try {
      final context = await _getContext();
      final idAcademia = context['id_academia'];
      final role = context['role'];
      final userId = _client.auth.currentUser!.id;

      if (idAcademia == null) return [];

      // Cache Key
      final cacheKey = role == 'admin'
          ? 'students_admin_$idAcademia'
          : CacheKeys.myStudents(userId);
      final cached = await CacheManager().get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return List<Map<String, dynamic>>.from(cached);
      }

      // 1. Buscar todos os alunos da academia
      final students = await _client
          .from('users_alunos')
          .select()
          .eq('id_academia', idAcademia)
          .order('nome');

      // 2. Buscar dietas para calcular count (opcional)
      var dietsQuery = _client
          .from('diets')
          .select('student_id')
          .eq('id_academia', idAcademia);

      if (role != 'admin') {
        dietsQuery = dietsQuery.eq('nutritionist_id', userId);
      }

      final diets = await dietsQuery;

      // Contar dietas por aluno
      final studentsWithCount = students.map((student) {
        final dietCount =
            diets.where((d) => d['student_id'] == student['id']).length;

        return {
          'id': student['id'],
          'name': student['nome'], // Normalizado
          'email': student['email'],
          'diet_count': dietCount,
        };
      }).toList();

      // Salvar no cache
      await CacheManager().set(cacheKey, studentsWithCount);

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
          .select()
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
