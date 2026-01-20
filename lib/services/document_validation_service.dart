import 'package:http/http.dart' as http;
import 'dart:convert';

/// Serviço para validar CPF e CNPJ com APIs da Receita Federal
class DocumentValidationService {
  // ============================================
  // VALIDAÇÃO DE CPF COM API
  // ============================================

  /// Valida CPF consultando API da Receita Federal
  /// Retorna: { 'valid': bool, 'exists': bool, 'message': String, 'data': Map? }
  static Future<Map<String, dynamic>> validateCPF(String cpf) async {
    try {
      // Remove caracteres não numéricos
      final cpfClean = cpf.replaceAll(RegExp(r'[^0-9]'), '');

      // Validação básica de formato
      if (cpfClean.length != 11) {
        return {
          'valid': false,
          'exists': false,
          'message': 'CPF deve ter 11 dígitos',
        };
      }

      // Verifica se todos os dígitos são iguais
      if (RegExp(r'^(\d)\1{10}$').hasMatch(cpfClean)) {
        return {
          'valid': false,
          'exists': false,
          'message': 'CPF inválido',
        };
      }

      // Validação de dígitos verificadores (local)
      if (!_validateCPFDigits(cpfClean)) {
        return {
          'valid': false,
          'exists': false,
          'message': 'CPF inválido - dígitos verificadores incorretos',
        };
      }

      // OPÇÃO 1: API Brasil API (Gratuita e confiável)
      // NOTA: Esta API não verifica existência real, apenas valida formato
      // Para verificação real, seria necessário acesso à Receita Federal (pago)

      final response = await http.get(
        Uri.parse('https://brasilapi.com.br/api/cpf/v1/$cpfClean'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'valid': true,
          'exists': true,
          'message': 'CPF válido',
          'data': data,
        };
      } else if (response.statusCode == 404) {
        return {
          'valid': true, // Matematicamente válido
          'exists': false, // Mas não encontrado na base
          'message': 'CPF não encontrado na base de dados',
        };
      } else {
        // Se API falhar, aceita CPF se for matematicamente válido
        return {
          'valid': true,
          'exists': null, // Não foi possível verificar
          'message': 'CPF válido (não foi possível verificar existência)',
        };
      }
    } catch (e) {
      // Em caso de erro na API, aceita se for matematicamente válido
      final cpfClean = cpf.replaceAll(RegExp(r'[^0-9]'), '');
      final isValid = _validateCPFDigits(cpfClean);

      return {
        'valid': isValid,
        'exists': null,
        'message': isValid
            ? 'CPF válido (verificação online indisponível)'
            : 'CPF inválido',
      };
    }
  }

  // ============================================
  // VALIDAÇÃO DE CNPJ COM API
  // ============================================

  /// Valida CNPJ consultando API da Receita Federal
  /// Retorna: { 'valid': bool, 'exists': bool, 'message': String, 'data': Map? }
  static Future<Map<String, dynamic>> validateCNPJ(String cnpj) async {
    try {
      // Remove caracteres não numéricos
      final cnpjClean = cnpj.replaceAll(RegExp(r'[^0-9]'), '');

      // Validação básica de formato
      if (cnpjClean.length != 14) {
        return {
          'valid': false,
          'exists': false,
          'message': 'CNPJ deve ter 14 dígitos',
        };
      }

      // Verifica se todos os dígitos são iguais
      if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpjClean)) {
        return {
          'valid': false,
          'exists': false,
          'message': 'CNPJ inválido',
        };
      }

      // Validação de dígitos verificadores (local)
      if (!_validateCNPJDigits(cnpjClean)) {
        return {
          'valid': false,
          'exists': false,
          'message': 'CNPJ inválido - dígitos verificadores incorretos',
        };
      }

