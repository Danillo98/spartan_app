import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/diet_service.dart';
import '../../config/app_theme.dart';

class AddDietDayScreen extends StatefulWidget {
  final String dietId;

  const AddDietDayScreen({
    super.key,
    required this.dietId,
  });

  @override
  State<AddDietDayScreen> createState() => _AddDietDayScreenState();
}

class _AddDietDayScreenState extends State<AddDietDayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dayNameController = TextEditingController();
  final _dayNumberController = TextEditingController();
  bool _isLoading = false;

  static const nutritionistPrimary = Color(0xFF2A9D8F);

  @override
  void dispose() {
    _dayNameController.dispose();
    _dayNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveDietDay() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await DietService.addDietDay(
        dietId: widget.dietId,
        dayNumber: int.parse(_dayNumberController.text),
        dayName: _dayNameController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor:
                result['success'] ? nutritionistPrimary : AppTheme.accentRed,
          ),
        );

        if (result['success']) {
          Navigator.pop(context, true); // Retorna true para indicar sucesso
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar dia: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text(
          'Adicionar Dia',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: nutritionistPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card com formulário
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informações do Dia',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Número do dia
                  TextFormField(
                    controller: _dayNumberController,
                    decoration: InputDecoration(
                      labelText: 'Número do Dia',
                      hintText: 'Ex: 1',
                      prefixIcon: const Icon(Icons.numbers_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: nutritionistPrimary),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe o número do dia';
                      }
                      final number = int.tryParse(value);
                      if (number == null || number < 1) {
                        return 'Informe um número válido (maior que 0)';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Nome do dia
                  TextFormField(
                    controller: _dayNameController,
                    decoration: InputDecoration(
                      labelText: 'Nome do Dia',
                      hintText: 'Ex: Segunda-feira, Dia 1, etc.',
                      prefixIcon: const Icon(Icons.label_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: nutritionistPrimary),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe o nome do dia';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Botão salvar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveDietDay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: nutritionistPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  'Adicionar Dia',
                                  style: GoogleFonts.lato(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Informação
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: nutritionistPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: nutritionistPrimary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: nutritionistPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Após adicionar o dia, você poderá adicionar refeições a ele.',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: nutritionistPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
