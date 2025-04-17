import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_bloc.dart';
import 'package:goalkeeper_stats/presentation/blocs/auth/auth_event.dart';
import 'package:image_picker/image_picker.dart';

/// Pantalla para editar información del perfil del usuario
class EditProfilePage extends StatefulWidget {
  final UserModel user;

  const EditProfilePage({
    super.key,
    required this.user,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _teamController;

  bool _isLoading = false;
  File? _imageFile;
  String? _currentPhotoUrl;
  bool _isImageChanged = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    // Inicializar controlador de equipo (asumiendo que tenemos este campo en UserModel)
    _teamController = TextEditingController(text: widget.user.team);
    _currentPhotoUrl = widget.user.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
      ),
      body: Stack(
        children: [
          _buildForm(),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Foto de perfil
            _buildProfilePhotoSelector(),
            const SizedBox(height: 24),

            // Nombre
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person),
                helperText: 'Tu nombre como aparecerá en la aplicación',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa tu nombre';
                }
                if (value.length < 2) {
                  return 'El nombre debe tener al menos 2 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Equipo
            TextFormField(
              controller: _teamController,
              decoration: const InputDecoration(
                labelText: 'Equipo',
                prefixIcon: Icon(Icons.sports_soccer),
                helperText: 'Equipo al que perteneces (opcional)',
              ),
            ),
            const SizedBox(height: 16),

            // Email (no editable, solo para mostrar)
            TextFormField(
              initialValue: widget.user.email,
              readOnly: true,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                helperText: 'No se puede cambiar el email',
              ),
            ),
            const SizedBox(height: 24),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSelector() {
    return Column(
      children: [
        GestureDetector(
          onTap: _selectImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: _getProfileImage(),
                child: _getProfileImagePlaceholder(),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Toca para cambiar tu foto de perfil',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  ImageProvider? _getProfileImage() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      return NetworkImage(_currentPhotoUrl!);
    }
    return null;
  }

  Widget? _getProfileImagePlaceholder() {
    if (_imageFile == null &&
        (_currentPhotoUrl == null || _currentPhotoUrl!.isEmpty)) {
      return const Icon(Icons.person, size: 60, color: Colors.white);
    }
    return null;
  }

  Future<void> _selectImage() async {
    final ImagePicker picker = ImagePicker();

    // Mostrar un diálogo para elegir entre cámara o galería
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Tomar foto'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? photo =
                      await picker.pickImage(source: ImageSource.camera);
                  _processSelectedImage(photo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Elegir de galería'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);
                  _processSelectedImage(image);
                },
              ),
              if (_currentPhotoUrl != null || _imageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Eliminar foto',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imageFile = null;
                      _currentPhotoUrl = null;
                      _isImageChanged = true;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _processSelectedImage(XFile? image) {
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _isImageChanged = true;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final AuthBloc authBloc = BlocProvider.of<AuthBloc>(context);

      // Obtener valores actualizados
      final updatedName = _nameController.text.trim();
      final updatedTeam = _teamController.text.trim();

      // Preparar la actualización del usuario
      // Aquí manejaríamos la carga de la imagen si fuera necesario
      String? updatedPhotoUrl = _currentPhotoUrl;

      // Si la imagen ha cambiado, deberíamos subirla a algún almacenamiento
      // y obtener la URL (esto es un ejemplo, dependería de la implementación real)
      if (_isImageChanged) {
        if (_imageFile != null) {
          // En una implementación real, aquí cargaríamos la imagen y obtendríamos la URL
          // updatedPhotoUrl = await _uploadImage(_imageFile!);

          // Por ahora, simulamos que la URL permanece igual
          updatedPhotoUrl = _currentPhotoUrl;
        } else {
          // Si la imagen se eliminó
          updatedPhotoUrl = null;
        }
      }

      // Crear una copia actualizada del usuario
      final updatedUser = widget.user.copyWith(
        name: updatedName,
        photoUrl: updatedPhotoUrl,
        team: updatedTeam.isEmpty ? null : updatedTeam,
      );

      // Actualizar el usuario usando el BLoC
      authBloc.add(UpdateUserEvent(updatedUser));

      // Mostrar mensaje de éxito y regresar con el usuario actualizado
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Regresar con el usuario actualizado
      Navigator.pop(context, updatedUser);
    } catch (e) {
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar perfil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
