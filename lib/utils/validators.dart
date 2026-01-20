/// Validadores de dados para garantir segurança e integridade
class Validators {
  // ============================================
  // VALIDAÇÃO DE CPF
  // ============================================
  static bool isValidCPF(String cpf) {
    // Remove caracteres não numéricos
    cpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');

    // Verifica se tem 11 dígitos
    if (cpf.length != 11) return false;

    // Verifica se todos os dígitos são iguais (CPF inválido)
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    // Validação do primeiro dígito verificador
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cpf[i]) * (10 - i);
    }
    int digit1 = 11 - (sum % 11);
    if (digit1 >= 10) digit1 = 0;
    if (digit1 != int.parse(cpf[9])) return false;

    // Validação do segundo dígito verificador
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cpf[i]) * (11 - i);
    }
    int digit2 = 11 - (sum % 11);
    if (digit2 >= 10) digit2 = 0;
    if (digit2 != int.parse(cpf[10])) return false;

    return true;
  }

  // ============================================
  // VALIDAÇÃO DE CNPJ
  // ============================================
  static bool isValidCNPJ(String cnpj) {
    // Remove caracteres não numéricos
    cnpj = cnpj.replaceAll(RegExp(r'[^0-9]'), '');

    // Verifica se tem 14 dígitos
    if (cnpj.length != 14) return false;

    // Verifica se todos os dígitos são iguais (CNPJ inválido)
    if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) return false;

    // Validação do primeiro dígito verificador
    List<int> weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += int.parse(cnpj[i]) * weights1[i];
    }
    int digit1 = sum % 11 < 2 ? 0 : 11 - (sum % 11);
    if (digit1 != int.parse(cnpj[12])) return false;

    // Validação do segundo dígito verificador
    List<int> weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    sum = 0;
    for (int i = 0; i < 13; i++) {
      sum += int.parse(cnpj[i]) * weights2[i];
    }
    int digit2 = sum % 11 < 2 ? 0 : 11 - (sum % 11);
    if (digit2 != int.parse(cnpj[13])) return false;

    return true;
  }

  // ============================================
  // VALIDAÇÃO DE EMAIL
  // ============================================
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;

    // Regex para validação de email
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) return false;

    // Lista de domínios de email descartáveis conhecidos
    final disposableEmailDomains = [
      'tempmail.com',
      'throwaway.email',
      'guerrillamail.com',
      'mailinator.com',
      '10minutemail.com',
      'trashmail.com',
    ];

    final domain = email.split('@').last.toLowerCase();
    if (disposableEmailDomains.contains(domain)) return false;

    return true;
  }

  // ============================================
  // VALIDAÇÃO DE TELEFONE BRASILEIRO
  // ============================================
  static bool isValidPhone(String phone) {
    // Remove caracteres não numéricos
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Verifica se tem 10 ou 11 dígitos (com DDD)
    if (phone.length != 10 && phone.length != 11) return false;

    // Verifica se o DDD é válido (11-99)
    final ddd = int.tryParse(phone.substring(0, 2));
    if (ddd == null || ddd < 11 || ddd > 99) return false;

    // Verifica se o primeiro dígito do número é válido
    final firstDigit = int.parse(phone[2]);
    if (phone.length == 11 && firstDigit != 9)
      return false; // Celular deve começar com 9

    return true;
  }

  // ============================================
  // VALIDAÇÃO DE SENHA FORTE
  // ============================================
  static Map<String, dynamic> validatePassword(String password) {
    final errors = <String>[];

    if (password.length < 8) {
      errors.add('A senha deve ter no mínimo 8 caracteres');
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      errors.add('A senha deve conter pelo menos uma letra maiúscula');
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      errors.add('A senha deve conter pelo menos uma letra minúscula');
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      errors.add('A senha deve conter pelo menos um número');
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      errors.add('A senha deve conter pelo menos um caractere especial');
    }

    // Verifica senhas comuns
    final commonPasswords = [
      '12345678',
      'password',
      'senha123',
      'admin123',
      'qwerty123',
    ];

    if (commonPasswords.contains(password.toLowerCase())) {
      errors.add('Esta senha é muito comum. Escolha uma senha mais segura');
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'strength': _calculatePasswordStrength(password),
    };
  }

  static int _calculatePasswordStrength(String password) {
    int strength = 0;

    if (password.length >= 8) strength += 20;
    if (password.length >= 12) strength += 20;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 15;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 15;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 15;

    return strength.clamp(0, 100);
  }

  // ============================================
  // SANITIZAÇÃO DE STRINGS (PREVENÇÃO XSS)
  // ============================================
  static String sanitizeString(String input) {
    if (input.isEmpty) return input;

    // Remove tags HTML
    String sanitized = input.replaceAll(RegExp(r'<[^>]*>'), '');

    // Escapa caracteres especiais
    sanitized = sanitized
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');

    return sanitized.trim();
  }

  // ============================================
  // VALIDAÇÃO DE NOME
  // ============================================
  static bool isValidName(String name) {
    if (name.isEmpty || name.length < 3) return false;

    // Permite apenas letras, espaços e acentos
    final nameRegex = RegExp(r'^[a-zA-ZÀ-ÿ\s]+$');
    return nameRegex.hasMatch(name);
  }

  // ============================================
  // VALIDAÇÃO DE ENDEREÇO
  // ============================================
  static bool isValidAddress(String address) {
    if (address.isEmpty || address.length < 10) return false;
    return true;
  }

  // ============================================
  // VALIDAÇÃO DE CEP
  // ============================================
  static bool isValidCEP(String cep) {
    // Remove caracteres não numéricos
    cep = cep.replaceAll(RegExp(r'[^0-9]'), '');

    // Verifica se tem 8 dígitos
    return cep.length == 8;
  }

  // ============================================
  // VALIDAÇÃO DE NÚMEROS POSITIVOS
  // ============================================
  static bool isPositiveNumber(String value) {
    final number = double.tryParse(value);
    return number != null && number > 0;
  }

  // ============================================
  // VALIDAÇÃO DE INTEIROS
  // ============================================
  static bool isValidInteger(String value, {int? min, int? max}) {
    final number = int.tryParse(value);
    if (number == null) return false;

    if (min != null && number < min) return false;
    if (max != null && number > max) return false;

    return true;
  }

  // ============================================
  // LIMITAÇÃO DE TAMANHO DE STRING
  // ============================================
  static bool isWithinLength(String value, {int? min, int? max}) {
    if (min != null && value.length < min) return false;
    if (max != null && value.length > max) return false;
    return true;
  }

  // ============================================
  // VALIDAÇÃO DE URL
  // ============================================
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // VALIDAÇÃO DE DATA
  // ============================================
  static bool isValidDate(String date) {
    try {
      DateTime.parse(date);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // VALIDAÇÃO DE IDADE MÍNIMA
  // ============================================
  static bool isMinimumAge(DateTime birthDate, int minimumAge) {
    final today = DateTime.now();
    final age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      return age - 1 >= minimumAge;
    }

    return age >= minimumAge;
  }
}
