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

  late UserRole _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _emailController = TextEditingController(text: widget.user['email']);
    _phoneController = TextEditingController(text: widget.user['phone']);

    // Inicia com valor existente ou vazio
    final existingDueDay = widget.user['payment_due_day'];
    _dueDayController = TextEditingController(
      text: existingDueDay != null ? existingDueDay.toString() : '',
    );

    _selectedRole = _stringToRole(widget.user['role']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dueDayController.dispose();
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

      await UserService.updateUser(
        userId: widget.user['id'],
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        paymentDueDay: dueDay,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Usuário atualizado com sucesso!',
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: ${e.toString()}',
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
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // Seleção de tipo de usuário
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

                // Cards de seleção de role
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildRoleCard(
                      UserRole.admin,
                      Icons.admin_panel_settings_rounded,
                    ),
                    _buildRoleCard(
                      UserRole.nutritionist,
                      Icons.restaurant_menu_rounded,
                    ),
                    _buildRoleCard(
                      UserRole.trainer,
                      Icons.fitness_center_rounded,
                    ),
                    _buildRoleCard(
                      UserRole.student,
                      Icons.person_rounded,
                    ),
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

                // Nome
                _buildTextField(
                  controller: _nameController,
                  label: 'Nome Completo',
                  hint: 'João Silva',
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o nome completo';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Email
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'usuario@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o email';
                    }
                    if (!value.contains('@')) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Telefone
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
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o telefone';
                    }
                    if (value.length < 10) {
                      return 'Telefone inválido';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Data de Vencimento (Apenas para Alunos)
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
                      if (_selectedRole != UserRole.student) return null;
                      if (value == null || value.isEmpty)
                        return null; // Opcional
                      final day = int.tryParse(value);
                      if (day == null || day < 1 || day > 31) {
                        return 'Dia inválido (1-31)';
                      }
                      return null;
                    },
                  ),

                const SizedBox(height: 30),

                // Botão Atualizar
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: AppTheme.buttonRadius,
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0xFF1A1A1A),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.buttonRadius,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'ATUALIZAR',
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botão Alterar Senha (Acesso rápido admin)
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _showChangePasswordDialog,
                    icon: const Icon(Icons.lock_reset_rounded,
                        color: Color(0xFF1A1A1A)),
                    label: Text(
                      'REDEFINIR SENHA',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                        letterSpacing: 1,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFF1A1A1A), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.buttonRadius,
                      ),
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

  Widget _buildRoleCard(UserRole role, IconData icon) {
    final isSelected = _selectedRole == role;
    final color = _getRoleColor(role);

    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: AppTheme.cardRadius,
      child: Container(
        width: (MediaQuery.of(context).size.width - 60) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: AppTheme.cardRadius,
          border: Border.all(
            color: isSelected ? color : AppTheme.borderGrey,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? color : AppTheme.secondaryText,
            ),
            const SizedBox(height: 8),
            Text(
              _getRoleName(role),
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppTheme.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters, // Adicionado parâmetro
    bool enabled = true,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            enabled ? AppTheme.lightGrey : AppTheme.lightGrey.withOpacity(0.5),
        borderRadius: AppTheme.inputRadius,
        border: Border.all(
          color: AppTheme.borderGrey,
        ),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters, // Usar formatters
        style: TextStyle(
          color: enabled ? AppTheme.primaryText : AppTheme.secondaryText,
        ),
        cursorColor: const Color(0xFF1A1A1A),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          helperStyle:
              GoogleFonts.lato(color: AppTheme.secondaryText, fontSize: 12),
          prefixIcon: Icon(icon,
              color:
                  enabled ? const Color(0xFF1A1A1A) : AppTheme.secondaryText),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: AppTheme.inputRadius,
            borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
          ),
          filled: false,
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
                    const Text(
                        'Digite a nova senha para o usuário. Esta ação é imediata e não envia email.'),
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
                          onPressed: () {
                            setStateDialog(() => obscureText = !obscureText);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Mínimo de 6 caracteres';
                        }
                        return null;
                      },
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
                            widget.user['id'],
                            passwordController.text,
                          );

                          if (!context.mounted) return;
                          Navigator.pop(context); // Close dialog

                          if (result['success'] == true) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Senha alterada com sucesso!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(result['message']),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                  ),
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
