import 'package:windows_single_instance/windows_single_instance.dart';

Future<void> setupWindowsSingleInstance(List<String> args) async {
  try {
    await WindowsSingleInstance.ensureSingleInstance(
        args, "com.example.spartan_app_unique_id", onSecondWindow: (args) {
      print("Segunda instância detectada! Argumentos recebidos: $args");
    });
  } catch (e) {
    print("Erro ao configurar Windows Single Instance: $e");
  }
}
