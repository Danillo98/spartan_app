/// Model para Aluno
class UserAluno {
  final String id;
  final String cnpjAcademia;
  final String academia;
  final String nome;
  final String email;
  final String? telefone;
  final String createdByAdminId;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAluno({
    required this.id,
    required this.cnpjAcademia,
    required this.academia,
    required this.nome,
    required this.email,
    this.telefone,
    required this.createdByAdminId,
    this.emailVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAluno.fromJson(Map<String, dynamic> json) {
    return UserAluno(
      id: json['id'] as String,
      cnpjAcademia: json['cnpj_academia'] as String,
      academia: json['academia'] as String,
      nome: json['nome'] as String,
      email: json['email'] as String,
      telefone: json['telefone'] as String?,
      createdByAdminId: json['created_by_admin_id'] as String,
      emailVerified: json['email_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cnpj_academia': cnpjAcademia,
      'academia': academia,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'created_by_admin_id': createdByAdminId,
      'email_verified': emailVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
