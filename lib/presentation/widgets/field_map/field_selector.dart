import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/position.dart';

/// Widget que muestra un campo de fútbol interactivo
///
/// Permite al usuario seleccionar la posición del tirador y del portero
/// en el campo de juego con vistas separadas y más intuitivas.
class FieldSelector extends StatefulWidget {
  final Function(Position) onShooterPositionSelected;
  final Function(Position) onGoalkeeperPositionSelected;
  final Position? selectedShooterPosition;
  final Position? selectedGoalkeeperPosition;

  const FieldSelector({
    super.key,
    required this.onShooterPositionSelected,
    required this.onGoalkeeperPositionSelected,
    this.selectedShooterPosition,
    this.selectedGoalkeeperPosition,
  });

  @override
  State<FieldSelector> createState() => _FieldSelectorState();
}

class _FieldSelectorState extends State<FieldSelector> {
  // Control de qué vista está activa
  bool _showGoalkeeperView = false;

  // Referencias para obtener posiciones exactas
  final GlobalKey _fieldKey = GlobalKey();
  final GlobalKey _goalkeeperKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Selector de vista
        _buildViewSelector(),

        // Contenedor principal
        Expanded(
          child: Stack(
            children: [
              // Vista del tirador (campo completo)
              AnimatedOpacity(
                opacity: _showGoalkeeperView ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: _showGoalkeeperView
                    ? const SizedBox.shrink()
                    : _buildShooterView(),
              ),

              // Vista del portero (área semicircular)
              AnimatedOpacity(
                opacity: _showGoalkeeperView ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: !_showGoalkeeperView
                    ? const SizedBox.shrink()
                    : _buildGoalkeeperView(),
              ),
            ],
          ),
        ),

