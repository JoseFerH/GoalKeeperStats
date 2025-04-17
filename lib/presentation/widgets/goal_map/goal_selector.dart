import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/position.dart';

/// Widget que muestra una portería interactiva para seleccionar posiciones
/// Divide la portería en 12 zonas (3x4) invisibles para selección simplificada
/// Versión optimizada con soporte para arrastre y mayor altura
class GoalSelector extends StatefulWidget {
  final Function(Position) onPositionSelected;
  final Position? selectedPosition;
  final ImageProvider? backgroundImage; // Para futuras mejoras
  final bool showMiniMap; // Controla la visibilidad del mini-mapa

  const GoalSelector({
    super.key,
    required this.onPositionSelected,
    this.selectedPosition,
    this.backgroundImage,
    this.showMiniMap = false, // Por defecto, oculto para ahorrar espacio
  });

  @override
  State<GoalSelector> createState() => _GoalSelectorState();
}

class _GoalSelectorState extends State<GoalSelector> {
  // Relación de aspecto de una portería reglamentaria modificada para aún más altura
  // Original: 7.32 / 2.44 = 3.0
  // Aumentada más para mejor experiencia táctil
  final double _aspectRatio = 7.32 / 3.5; // Aumentada a 3.5 para más altura

  // Altura proporcional de la zona baja (tiros rasos)
  final double _bottomZoneHeightRatio = 0.125;

  // Zona seleccionada actual (null si no hay selección)
  int? _selectedZoneIndex;

