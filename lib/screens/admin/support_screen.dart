import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _messageController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

  // Número de Suporte (Fornecido pelo usuário)
  final String _supportNumber = "5522998786284";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final data = await AuthService.getCurrentUserData();
    if (mounted) {
      setState(() {
        _userData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSendWhatsApp() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite sua mensagem.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Dados do Cliente
    final nomeCliente = _userData?['nome'] ?? 'Cliente';
    final nomeAcademia = _userData?['academia'] ?? 'Academia não informada';
    final cnpjAcademia = _userData?['cnpj_academia'] ??
        _userData?['cnpj'] ??
        'CNPJ não informado';
    final telefoneCliente = _userData?['telefone'] ?? 'Telefone não informado';
    final userMessage = _messageController.text.trim();

    // Montar mensagem formatada
    final text = """
*SUPORTE SPARTAN APP* 🛡️

*Cliente:* $nomeCliente
*Academia:* $nomeAcademia
*CNPJ:* $cnpjAcademia
*Telefone:* $telefoneCliente

*Mensagem:*
$userMessage
""";

    // Criar URL do WhatsApp
    final whatsappUrl = Uri.parse(
        "https://wa.me/$_supportNumber?text=${Uri.encodeComponent(text)}");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);

        if (!mounted) return;

        // Mostrar Dialog de Confirmação
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Colors.green, size: 60),
                const SizedBox(height: 16),
                Text(
                  'Redirecionando...',
                  style: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              'Sua mensagem foi gerada!\n\nPor favor, confirme o envio no WhatsApp e aguarde nosso atendimento.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Fechar Dialog
                  Navigator.pop(
                      context); // Voltar para Dashboard (Opicional, mas bom UX)
                },
                child: const Text('ENTENDI'),
              ),
            ],
          ),
        );
      } else {
        throw 'Não foi possível abrir o WhatsApp';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir WhatsApp: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          color: AppTheme.secondaryText,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Suporte',
          style: GoogleFonts.cinzel(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.support_agent_rounded,
                              size: 64,
                              color: Color(0xFF25D366), // WhatsApp Green
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Fale Conosco no WhatsApp',
                              style: GoogleFonts.lato(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nosso time de suporte está pronto para te ajudar. Descreva seu problema abaixo e clique em enviar.',
                              style: GoogleFonts.lato(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Campo de Texto
                            TextField(
                              controller: _messageController,
                              maxLines: 5,
                              decoration: InputDecoration(
                                labelText: 'Como podemos ajudar?',
                                alignLabelWithHint: true,
                                hintText: 'Descreva sua dúvida aqui...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Botão Enviar
                            SizedBox(
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _handleSendWhatsApp,
                                icon: const Icon(
                                    Icons.chat_bubble_outline_rounded),
                                label: const Text(
                                  'ENVIAR WHATSAPP',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Exibição do Número Compacto com Copiar
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Ou adicione manualmente:',
                                    style: GoogleFonts.lato(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(
                                          ClipboardData(text: _supportNumber));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Número copiado para a área de transferência!'),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '+55 (22) 99878-6284',
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[800],
                                              letterSpacing:
                                                  -0.5, // Juntar mais os números
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.copy_rounded,
                                              size: 20,
                                              color: Colors.grey[600]),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // SEÇÃO: SOBRE O DESENVOLVEDOR (Sobre Mim)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(
                              0xFF1D1D1F), // Dark premium background
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundColor: AppTheme.primaryGold,
                              child: Icon(Icons.person,
                                  color: Colors.white, size: 35),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sobre Mim',
                              style: GoogleFonts.cinzel(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Danillo Neto',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sou formado em Sistemas de Informação (TI) e trabalho desenvolvendo sistemas personalizados que solucionam problemas reais de empresas dos mais variados ramos. Minha missão é transformar processos complexos em ferramentas simples e eficientes.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                color: Colors.grey[400],
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 12),
                            Text(
                              'Fico à disposição através do meu WhatsApp para a criação de sistemas para outros tipos de negócios também.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGold.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Botões Legais (Agora no final)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse('/termos/'),
                              mode: LaunchMode.externalApplication,
                              webOnlyWindowName: '_blank',
                            ),
                            icon: const Icon(Icons.description_outlined,
                                size: 18),
                            label: const Text('Termos de Uso'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text('|', style: TextStyle(color: Colors.grey[300])),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse('/politicas/'),
                              mode: LaunchMode.externalApplication,
                              webOnlyWindowName: '_blank',
                            ),
                            icon: const Icon(Icons.lock_outline, size: 18),
                            label: const Text('Política de Privacidade'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