        // Leyenda
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: _showGoalkeeperView
                      ? Colors.green.withOpacity(0.7)
                      : Colors.blue.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _showGoalkeeperView ? 'Portero' : 'Tirador',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Selector de vista tipo toggle switch
  Widget _buildViewSelector() {
    return Container(
      margin: const EdgeInsets.all(8),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Opción Tirador
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showGoalkeeperView = false;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color:
                      !_showGoalkeeperView ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person,
                      color:
                          !_showGoalkeeperView ? Colors.white : Colors.black54,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Campo',
                      style: TextStyle(
                        color: !_showGoalkeeperView
                            ? Colors.white
                            : Colors.black54,
                        fontWeight: !_showGoalkeeperView
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Opción Portero
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showGoalkeeperView = true;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color:
                      _showGoalkeeperView ? Colors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sports_soccer,
                      color:
                          _showGoalkeeperView ? Colors.white : Colors.black54,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Área',
                      style: TextStyle(
                        color:
                            _showGoalkeeperView ? Colors.white : Colors.black54,
                        fontWeight: _showGoalkeeperView
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Vista del campo completo para el tirador
  Widget _buildShooterView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Relación de aspecto para campo vertical de futsal (ancho/alto)
        const aspectRatio = 0.6;

        // Calcular dimensiones manteniendo relación de aspecto
        double width, height;
        if (constraints.maxWidth / aspectRatio > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * aspectRatio;
        } else {
          width = constraints.maxWidth;
          height = width / aspectRatio;
        }

        return Center(
          child: GestureDetector(
            onTapDown: (details) {
              _handleShooterTap(details.globalPosition);
            },
            child: Container(
              key: _fieldKey,
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Área del portero (zona sombreada)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: height / 7,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.shade800.withOpacity(0.3),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.7),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "Área del portero",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Líneas del campo de fútbol sala
                  CustomPaint(
                    size: Size(width, height),
                    painter: FutsalFieldPainter(),
                  ),

                  // Icono de posición del tirador (draggable)
                  if (widget.selectedShooterPosition != null)
                    Positioned(
                      left: widget.selectedShooterPosition!.x * width - 15,
                      top: widget.selectedShooterPosition!.y * height - 15,
                      child: Draggable<String>(
                        data: 'shooter',
                        feedback: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        childWhenDragging: Container(),
                        onDragEnd: (details) {
                          final RenderBox? fieldBox = _fieldKey.currentContext
                              ?.findRenderObject() as RenderBox?;
                          if (fieldBox == null) return;

                          final localPosition =
                              fieldBox.globalToLocal(details.offset);
                          // Verificar si está dentro del campo
                          if (localPosition.dx >= 0 &&
                              localPosition.dx <= width &&
                              localPosition.dy >= 0 &&
                              localPosition.dy <= height) {
                            // Calcular posición normalizada
                            final normalizedX = localPosition.dx / width;
                            final normalizedY = localPosition.dy / height;

                            // Ajustar a la columna más cercana (3 columnas)
                            final column = (normalizedX * 3).floor();
                            final columnCenterX = (column + 0.5) / 3;

                            // Ajustar a la fila más cercana (8 filas)
                            final row = (normalizedY * 8).floor();
                            final rowCenterY = (row + 0.5) / 8;

                            // Crear posición ajustada al centro de la celda
                            final adjustedPosition =
                                Position(x: columnCenterX, y: rowCenterY);

                            // Notificar la posición seleccionada
                            widget.onShooterPositionSelected(adjustedPosition);
                          }
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.7),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Construye 8 filas horizontales exactas (ahora invisibles)
  List<Widget> _buildEightRows(double width, double height) {
    // Retornamos una lista vacía ya que no queremos mostrar las divisiones
    return [];
  }

  // Vista del área del portero (semicírculo simplificado, sin portería)
  Widget _buildGoalkeeperView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular dimensiones para el semicírculo
        double height = constraints.maxHeight * 0.8;
        double width = height * 2; // Semicírculo con relación 2:1

        if (width > constraints.maxWidth) {
          width = constraints.maxWidth;
          height = width / 2;
        }

        return Center(
          child: GestureDetector(
            onTapDown: (details) {
              _handleGoalkeeperTap(details.globalPosition);
            },
            child: Container(
              key: _goalkeeperKey,
              width: width,
              height: height,
              decoration: BoxDecoration(
                // Fondo degradado verde para representar el área
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.shade800,
                    Colors.green.shade600,
                  ],
                ),
                // Semicírculo para el área
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(width / 2),
                ),
                // Borde blanco
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                // Sombra suave
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Línea frontal (área de 6 metros)
                  Positioned(
                    top: height * 0.3,
                    left: width * 0.2,
                    right: width * 0.2,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Posición central de la portería (referencia visual)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      color: Colors.white.withOpacity(0.7),
                      child: Center(
                        child: Container(
                          height: 8,
                          width: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Icono de posición del portero (draggable)
                  if (widget.selectedGoalkeeperPosition != null)
                    Positioned(
                      left: widget.selectedGoalkeeperPosition!.x * width - 15,
                      top: widget.selectedGoalkeeperPosition!.y * height - 15,
                      child: Draggable<String>(
                        data: 'goalkeeper',
                        feedback: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sports_soccer,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        childWhenDragging: Container(),
                        onDragEnd: (details) {
                          final RenderBox? areaBox =
                              _goalkeeperKey.currentContext?.findRenderObject()
                                  as RenderBox?;
                          if (areaBox == null) return;

                          final localPosition =
                              areaBox.globalToLocal(details.offset);

                          // Verificar si está dentro del área
                          if (localPosition.dx >= 0 &&
                              localPosition.dx <= width &&
                              localPosition.dy >= 0 &&
                              localPosition.dy <= height) {
                            // Verificar si está dentro del semicírculo para la parte inferior
                            if (localPosition.dy > height / 2) {
                              final centerX = width / 2;
                              final bottomY =
                                  height; // Punto central del arco inferior
                              final radius = width / 2; // Radio del semicírculo

                              final deltaX = localPosition.dx - centerX;
                              final deltaY = localPosition.dy - bottomY;
                              final distance =
                                  sqrt(deltaX * deltaX + deltaY * deltaY);

                              // Si está fuera del semicírculo, no hacer nada
                              if (distance > radius) return;
                            }

                            // Calcular posición normalizada
                            final normalizedX = localPosition.dx / width;
                            final normalizedY = localPosition.dy / height;

                            // Ajustar a la columna más cercana (3 columnas)
                            final column = (normalizedX * 3).floor();
                            final columnCenterX = (column + 0.5) / 3;

                            // Ajustar a la fila más cercana (4 filas)
                            final row = (normalizedY * 4).floor();
                            final rowCenterY = (row + 0.5) / 4;

                            // Crear posición ajustada al centro de la celda
                            final adjustedPosition =
                                Position(x: columnCenterX, y: rowCenterY);

                            // Notificar la posición seleccionada
                            widget
                                .onGoalkeeperPositionSelected(adjustedPosition);
                          }
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.7),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.sports_soccer,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Crea líneas de división para el área del portero (ahora invisibles)
  Widget _buildGoalkeeperGridLines(double width, double height) {
    // Retornamos un contenedor vacío ya que no queremos mostrar las divisiones
    return Container();
  }

  // Manejo de toque en el campo para el tirador
  void _handleShooterTap(Offset globalPosition) {
    final RenderBox? fieldBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (fieldBox == null) return;

    final localPosition = fieldBox.globalToLocal(globalPosition);
    final width = fieldBox.size.width;
    final height = fieldBox.size.height;

    // Verificar si está dentro del campo
    if (localPosition.dx >= 0 &&
        localPosition.dx <= width &&
        localPosition.dy >= 0 &&
        localPosition.dy <= height) {
      // Calcular posición normalizada
      final normalizedX = localPosition.dx / width;
      final normalizedY = localPosition.dy / height;

      // Ajustar a la fila más cercana (8 filas exactas)
      final row = (normalizedY * 8).floor();
      final rowCenterY = (row + 0.5) / 8;

      // Ajustar a una de 3 columnas
      final column = (normalizedX * 3).floor();
      final columnCenterX = (column + 0.5) / 3;

      // Crear posición ajustada al centro de la celda
      final position = Position(x: columnCenterX, y: rowCenterY);

      // Notificar la posición seleccionada
      widget.onShooterPositionSelected(position);
    }
  }

  // Manejo de toque en el área para el portero
  void _handleGoalkeeperTap(Offset globalPosition) {
    final RenderBox? areaBox =
        _goalkeeperKey.currentContext?.findRenderObject() as RenderBox?;
    if (areaBox == null) return;

    final localPosition = areaBox.globalToLocal(globalPosition);
    final width = areaBox.size.width;
    final height = areaBox.size.height;

    // Verificar si está dentro del área
    if (localPosition.dx >= 0 &&
        localPosition.dx <= width &&
        localPosition.dy >= 0 &&
        localPosition.dy <= height) {
      // Verificar si está dentro del semicírculo para la parte inferior
      if (localPosition.dy > height / 2) {
        final centerX = width / 2;
        final bottomY = height; // Punto central del arco inferior
        final radius = width / 2; // Radio del semicírculo

        // Calcular distancia al centro del arco
        final deltaX = localPosition.dx - centerX;
        final deltaY = localPosition.dy - bottomY;
        final distance = sqrt(deltaX * deltaX + deltaY * deltaY);

        // Si está fuera del semicírculo, no hacer nada
        if (distance > radius) return;
      }

      // Calcular posición normalizada
      final normalizedX = localPosition.dx / width;
      final normalizedY = localPosition.dy / height;

      // Ajustar a la columna más cercana (3 columnas)
      final column = (normalizedX * 3).floor();
      final columnCenterX = (column + 0.5) / 3;

      // Ajustar a la fila más cercana (4 filas)
      final row = (normalizedY * 4).floor();
      final rowCenterY = (row + 0.5) / 4;

      // Crear posición ajustada al centro de la celda
      final position = Position(x: columnCenterX, y: rowCenterY);

      // Notificar la posición seleccionada
      widget.onGoalkeeperPositionSelected(position);
    }
  }

  // Función auxiliar para calcular raíz cuadrada
  double sqrt(double value) {
    return value < 0
        ? 0
        : value == 0
            ? 0
            : value == 1
                ? 1
                : _newton(value);
  }

  // Método de Newton para calcular raíz cuadrada
  double _newton(double value) {
    double result = value;
    double h;
    do {
      h = 0.5 * (result - value / result);
      result = result - h;
    } while (h.abs() > 1e-6);
    return result;
  }
}

/// Pintor personalizado para dibujar las líneas del campo de fútbol sala
class FutsalFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final width = size.width;
    final height = size.height;

    // Línea central
    canvas.drawLine(
      Offset(0, height / 2),
      Offset(width, height / 2),
      paint,
    );

    // Círculo central
    canvas.drawCircle(
      Offset(width / 2, height / 2),
      width / 3.5,
      paint,
    );

    // Punto central
    canvas.drawCircle(
      Offset(width / 2, height / 2),
      3,
      paint..style = PaintingStyle.fill,
    );

    // Área pequeña superior (portería)
    final smallBoxWidth = width * 0.6;
    final smallBoxHeight = height / 25;
    canvas.drawRect(
      Rect.fromLTWH(
        (width - smallBoxWidth) / 2,
        0,
        smallBoxWidth,
        smallBoxHeight,
      ),
      paint..style = PaintingStyle.stroke,
    );

    // Área pequeña inferior (portería)
    canvas.drawRect(
      Rect.fromLTWH(
        (width - smallBoxWidth) / 2,
        height - smallBoxHeight,
        smallBoxWidth,
        smallBoxHeight,
      ),
      paint,
    );

    // Puntos de penalti
    final penaltyDistanceFromGoal = height / 5;

    // Penalti superior
    canvas.drawCircle(
      Offset(width / 2, penaltyDistanceFromGoal),
      3,
      paint..style = PaintingStyle.fill,
    );

    // Penalti inferior
    canvas.drawCircle(
      Offset(width / 2, height - penaltyDistanceFromGoal),
      3,
      paint..style = PaintingStyle.fill,
    );

    // Esquinas del campo
    final cornerRadius = width / 12;

    // Esquina superior izquierda
    canvas.drawArc(
      Rect.fromLTWH(0, 0, cornerRadius * 2, cornerRadius * 2),
      0,
      3.14 / 2,
      false,
      paint..style = PaintingStyle.stroke,
    );

    // Esquina superior derecha
    canvas.drawArc(
      Rect.fromLTWH(
          width - cornerRadius * 2, 0, cornerRadius * 2, cornerRadius * 2),
      3.14 / 2,
      3.14 / 2,
      false,
      paint,
    );

    // Esquina inferior izquierda
    canvas.drawArc(
      Rect.fromLTWH(
          0, height - cornerRadius * 2, cornerRadius * 2, cornerRadius * 2),
      3.14 * 3 / 2,
      3.14 / 2,
      false,
      paint,
    );

    // Esquina inferior derecha
    canvas.drawArc(
      Rect.fromLTWH(width - cornerRadius * 2, height - cornerRadius * 2,
          cornerRadius * 2, cornerRadius * 2),
      3.14,
      3.14 / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
