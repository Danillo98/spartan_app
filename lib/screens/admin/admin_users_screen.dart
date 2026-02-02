import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_role.dart';
import '../../services/user_service.dart';
import '../../config/app_theme.dart';
import 'create_user_screen.dart';
import 'edit_user_screen.dart';
import 'subscription_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  UserRole? _filterRole;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _loadUsers();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await UserService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao carregar usuários: ${e.toString()}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    _filteredUsers = _users.where((user) {
      // Filtro por nome
      final matchesSearch = user['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());

      // Filtro por role
      final matchesRole = _filterRole == null ||
          user['role'] == _filterRole.toString().split('.').last;

      return matchesSearch && matchesRole;
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onFilterRoleChanged(UserRole? role) {
    setState(() {
      _filterRole = role;
      _applyFilters();
    });
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        title: Text('Confirmar Exclusão',
            style: TextStyle(color: AppTheme.primaryText)),
        content: Text('Deseja realmente excluir o usuário "$userName"?',
            style: TextStyle(color: AppTheme.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final result = await UserService.deleteUser(userId);

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Usuário excluído com sucesso!',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: ${result['message']}',
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir usuário: ${e.toString()}',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleBlockUser(
      String userId, String userName, String role, bool currentStatus) async {
    final action = currentStatus ? "Desbloquear" : "Bloquear";
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.white,
        title: Text('$action Usuário',
            style: TextStyle(color: AppTheme.primaryText)),
        content: Text('Deseja realmente $action o acesso de "$userName"?',
            style: TextStyle(color: AppTheme.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  currentStatus ? AppTheme.success : AppTheme.accentRed,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final result = await UserService.toggleUserBlockStatus(
            userId, role, currentStatus);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'],
                style: const TextStyle(color: Colors.white)),
            backgroundColor:
                result['success'] ? AppTheme.success : AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao executar ação: ${e.toString()}',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFF1A1A1A);
      case 'nutritionist':
        return const Color(0xFF2A9D8F);
      case 'trainer':
        return AppTheme.primaryRed;
      case 'student':
        return const Color(0xFF457B9D);
      default:
        return AppTheme.secondaryText;
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'nutritionist':
        return 'Nutricionista';
      case 'trainer':
        return 'Personal';
      case 'student':
        return 'Aluno';
      default:
        return role;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'nutritionist':
        return Icons.restaurant_menu_rounded;
      case 'trainer':
        return Icons.fitness_center_rounded;
      case 'student':
        return Icons.person_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.secondaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Painel de Usuários',
          style: GoogleFonts.cinzel(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.secondaryText),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppTheme.borderGrey,
            height: 1.0,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Barra de pesquisa e filtros
            Container(
              color: AppTheme.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Campo de pesquisa
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Pesquisar por nome...',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF1A1A1A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.borderGrey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1A1A1A), width: 2),
                      ),
                      filled: true,
                      fillColor: AppTheme.lightGrey,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: _onSearchChanged,
                    cursorColor: const Color(0xFF1A1A1A),
                  ),
                  const SizedBox(height: 16),

                  // Filtros por role
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Todos', null),
                        const SizedBox(width: 8),
                        _buildFilterChip('Admins', UserRole.admin),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                            'Nutricionistas', UserRole.nutritionist),
                        const SizedBox(width: 8),
                        _buildFilterChip('Personals', UserRole.trainer),
                        const SizedBox(width: 8),
                        _buildFilterChip('Alunos', UserRole.student),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Divisor com sombra
            Container(
              height: 1,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),

            // Estatísticas
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total de Usuários',
                      _users.length.toString(),
                      Icons.people_alt_rounded,
                      const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Exibindo Agora',
                      _filteredUsers.length.toString(),
                      Icons.filter_list_alt,
                      AppTheme.primaryText,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de usuários
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGold,
                      ),
                    )
                  : _filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 60,
                                color: AppTheme.borderGrey,
                              ),
                              const SizedBox(height: 15),
                              Text(
                                'Nenhum usuário encontrado',
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  color: AppTheme.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadUsers,
                          color: const Color(0xFF1A1A1A),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return _buildUserCard(user);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1A1A).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            // Verificar limite ANTES de navegar
            try {
              final limitStatus = await UserService.checkPlanLimitStatus();
              final isAtLimit = limitStatus['isAtLimit'] ?? false;
              // final plan = limitStatus['plan'] ?? 'Bronze'; // Se precisar mostrar o plano

              if (isAtLimit && mounted) {
                // Mostrar Popup de Bloqueio Imediato
                _showUpgradeDialog();
              } else {
                // Navegar para Criar Usuário
                if (mounted) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateUserScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadUsers();
                  }
                }
              }
            } catch (e) {
              // Fallback: se der erro na verificação, deixa tentar entrar (o backend barra depois)
              if (mounted) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateUserScreen(),
                  ),
                );
                if (result == true) _loadUsers();
              }
            }
          },
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text('NOVO USUÁRIO',
              style: GoogleFonts.lato(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Colors.white,
              )),
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
        ),
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: 450), // Fixa a largura máxima elegantemente
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone Foguete (Substituir por imagem se tiver, mas icone é leve)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E5), // Fundo suave amarelo
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    size: 50,
                    color: Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'HORA DE CRESCER! 🚀',
                  style: GoogleFonts.cinzel(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                Text(
                  'Incrível! Sua academia atingiu o limite máximo do plano atual.',
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    color: const Color(0xFF666666),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'O próximo cadastro só será liberado após o upgrade.',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(
                          0xFFD32F2F), // Vermelho alerta leve ou laranja
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Fecha Dialog
                      // Navega para Subscription
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SubscriptionScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700), // Dourado
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                      shadowColor: const Color(0xFFFFD700).withOpacity(0.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'DESBLOQUEAR CRESCIMENTO',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Voltar',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, UserRole? role) {
    final isSelected = _filterRole == role;
    return FilterChip(
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.secondaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: isSelected,
      onSelected: (selected) => _onFilterRoleChanged(selected ? role : null),
      selectedColor: const Color(0xFF1A1A1A),
      backgroundColor: AppTheme.lightGrey,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : AppTheme.borderGrey,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderGrey.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.lato(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 13,
              color: AppTheme.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] as String;
    final color = _getRoleColor(role);
    final isBlocked = user['is_blocked'] ?? false;
    final itemColor = isBlocked ? Colors.grey : color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: AppTheme.cardRadius,
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: AppTheme.borderGrey.withOpacity(0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: itemColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: itemColor.withOpacity(0.2), width: 2),
          ),
          child: Icon(
            _getRoleIcon(role),
            color: itemColor,
            size: 24,
          ),
        ),
        title: Text(
          user['name'],
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppTheme.primaryText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.email_outlined,
                    size: 14, color: AppTheme.secondaryText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    user['email'],
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: AppTheme.secondaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Text(
                    _getRoleName(role),
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      color: itemColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (isBlocked) ...[
                  Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'BLOQUEADO',
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ] else if (user['phone'] != null) ...[
                  Icon(Icons.phone_rounded,
                      size: 14, color: AppTheme.secondaryText),
                  const SizedBox(width: 4),
                  Text(
                    user['phone'],
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: MenuAnchor(
          builder: (context, controller, child) {
            return IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.more_vert_rounded),
              color: AppTheme.secondaryText,
              tooltip: 'Opções',
            );
          },
          menuChildren: [
            MenuItemButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditUserScreen(user: user),
                  ),
                );
                if (result == true) {
                  _loadUsers();
                }
              },
              child: const Row(
                children: [
                  Icon(Icons.edit_rounded,
                      size: 18, color: AppTheme.primaryText),
                  SizedBox(width: 10),
                  Text('Editar'),
                ],
              ),
            ),
            MenuItemButton(
              onPressed: () => _toggleBlockUser(
                  user['id'], user['name'], user['role'], isBlocked),
              child: Row(
                children: [
                  Icon(
                      isBlocked
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      size: 18,
                      color: isBlocked ? Colors.green : Colors.orange),
                  const SizedBox(width: 10),
                  Text(isBlocked ? 'Desbloquear Acesso' : 'Bloquear Acesso'),
                ],
              ),
            ),
            MenuItemButton(
              onPressed: () => _deleteUser(user['id'], user['name']),
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppTheme.accentRed),
                  const SizedBox(width: 10),
                  Text('Excluir', style: TextStyle(color: AppTheme.accentRed)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