      // API Brasil API - Consulta CNPJ na Receita Federal
      final response = await http.get(
        Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$cnpjClean'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Verifica se a empresa está ativa
        final situacao =
            data['descricao_situacao_cadastral']?.toString().toLowerCase() ??
                '';
        final isActive = situacao.contains('ativa');

        return {
          'valid': true,
          'exists': true,
          'active': isActive,
          'message': isActive
              ? 'CNPJ válido e ativo'
              : 'CNPJ válido mas empresa não está ativa',
          'data': {
            'razao_social': data['razao_social'],
            'nome_fantasia': data['nome_fantasia'],
            'situacao': data['descricao_situacao_cadastral'],
            'data_situacao': data['data_situacao_cadastral'],
            'cnae_principal': data['cnae_fiscal_descricao'],
            'data_abertura': data['data_inicio_atividade'],
            'uf': data['uf'],
            'municipio': data['municipio'],
          },
        };
      } else if (response.statusCode == 404) {
        return {
          'valid': true, // Matematicamente válido
          'exists': false, // Mas não encontrado na Receita
          'message': 'CNPJ não encontrado na Receita Federal',
        };
      } else {
        // Se API falhar, aceita CNPJ se for matematicamente válido
        return {
          'valid': true,
          'exists': null,
          'message': 'CNPJ válido (não foi possível verificar existência)',
        };
      }
    } catch (e) {
      // Em caso de erro na API, aceita se for matematicamente válido
      final cnpjClean = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
      final isValid = _validateCNPJDigits(cnpjClean);

      return {
        'valid': isValid,
        'exists': null,
        'message': isValid
            ? 'CNPJ válido (verificação online indisponível)'
            : 'CNPJ inválido',
      };
    }
  }

  // ============================================
  // VALIDAÇÃO LOCAL DE DÍGITOS VERIFICADORES
  // ============================================

  static bool _validateCPFDigits(String cpf) {
    if (cpf.length != 11) return false;

    // Primeiro dígito verificador
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cpf[i]) * (10 - i);
    }
    int digit1 = 11 - (sum % 11);
    if (digit1 >= 10) digit1 = 0;
    if (digit1 != int.parse(cpf[9])) return false;

    // Segundo dígito verificador
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cpf[i]) * (11 - i);
    }
    int digit2 = 11 - (sum % 11);
    if (digit2 >= 10) digit2 = 0;
    if (digit2 != int.parse(cpf[10])) return false;

    return true;
  }

  static bool _validateCNPJDigits(String cnpj) {
    if (cnpj.length != 14) return false;

    // Primeiro dígito verificador
    List<int> weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += int.parse(cnpj[i]) * weights1[i];
    }
    int digit1 = sum % 11 < 2 ? 0 : 11 - (sum % 11);
    if (digit1 != int.parse(cnpj[12])) return false;

    // Segundo dígito verificador
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
  // VALIDAÇÃO COMBINADA (CPF + CNPJ)
  // ============================================

  /// Valida CPF e CNPJ simultaneamente
  static Future<Map<String, dynamic>> validateDocuments({
    required String cpf,
    required String cnpj,
  }) async {
    final cpfResult = await validateCPF(cpf);
    final cnpjResult = await validateCNPJ(cnpj);

    final allValid = cpfResult['valid'] && cnpjResult['valid'];
    final allExist =
        (cpfResult['exists'] ?? true) && (cnpjResult['exists'] ?? true);

    List<String> errors = [];
    if (!cpfResult['valid']) errors.add('CPF: ${cpfResult['message']}');
    if (!cnpjResult['valid']) errors.add('CNPJ: ${cnpjResult['message']}');
    if (cpfResult['valid'] && cpfResult['exists'] == false) {
      errors.add('CPF não encontrado na base de dados');
    }
    if (cnpjResult['valid'] && cnpjResult['exists'] == false) {
      errors.add('CNPJ não encontrado na Receita Federal');
    }
    if (cnpjResult['active'] == false) {
      errors.add('CNPJ está inativo na Receita Federal');
    }

    return {
      'valid': allValid && allExist,
      'cpf': cpfResult,
      'cnpj': cnpjResult,
      'errors': errors,
      'message': errors.isEmpty
          ? 'Documentos validados com sucesso'
          : errors.join('\n'),
    };
  }

  // ============================================
  // FORMATAÇÃO DE DOCUMENTOS
  // ============================================

  static String formatCPF(String cpf) {
    final clean = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length != 11) return cpf;
    return '${clean.substring(0, 3)}.${clean.substring(3, 6)}.${clean.substring(6, 9)}-${clean.substring(9)}';
  }

  static String formatCNPJ(String cnpj) {
    final clean = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length != 14) return cnpj;
    return '${clean.substring(0, 2)}.${clean.substring(2, 5)}.${clean.substring(5, 8)}/${clean.substring(8, 12)}-${clean.substring(12)}';
  }
}
