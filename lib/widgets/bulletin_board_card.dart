import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notice_service.dart';
import '../config/app_theme.dart';

class BulletinBoardCard extends StatefulWidget {
  final Color baseColor;

  const BulletinBoardCard({super.key, required this.baseColor});

  @override
  State<BulletinBoardCard> createState() => _BulletinBoardCardState();
}

class _BulletinBoardCardState extends State<BulletinBoardCard> {
  List<Map<String, dynamic>> _activeNotices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveNotices();
  }

  Future<void> _loadActiveNotices() async {
    try {
      final notices = await NoticeService.getActiveNotices();
      if (mounted) {
        setState(() {
          _activeNotices = notices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeNotices.isEmpty) {
      return _buildEmptyNotice();
    }

    return Column(
      children:
          _activeNotices.map((notice) => _buildNoticeItem(notice)).toList(),
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
                  'Não há avisos da academia no momento!',
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
    if (label.contains('nutri')) return const Color(0xFF2A9D8F); // Verde Nutri
    return Colors.black87; // Admin (Preto suave)
  }

  Widget _buildNoticeItem(Map<String, dynamic> notice) {
    final author = notice['author_label'] ?? 'Gestão da Academia';
    final noticeColor = _getNoticeColor(author);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: noticeColor.withOpacity(0.08), // Fundo bem suave
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: noticeColor.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: noticeColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: noticeColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Autor Label
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: noticeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    author.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  notice['title'],
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notice['description'],
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
}
