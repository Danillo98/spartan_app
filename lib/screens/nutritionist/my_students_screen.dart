import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/diet_service.dart';
import '../../services/notice_service.dart';
import '../../services/auth_service.dart';
import '../../config/app_theme.dart';
import 'package:intl/intl.dart';
import '../../widgets/sent_notices_list.dart';

class MyStudentsNutritionistScreen extends StatefulWidget {
  const MyStudentsNutritionistScreen({super.key});

  @override
  State<MyStudentsNutritionistScreen> createState() =>
      _MyStudentsNutritionistScreenState();
}

class _MyStudentsNutritionistScreenState
    extends State<MyStudentsNutritionistScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  Set<String> _selectedStudentIds = {};
  bool _selectAll = false;
  final TextEditingController _searchController = TextEditingController();
  static const nutritionistPrimary =
      Color(0xFF2A9D8F); // Verde do nutricionista

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(_filterStudents);
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = List.from(_students);
      } else {
        _filteredStudents = _students.where((student) {
          final name = (student['name'] ?? '').toLowerCase();
          final email = (student['email'] ?? '').toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await DietService.getMyStudents();
      if (mounted) {
        setState(() {
          _students = students;
          _filteredStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar alunos: $e')),
        );
      }
    }
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedStudentIds =
            _filteredStudents.map((s) => s['id'] as String).toSet();
      } else {
        _selectedStudentIds.clear();
      }
    });
  }

  void _toggleStudent(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
        _selectAll = false;
      } else {
        _selectedStudentIds.add(studentId);
        if (_selectedStudentIds.length == _filteredStudents.length) {
          _selectAll = true;
        }
      }
    });
  }

  Future<void> _showNoticeForm() async {
    if (_selectedStudentIds.isEmpty) return;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime startAt = DateTime.now();
    DateTime endAt = DateTime.now().add(const Duration(days: 7));

    // Obter nome do nutricionista
    final userData = await AuthService.getCurrentUserData();
    final nutriName = userData?['nome'] ?? 'Nutricionista';

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
                'Novo Aviso para ${_selectedStudentIds.length} aluno(s)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Título'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: startAt,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 1)),
                                lastDate: DateTime(2030),
                              );
                              if (date != null) {
                                final time = await showTimePicker(
                                    context: context,
                                    initialTime:
                                        TimeOfDay.fromDateTime(startAt));
                                if (time != null) {
                                  setStateDialog(() => startAt = DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      time.hour,
                                      time.minute));
                                }
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Início',
                                  border: OutlineInputBorder()),
                              child: Text(
                                  DateFormat('dd/MM HH:mm').format(startAt)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: endAt,
                                firstDate: startAt,
                                lastDate: DateTime(2030),
                              );
                              if (date != null) {
                                final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(endAt));
                                if (time != null) {
                                  setStateDialog(() => endAt = DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      time.hour,
                                      time.minute));
                                }
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                  labelText: 'Fim',
                                  border: OutlineInputBorder()),
                              child:
                                  Text(DateFormat('dd/MM HH:mm').format(endAt)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isEmpty ||
                      descController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Preencha título e descrição')));
                    return;
                  }
                  if (endAt.isBefore(startAt)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Data fim deve ser após início')));
                    return;
                  }

                  Navigator.pop(context); // Fecha dialog

                  // Enviar
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enviando avisos...')));

                  try {
                    for (var studentId in _selectedStudentIds) {
                      await NoticeService.createNotice(
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        startAt: startAt,
                        endAt: endAt,
                        targetStudentId: studentId,
                        authorLabel: 'Nutricionista: $nutriName',
                      );
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Avisos enviados com sucesso!'),
                          backgroundColor: Colors.green));
                      setState(() {
                        _selectedStudentIds.clear();
                        _selectAll = false;
                      });
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Erro ao enviar: $e'),
                          backgroundColor: Colors.red));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: nutritionistPrimary),
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          backgroundColor: nutritionistPrimary,
          title: Text(
            'Gestão de Alunos',
            style: GoogleFonts.lato(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Meus Alunos'),
              Tab(text: 'Avisos Enviados'),
            ],
          ),
          actions: [
            if (_students.isNotEmpty)
              TextButton.icon(
                onPressed: _toggleSelectAll,
                icon: Icon(
                  _selectAll ? Icons.check_box : Icons.check_box_outline_blank,
                  color: Colors.white,
                ),
                label: Text(
                  _selectAll ? 'Desmarcar Todos' : 'Marcar Todos',
                  style: GoogleFonts.lato(color: Colors.white),
                ),
              ),
          ],
        ),
        body: TabBarView(
          children: [
            // ABA 1: LISTA DE ALUNOS
            _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: nutritionistPrimary),
                  )
                : _students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhum aluno encontrado',
                              style: GoogleFonts.lato(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Crie dietas para seus alunos',
                              style: GoogleFonts.lato(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Header com contador
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.white,
                            child: Row(
                              children: [
                                Icon(Icons.people, color: nutritionistPrimary),
                                const SizedBox(width: 12),
                                Text(
                                  '${_students.length} aluno(s) com dietas',
                                  style: GoogleFonts.lato(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                if (_selectedStudentIds.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: nutritionistPrimary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_selectedStudentIds.length} selecionado(s)',
                                      style: GoogleFonts.lato(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Campo de pesquisa
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Pesquisar por nome ou email...',
                                prefixIcon: const Icon(Icons.search,
                                    color: nutritionistPrimary),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: nutritionistPrimary, width: 2),
                                ),
                              ),
                            ),
                          ),

                          // Lista de alunos
                          Expanded(
                            child: _filteredStudents.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.search_off,
                                          size: 60,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Nenhum aluno encontrado',
                                          style: GoogleFonts.lato(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    itemCount: _filteredStudents.length,
                                    itemBuilder: (context, index) {
                                      final student = _filteredStudents[index];
                                      final isSelected = _selectedStudentIds
                                          .contains(student['id']);

                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: isSelected
                                                ? nutritionistPrimary
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: CheckboxListTile(
                                          value: isSelected,
                                          onChanged: (value) =>
                                              _toggleStudent(student['id']),
                                          activeColor: nutritionistPrimary,
                                          title: Text(
                                            student['name'] ?? 'Sem nome',
                                            style: GoogleFonts.lato(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 4),
                                              Text(
                                                student['email'] ?? '',
                                                style: GoogleFonts.lato(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.restaurant_menu,
                                                    size: 16,
                                                    color: nutritionistPrimary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${student['diet_count'] ?? 0} dieta(s)',
                                                    style: GoogleFonts.lato(
                                                      fontSize: 12,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          secondary: CircleAvatar(
                                            backgroundColor: nutritionistPrimary
                                                .withOpacity(0.1),
                                            child: Text(
                                              (student['name'] ?? 'A')[0]
                                                  .toUpperCase(),
                                              style: GoogleFonts.lato(
                                                color: nutritionistPrimary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),

            // ABA 2: AVISOS ENVIADOS
            SentNoticesList(baseColor: nutritionistPrimary),
          ],
        ),
        floatingActionButton: _selectedStudentIds.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _showNoticeForm,
                backgroundColor: nutritionistPrimary,
                icon: const Icon(Icons.send),
                label: Text(
                  'Enviar Aviso', // MUDADO DE ALERTA PARA AVISO
                  style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
