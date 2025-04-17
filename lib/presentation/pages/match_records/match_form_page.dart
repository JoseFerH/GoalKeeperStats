import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/match_model.dart';
import 'package:goalkeeper_stats/domain/repositories/matches_repository.dart';
import 'package:goalkeeper_stats/data/models/user_model.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/intl.dart';

class MatchFormPage extends StatefulWidget {
  final String userId;
  final MatchesRepository matchesRepository;
  final MatchModel? match; // Null para crear nuevo, no-null para editar
  final UserModel user; // Añadido para verificar estado premium

  const MatchFormPage({
    Key? key,
    required this.userId,
    required this.matchesRepository,
    required this.user,
    this.match,
  }) : super(key: key);

  @override
  State<MatchFormPage> createState() => _MatchFormPageState();
}

class _MatchFormPageState extends State<MatchFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _opponentController;
  late TextEditingController _venueController;
  late TextEditingController _notesController;
  late TextEditingController _dateController;
  late TextEditingController _goalsScoredController;
  late TextEditingController _goalsConcededController;

  DateTime _selectedDate = DateTime.now();
  String _selectedType = MatchModel.TYPE_FRIENDLY;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();

    // Verificar que el usuario tenga permiso para usar esta función
    _checkUserPermissions();
  }

  void _checkUserPermissions() {
    // Verificar si el usuario es premium
    if (!widget.user.subscription.isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Mostrar mensaje y volver atrás
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta función requiere una suscripción Premium'),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      });
    }
  }

  void _initializeFields() {
    try {
      // Si estamos editando, inicializar con datos del partido
      if (widget.match != null) {
        _selectedDate = widget.match!.date;
        _selectedType = widget.match!.type;

        _opponentController =
            TextEditingController(text: widget.match!.opponent);
        _venueController = TextEditingController(text: widget.match!.venue);
        _notesController = TextEditingController(text: widget.match!.notes);
        _goalsScoredController = TextEditingController(
          text: widget.match!.goalsScored?.toString() ?? '',
        );
        _goalsConcededController = TextEditingController(
          text: widget.match!.goalsConceded?.toString() ?? '',
        );
      } else {
        // Si es nuevo, inicializar campos vacíos
        _opponentController = TextEditingController();
        _venueController = TextEditingController();
        _notesController = TextEditingController();
        _goalsScoredController = TextEditingController();
        _goalsConcededController = TextEditingController();
      }

      // Controlador para mostrar la fecha formateada
      _dateController = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(_selectedDate),
      );
    } catch (e, stack) {
      // Reportar error a Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error al inicializar campos del formulario de partido',
        fatal: false,
      );
      // Re-lanzar para manejo local
      rethrow;
    }
  }

  @override
  void dispose() {
    _opponentController.dispose();
    _venueController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    _goalsScoredController.dispose();
    _goalsConcededController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.match != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Partido' : 'Nuevo Partido'),
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            // Formulario
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tipo de partido
                  const Text(
                    'Tipo de Evento',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMatchTypeSelector(),
                  const SizedBox(height: 20),

                  // Fecha
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: _selectDate,
                  ),
                  const SizedBox(height: 16),

                  // Rival (opcional para entrenamientos)
                  TextFormField(
                    controller: _opponentController,
                    decoration: InputDecoration(
                      labelText: _selectedType == MatchModel.TYPE_TRAINING
                          ? 'Equipo (opcional)'
                          : 'Equipo rival',
                      prefixIcon: const Icon(Icons.people),
                    ),
                    validator: _selectedType != MatchModel.TYPE_TRAINING
                        ? (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa el nombre del rival';
                            }
                            return null;
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Lugar
                  TextFormField(
                    controller: _venueController,
                    decoration: const InputDecoration(
                      labelText: 'Lugar (opcional)',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mostrar campos de resultado solo para partidos (no entrenamientos)
                  if (_selectedType != MatchModel.TYPE_TRAINING) ...[
                    const Text(
                      'Resultado',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _goalsScoredController,
                            decoration: const InputDecoration(
                              labelText: 'Goles a favor',
                              prefixIcon: Icon(Icons.sports_soccer),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _goalsConcededController,
                            decoration: const InputDecoration(
                              labelText: 'Goles en contra',
                              prefixIcon: Icon(Icons.sports_score),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notas
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Botón de guardar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveMatch,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isEditing ? 'Actualizar' : 'Guardar',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Indicador de carga
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeOption(
            title: 'Oficial',
            value: MatchModel.TYPE_OFFICIAL,
            icon: Icons.emoji_events,
            color: Colors.amber,
          ),
        ),
        Expanded(
          child: _buildTypeOption(
            title: 'Amistoso',
            value: MatchModel.TYPE_FRIENDLY,
            icon: Icons.handshake,
            color: Colors.blue,
          ),
        ),
        Expanded(
          child: _buildTypeOption(
            title: 'Entreno',
            value: MatchModel.TYPE_TRAINING,
            icon: Icons.fitness_center,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = value;
        });
      },
      child: Card(
        color: isSelected ? color.withOpacity(0.2) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    try {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );

      if (pickedDate != null && pickedDate != _selectedDate) {
        setState(() {
          _selectedDate = pickedDate;
          _dateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
        });
      }
    } catch (e, stack) {
      // Reportar error a Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error al seleccionar fecha en formulario de partido',
        fatal: false,
      );
    }
  }

  Future<void> _saveMatch() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verificación adicional de premium
    if (!widget.user.subscription.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta función requiere una suscripción Premium'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Convertir campos de goles a enteros si están presentes
      final goalsScored = _goalsScoredController.text.isNotEmpty
          ? int.parse(_goalsScoredController.text)
          : null;
      final goalsConceded = _goalsConcededController.text.isNotEmpty
          ? int.parse(_goalsConcededController.text)
          : null;

      // Crear modelo de partido
      if (widget.match == null) {
        // Nuevo partido
        final newMatch = MatchModel.create(
          userId: widget.userId,
          date: _selectedDate,
          type: _selectedType,
          opponent: _opponentController.text.isEmpty
              ? null
              : _opponentController.text,
          venue: _venueController.text.isEmpty ? null : _venueController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          goalsScored: goalsScored,
          goalsConceded: goalsConceded,
        );

        // Guardar y obtener el partido creado con su ID asignado
        final createdMatch =
            await widget.matchesRepository.createMatch(newMatch);

        // Registrar evento en Crashlytics para monitoreo
        FirebaseCrashlytics.instance
            .log('Usuario creó un partido: ${createdMatch.id}');

        // Devolver el partido creado
        if (mounted) {
          Navigator.pop(context, createdMatch);
        }
      } else {
        // Actualizar partido existente
        final updatedMatch = widget.match!.copyWith(
          date: _selectedDate,
          type: _selectedType,
          opponent: _opponentController.text.isEmpty
              ? null
              : _opponentController.text,
          venue: _venueController.text.isEmpty ? null : _venueController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          goalsScored: goalsScored,
          goalsConceded: goalsConceded,
        );

        // Actualizar y obtener el partido actualizado
        final updated =
            await widget.matchesRepository.updateMatch(updatedMatch);

        // Registrar evento en Crashlytics para monitoreo
        FirebaseCrashlytics.instance
            .log('Usuario actualizó un partido: ${updated.id}');

        // Devolver el partido actualizado
        if (mounted) {
          Navigator.pop(context, updated);
        }
      }
    } catch (e, stack) {
      // Reportar error a Crashlytics
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error al guardar partido',
        fatal: false,
      );

      // Mostrar error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
