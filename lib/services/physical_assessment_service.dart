import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/*
  SQL REQUIRED FOR THIS SERVICE:

  -- New columns needed for the updated physical assessment form:
  alter table public.physical_assessments
  add column shoulder numeric,
  add column right_forearm numeric,
  add column left_forearm numeric,
  add column skinfold_chest numeric,
  add column skinfold_abdomen numeric,
  add column skinfold_thigh numeric,
  add column skinfold_calf numeric,
  add column skinfold_triceps numeric,
  add column skinfold_biceps numeric,
  add column skinfold_subscapular numeric,
  add column skinfold_suprailiac numeric,
  add column skinfold_midaxillary numeric,
  add column workout_focus text;

  -- Previous table definition:
  create table public.physical_assessments (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    cnpj_academia text not null,
    nutritionist_id uuid not null references public.users_nutricionista(id),
    student_id uuid not null references public.users_alunos(id),
    assessment_date timestamp with time zone not null,
    weight numeric, -- Peso (kg)
    height numeric, -- Estatura (cm)
    neck numeric,   -- Pescoço
    chest numeric,  -- Tórax
    waist numeric,  -- Cintura
    abdomen numeric, -- Abdômen
    hips numeric,   -- Quadril
    right_arm numeric, -- Mesoumeral Dir.
    left_arm numeric,  -- Mesoumeral Esq.
    right_thigh numeric, -- Mesofemural Dir.
    left_thigh numeric,  -- Mesofemural Esq.
    right_calf numeric,  -- Perna Dir.
    left_calf numeric,   -- Perna Esq.
    body_fat numeric,    -- % Gordura
    muscle_mass numeric, -- % Massa Muscular
    notes text,
    -- New fields
    shoulder numeric,
    right_forearm numeric,
    left_forearm numeric,
    skinfold_chest numeric,
    skinfold_abdomen numeric,
    skinfold_thigh numeric,
    skinfold_calf numeric,
    skinfold_triceps numeric,
    skinfold_biceps numeric,
    skinfold_subscapular numeric,
    skinfold_suprailiac numeric,
    skinfold_midaxillary numeric,
    workout_focus text
  );

  -- RLS Policies
  alter table public.physical_assessments enable row level security;

  create policy "Nutritionists can view their academy assessments"
  on public.physical_assessments for select
  using (cnpj_academia = (select cnpj_academia from public.users_nutricionista where id = auth.uid()));

  create policy "Nutritionists can insert assessments"
  on public.physical_assessments for insert
  with check (auth.uid() = nutritionist_id);

  create policy "Nutritionists can update assessments"
  on public.physical_assessments for update
  using (auth.uid() = nutritionist_id);

  create policy "Nutritionists can delete assessments"
  on public.physical_assessments for delete
  using (auth.uid() = nutritionist_id);
*/

class PhysicalAssessmentService {
  static final SupabaseClient _client = SupabaseService.client;

  // Obter ID da Academia atual (Funciona para Admin, Nutri e Personal)
  static Future<String> _getAcademyId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // 1. Tentar Nutricionista
    final nutri = await _client
        .from('users_nutricionista')
        .select('id_academia')
        .eq('id', user.id)
        .maybeSingle();
    if (nutri != null && nutri['id_academia'] != null)
      return nutri['id_academia'];

    // 2. Tentar Personal
    final personal = await _client
        .from('users_personal')
        .select('id_academia')
        .eq('id', user.id)
        .maybeSingle();
    if (personal != null && personal['id_academia'] != null)
      return personal['id_academia'];

    // 3. Tentar Admin
    final admin = await _client
        .from('users_adm')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (admin != null) return admin['id'];

