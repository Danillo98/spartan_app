enum UserRole {
  admin,
  nutritionist,
  trainer,
  student,
}

extension UserRoleExtension on UserRole {
  String get name {
    switch (this) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.nutritionist:
        return 'Nutricionista';
      case UserRole.trainer:
        return 'Personal Trainer';
      case UserRole.student:
        return 'Aluno';
    }
  }
}