  // Para saber si estamos arrastrando
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Si hay una posición seleccionada previamente, determinar zona
    if (widget.selectedPosition != null) {
      _selectedZoneIndex = _getZoneFromPosition(
          widget.selectedPosition!.x, widget.selectedPosition!.y);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular dimensiones manteniendo relación de aspecto
        // Usar hasta el 90% de la altura disponible para la portería (incrementado desde 80%)
        double width, height;
        if (constraints.maxWidth / _aspectRatio > constraints.maxHeight * 0.9) {
          height = constraints.maxHeight * 0.9;
          width = height * _aspectRatio;
        } else {
          width = constraints.maxWidth;
          height = width / _aspectRatio;
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Minimizar espacio vertical
          children: [
            // Contenedor fijo para la etiqueta de zona (para evitar saltos)
            SizedBox(
              height: 30, // Altura fija para la etiqueta (muestra o no muestra)
              child: _selectedZoneIndex != null
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Text(
                          'Zona: ${_getZoneDescription(_selectedZoneIndex!)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox
                      .shrink(), // Widget vacío cuando no hay selección
            ),

            // Escena completa (fondo + portería)
            SizedBox(
              height: height + 10, // Ajustar para evitar recortes
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Fondo de la escena (un rectángulo más grande que la portería)
                  Container(
                    width: width * 1.2,
                    height: height * 1.4,
                    decoration: BoxDecoration(
                      // Gradiente de cielo azul
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.blue.shade300,
                          Colors.blue.shade600,
                        ],
                      ),
                      // Espacio para futuras imágenes
                      image: widget.backgroundImage != null
                          ? DecorationImage(
                              image: widget.backgroundImage!,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    // Césped en la parte inferior
                    foregroundDecoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.green.shade800,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Portería con gestos de toque y arrastre
                  GestureDetector(
                    // Detectar toque
                    onTapDown: (details) =>
                        _handleInteraction(details.globalPosition, context),

                    // Detectar inicio de arrastre
                    onPanStart: (details) {
                      setState(() {
                        _isDragging = true;
                      });
                      _handleInteraction(details.globalPosition, context);
                    },

                    // Detectar movimiento de arrastre
                    onPanUpdate: (details) {
                      if (_isDragging) {
                        _handleInteraction(details.globalPosition, context);
                      }
                    },

                    // Detectar fin de arrastre
                    onPanEnd: (details) {
                      setState(() {
                        _isDragging = false;
                      });
                    },

                    child: Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        // Interior de la portería (transparente)
                        color: Colors.transparent,
                        // Sombra para dar profundidad
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Área blanca dentro de la portería
                          Positioned.fill(
                            child: Container(
                              color: Colors.white.withOpacity(0.9),
                              margin: const EdgeInsets.all(2),
                            ),
                          ),

                          // Red/malla
                          Positioned.fill(
                            child: CustomPaint(
                              painter: GoalNetPainter(),
                            ),
                          ),

                          // Cuadrícula de zonas (invisible pero facilita la visualización durante desarrollo)
                          // Esta parte se puede comentar en producción
                          Positioned.fill(
                            child: _buildZoneGrid(width, height),
                          ),

                          // Marco de la portería (postes y travesaño)
                          // Post izquierdo
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.white,
                                    Colors.grey.shade400,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Post derecho
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [
                                    Colors.white,
                                    Colors.grey.shade400,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Travesaño
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white,
                                    Colors.grey.shade400,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Indicador de zona seleccionada
                  if (_selectedZoneIndex != null)
                    Positioned(
                      width: width,
                      height: height,
                      child: _buildSelectedBall(
                          width, height, _selectedZoneIndex!),
                    ),
                ],
              ),
            ),

            // Mini-mapa de zonas (opcional)
            if (widget.showMiniMap)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  width: width * 0.7,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        width: double.infinity,
                        color: Colors.blue.shade100,
                        child: const Text(
                          'ZONAS DE LA PORTERÍA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildZoneMap(),
                      ),
                    ],
                  ),
                ),
              ),

            // Texto de ayuda/instrucción (sólo visible si no hay Mini-mapa y no hay selección)
            if (!widget.showMiniMap && _selectedZoneIndex == null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Toca o arrastra en la portería para seleccionar zona',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Función para manejar tanto el toque como el arrastre
  void _handleInteraction(Offset globalPosition, BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(globalPosition);

    // Calcular las dimensiones de la portería
    final constraints = box.constraints;
    double width, height;
    if (constraints.maxWidth / _aspectRatio > constraints.maxHeight * 0.9) {
      height = constraints.maxHeight * 0.9;
      width = height * _aspectRatio;
    } else {
      width = constraints.maxWidth;
      height = width / _aspectRatio;
    }

    // Calcular coordenadas relativas al centro de la portería
    final centerX = box.size.width / 2;
    final centerY =
        (box.size.height / 2) + 15; // +15 para compensar la etiqueta

    final offsetX = localPosition.dx - (centerX - width / 2);
    final offsetY = localPosition.dy - (centerY - height / 2);

    final normalizedX = offsetX / width;
    final normalizedY = offsetY / height;

    // Verificar si está dentro de la portería
    if (normalizedX >= 0 &&
        normalizedX <= 1 &&
        normalizedY >= 0 &&
        normalizedY <= 1) {
      // Obtener índice de zona
      int zoneIndex = _getZoneFromPosition(normalizedX, normalizedY);

      // Si no ha cambiado, no hacer nada (para evitar reconstrucciones innecesarias)
      if (zoneIndex == _selectedZoneIndex && !_isDragging) {
        return;
      }

      // Obtener coordenadas del centro de esa zona
      final zoneCenter = _getZoneCenterCoordinates(zoneIndex);

      setState(() {
        _selectedZoneIndex = zoneIndex;
      });

      // Notificar con posición del centro de la zona
      widget.onPositionSelected(Position(x: zoneCenter.dx, y: zoneCenter.dy));
    }
  }

  // Construye una cuadrícula visual para las zonas (opcional, para desarrollo)
  Widget _buildZoneGrid(double width, height) {
    final bottomHeight = height * _bottomZoneHeightRatio;
    final regularHeight = (height - bottomHeight) / 3;
    final columnWidth = width / 3;

    return Stack(
      children: [
        // Líneas verticales
        Positioned(
          left: columnWidth,
          top: 0,
          bottom: 0,
          child: Container(
            width: 0.5,
            color: Colors.grey.withOpacity(0.3),
          ),
        ),
        Positioned(
          left: columnWidth * 2,
          top: 0,
          bottom: 0,
          child: Container(
            width: 0.5,
            color: Colors.grey.withOpacity(0.3),
          ),
        ),

        // Líneas horizontales
        Positioned(
          top: regularHeight,
          left: 0,
          right: 0,
          child: Container(
            height: 0.5,
            color: Colors.grey.withOpacity(0.3),
          ),
        ),
        Positioned(
          top: regularHeight * 2,
          left: 0,
          right: 0,
          child: Container(
            height: 0.5,
            color: Colors.grey.withOpacity(0.3),
          ),
        ),
        Positioned(
          top: height - bottomHeight,
          left: 0,
          right: 0,
          child: Container(
            height: 0.5,
            color: Colors.grey.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedBall(double width, double height, int zoneIndex) {
    // Obtener coordenadas del centro de la zona
    final center = _getZoneCenterCoordinates(zoneIndex);

    // Convertir coordenadas normalizadas a píxeles
    final centerX = center.dx * width;
    final centerY = center.dy * height;

    return Stack(
      children: [
        // Sombra
        Positioned(
          left: centerX - 13,
          top: centerY - 11,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
        ),
        // Balón - intenta cargar la imagen si está disponible
        Positioned(
          left: centerX - 15,
          top: centerY - 15,
          child: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage('assets/images/soccer_ball.png'),
                fit: BoxFit.cover,
              ),
            ),
            // Fallback si la imagen no se puede cargar
            child: const Icon(
              Icons.sports_soccer,
              color: Colors.black,
              size: 26,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZoneMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Altura de la zona de tiros rasos
        final bottomHeight = height * _bottomZoneHeightRatio;
        final regularHeight = (height - bottomHeight) / 3;

        return Stack(
          children: [
            // Líneas verticales
            Positioned(
              left: width / 3,
              top: 0,
              bottom: 0,
              child: Container(
                width: 0.5,
                color: Colors.grey.shade400,
              ),
            ),
            Positioned(
              left: width * 2 / 3,
              top: 0,
              bottom: 0,
              child: Container(
                width: 0.5,
                color: Colors.grey.shade400,
              ),
            ),

            // Líneas horizontales
            Positioned(
              top: regularHeight,
              left: 0,
              right: 0,
              child: Container(
                height: 0.5,
                color: Colors.grey.shade400,
              ),
            ),
            Positioned(
              top: regularHeight * 2,
              left: 0,
              right: 0,
              child: Container(
                height: 0.5,
                color: Colors.grey.shade400,
              ),
            ),
            Positioned(
              top: height - bottomHeight,
              left: 0,
              right: 0,
              child: Container(
                height: 0.5,
                color: Colors.grey.shade400,
              ),
            ),

            // Sombreado para tiros rasos
            Positioned(
              top: height - bottomHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: Text(
                  'RASOS',
                  style: TextStyle(
                    fontSize: 7,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),

            // Indicador de zona seleccionada
            if (_selectedZoneIndex != null)
              _buildZoneHighlight(width, height, _selectedZoneIndex!),
          ],
        );
      },
    );
  }

  Widget _buildZoneHighlight(double width, double height, int zoneIndex) {
    // Calcular dimensiones de cada zona
    final columnWidth = width / 3;
    final bottomHeight = height * _bottomZoneHeightRatio;
    final regularHeight = (height - bottomHeight) / 3;

    // Determinar columna (0, 1, 2)
    final column = zoneIndex % 3;
    // Determinar fila (0, 1, 2, 3)
    final row = zoneIndex ~/ 3;

    // Calcular posición
    final left = column * columnWidth;
    double top;
    double zoneHeight;

    if (row < 3) {
      // Zonas regulares
      top = row * regularHeight;
      zoneHeight = regularHeight;
    } else {
      // Zona de tiros rasos
      top = height - bottomHeight;
      zoneHeight = bottomHeight;
    }

    return Positioned(
      left: left,
      top: top,
      width: columnWidth,
      height: zoneHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.3),
          border: Border.all(
            color: Colors.red.withOpacity(0.6),
            width: 1,
          ),
        ),
      ),
    );
  }

  /// Obtiene el índice de zona (0-11) basado en coordenadas normalizadas
  int _getZoneFromPosition(double x, double y) {
    // Determinar columna (0-2)
    int column;
    if (x < 1 / 3) {
      column = 0; // Izquierda
    } else if (x < 2 / 3) {
      column = 1; // Centro
    } else {
      column = 2; // Derecha
    }

    // Determinar fila (0-3)
    int row;
    if (y < (1 - _bottomZoneHeightRatio) / 3) {
      row = 0; // Superior
    } else if (y < 2 * (1 - _bottomZoneHeightRatio) / 3) {
      row = 1; // Media-alta
    } else if (y < (1 - _bottomZoneHeightRatio)) {
      row = 2; // Media-baja
    } else {
      row = 3; // Rasa
    }

    // Calcular índice: fila * 3 + columna
    return row * 3 + column;
  }

  /// Obtiene las coordenadas del centro de una zona específica
  Offset _getZoneCenterCoordinates(int zoneIndex) {
    // Determinar fila y columna
    final row = zoneIndex ~/ 3;
    final column = zoneIndex % 3;

    // Calcular el centro X
    final centerX = (column * (1 / 3)) + (1 / 6);

    // Calcular el centro Y
    double centerY;
    if (row < 3) {
      // Para las primeras 3 filas
      final regularHeight = (1 - _bottomZoneHeightRatio) / 3;
      centerY = (row * regularHeight) + (regularHeight / 2);
    } else {
      // Para la fila de tiros rasos
      centerY = (1 - _bottomZoneHeightRatio) + (_bottomZoneHeightRatio / 2);
    }

    return Offset(centerX, centerY);
  }

  /// Devuelve descripción textual de una zona por su índice
  String _getZoneDescription(int zoneIndex) {
    final row = zoneIndex ~/ 3;
    final column = zoneIndex % 3;

    String vertical;
    switch (row) {
      case 0:
        vertical = 'Alta';
        break;
      case 1:
        vertical = 'Media-Alta';
        break;
      case 2:
        vertical = 'Media-Baja';
        break;
      case 3:
        vertical = 'Rasa';
        break;
      default:
        vertical = '?';
    }

    String horizontal;
    switch (column) {
      case 0:
        horizontal = 'Izquierda';
        break;
      case 1:
        horizontal = 'Centro';
        break;
      case 2:
        horizontal = 'Derecha';
        break;
      default:
        horizontal = '?';
    }

    return '$vertical $horizontal';
  }
}

/// Pintor personalizado para dibujar la red de la portería
class GoalNetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    final verticalLines = 16; // Número de líneas verticales
    final horizontalLines = 8; // Número de líneas horizontales

    // Dibujar líneas verticales
    final verticalSpacing = size.width / verticalLines;
    for (int i = 1; i < verticalLines; i++) {
      canvas.drawLine(
        Offset(i * verticalSpacing, 0),
        Offset(i * verticalSpacing, size.height),
        paint,
      );
    }

    // Dibujar líneas horizontales
    final horizontalSpacing = size.height / horizontalLines;
    for (int i = 1; i < horizontalLines; i++) {
      canvas.drawLine(
        Offset(0, i * horizontalSpacing),
        Offset(size.width, i * horizontalSpacing),
        paint,
      );
    }

    // Dibujar líneas diagonales para dar efecto de perspectiva a la red
    paint.strokeWidth = 0.4;
    for (int i = 1; i < verticalLines; i += 2) {
      for (int j = 1; j < horizontalLines; j += 2) {
        canvas.drawLine(
          Offset(i * verticalSpacing, j * horizontalSpacing),
          Offset((i - 0.5) * verticalSpacing, (j - 0.5) * horizontalSpacing),
          paint,
        );
        canvas.drawLine(
          Offset(i * verticalSpacing, j * horizontalSpacing),
          Offset((i + 0.5) * verticalSpacing, (j - 0.5) * horizontalSpacing),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