    throw Exception('Academia não encontrada para o usuário atual.');
  }

  // Buscar todos os relatórios da academia
  static Future<List<Map<String, dynamic>>> getAssessments() async {
    try {
      final academyId = await _getAcademyId();

      final response = await _client
          .from('physical_assessments')
          .select('*, users_alunos(id, nome, email)')
          .eq('id_academia', academyId)
          .order('assessment_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Erro ao buscar avaliações: $e');
      return [];
    }
  }

  // Buscar todos os relatórios DE UM ALUNO
  static Future<List<Map<String, dynamic>>> getStudentAssessments(
      String studentId) async {
    try {
      final response = await _client
          .from('physical_assessments')
          .select('*, users_nutricionista(nome), users_alunos(nome)')
          .eq('student_id', studentId)
          .order('assessment_date', ascending: false);

      return await _populateUsers(response);
    } catch (e) {
      print('Erro ao buscar avaliações do aluno: $e');
      return [];
    }
  }

  // Lógica COPIADA do DietService para popular nomes manualmente (Bypass RLS)
  static Future<List<Map<String, dynamic>>> _populateUsers(
      List<dynamic> assessments) async {
    if (assessments.isEmpty) return [];

    final assessmentList = List<Map<String, dynamic>>.from(assessments);
    final nutriIds = assessmentList
        .map((a) => a['nutritionist_id'].toString())
        .where((id) => id != 'null')
        .toSet()
        .toList();

    Map<String, dynamic> nutrisMap = {};
    if (nutriIds.isNotEmpty) {
      // 1. Tenta buscar em Nutricionistas
      final nutris = await _client
          .from('users_nutricionista')
          .select('id, nome, email')
          .inFilter('id', nutriIds);

      nutrisMap.addAll({
        for (var n in nutris)
          n['id']: {
            'id': n['id'],
            'nome': n['nome'],
            'name': n['nome'], // Adicionado
            'email': n['email'],
          }
      });

      // 2. Fallback para Personais (IDs que não foram achados)
      final missingIds =
          nutriIds.where((id) => !nutrisMap.containsKey(id)).toList();
      if (missingIds.isNotEmpty) {
        final personals = await _client
            .from('users_personal')
            .select('id, nome, email')
            .inFilter('id', missingIds);

        nutrisMap.addAll({
          for (var p in personals)
            p['id']: {
              'id': p['id'],
              'nome': p['nome'],
              'name': p['nome'],
              'email': p['email'],
            }
        });
      }

      // 3. Fallback para Admins (última tentativa)
      final stillMissing =
          nutriIds.where((id) => !nutrisMap.containsKey(id)).toList();
      if (stillMissing.isNotEmpty) {
        final adms = await _client
            .from('users_adm')
            .select('id, nome') // Adm as vezes não tem email público
            .inFilter('id', stillMissing);

        nutrisMap.addAll({
          for (var a in adms)
            a['id']: {
              'id': a['id'],
              'nome': a['nome'] ?? 'Administração',
              'name': a['nome'] ?? 'Administração',
              'email': '',
            }
        });
      }
    }

    // Populando o resultado final
    return assessmentList.map((a) {
      final nid = a['nutritionist_id'].toString();
      final existingUserObj = a['users_nutricionista'] ?? {};

      // Pega do mapa manual OU do objeto que veio do join (se existir) OU 'Nutricionista'
      final resolvedUser =
          nutrisMap[nid] ?? (existingUserObj is Map ? existingUserObj : {});
      final resolvedName =
          resolvedUser['nome'] ?? resolvedUser['name'] ?? 'Nutricionista';

      return {
        ...a,
        'users_nutricionista': {
          ...(existingUserObj is Map ? existingUserObj : {}),
          'nome': resolvedName,
        }
      };
    }).toList();
  }

  // Criar Relatório
  static Future<void> createAssessment({
    required String studentId,
    required DateTime date,
    double? weight,
    double? height,
    double? chest,
    double? waist,
    double? abdomen,
    double? hips,
    double? rightArm,
    double? leftArm,
    double? rightThigh,
    double? leftThigh,
    double? rightCalf,
    double? leftCalf,
    double? bodyFat,
    double? shoulder,
    double? rightForearm,
    double? leftForearm,
    double? skinfoldChest,
    double? skinfoldAbdomen,
    double? skinfoldThigh,
    double? skinfoldCalf,
    double? skinfoldTriceps,
    double? skinfoldBiceps,
    double? skinfoldSubscapular,
    double? skinfoldSuprailiac,
    double? skinfoldMidaxillary,
    String? workoutFocus,
    double? bodyFat3,
    double? bodyFat7,
    String? gender,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final idAcademia = await _getAcademyId();

    await _client.from('physical_assessments').insert({
      'id_academia': idAcademia, // Use id_academia
      // 'cnpj_academia': cnpj, // REMOVIDO
      'nutritionist_id': user.id,
      'student_id': studentId,
      'assessment_date': date.toIso8601String(),
      'weight': weight,
      'height': height,
      'chest': chest,
      'waist': waist,
      'abdomen': abdomen,
      'hips': hips,
      'right_arm': rightArm,
      'left_arm': leftArm,
      'right_thigh': rightThigh,
      'left_thigh': leftThigh,
      'right_calf': rightCalf,
      'left_calf': leftCalf,
      'body_fat': bodyFat,
      'shoulder': shoulder,
      'right_forearm': rightForearm,
      'left_forearm': leftForearm,
      'skinfold_chest': skinfoldChest,
      'skinfold_abdomen': skinfoldAbdomen,
      'skinfold_thigh': skinfoldThigh,
      'skinfold_calf': skinfoldCalf,
      'skinfold_triceps': skinfoldTriceps,
      'skinfold_biceps': skinfoldBiceps,
      'skinfold_subscapular': skinfoldSubscapular,
      'skinfold_suprailiac': skinfoldSuprailiac,
      'skinfold_midaxillary': skinfoldMidaxillary,
      'workout_focus': workoutFocus,
      'body_fat_3_folds': bodyFat3,
      'body_fat_7_folds': bodyFat7,
      'gender': gender,
    });
  }

  // Atualizar Relatório
  static Future<void> updateAssessment({
    required String id,
    DateTime? date,
    double? weight,
    double? height,
    double? chest,
    double? waist,
    double? abdomen,
    double? hips,
    double? rightArm,
    double? leftArm,
    double? rightThigh,
    double? leftThigh,
    double? rightCalf,
    double? leftCalf,
    double? bodyFat,
    double? shoulder,
    double? rightForearm,
    double? leftForearm,
    double? skinfoldChest,
    double? skinfoldAbdomen,
    double? skinfoldThigh,
    double? skinfoldCalf,
    double? skinfoldTriceps,
    double? skinfoldBiceps,
    double? skinfoldSubscapular,
    double? skinfoldSuprailiac,
    double? skinfoldMidaxillary,
    String? workoutFocus,
    double? bodyFat3,
    double? bodyFat7,
    String? gender,
  }) async {
    final Map<String, dynamic> updates = {};
    if (date != null) updates['assessment_date'] = date.toIso8601String();
    updates['weight'] = weight;
    updates['height'] = height;
    updates['chest'] = chest;
    updates['waist'] = waist;
    updates['abdomen'] = abdomen;
    updates['hips'] = hips;
    updates['right_arm'] = rightArm;
    updates['left_arm'] = leftArm;
    updates['right_thigh'] = rightThigh;
    updates['left_thigh'] = leftThigh;
    updates['right_calf'] = rightCalf;
    updates['left_calf'] = leftCalf;
    updates['body_fat'] = bodyFat;
    updates['shoulder'] = shoulder;
    updates['right_forearm'] = rightForearm;
    updates['left_forearm'] = leftForearm;
    updates['skinfold_chest'] = skinfoldChest;
    updates['skinfold_abdomen'] = skinfoldAbdomen;
    updates['skinfold_thigh'] = skinfoldThigh;
    updates['skinfold_calf'] = skinfoldCalf;
    updates['skinfold_triceps'] = skinfoldTriceps;
    updates['skinfold_biceps'] = skinfoldBiceps;
    updates['skinfold_subscapular'] = skinfoldSubscapular;
    updates['skinfold_suprailiac'] = skinfoldSuprailiac;
    updates['skinfold_midaxillary'] = skinfoldMidaxillary;
    if (workoutFocus != null) updates['workout_focus'] = workoutFocus;
    updates['body_fat_3_folds'] = bodyFat3;
    updates['body_fat_7_folds'] = bodyFat7;
    if (gender != null) updates['gender'] = gender;

    await _client.from('physical_assessments').update(updates).eq('id', id);
  }

  // Excluir Relatório
  static Future<void> deleteAssessment(String id) async {
    await _client.from('physical_assessments').delete().eq('id', id);
  }
}
