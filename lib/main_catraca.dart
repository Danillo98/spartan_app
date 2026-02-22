import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/supabase_service.dart';
import 'screens/motor_catraca_screen.dart';

// IMPORT CONDICIONAL
import 'services/windows_bridge_stub.dart'
    if (dart.library.io) 'services/windows_bridge_impl.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configura janela única no windows se suportado
  await setupWindowsSingleInstance(args);

  // Inicializa o Supabase (usa as suas credenciais originais do projeto)
  await SupabaseService.initialize();

  // Define orientação
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MotorCatracaApp());
}

class MotorCatracaApp extends StatelessWidget {
  const MotorCatracaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spartan - Motor Catraca',
      theme: ThemeData.dark(),
      home: const MotorCatracaScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
