/// Model para Administrador
class UserAdm {
  final String id;
  final String? cnpjAcademia;
  final String academia;
  final String nome;
  final String email;
  final String? telefone;
  final String? cnpj;
  final String? cpf;
  final String? endereco;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAdm({
    required this.id,
    this.cnpjAcademia,
    required this.academia,
    required this.nome,
    required this.email,
    this.telefone,
    this.cnpj,
    this.cpf,
    this.endereco,
    this.emailVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAdm.fromJson(Map<String, dynamic> json) {
    return UserAdm(
      id: json['id'] as String,
      cnpjAcademia: json['cnpj_academia'] as String?,
      academia: json['academia'] as String,
      nome: json['nome'] as String,
      email: json['email'] as String,
      telefone: json['telefone'] as String?,
      cnpj: json['cnpj'] as String?,
      cpf: json['cpf'] as String?,
      endereco: json['endereco'] as String?,
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
      'cnpj': cnpj,
      'cpf': cpf,
      'endereco': endereco,
      'email_verified': emailVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
