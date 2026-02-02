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
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

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
          _isLoading = false;
        });

        // Auto-scroll para centralizar o plano recomendado (Ouro) se for desktop
        // ou scrollar para o meio se o usuário estiver no Bronze
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            // Um scroll suave para mostrar que tem mais opções
            _scrollController.animateTo(100,
                duration: const Duration(seconds: 1), curve: Curves.easeOut);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
              controller: _scrollController,
              scrollDirection: Axis
                  .horizontal, // Scroll Horizontal para caber cards lado a lado
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                // Row para colocar um ao lado do outro
                crossAxisAlignment: CrossAxisAlignment.start, // Alinhar no topo
                children: [
                  // Coluna de Intro e Logo (Fica à esquerda ou topo? O usuário pediu cards lado a lado)
                  // Mas onde fica a Logo? "No lugar do foguete no topo da página".
                  // Ah, então a página tem um HEADER vertical e depois os cards horizontais.
                  // ENTÃO: O SingleScrollView horizontal deve ser APENAS nos cards ou a tela toda é scrollavel?
                  // Se for Desktop Web, faz sentido ter header + row.
                  // Se for Mobile, Row vai estourar.
                  // Vou fazer um Column(Header, SingleScrollView(Row(Cards)))
                ],
              ),
            ),
    );
  }
}
