import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';

class PixCheckoutScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String planName;
  final double amount;

  const PixCheckoutScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.planName,
    required this.amount,
  });

  @override
  State<PixCheckoutScreen> createState() => _PixCheckoutScreenState();
}

class _PixCheckoutScreenState extends State<PixCheckoutScreen> {
  bool _isLoading = true;
  String? _qrCode; // Código copia e cola
  String? _qrCodeBase64; // Imagem QR Code

  String? _error;
  bool _copied = false;
  bool _paymentConfirmed = false;

  StreamSubscription? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _generatePix();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _generatePix() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'gerar-pix',
        body: {
          'userId': widget.userId,
          'userEmail': widget.userEmail,
          'planName': widget.planName,
          'amount': widget.amount,
          'externalReference': widget.userId,
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        setState(() {
          _qrCode = data['qrCode'];
          _qrCodeBase64 = data['qrCodeBase64'];
          _isLoading = false;
        });
        _listenForPayment();
      } else {
        setState(() {
          _error = data?['error'] ?? 'Erro ao gerar PIX';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro de conexão: $e';
        _isLoading = false;
      });
    }
  }

  void _listenForPayment() {
    // Escuta alterações na tabela users_adm em tempo real
    _realtimeSubscription = Supabase.instance.client
        .from('users_adm')
        .stream(primaryKey: ['id'])
        .eq('id', widget.userId)
        .listen((data) {
          if (data.isNotEmpty) {
            final status = data.first['status_assinatura'];
            if (status == 'active' && mounted && !_paymentConfirmed) {
              setState(() => _paymentConfirmed = true);
              _showSuccessAndClose();
            }
          }
        });
  }

  void _showSuccessAndClose() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 50),
            ),
            const SizedBox(height: 20),
            Text(
              'Pagamento Confirmado!',
              style:
                  GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Sua assinatura do plano ${widget.planName.toUpperCase()} foi ativada com sucesso!',
              style: const TextStyle(color: AppTheme.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true); // Retorna 'true' de sucesso
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ACESSAR DASHBOARD',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyCode() async {
    if (_qrCode == null) return;
    await Clipboard.setData(ClipboardData(text: _qrCode!));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Pagar com PIX',
            style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.primaryText),
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildPixContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF009EE3)),
          const SizedBox(height: 24),
          Text('Gerando seu PIX...',
              style: GoogleFonts.lato(
                  fontSize: 16, color: AppTheme.secondaryText)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_error ?? 'Erro desconhecido',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _generatePix();
              },
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPixContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // Header MP
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF009EE3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pix, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Text('PIX via Mercado Pago',
                        style: GoogleFonts.lato(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Valor
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)
                  ],
                ),
                child: Column(
                  children: [
                    Text('Plano ${widget.planName.toUpperCase()}',
                        style: GoogleFonts.cinzel(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'R\$ ${widget.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: GoogleFonts.lato(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF009EE3)),
                    ),
                    const Text('por mês',
                        style: TextStyle(color: AppTheme.secondaryText)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Instruções
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Como pagar:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _buildStep('1', 'Abra o app do seu banco'),
                    _buildStep('2', 'Escolha pagar com PIX'),
                    _buildStep('3',
                        'Escaneie o QR Code ou use o código "Copia e Cola"'),
                    _buildStep('4', 'Confirme o pagamento'),
                    _buildStep('5',
                        'Aguarde — sua assinatura é ativada automaticamente!'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // QR Code
              if (_qrCodeBase64 != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text('Escaneie o QR Code',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(_qrCodeBase64!),
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Copia e Cola
              if (_qrCode != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Ou use o código PIX:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          _qrCode!,
                          style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Colors.black54),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _copyCode,
                        icon: Icon(_copied ? Icons.check : Icons.copy_rounded),
                        label: Text(_copied ? 'Copiado!' : 'Copiar Código PIX'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _copied ? Colors.green : const Color(0xFF009EE3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Status de espera
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCC02)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFFCC02),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Aguardando confirmação do pagamento...\nSua assinatura será ativada automaticamente.',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF795548)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF009EE3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.secondaryText)),
          ),
        ],
      ),
    );
  }
}
