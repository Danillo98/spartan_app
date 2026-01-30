import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'notification_service.dart'; // Import Notification

/*
  SQL REQUIRED FOR THIS SERVICE:

  create table public.physical_assessments (
    id uuid default gen_random_uuid() primary key,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    cnpj_academia text not null,
    nutritionist_id uuid not null references public.users_nutricionista(id),
    student_id uuid not null references public.users_alunos(id),
    assessment_date timestamp with time zone not null,
    weight numeric, -- Peso (kg)
    height numeric, -- Altura (cm)
    neck numeric,   -- Pescoço
    chest numeric,  -- Peitoral
    waist numeric,  -- Cintura
    abdomen numeric, -- Abdômen
    hips numeric,   -- Quadril
    right_arm numeric, -- Braço Direito
    left_arm numeric,  -- Braço Esquerdo
    right_thigh numeric, -- Coxa Direita
    left_thigh numeric,  -- Coxa Esquerda
    right_calf numeric,  -- Panturrilha Direita
    left_calf numeric,   -- Panturrilha Esquerda
    body_fat numeric,    -- % Gordura
    muscle_mass numeric, -- % Massa Muscular
    notes text
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

  // Obter ID da Academia do nutricionista atual
  static Future<String> _getNutritionistAcademyId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final nutri = await _client
        .from('users_nutricionista')
        .select('id_academia')
        .eq('id', user.id)
        .maybeSingle();

    if (nutri != null) return nutri['id_academia'];
    throw Exception('Nutricionista não encontrado ou sem academia vinculada');
  }

  // Buscar todos os relatórios do nutricionista (com dados do aluno)
  static Future<List<Map<String, dynamic>>> getAssessments() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('physical_assessments')
        .select('*, users_alunos(id, nome, email)')
        .eq('nutritionist_id', user.id)
        .order('assessment_date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Buscar todos os relatórios DE UM ALUNO
  static Future<List<Map<String, dynamic>>> getStudentAssessments(
      String studentId) async {
    final response = await _client
        .from('physical_assessments')
        .select('*, users_nutricionista(nome), users_alunos(nome)')
        .eq('student_id', studentId)
        .order('assessment_date', ascending: false);

    return await _populateUsers(response);
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
    double? neck,
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
    double? muscleMass,
    String? notes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final idAcademia = await _getNutritionistAcademyId();

    await _client.from('physical_assessments').insert({
      'id_academia': idAcademia, // Use id_academia
      // 'cnpj_academia': cnpj, // REMOVIDO
      'nutritionist_id': user.id,
      'student_id': studentId,
      'assessment_date': date.toIso8601String(),
      'weight': weight,
      'height': height,
      'neck': neck,
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
      'muscle_mass': muscleMass,
      'notes': notes,
    });
  }

  // Atualizar Relatório
  static Future<void> updateAssessment({
    required String id,
    DateTime? date,
    double? weight,
    double? height,
    double? neck,
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
    double? muscleMass,
    String? notes,
  }) async {
    final Map<String, dynamic> updates = {};
    if (date != null) updates['assessment_date'] = date.toIso8601String();
    updates['weight'] = weight;
    updates['height'] = height;
    updates['neck'] = neck;
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
    updates['muscle_mass'] = muscleMass;
    if (notes != null) updates['notes'] = notes;

    await _client.from('physical_assessments').update(updates).eq('id', id);
  }

  // Excluir Relatório
  static Future<void> deleteAssessment(String id) async {
    await _client.from('physical_assessments').delete().eq('id', id);
  }
}
