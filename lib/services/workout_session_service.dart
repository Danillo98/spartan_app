class WorkoutSessionService {
  // Mapa estático para guardar o progresso em MEMÓRIA
  // Chave: ID do Treino
  // Valor: Set de IDs dos exercícios concluídos
  static final Map<String, Set<String>> _sessions = {};

  // Obter exercícios concluídos de um treino específico
  static Set<String> getCompletedExercises(String workoutId) {
    if (!_sessions.containsKey(workoutId)) {
      _sessions[workoutId] = {};
    }
    return _sessions[workoutId]!;
  }

  // Marcar exercício como feito/não feito
  static void toggleExercise(String workoutId, String exerciseId) {
    final session = getCompletedExercises(workoutId);
    if (session.contains(exerciseId)) {
      session.remove(exerciseId);
    } else {
      session.add(exerciseId);
    }
  }

  // Limpar sessão (se necessário futuramente)
  static void clearSession(String workoutId) {
    _sessions.remove(workoutId);
  }
}
