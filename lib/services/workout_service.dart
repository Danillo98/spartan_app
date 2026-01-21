import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class WorkoutService {
  static final _client = Supabase.instance.client;

  // Buscar alunos do personal que têm fichas
  // Buscar TODOS os alunos da academia do personal
  static Future<List<Map<String, dynamic>>> getMyStudents() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      // 1. Buscar id_academia do personal logado
      final personalData = await _client
          .from('users_personal')
          .select('id_academia')
          .eq('id', user.id)
          .maybeSingle();

      if (personalData == null || personalData['id_academia'] == null) {
        return [];
      }
      final idAcademia = personalData['id_academia'];

      // 2. Buscar todos os alunos da mesma academia
      final students = await _client
          .from('users_alunos')
          .select('id, nome, email')
          .eq('id_academia', idAcademia)
          .order('nome');

      // 3. Buscar fichas para calcular count (opcional, mas mantendo compatibilidade)
      // Filtramos fichas onde este personal é o criador, ou da academia toda?
      // O método original retornava "students of the personal".
      // Para manter a contagem de "quantas fichas EU fiz para esse aluno":
      final workouts = await _client
          .from('workouts')
          .select('student_id')
          .eq('personal_id', user.id);

      // Contar fichas por aluno
      final studentsWithCount = students.map((student) {
        final workoutCount =
            workouts.where((w) => w['student_id'] == student['id']).length;

        return {
          'id': student['id'],
          'name': student['nome'],
          'email': student['email'],
          'workout_count': workoutCount,
        };
      }).toList();

      return studentsWithCount;
    } catch (e) {
      print('Erro ao buscar alunos: $e');
      return [];
    }
  }

  // Criar Treino
  static Future<Map<String, dynamic>> createWorkout({
    required String studentId,
    required String name,
    String? description,
    String? goal,
    String? difficultyLevel,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      // Buscar id_academia do personal
      final personalData = await _client
          .from('users_personal')
          .select('id_academia')
          .eq('id', user.id)
          .single();

      final idAcademia = personalData['id_academia'];

      final workoutData = await _client
          .from('workouts')
          .insert({
            'personal_id': user.id,
            'student_id': studentId,
            'id_academia': idAcademia, // Insert id_academia
            'name': name,
            'description': description,
            'goal': goal,
            'difficulty_level': difficultyLevel,
            'start_date': startDate?.toIso8601String(),
            'end_date': endDate?.toIso8601String(),
          })
          .select()
          .single();

      // --- NOTIFICATION ---
      try {
        final personal = await _client
            .from('users_personal')
            .select('nome')
            .eq('id', user.id)
            .maybeSingle();
        final personalName = personal?['nome'] ?? 'Seu Personal';

        await NotificationService.notifyNewWorkout(studentId, personalName);
      } catch (e) {
        print('Erro ao enviar push de treino: $e');
      }
      // --------------------

      return {'success': true, 'workout': workoutData};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao criar treino: $e'};
    }
  }

  // ... (Header update skipped)

  // (Note: Jumping to sendAlertToStudents to update it too in the same Step if possible,
  // but tool only allows contiguous block. I will do createWorkout first, then sendAlertToStudents in next call or use multi_replace if applicable.
  // Tool says: "Do NOT use this tool if you are only editing a single contiguous block... use multi_replace".
  // Actually I can use multi_replace for this.)

  // Atualizar Treino (Header)
  static Future<Map<String, dynamic>> updateWorkout({
    required String workoutId,
    String? name,
    String? description,
    String? goal,
    String? difficultyLevel,
    bool? isActive,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (goal != null) updates['goal'] = goal;
      if (difficultyLevel != null)
        updates['difficulty_level'] = difficultyLevel;
      if (isActive != null) updates['is_active'] = isActive;
      if (startDate != null) updates['start_date'] = startDate;
      if (endDate != null) updates['end_date'] = endDate;

      await _client.from('workouts').update(updates).eq('id', workoutId);

      return {'success': true, 'message': 'Ficha atualizada com sucesso!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao atualizar ficha: $e'};
    }
  }

  // Listar Treinos do Personal
  static Future<List<Map<String, dynamic>>> getWorkouts() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('workouts')
          // Join correto com users_alunos
          .select('*, student:users_alunos!student_id(nome)')
          .eq('personal_id', user.id)
          // RLS already handles id_academia isolation via personal_id linkage,
          // but we rely on RLS policies.
          .order('created_at', ascending: false);

      // Adaptar resposta para UI
      return response.map((w) {
        final studentData = w['student'] as Map<String, dynamic>?;
        // Criar um objeto student compatível com a UI que espera 'name'
        final adaptedStudent = studentData != null
            ? {'name': studentData['nome'], 'photo_url': null}
            : null;

        final newMap = Map<String, dynamic>.from(w);
        newMap['student'] = adaptedStudent;
        return newMap;
      }).toList();
    } catch (e) {
      print('Erro ao buscar treinos: $e');
      return [];
    }
  }

  // Buscar treinos por aluno
  static Future<List<Map<String, dynamic>>> getWorkoutsByStudent(
      String studentId) async {
    try {
      final response = await _client
          .from('workouts')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      // Buscar informações do personal para cada treino
      for (var workout in response) {
        final personalId = workout['personal_id'];
        if (personalId != null) {
          try {
            final personal = await _client
                .from('users_personal')
                .select('id, nome, email')
                .eq('id', personalId)
                .maybeSingle();

            if (personal != null) {
              workout['personal'] = {
                'id': personal['id'],
                'name': personal['nome'],
                'email': personal['email']
              };
            }
          } catch (e) {
            print('Warning: Failed to fetch personal: $e');
          }
        }
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erro ao buscar treinos do aluno: $e');
      return [];
    }
  }

  // Obter Detalhes do Treino (com dias e exercícios)
  static Future<Map<String, dynamic>?> getWorkoutById(String workoutId) async {
    try {
      print('Fetching workout details for ID: $workoutId');

      // 1. Fetch basic workout data
      final workout = await _client
          .from('workouts')
          .select('*')
          .eq('id', workoutId)
          .maybeSingle();

      if (workout == null) {
        print('Workout not found');
        return null;
      }

      print('Workout fetched: ${workout['name']}');

      // 2. Fetch student info if exists
      final studentId = workout['student_id'];
      if (studentId != null) {
        try {
          final studentView = await _client
              .from('users_alunos')
              .select('id, nome, email')
              .eq('id', studentId)
              .maybeSingle();

          if (studentView != null) {
            workout['student'] = {
              'id': studentView['id'],
              'name': studentView['nome'],
              'email': studentView['email']
            };
            print('Student fetched: ${studentView['nome']}');
          }
        } catch (e) {
          print('Warning: Failed to fetch student: $e');
        }
      }

      // 3. Fetch workout days
      final days = await _client
          .from('workout_days')
          .select('*')
          .eq('workout_id', workoutId)
          .order('day_number', ascending: true);

      print('Days fetched: ${days.length}');

      // 4. For each day, fetch exercises
      for (var day in days) {
        final exercises = await _client
            .from('workout_exercises')
            .select('*')
            .eq('day_id', day['id']);

        day['exercises'] = exercises;
        print('Day ${day['day_name']}: ${exercises.length} exercises');
      }

      workout['days'] = days;

      print('Complete workout data assembled successfully');
      return workout;
    } catch (e) {
      print('ERRO FATAL ao buscar detalhes do treino ($workoutId): $e');
      rethrow;
    }
  }

  // Deletar Treino
  static Future<Map<String, dynamic>> deleteWorkout(String workoutId) async {
    try {
      await _client.from('workouts').delete().eq('id', workoutId);
      return {'success': true, 'message': 'Treino excluído com sucesso'};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao excluir treino: $e'};
    }
  }

  // Adicionar Dia de Treino (Divisão)
  static Future<Map<String, dynamic>> addWorkoutDay({
    required String workoutId,
    required String dayName,
    required int dayNumber,
    String? dayLetter,
    String? description,
  }) async {
    try {
      final dayData = await _client
          .from('workout_days')
          .insert({
            'workout_id': workoutId,
            'day_name': dayName,
            'day_number': dayNumber,
            'day_letter': dayLetter,
            'description': description,
          })
          .select()
          .single();
      return {'success': true, 'day': dayData, 'message': 'Dia adicionado!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro: $e'};
    }
  }

  static Future<Map<String, dynamic>?> getWorkoutDay(
      String workoutId, int dayNumber) async {
    try {
      final response = await _client
          .from('workout_days')
          .select()
          .eq('workout_id', workoutId)
          .eq('day_number', dayNumber)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Deletar Dia
  static Future<Map<String, dynamic>> deleteWorkoutDay(String dayId) async {
    try {
      await _client.from('workout_days').delete().eq('id', dayId);
      return {'success': true, 'message': 'Dia excluído com sucesso!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao deletar dia: $e'};
    }
  }

  // Atualizar Dia de Treino
  static Future<Map<String, dynamic>> updateWorkoutDay({
    required String dayId,
    required String dayName,
    String? dayLetter,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{
        'day_name': dayName,
      };
      if (dayLetter != null) updates['day_letter'] = dayLetter;
      if (description != null) updates['description'] = description;

      await _client.from('workout_days').update(updates).eq('id', dayId);

      return {'success': true, 'message': 'Dia atualizado com sucesso!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao atualizar dia: $e'};
    }
  }

  // Adicionar Exercício
  static Future<Map<String, dynamic>> addExercise({
    required String workoutDayId,
    required String name,
    String? muscleGroup,
    required int sets,
    required String reps,
    int? weight,
    int? restSeconds,
  }) async {
    try {
      final exerciseData = await _client
          .from('workout_exercises')
          .insert({
            'day_id': workoutDayId,
            'exercise_name': name,
            'muscle_group': muscleGroup,
            'sets': sets,
            'reps': reps,
            'weight_kg': weight,
            'rest_seconds': restSeconds,
          })
          .select()
          .single();
      return {
        'success': true,
        'exercise': exerciseData,
        'message': 'Exercício adicionado!'
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro: $e'};
    }
  }

  // Atualizar Exercício
  static Future<Map<String, dynamic>> updateExercise({
    required String exerciseId,
    String? name,
    String? muscleGroup,
    int? sets,
    String? reps,
    int? weight,
    int? restSeconds,
    String? technique,
    String? notes,
    String? videoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['exercise_name'] = name;
      if (muscleGroup != null) updates['muscle_group'] = muscleGroup;
      if (sets != null) updates['sets'] = sets;
      if (reps != null) updates['reps'] = reps;

      if (weight != null) updates['weight_kg'] = weight;
      if (restSeconds != null) updates['rest_seconds'] = restSeconds;
      if (technique != null) updates['technique'] = technique;
      if (notes != null) updates['notes'] = notes;
      if (videoUrl != null) updates['video_url'] = videoUrl;

      await _client
          .from('workout_exercises')
          .update(updates)
          .eq('id', exerciseId);

      return {'success': true, 'message': 'Exercício atualizado!'};
    } catch (e) {
      return {'success': false, 'message': 'Erro: $e'};
    }
  }

  // Deletar Exercício
  static Future<void> deleteExercise(String exerciseId) async {
    try {
      await _client.from('workout_exercises').delete().eq('id', exerciseId);
    } catch (e) {
      print('Erro ao deletar exercício: $e');
      throw e;
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

      // Buscar informações do personal
      final personal = await _client
          .from('users_personal')
          .select('nome')
          .eq('id', user.id)
          .maybeSingle();

      final personalName = personal?['nome'] ?? 'Personal Trainer';

      // Inserir notificações para cada aluno
      final notifications = studentIds
          .map((studentId) => {
                'user_id': studentId,
                'title': 'Mensagem do seu Personal',
                'message': message,
                'sender_name': personalName,
                'type': 'alert',
                'is_read': false,
                'created_at': DateTime.now().toIso8601String(),
              })
          .toList();

      await _client.from('notifications').insert(notifications);

      // --- PUSH NOTIFICATIONS ---
      for (var studentId in studentIds) {
        await NotificationService.notifyNotice(
          message, // Content
          'Seu Personal', // Author/Role Label
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

  // Ordenar Dias por número
  static List<Map<String, dynamic>> sortDays(List<dynamic> days) {
    final List<Map<String, dynamic>> sortedDays =
        List<Map<String, dynamic>>.from(days);
    sortedDays
        .sort((a, b) => (a['day_number'] ?? 0).compareTo(b['day_number'] ?? 0));
    return sortedDays;
  }
}
