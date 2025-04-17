import 'package:flutter/material.dart';
import 'package:goalkeeper_stats/data/models/position.dart';

/// Widget que muestra un campo de fútbol interactivo para seleccionar posiciones de saques
///
/// Permite al usuario seleccionar la posición final del saque en el campo mediante
/// toques o arrastre, y determina automáticamente la distancia basada en la posición.
class PassFieldSelector extends StatefulWidget {
  final Function(Position, String) onEndPositionSelected;
  final Position? selectedEndPosition;

  const PassFieldSelector({
    super.key,
    required this.onEndPositionSelected,
    this.selectedEndPosition,
  });

  @override
  State<PassFieldSelector> createState() => _PassFieldSelectorState();
}

class _PassFieldSelectorState extends State<PassFieldSelector> {
  // Relación de aspecto de un campo de fútbol (largo/ancho)
  // Usando 0.7 para aprovechar mejor el espacio vertical
  final double _aspectRatio = 0.7;
  
  // Key para obtener el tamaño y posición del campo
  final GlobalKey _fieldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular dimensiones manteniendo relación de aspecto
        double width, height;
        if (constraints.maxWidth / _aspectRatio > constraints.maxHeight) {
          // Limitado por altura
          height = constraints.maxHeight;
          width = height * _aspectRatio;
        } else {
          // Limitado por anchura
          width = constraints.maxWidth;
          height = width / _aspectRatio;
        }

