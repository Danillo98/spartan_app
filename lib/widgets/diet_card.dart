import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

class DietCard extends StatelessWidget {
  final Map<String, dynamic> diet;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onStatusToggle;

  const DietCard({
    super.key,
    required this.diet,
    this.onTap,
    this.onDelete,
    this.onStatusToggle,
  });

  static const nutritionistPrimary = Color(0xFF2A9D8F);

  @override
  Widget build(BuildContext context) {
    final status = diet['status'] ?? 'active';
    final studentName = diet['student']?['name'] ?? 'Aluno não atribuído';
    final totalCalories = diet['total_calories'] ?? 0;
    final goal = diet['objective_diet'] ?? 'Não especificado';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: nutritionistPrimary.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header com status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    nutritionistPrimary.withOpacity(0.1),
                    nutritionistPrimary.withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Ícone
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: nutritionistPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Nome da dieta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diet['name_diet'] ?? 'Sem nome',
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color: AppTheme.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                studentName,
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  color: AppTheme.secondaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Profissional Responsável (Novo)
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 14,
                              color: AppTheme.secondaryText.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                diet['users_nutricionista']?['nome'] ??
                                    'Administração da Academia',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color:
                                      AppTheme.secondaryText.withOpacity(0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Status badge
                  _buildStatusBadge(status),
                ],
              ),
            ),

            // Descrição
            if (diet['description'] != null &&
                diet['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  diet['description'],
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Informações
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Calorias
                  Expanded(
                    child: _buildInfoChip(
                      Icons.local_fire_department_rounded,
                      '$totalCalories kcal',
                      const Color(0xFFFF6B6B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Objetivo
                  Expanded(
                    child: _buildInfoChip(
                      Icons.flag_rounded,
                      goal,
                      nutritionistPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Datas
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppTheme.secondaryText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateRange(),
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  const Spacer(),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: AppTheme.accentRed,
                      iconSize: 20,
                      onPressed: onDelete,
                      tooltip: 'Excluir',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'active':
        color = const Color(0xFF4CAF50);
        label = 'Ativa';
        icon = Icons.check_circle_rounded;
        break;
      case 'paused':
        color = const Color(0xFFFFA726);
        label = 'Pausada';
        icon = Icons.pause_circle_rounded;
        break;
      case 'completed':
        color = const Color(0xFF757575);
        label = 'Concluída';
        icon = Icons.done_all_rounded;
        break;
      default:
        color = AppTheme.secondaryText;
        label = 'Indefinido';
        icon = Icons.help_outline_rounded;
    }

    return InkWell(
      onTap: onStatusToggle,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange() {
    final startDate = diet['start_date'];
    final endDate = diet['end_date'];

    if (startDate == null) return 'Data não definida';

    final start = DateTime.parse(startDate);
    final startFormatted =
        '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';

    if (endDate == null) {
      return 'Início: $startFormatted';
    }

    final end = DateTime.parse(endDate);
    final endFormatted =
        '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';

    return '$startFormatted - $endFormatted';
  }
}
