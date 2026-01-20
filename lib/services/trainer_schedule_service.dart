import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/*
  SQL REQUIRED:

  create table public.training_sessions (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    personal_id uuid not null references public.users_personal(id),
    student_id uuid not null references public.users_alunos(id),
    scheduled_at timestamp with time zone not null,
    status text default 'scheduled', -- scheduled, completed, cancelled
    notes text
  );

  alter table public.training_sessions enable row level security;

  create policy "Personal can view their sessions"
  on public.training_sessions for select
  using (auth.uid() = personal_id);

  create policy "Personal can insert sessions"
  on public.training_sessions for insert
  with check (auth.uid() = personal_id);

  create policy "Personal can update sessions"
  on public.training_sessions for update
  using (auth.uid() = personal_id);

  create policy "Personal can delete sessions"
  on public.training_sessions for delete
  using (auth.uid() = personal_id);
*/

class TrainerScheduleService {
  static final SupabaseClient _client = SupabaseService.client;

  // Listar agendamentos (ordenados por data mais próxima)
  static Future<List<Map<String, dynamic>>> getSessions(
      {DateTime? filterDate}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    var query = _client
        .from('training_sessions')
        .select('*, users_alunos(id, nome, email)')
        .eq('personal_id', user.id);

    if (filterDate != null) {
      // Filtrar pelo dia específico (ignora hora)
      final start = DateTime(filterDate.year, filterDate.month, filterDate.day);
      final end = start.add(const Duration(days: 1));
      query = query
          .gte('scheduled_at', start.toIso8601String())
          .lt('scheduled_at', end.toIso8601String());
    }

    final response = await query.order('scheduled_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Criar agendamento
  static Future<void> createSession({
    required String studentId,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    await _client.from('training_sessions').insert({
      'personal_id': user.id,
      'student_id': studentId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'notes': notes,
    });
  }

  // Deletar agendamento
  static Future<void> deleteSession(String id) async {
    await _client.from('training_sessions').delete().eq('id', id);
  }

  // Lógica inteligente para descobrir o treino do dia
  static Future<Map<String, dynamic>?> getWorkoutForDate(
    String studentId,
    DateTime date,
  ) async {
    // 1. Obter dia da semana (ex: 'Monday')
    // Mapear para Português, pois o app é PT-BR
    final weekDayMap = {
      1: 'Segunda',
      2: 'Terça',
      3: 'Quarta',
      4: 'Quinta',
      5: 'Sexta',
      6: 'Sábado',
      7: 'Domingo',
    };
    final ptDay = weekDayMap[date.weekday] ?? '';

    // 2. Buscar ficha ativa do aluno
    final workout = await _client
        .from('workouts')
        .select('id, name')
        .eq('student_id', studentId)
        .eq('is_active',
            true) // Assumindo que existe flag is_active ou pega o mais recente
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (workout == null) return null; // Sem ficha

    // 3. Buscar se existe um dia com esse nome na ficha
    // Tenta match exato 'Segunda' ou 'Segunda-feira' ou contém a string
    final days = await _client
        .from('workout_days')
        .select('*, workout_exercises(*)')
        .eq('workout_id', workout['id']);

    // Tentar encontrar o dia correspondente
    Map<String, dynamic>? matchDay;
    for (var d in days) {
      final dName = d['day_name'].toString().toLowerCase();
      final target = ptDay.toLowerCase();
      if (dName.contains(target)) {
        matchDay = d;
        break;
      }
    }

    if (matchDay != null) {
      return {
        'workout_name': workout['name'],
        'day_name': matchDay['day_name'],
        'exercises': matchDay['workout_exercises']
      };
    }

    return {
      'workout_name': workout['name'],
      'day_name':
          null, // Ficha existe, mas não tem dia específico configurado com esse nome
    };
  }
}
