class AppVersion {
  // VERSÃO ATUAL DO APLICATIVO (Hardcoded no Build)
  static const String current = '2.3.4';

  // Helper para converter string de versão em número comparável
  // Ex: "1.0.1" -> 10001
  static int parseVersion(String version) {
    try {
      final parts = version.split('.');
      if (parts.length != 3) return 0;

      final major = int.parse(parts[0]);
      final minor = int.parse(parts[1]);
      final patch = int.parse(parts[2]);

      return (major * 10000) + (minor * 100) + patch;
    } catch (e) {
      return 0; // Versão inválida assume valor baixo
    }
  }
}
