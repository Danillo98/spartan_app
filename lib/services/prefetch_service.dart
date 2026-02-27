import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'workout_service.dart';
import 'diet_service.dart';
import 'cache_manager.dart';

/// PrefetchService - Pré-carrega dados logo após login usando prioridade por role.
///
/// Estratégia:
/// - Prioridade 1 (await): dados mais prováveis de serem acessados primeiro
/// - Prioridade 2+ (unawaited): dados secundários em background
/// - SEMPRE memoryOnly: evita QuotaExceededError no localStorage
class PrefetchService {
  static final _client = Supabase.instance.client;
  static bool _isRunning = false; // Evita execuções duplicadas

  /// Dispara o pre-fetch em background (fire-and-forget).
  /// Chamar logo após login bem-sucedido.
  static void warmUp() {
    if (_isRunning) return; // Proteção contra chamadas duplas
    unawaited(_warmUpAsync());
  }

  static Future<void> _warmUpAsync() async {
    _isRunning = true;
    try {
      final userData = await AuthService.getCurrentUserData();
      if (userData == null) return;

      final role = userData['role'] as String? ?? '';
      final idAcademia = userData['id_academia'] ?? userData['id'];
      if (idAcademia == null) return;

      // Estabelece conexão com banco imediatamente (elimina cold-start)
      await _ping(idAcademia);

      // Prefetch baseado no role com prioridade
      switch (role) {
        case 'admin':
          await _warmUpAdmin(idAcademia);
          break;
        case 'trainer':
          await _warmUpTrainer(idAcademia);
          break;
        case 'nutritionist':
          await _warmUpNutritionist(idAcademia);
          break;
        case 'student':
          await _warmUpStudent();
          break;
      }

      print('✅ [PrefetchService] Warm-up completo para role: $role');
    } catch (e) {
      print('⚠️ [PrefetchService] Warm-up parcial: $e');
    } finally {
      _isRunning = false;
    }
  }

  // ============================================================
  // ADMIN: Prioridade → fichas de treino, depois alunos e dietas
  // ============================================================
  static Future<void> _warmUpAdmin(String idAcademia) async {
    // P1: Fichas de treino (tela mais acessada por admins)
    await Future.wait([
      _prefetchWorkoutsRaw(idAcademia),
      _prefetchStudentsRaw(idAcademia),
    ]);

    // P2: Dietas em background
    unawaited(_prefetchDietsRaw(idAcademia));
  }

