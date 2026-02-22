import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/supabase_config.dart';
import 'support_screen.dart';

class AdminTurnstilesScreen extends StatefulWidget {
  const AdminTurnstilesScreen({super.key});

  @override
  State<AdminTurnstilesScreen> createState() => _AdminTurnstilesScreenState();
}

class _AdminTurnstilesScreenState extends State<AdminTurnstilesScreen> {
  // O link agora aponta direto para o seu disco storage do Supabase
  final String _downloadUrl =
      '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/downloads/Spartan_Motor_Catraca.zip';

  Future<void> _launchDownloadLink() async {
    final Uri url = Uri.parse(_downloadUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Não foi possível iniciar o download. Verifique sua rede.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Minhas Catracas',
            style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecalho de Status
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.sensor_door_rounded,
                          size: 64, color: Color(0xFFEBC115)),
                      const SizedBox(height: 16),
                      Text(
                        'Motor da Catraca (Control iD)',
                        style: GoogleFonts.cinzel(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A versão Web do seu sistema não pode se comunicar diretamente com dispositivos locais (IP) devido a barreiras de segurança dos navegadores. Para que sua catraca abra as portas, você precisa manter o "Motor da Catraca" rodando em um computador da recepção.',
                        style: TextStyle(
                            fontSize: 16, color: AppTheme.secondaryText),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Card de Instalação e Baixa
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey[900]!, Colors.black],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.download_for_offline_rounded,
                          size: 56, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Passo 1: Fazer o Download',
                        style: GoogleFonts.cinzel(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Baixe agora mesmo a última versão do Motor da Catraca diretamente do nosso servidor oficial.',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _launchDownloadLink,
                        icon: const Icon(Icons.download_rounded,
                            color: Colors.black),
                        label: const Text('BAIXAR AGORA (Windows)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEBC115),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 20),
                          textStyle: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Card de Tutoriais
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.borderGrey),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Passo 2: Como iniciar todos os dias?',
                        style: GoogleFonts.cinzel(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 20),
                      _buildStepRow(
                        '1',
                        'Descompacte o arquivo',
                        'Extraia a pasta Spartan_Motor_Catraca.zip \n(procure o arquivo na pasta donwloads e clique com o botão direito, em sequida clique em "Extrair Aqui").',
                      ),
                      _buildStepRow(
                        '2',
                        'Abra o Programa',
                        'Abra o arquivo spartan_app.exe e digite o IP da sua catraca.',
                      ),
                      _buildStepRow(
                        '3',
                        'Clique em INICIAR MOTOR',
                        'A tela mostrará os logs de acesso. O motor DEVE ficar aberto (ou minimizado) enquanto a recepção funcionar.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: const Text(
                        'Casos tenha problemas para executar os passos à cima, entre em contato com nosso suporte e descreva o problema',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryText,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SupportScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Suporte'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEBC115),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String number, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEBC115).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: const Color(0xFFEBC115),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