        return Center(
          child: GestureDetector(
            onTapDown: (details) {
              _handleTap(details.globalPosition);
            },
            child: Container(
              key: _fieldKey,
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
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
                  // Líneas del campo
                  _buildFieldLines(width, height),

                  // Zonas de distancia
                  _buildDistanceZones(width, height),

                  // Marcador de posición seleccionada con función de arrastre
                  if (widget.selectedEndPosition != null)
                    Positioned(
                      left: widget.selectedEndPosition!.x * width - 15,
                      top: widget.selectedEndPosition!.y * height - 15,
                      child: Draggable<String>(
                        data: 'pass',
                        feedback: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sports_handball,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        childWhenDragging: Container(),
                        onDragEnd: (details) {
                          _handleDragEnd(details.offset);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.7),
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
                            Icons.sports_handball,
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

  Widget _buildFieldLines(double width, double height) {
    return CustomPaint(
      size: Size(width, height),
      painter: FieldPainter(),
    );
  }

  Widget _buildDistanceZones(double width, double height) {
    return Stack(
      children: [
        // Zona "corto" (hasta 10 metros)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: height * 0.2,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Corto',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Zona "15m" (10-20 metros)
        Positioned(
          bottom: height * 0.2,
          left: 0,
          right: 0,
          height: height * 0.2,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '15m',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Zona "20m" (20-30 metros)
        Positioned(
          bottom: height * 0.4,
          left: 0,
          right: 0,
          height: height * 0.2,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '20m',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Zona "25m" (30-40 metros)
        Positioned(
          bottom: height * 0.6,
          left: 0,
          right: 0,
          height: height * 0.2,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '25m',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Zona ">25m" (más de 40 metros)
        Positioned(
          bottom: height * 0.8,
          left: 0,
          right: 0,
          height: height * 0.2,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '>25m',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Manejador para toques en el campo
  void _handleTap(Offset globalPosition) {
    final RenderBox? fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
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

      // Ajustar a la columna más cercana (3 columnas)
      final column = (normalizedX * 3).floor();
      final columnCenterX = (column + 0.5) / 3;

      // Ajustar a la fila más cercana (5 filas para las 5 zonas de distancia)
      final row = (normalizedY * 5).floor();
      final rowCenterY = (row + 0.5) / 5;

      // Crear posición ajustada al centro de la celda
      final position = Position(x: columnCenterX, y: rowCenterY);

      // Calcular la distancia según la fila
      final distance = _calculateDistance(rowCenterY);

      // Notificar la posición y distancia seleccionadas
      widget.onEndPositionSelected(position, distance);
    }
  }

  // Manejador para final de arrastre
  void _handleDragEnd(Offset globalPosition) {
    final RenderBox? fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
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

      // Ajustar a la columna más cercana (3 columnas)
      final column = (normalizedX * 3).floor();
      final columnCenterX = (column + 0.5) / 3;

      // Ajustar a la fila más cercana (5 filas para las 5 zonas de distancia)
      final row = (normalizedY * 5).floor();
      final rowCenterY = (row + 0.5) / 5;

      // Crear posición ajustada al centro de la celda
      final position = Position(x: columnCenterX, y: rowCenterY);

      // Calcular la distancia según la fila
      final distance = _calculateDistance(rowCenterY);

      // Notificar la posición y distancia seleccionadas
      widget.onEndPositionSelected(position, distance);
    }
  }

  String _calculateDistance(double normalizedY) {
    // Invertir Y porque 0 está arriba en el canvas pero representa el fondo del campo
    final invertedY = 1 - normalizedY;

    if (invertedY < 0.2) {
      return 'corto';
    } else if (invertedY < 0.4) {
      return '15m';
    } else if (invertedY < 0.6) {
      return '20m';
    } else if (invertedY < 0.8) {
      return '25m';
    } else {
      return '>25m';
    }
  }
}

/// Pintor personalizado para dibujar las líneas del campo
class FieldPainter extends CustomPainter {
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
      height / 10,
      paint,
    );

    // Punto central
    canvas.drawCircle(
      Offset(width / 2, height / 2),
      3,
      paint..style = PaintingStyle.fill,
    );
    paint.style = PaintingStyle.stroke;

    // Área pequeña superior
    final smallBoxWidth = width / 5;
    final smallBoxHeight = height / 12;
    canvas.drawRect(
      Rect.fromLTWH(
        (width - smallBoxWidth) / 2,
        0,
        smallBoxWidth,
        smallBoxHeight,
      ),
      paint,
    );

    // Área grande superior
    final largeBoxWidth = width / 3;
    final largeBoxHeight = height / 6;
    canvas.drawRect(
      Rect.fromLTWH(
        (width - largeBoxWidth) / 2,
        0,
        largeBoxWidth,
        largeBoxHeight,
      ),
      paint,
    );

    // Área pequeña inferior
    canvas.drawRect(
      Rect.fromLTWH(
        (width - smallBoxWidth) / 2,
        height - smallBoxHeight,
        smallBoxWidth,
        smallBoxHeight,
      ),
      paint,
    );

    // Área grande inferior
    canvas.drawRect(
      Rect.fromLTWH(
        (width - largeBoxWidth) / 2,
        height - largeBoxHeight,
        largeBoxWidth,
        largeBoxHeight,
      ),
      paint,
    );

    // Semicírculo área superior
    final arcRect = Rect.fromLTWH(
      (width - largeBoxWidth) / 2 - largeBoxHeight / 3,
      0,
      largeBoxWidth + (largeBoxHeight / 3) * 2,
      largeBoxHeight * 2,
    );
    canvas.drawArc(
      arcRect,
      0,
      3.14,
      false,
      paint,
    );

    // Semicírculo área inferior
    final arcRect2 = Rect.fromLTWH(
      (width - largeBoxWidth) / 2 - largeBoxHeight / 3,
      height - largeBoxHeight * 2,
      largeBoxWidth + (largeBoxHeight / 3) * 2,
      largeBoxHeight * 2,
    );
    canvas.drawArc(
      arcRect2,
      3.14,
      3.14,
      false,
      paint,
    );

    // Punto penal superior
    canvas.drawCircle(
      Offset(width / 2, largeBoxHeight - (largeBoxHeight / 4)),
      3,
      paint..style = PaintingStyle.fill,
    );

    // Punto penal inferior
    canvas.drawCircle(
      Offset(width / 2, height - largeBoxHeight + (largeBoxHeight / 4)),
      3,
      paint..style = PaintingStyle.fill,
    );
    
    // Líneas verticales para dividir en 3 columnas (sutiles)
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.3);
      
    final columnWidth = width / 3;
    
    // Primera línea vertical (1/3)
    canvas.drawLine(
      Offset(columnWidth, 0),
      Offset(columnWidth, height),
      paint,
    );
    
    // Segunda línea vertical (2/3)
    canvas.drawLine(
      Offset(columnWidth * 2, 0),
      Offset(columnWidth * 2, height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}