  // ============================================================
  // PERSONAL: Prioridade → alunos e fichas
  // ============================================================
  static Future<void> _warmUpTrainer(String idAcademia) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // P1: Alunos + fichas (o que o personal usa mais)
    await Future.wait([
      _prefetchStudentsRaw(idAcademia),
      _prefetchWorkoutsForPersonal(idAcademia, user.id),
    ]);
  }

  // ============================================================
  // NUTRICIONISTA: Prioridade → alunos e dietas
  // ============================================================
  static Future<void> _warmUpNutritionist(String idAcademia) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // P1: Alunos + dietas
    await Future.wait([
      _prefetchStudentsRaw(idAcademia),
      _prefetchDietsForNutri(user.id),
    ]);
  }

  // ============================================================
  // ALUNO: Prioridade → seus próprios treinos e dietas
  // ============================================================
  static Future<void> _warmUpStudent() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // P1: Treinos do aluno (tela mais acessada)
    await _prefetchStudentWorkouts(user.id);

    // P2: Dietas do aluno em background
    unawaited(_prefetchStudentDiets(user.id));
  }

  // ============================================================
  // HELPERS — todas usam memoryOnly para evitar QuotaExceededError
  // ============================================================

  static Future<void> _ping(String idAcademia) async {
    try {
      await _client
          .from('users_alunos')
          .select('id')
          .eq('id_academia', idAcademia)
          .limit(1)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Fichas de treino para admin (por academia)
  static Future<void> _prefetchWorkoutsRaw(String idAcademia) async {
    try {
      final cacheKey = CacheKeys.allWorkouts(idAcademia);
      if (await CacheManager().get<List<dynamic>>(cacheKey) != null) return;

      final workouts = await WorkoutService.getWorkouts();

      // Re-salvar em memória apenas (evita QuotaExceededError)
      await CacheManager().set(cacheKey, workouts, memoryOnly: true);
      print(
          '✅ [Prefetch] ${workouts.length} fichas (admin) em cache de memória');
    } catch (e) {
      print('⚠️ [Prefetch] Treinos admin: $e');
    }
  }

  /// Fichas de treino para personal
  static Future<void> _prefetchWorkoutsForPersonal(
      String idAcademia, String personalId) async {
    try {
      final cacheKey = CacheKeys.workoutsByPersonal(personalId);
      if (await CacheManager().get<List<dynamic>>(cacheKey) != null) return;

      final workouts = await WorkoutService.getWorkouts();
      await CacheManager().set(cacheKey, workouts, memoryOnly: true);
      print('✅ [Prefetch] ${workouts.length} fichas (personal) em cache');
    } catch (e) {
      print('⚠️ [Prefetch] Treinos personal: $e');
    }
  }

  /// Lista de alunos (id, nome, email apenas — leve)
  static Future<void> _prefetchStudentsRaw(String idAcademia) async {
    try {
      final cacheKey = 'students_admin_$idAcademia';
      if (await CacheManager().get<List<dynamic>>(cacheKey) != null) return;

      final students = await _client
          .from('users_alunos')
          .select('id, nome, email, payment_due_day, is_blocked')
          .eq('id_academia', idAcademia)
          .order('nome')
          .timeout(const Duration(seconds: 10));

      final formatted = students
          .map((s) => {
                'id': s['id'],
                'name': s['nome'],
                'email': s['email'],
                'payment_due_day': s['payment_due_day'],
                'is_blocked': s['is_blocked'],
                'workout_count': 0,
              })
          .toList();

      await CacheManager().set(cacheKey, formatted, memoryOnly: true);
      print('✅ [Prefetch] ${students.length} alunos em cache de memória');
    } catch (e) {
      print('⚠️ [Prefetch] Alunos: $e');
    }
  }

  /// Dietas para admin
  static Future<void> _prefetchDietsRaw(String idAcademia) async {
    try {
      final cacheKey = CacheKeys.allDiets(idAcademia);
      if (await CacheManager().get<List<dynamic>>(cacheKey) != null) return;

      final diets = await DietService.getAllDiets();
      await CacheManager().set(cacheKey, diets, memoryOnly: true);
      print('✅ [Prefetch] ${diets.length} dietas em cache de memória');
    } catch (e) {
      print('⚠️ [Prefetch] Dietas admin: $e');
    }
  }

  /// Dietas para nutricionista
  static Future<void> _prefetchDietsForNutri(String nutriId) async {
    try {
      final cacheKey = CacheKeys.dietsByNutritionist(nutriId);
      if (await CacheManager().get<List<dynamic>>(cacheKey) != null) return;

      final diets = await DietService.getAllDiets();
      await CacheManager().set(cacheKey, diets, memoryOnly: true);
      print('✅ [Prefetch] ${diets.length} dietas (nutri) em cache');
    } catch (e) {
      print('⚠️ [Prefetch] Dietas nutri: $e');
    }
  }

  /// Treinos do aluno
  static Future<void> _prefetchStudentWorkouts(String studentId) async {
    try {
      final cacheKey = CacheKeys.workoutsByStudent(studentId);
      if (await CacheManager().get<List<dynamic>>(cacheKey) != null) return;

      final workouts = await _client
          .from('workouts')
          .select('id, name, description, goal, is_active, created_at')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final result = List<Map<String, dynamic>>.from(workouts);
      await CacheManager().set(cacheKey, result, memoryOnly: true);
      print('✅ [Prefetch] ${result.length} treinos do aluno em cache');
    } catch (e) {
      print('⚠️ [Prefetch] Treinos aluno: $e');
    }
  }

  /// Dietas do aluno
  static Future<void> _prefetchStudentDiets(String studentId) async {
    try {
      final cacheKey = CacheKeys.dietsByStudent(studentId);
      if (await CacheManager().get<List<dynamic>>(cacheKey) != null) return;

      final diets = await _client
          .from('diets')
          .select('id, name, description, goal, is_active, created_at')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final result = List<Map<String, dynamic>>.from(diets);
      await CacheManager().set(cacheKey, result, memoryOnly: true);
      print('✅ [Prefetch] ${result.length} dietas do aluno em cache');
    } catch (e) {
      print('⚠️ [Prefetch] Dietas aluno: $e');
    }
  }
}
