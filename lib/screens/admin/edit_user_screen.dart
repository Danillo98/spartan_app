import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_role.dart';
import '../../services/user_service.dart';
import '../../config/app_theme.dart';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _dueDayController;
  late TextEditingController _birthDateController;

  DateTime? _selectedBirthDate;
  late UserRole _selectedRole;
  int? _due_day_value;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _emailController = TextEditingController(text: widget.user['email']);
    _phoneController = TextEditingController(text: widget.user['phone']);

    final existingDueDay = widget.user['payment_due_day'];
    if (existingDueDay != null && existingDueDay is int) {
      _due_day_value = existingDueDay; // Usar o valor exato do banco
    } else {
      _due_day_value = null;
    }

    _dueDayController = TextEditingController(
      text: _due_day_value != null ? _due_day_value.toString() : '',
    );

    if (widget.user['birth_date'] != null) {
      try {
        _selectedBirthDate = DateTime.parse(widget.user['birth_date']);
      } catch (e) {
        print('Erro ao converter data de nascimento: $e');
      }
    }
    _birthDateController = TextEditingController(
      text: _selectedBirthDate != null
          ? "${_selectedBirthDate!.day.toString().padLeft(2, '0')}/${_selectedBirthDate!.month.toString().padLeft(2, '0')}/${_selectedBirthDate!.year}"
          : '',
    );

    _selectedRole = _stringToRole(widget.user['role']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dueDayController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  UserRole _stringToRole(String roleString) {
    switch (roleString) {
      case 'admin':
        return UserRole.admin;
      case 'nutritionist':
        return UserRole.nutritionist;
      case 'trainer':
        return UserRole.trainer;
      case 'student':
        return UserRole.student;
      default:
        return UserRole.student;
    }
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      int? dueDay;
      if (_selectedRole == UserRole.student &&
          _dueDayController.text.isNotEmpty) {
        dueDay = int.tryParse(_dueDayController.text);
      }

      final result = await UserService.updateUser(
        userId: widget.user['id'],
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        paymentDueDay: dueDay,
        birthDate: _selectedBirthDate != null
            ? "${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}"
            : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário atualizado com sucesso!',
                style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(result['message'] ?? 'Erro desconhecido');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Erro ao atualizar: ${e.toString().replaceAll('Exception: ', '')}',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.nutritionist:
        return 'Nutricionista';
      case UserRole.trainer:
        return 'Personal Trainer';
      case UserRole.student:
        return 'Aluno';
      case UserRole.visitor:
        return 'Visitante';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.nutritionist:
        return const Color(0xFF2A9D8F);
      case UserRole.trainer:
        return AppTheme.primaryRed;
      case UserRole.student:
        return const Color(0xFF457B9D);
      case UserRole.admin:
        return const Color(0xFF1A1A1A);
      case UserRole.visitor:
        return AppTheme.primaryGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(_selectedRole);

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.secondaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Editar Usuário',
          style: GoogleFonts.cinzel(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'TIPO DE USUÁRIO',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryText,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildRoleCard(
                        UserRole.admin, Icons.admin_panel_settings_rounded),
                    _buildRoleCard(
                        UserRole.nutritionist, Icons.restaurant_menu_rounded),
                    _buildRoleCard(
                        UserRole.trainer, Icons.fitness_center_rounded),
                    _buildRoleCard(UserRole.student, Icons.person_rounded),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  'DADOS DO USUÁRIO',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryText,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _nameController,
                  label: 'Nome Completo',
                  hint: 'João Silva',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Por favor, insira o nome completo'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'usuario@email.com',
                  icon: Icons.email_outlined,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Por favor, insira o email';
                    if (!value.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Telefone',
                  hint: '(00) 00000-0000',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Por favor, insira o telefone';
                    if (value.length < 10) return 'Telefone inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildDatePickerField(
                  controller: _birthDateController,
                  label: 'Data de Nascimento',
                  hint: 'DD/MM/AAAA',
                  icon: Icons.cake_outlined,
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedBirthDate ?? DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: roleColor,
                              onPrimary: Colors.white,
                              onSurface: const Color(0xFF1A1A1A),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedBirthDate = picked;
                        _birthDateController.text =
                            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedRole == UserRole.student)
                  _buildTextField(
                    controller: _dueDayController,
                    label: 'Dia de Vencimento',
                    hint: '1-31',
                    icon: Icons.calendar_today_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final day = int.tryParse(value);
                      if (day == null || day < 1 || day > 31)
                        return 'Dia inválido (1-31)';
                      return null;
                    },
                  ),
                const SizedBox(height: 30),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: AppTheme.buttonRadius,
                    boxShadow: [
                      BoxShadow(
                        color: roleColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: roleColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.buttonRadius),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('ATUALIZAR',
                            style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _showChangePasswordDialog,
                    icon: Icon(Icons.lock_reset_rounded, color: roleColor),
                    label: Text(
                      'REDEFINIR SENHA',
                      style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                          letterSpacing: 1),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: roleColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.buttonRadius),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: AppTheme.inputRadius,
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        style: const TextStyle(color: AppTheme.primaryText),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _getRoleColor(_selectedRole)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRoleCard(UserRole role, IconData icon) {
    final isSelected = _selectedRole == role;
    final color = _getRoleColor(role);
    return Container(
      width: (MediaQuery.of(context).size.width - 60) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.white,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(
            color: isSelected ? color : AppTheme.borderGrey,
            width: isSelected ? 2 : 1),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 32, color: isSelected ? color : AppTheme.secondaryText),
          const SizedBox(height: 8),
          Text(
            _getRoleName(role),
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            enabled ? AppTheme.lightGrey : AppTheme.lightGrey.withOpacity(0.5),
        borderRadius: AppTheme.inputRadius,
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: TextStyle(
            color: enabled ? AppTheme.primaryText : AppTheme.secondaryText),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _getRoleColor(_selectedRole)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator,
      ),
    );
  }

  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureText = true;
    bool isSaving = false;
    final roleColor = _getRoleColor(_selectedRole);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Redefinir Senha'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Digite a nova senha para o usuário.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscureText,
                      decoration: InputDecoration(
                        labelText: 'Nova Senha',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureText
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setStateDialog(() => obscureText = !obscureText),
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 6)
                          ? 'Mínimo de 6 caracteres'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setStateDialog(() => isSaving = true);
                          final result =
                              await UserService.adminUpdateUserPassword(
                                  widget.user['id'], passwordController.text);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(result['success']
                                  ? 'Senha alterada com sucesso!'
                                  : result['message']),
                              backgroundColor:
                                  result['success'] ? Colors.green : Colors.red,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: roleColor),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Salvar Senha',
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
