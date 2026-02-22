import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/workout_template_service.dart';
import '../../config/app_theme.dart';
import 'create_workout_template_screen.dart';

class WorkoutTemplatesListScreen extends StatefulWidget {
  const WorkoutTemplatesListScreen({super.key});

  @override
  State<WorkoutTemplatesListScreen> createState() =>
      _WorkoutTemplatesListScreenState();
}

class _WorkoutTemplatesListScreenState
    extends State<WorkoutTemplatesListScreen> {
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    if (_templates.isEmpty) setState(() => _isLoading = true);
    try {
      final templates = await WorkoutTemplateService.getTemplates();
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToCreateTemplate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateWorkoutTemplateScreen(),
      ),
    );
    if (result == true) {
      _loadTemplates();
    }
  }

  void _confirmDelete(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir Modelo',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Text(
          'Deseja realmente excluir o modelo "${template['name']}"?\nToda ficha gerada com ele permanecerá intacta.',
          style: GoogleFonts.lato(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final res =
                  await WorkoutTemplateService.deleteTemplate(template['id']);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res['message']),
                  backgroundColor:
                      res['success'] ? Colors.green : AppTheme.accentRed,
                ));
                _loadTemplates();
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Text(
          'Modelos de Treino',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryRed,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : _templates.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum modelo cadastrado ainda.\nCadastre um para facilitar a criação de fichas!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                        color: AppTheme.secondaryText, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final t = _templates[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryRed.withOpacity(0.1),
                          child: Icon(Icons.fitness_center,
                              color: AppTheme.primaryRed),
                        ),
                        title: Text(
                          t['name'] ?? 'Sem nome',
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          t['goal'] ?? 'Treino Personalizado',
                          style:
                              GoogleFonts.lato(color: AppTheme.secondaryText),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.accentRed),
                              onPressed: () => _confirmDelete(t),
                            ),
                          ],
                        ),
                        onTap: () {
                          // Pode abrir edição futura
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateTemplate,
        backgroundColor: AppTheme.primaryRed,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Novo Modelo',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
