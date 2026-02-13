import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/notice_service.dart';
import '../services/appointment_service.dart';
import '../config/app_theme.dart';

class BulletinBoardCard extends StatefulWidget {
  final Color baseColor;

  const BulletinBoardCard({super.key, required this.baseColor});

  @override
  State<BulletinBoardCard> createState() => _BulletinBoardCardState();
}

class _BulletinBoardCardState extends State<BulletinBoardCard> {
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Carregar Agendamentos (Avaliações)
      final appointments = await AppointmentService.getMyAppointments();
      final appointmentsFormatted = appointments
          .map((a) => {
                ...a,
                'type': 'appointment',
                'sortDate': DateTime.parse(a['scheduled_at']),
              })
          .toList();

      if (mounted) {
        setState(() {
          _appointments = appointmentsFormatted;
        });
      }
    } catch (e) {
      if (mounted) setState(() {});
      print('Erro ao carregar agendamentos iniciais: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: NoticeService.getActiveNotices(), // Chamada simples
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _appointments.isEmpty) {
          // Check _appointments for initial loading state
          return Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final notices = snapshot.data ?? [];

        final noticesFormatted = notices
            .map((n) => {
                  ...n,
                  'type': 'notice',
                  'sortDate': DateTime.parse(n['created_at']),
                })
            .toList();

        // Combine notices from FutureBuilder with appointments loaded in initState
        final combinedItems = [...noticesFormatted, ..._appointments];

        // Deduplicate items by ID to avoid showing the same item multiple times
        // This assumes 'id' is a unique identifier for both notices and appointments
        final Map<String, Map<String, dynamic>> uniqueItemsMap = {};
        for (var item in combinedItems) {
          final id = item['id']?.toString() ??
              UniqueKey().toString(); // Use UniqueKey if id is null
          uniqueItemsMap[id] = item;
        }

        final dedupedItems = uniqueItemsMap.values.toList();

        // Sort by date
        dedupedItems.sort((a, b) {
          final dateA = a['sortDate'] as DateTime;
          final dateB = b['sortDate'] as DateTime;
          return dateB.compareTo(dateA);
        });

        // If no items, show empty state
        if (dedupedItems.isEmpty) {
          return _buildEmptyNotice();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Quadro de Avisos:',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dedupedItems.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = dedupedItems[index];
                    if (item['type'] == 'appointment') {
                      return _buildAppointmentItem(item);
                    } else {
                      return _buildNoticeItem(item);
                    }
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyNotice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.baseColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.baseColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.baseColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: widget.baseColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quadro de Avisos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Não há avisos ou agendamentos no momento!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getNoticeColor(String authorLabel) {
    final label = authorLabel.toLowerCase();
    if (label.contains('personal')) return AppTheme.primaryRed;
    if (label.contains('nutri')) return const Color(0xFF2A9D8F);
    return Colors.black87;
  }

  Widget _buildNoticeItem(Map<String, dynamic> notice) {
    final author = notice['author_label'] ?? 'Geral';
    final noticeColor = _getNoticeColor(author);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: noticeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: noticeColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.campaign_rounded, // Ícone de megafone para aviso
              color: noticeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: noticeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'AVISO - ${author.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  notice['title'],
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notice['description'],
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryText,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem(Map<String, dynamic> appt) {
    final date = DateTime.parse(appt['scheduled_at']).toLocal();
    final dateStr = DateFormat('dd/MM').format(date);
    final timeStr = DateFormat('HH:mm').format(date);
    final color = AppTheme.primaryGold; // Dourado para agendamentos importantes

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AGENDA',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'Avaliação Física',
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aluno: ${appt['display_name']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Data: $dateStr às $timeStr',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
