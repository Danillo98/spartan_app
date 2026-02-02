import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/user_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _currentPlan = '';
  String? _selectedPlan; // Para controlar qual card está selecionado
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentPlan();
  }

  Future<void> _loadCurrentPlan() async {
    try {
      final status = await UserService.checkPlanLimitStatus();
      if (mounted) {
        setState(() {
          _currentPlan = status['plan'] ?? 'Bronze';
          // Não selecionamos nenhum automaticamente para forçar o clique,
          // ou podemos selecionar o atual? O usuário disse "só ativar se o card for selecionado".
          // Vou deixar null para o usuário ter a ação de clicar.
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleCardTap(String planName) {
    setState(() {
      _selectedPlan = planName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ASSINATURA SPARTAN',
          style: GoogleFonts.cinzel(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  // LOGO (Responsiva: Desktop 300, Mobile 150)
                  Image.asset(
                    'assets/images/splash_logo.png',
                    height: MediaQuery.of(context).size.width > 600 ? 300 : 150,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sua Evolução Não Pode Parar',
                    style: GoogleFonts.lato(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'O crescimento da sua academia exige ferramentas mais poderosas. Escolha o plano que combina com sua ambição.',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // LISTA HORIZONTAL
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                        left: 24, right: 24, top: 25, bottom: 40),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width - 48,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // PRATA
                          _buildInteractableCard(
                            title: 'PRATA',
                            tag: 'VALIDAÇÃO',
                            price: '129,90',
                            description:
                                'Ideal para academias de pequeno porte.',
                            bgColor: const Color(0xFFC5D1D8),
                            borderColor: const Color(0xFF5A7D8F),
                            cardColorName: 'Prata',
                            features: [
                              'Módulos: Administrador, Nutricionista, Personal Trainer e Aluno.',
                              'Dietas, Relatórios Físicos e Treinos.',
                              'Monitoramento de Mensalidades, Controle Financeiro, Fluxo de Caixa e Relatórios Mensais e Anuais em PDF.',
                              'Suporta até 200 alunos.',
                            ],
                          ),
                          const SizedBox(width: 24),

                          // OURO
                          _buildInteractableCard(
                            title: 'OURO',
                            tag: 'MAIS ESCOLHIDO', // Tag interna
                            price: '239,90',
                            description:
                                'Para quem já validou e precisa escalar.',
                            bgColor: const Color(0xFFFBF9F2),
                            borderColor: const Color(0xFFD4AF37),
                            cardColorName: 'Ouro',
                            features: [
                              'Módulos: Administrador, Nutricionista, Personal Trainer e Aluno.',
                              'Dietas, Relatórios Físicos e Treinos.',
                              'Monitoramento de Mensalidades, Controle Financeiro, Fluxo de Caixa e Relatórios Mensais e Anuais em PDF.',
                              'Suporta até 500 alunos.',
                              'Maior margem de lucro por aluno.',
                              'Estrutura para crescimento forte.'
                            ],
                          ),
                          const SizedBox(width: 24),

                          // PLATINA
                          _buildInteractableCard(
                            title: 'PLATINA',
                            tag: 'INFINITO',
                            price: '349,90',
                            description:
                                'A liberdade absoluta. O céu é o limite.',
                            bgColor: const Color(0xFFE8F6F9),
                            borderColor: const Color(0xFF00BCD4),
                            cardColorName: 'Platina',
                            features: [
                              'Módulos: Administrador, Nutricionista, Personal Trainer e Aluno.',
                              'Dietas, Relatórios Físicos e Treinos Integrados.',
                              'Monitoramento de Mensalidades, Controle Financeiro, Fluxo de Caixa e Relatórios Mensais e Anuais em PDF.',
                              'Alunos ILIMITADOS.',
                              'O céu é o limite! Aqui o lucro é exponencial.',
                              'Estrutura para grandes empreendimentos.'
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildInteractableCard({
    required String title,
    required String tag,
    required String price,
    required String description,
    required Color bgColor,
    required Color borderColor,
    required String
        cardColorName, // Nome interno para comparação (ex: 'Prata', 'Ouro')
    required List<String> features,
  }) {
    final width = 340.0;

    // Lógica de Estado
    // Normalizamos para comparar com o backend (que retorna Prata/Ouro/Platina capitalize ou lower)
    final bool isMyPlan =
        _currentPlan.toLowerCase() == cardColorName.toLowerCase();

    // Seleção: Se o nome deste card for igual ao _selectedPlan
    final bool isSelected = _selectedPlan == cardColorName;

    // Efeito LED/Brilho quando selecionado
    final List<BoxShadow> shadows = isSelected
        ? [
            BoxShadow(
              color: borderColor.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            )
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ];

    final borderDisplay = isSelected
        ? Border.all(
            color: borderColor, width: 3) // Borda mais grossa se selecionado
        : Border.all(color: borderColor.withOpacity(0.5), width: 1.5);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () {
            _handleCardTap(cardColorName);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: borderDisplay,
              boxShadow: shadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: borderColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: borderColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: borderColor.withOpacity(0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Indicador de Seleção (Radio Visual)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? borderColor : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? borderColor
                              : borderColor.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Preço
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'R\$',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      TextSpan(
                        text: ' $price',
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -1.0,
                        ),
                      ),
                      TextSpan(
                        text: ' /mês',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),

                const SizedBox(height: 24),
                Divider(color: borderColor.withOpacity(0.3)),
                const SizedBox(height: 24),

                // Features
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.flash_on_rounded,
                            size: 18,
                            color: borderColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF444444),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 16),

                // Botão "FAZER UPGRADE" (Lógica Pedida)
                // Desativado se o card não for selecionado.
                // Ativado se for selecionado.
                SizedBox(
                  width: double.infinity,
                  child: IgnorePointer(
                    ignoring: !isSelected, // Ignora clique se não selecionado
                    child: ElevatedButton(
                      onPressed: isSelected
                          ? () {
                              // Ação do botão
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Iniciando Upgrade...')));
                            }
                          : null, // Visualmente desativado (null onPressed faz o estilo disabled)
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D1D1F),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.grey[300], // Cor Cinza se desativado
                        disabledForegroundColor: Colors.grey[500],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isMyPlan ? 'RENOVAR ASSINATURA' : 'FAZER UPGRADE',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tag Flutuante "PLANO ATUAL" (Apenas se for o plano do usuário)
        if (isMyPlan)
          Positioned(
            top: -15,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: borderColor, // Usa a cor do tema do card
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Text(
                  'PLANO ATUAL',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white, // Contraste
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
