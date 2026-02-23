import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../config/app_theme.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  bool _isLoading = true;
  bool _isUploading = false;
  Map<String, dynamic>? _profileData;
  static const studentPrimary = Color(0xFF457B9D);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final data = await AuthService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar perfil: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Escolher foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Câmera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeria'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _isUploading = true);

        final userId = _profileData?['id'];
        if (userId == null) throw Exception('ID do usuário não encontrado');

        final url = await ProfileService.uploadProfilePhoto(pickedFile, userId);
        if (url == null) throw Exception('Falha no upload da imagem');

        final success =
            await ProfileService.updatePhotoUrl(userId, 'student', url);
        if (!success) throw Exception('Falha ao atualizar URL no banco');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadProfile();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar foto: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: studentPrimary,
        title: Text(
          'Meu Perfil',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: studentPrimary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar e Nome
                  Container(
                    padding: const EdgeInsets.all(24),
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
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 4.0,
                                child: GestureDetector(
                                  onTap: _pickAndUploadImage,
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor:
                                        studentPrimary.withOpacity(0.1),
                                    backgroundImage:
                                        _profileData?['photo_url'] != null
                                            ? NetworkImage(
                                                _profileData!['photo_url'])
                                            : null,
                                    child: _profileData?['photo_url'] == null
                                        ? (_isUploading
                                            ? const CircularProgressIndicator()
                                            : Icon(Icons.person,
                                                size: 50,
                                                color: studentPrimary))
                                        : (_isUploading
                                            ? const CircularProgressIndicator()
                                            : null),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: studentPrimary,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _profileData?['nome'] ?? 'Aluno',
                          style: GoogleFonts.lato(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: studentPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Aluno',
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: studentPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Informações Pessoais
                  _buildSectionTitle('Informações Pessoais'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.email,
                    label: 'Email',
                    value: _profileData?['email'] ?? 'Não informado',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.phone,
                    label: 'Telefone',
                    value: _profileData?['telefone'] ?? 'Não informado',
                  ),

                  const SizedBox(height: 24),

                  // Informações da Academia
                  _buildSectionTitle('Academia'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.business,
                    label: 'Nome',
                    value: _profileData?['academia'] ?? 'Não informado',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.location_on,
                    label: 'Endereço',
                    value:
                        _profileData?['endereco_academia'] ?? 'Não informado',
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.lato(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryText,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: studentPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: studentPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.w600,
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
