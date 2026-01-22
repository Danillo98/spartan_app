import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../services/financial_service.dart';
import '../../../services/user_service.dart';
import '../../../models/user_role.dart';
import '../../../widgets/searchable_selection.dart';

class AddTransactionScreen extends StatefulWidget {
  final Map<String, dynamic>? transactionToEdit;

  const AddTransactionScreen({super.key, this.transactionToEdit});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String _type = 'expense'; // 'income' or 'expense'
  String _category = 'variable'; // 'fixed' or 'variable' (only for expense)
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Campos para vínculo com usuário
  bool _linkUser = false;
  String _selectedUserRoleStr = 'student'; // student, nutritionist, trainer
  String? _selectedUserId;
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      _loadTransactionData();
    }
  }

  void _loadTransactionData() {
    final t = widget.transactionToEdit!;
    _descriptionController.text = t['description'];
    _amountController.text =
        (t['amount'] as num).toStringAsFixed(2).replaceAll('.', ',');
    _type = t['type'];
    _category = t['category'] ?? 'variable';
    _selectedDate = DateTime.parse(t['transaction_date']);

    if (t['related_user_id'] != null) {
      _linkUser = true;
      _selectedUserId = t['related_user_id'];
      _selectedUserRoleStr = t['related_user_role'] ?? 'student';
      // Carregar usuários para mostrar o nome correto no dropdown
      _loadUsers(_selectedUserRoleStr);
    }
  }

  Future<void> _loadUsers(String roleStr) async {
    setState(() {
      _isLoadingUsers = true;
      // Only reset _selectedUserId if the role is changing, not on initial load for editing
      if (widget.transactionToEdit == null || _selectedUserRoleStr != roleStr) {
        _selectedUserId = null;
      }
    });

    try {
      UserRole role;
      if (roleStr == 'student') {
        role = UserRole.student;
      } else if (roleStr == 'nutritionist') {
        role = UserRole.nutritionist;
      } else {
        role = UserRole.trainer;
      }

      final users = await UserService.getUsersByRole(role);

      if (mounted) {
        setState(() {
          _availableUsers = users;
          _isLoadingUsers = false;
          // If editing and _selectedUserId was set, ensure it's still valid in the new list
          if (widget.transactionToEdit != null &&
              _selectedUserId != null &&
              !_availableUsers.any((user) => user['id'] == _selectedUserId)) {
            _selectedUserId =
                null; // Reset if the previously selected user is not in the new list
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar usuários: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amountController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Parse amount
      final amountStr =
          _amountController.text.replaceAll('.', '').replaceAll(',', '.');
      // Nota: assumindo entrada pt_BR ex "1.000,00" -> remove ponto milhar, troca virgula por ponto
      // Se a entrada for simples "1000,00" funciona. Se for "1000.00" (en) pode dar erro se não tratar.
      // Vou usar uma lógica mais robusta:
      double amount;
      try {
        amount = double.parse(amountStr);
      } catch (e) {
        // Fallback se falhar, tenta parse direto (caso input seja "1000.00")
        amount = double.parse(_amountController.text.replaceAll(',', '.'));
      }

      if (widget.transactionToEdit != null) {
        await FinancialService.updateTransaction(
          id: widget.transactionToEdit!['id'],
          description: _descriptionController.text,
          amount: amount,
          type: _type,
          date: _selectedDate,
          category: _type == 'expense' ? _category : 'income_other',
          relatedUserId: _linkUser ? _selectedUserId : null,
          relatedUserRole: _linkUser ? _selectedUserRoleStr : null,
        );
      } else {
        await FinancialService.addTransaction(
          description: _descriptionController.text,
          amount: amount,
          type: _type,
          date: _selectedDate,
          category: _type == 'expense' ? _category : 'income_other',
          relatedUserId: _linkUser ? _selectedUserId : null,
          relatedUserRole: _linkUser ? _selectedUserRoleStr : null,
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to refresh list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == 'expense';
    final primaryColor = isExpense ? Colors.red : Colors.green;
    final isEditing = widget.transactionToEdit != null;

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Editar Transação' : 'Nova Transação',
          style: GoogleFonts.lato(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toggle Type
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton(
                          'Saída', 'expense', Colors.red, Icons.arrow_downward),
                    ),
                    Expanded(
                      child: _buildTypeButton('Entrada', 'income', Colors.green,
                          Icons.arrow_upward),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Valor
              Text('Valor',
                  style: GoogleFonts.lato(
                      fontSize: 14, color: AppTheme.secondaryText)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.lato(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                decoration: InputDecoration(
                  prefixText: 'R\$ ',
                  prefixStyle: TextStyle(color: primaryColor),
                  border: InputBorder.none,
                  hintText: '0,00',
                  hintStyle: TextStyle(color: Colors.grey[300]),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Informe o valor';
                  return null;
                },
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 24),

              // Descrição
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex: Conta de Luz, Mensalidade...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Informe a descrição';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Data
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: GoogleFonts.lato(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Vínculo com Usuário (Opcional)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Vincular a Usuário (Opcional)',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: _linkUser,
                      onChanged: (value) {
                        setState(() {
                          _linkUser = value;
                          if (value && _availableUsers.isEmpty) {
                            _loadUsers(_selectedUserRoleStr);
                          } else if (!value) {
                            _selectedUserId =
                                null; // Clear selection if unlinking
                          }
                        });
                      },
                      activeColor: primaryColor,
                    ),
                    if (_linkUser) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Selector Tipo
                            DropdownButtonFormField<String>(
                              value: _selectedUserRoleStr,
                              decoration: InputDecoration(
                                labelText: 'Tipo de Usuário',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'student', child: Text('Aluno')),
                                DropdownMenuItem(
                                    value: 'trainer', child: Text('Personal')),
                                DropdownMenuItem(
                                    value: 'nutritionist',
                                    child: Text('Nutricionista')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedUserRoleStr = value);
                                  _loadUsers(value);
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // Selector Usuário (Searchable)
                            _isLoadingUsers
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : SearchableSelection<Map<String, dynamic>>(
                                    label: 'Selecionar Usuário',
                                    hintText: 'Escolha um usuário',
                                    items: _availableUsers,
                                    value: _selectedUserId != null
                                        ? _availableUsers.firstWhere(
                                            (u) => u['id'] == _selectedUserId,
                                            orElse: () => {})
                                        : null,
                                    labelBuilder: (user) =>
                                        user['name'] ?? 'Sem nome',
                                    onChanged: (user) {
                                      setState(() {
                                        _selectedUserId = user?['id'];
                                      });
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Categoria (Apenas para despesas)
              if (isExpense) ...[
                Text('Tipo de Gasto',
                    style: GoogleFonts.lato(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryRadio('Fixo', 'fixed'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCategoryRadio('Variável', 'variable'),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 40),

              // Botão Salvar
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        isEditing ? 'ATUALIZAR' : 'SALVAR',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _type == 'expense' ? Colors.red : Colors.green,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildTypeButton(
      String label, String value, Color color, IconData icon) {
    final isSelected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black12, blurRadius: 4)]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRadio(String label, String value) {
    final isSelected = _category == value;
    return InkWell(
      onTap: () => setState(() => _category = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? Colors.red.withOpacity(0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.red : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.red[900] : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
