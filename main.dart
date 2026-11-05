import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ElasticVolumeSlider(),
    );
  }
}

class ElasticVolumeSlider extends StatefulWidget {
  const ElasticVolumeSlider({super.key});

  @override
  State<ElasticVolumeSlider> createState() => _ElasticVolumeSliderState();
}

class _ElasticVolumeSliderState extends State<ElasticVolumeSlider> with SingleTickerProviderStateMixin {
  double _sliderWidth = 28.0; 
  double _sliderHeight = 320.0;
  
  double _volume = 0.5;
  double _dragOffset = 0.0; 
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, lowerBound: -150, upperBound: 150);
    _controller.addListener(() {
      setState(() {
        _dragOffset = _controller.value;
      });
    });
  }

  void _updateVolume(double localY) {
    double newValue = 1.0 - (localY / _sliderHeight);
    setState(() {
      _volume = newValue.clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1c1c1e), // Серый фон смартфона
      body: Stack(
        children: [
          // Прижимаем CustomPaint вплотную к правому краю экрана смартфона
          Positioned(
            right: 0,
            top: MediaQuery.of(context).size.height / 2 - (_sliderHeight / 2),
            child: GestureDetector(
              onTapDown: (details) => _updateVolume(details.localPosition.dy),
              onVerticalDragUpdate: (details) {
                double localY = details.localPosition.dy;
                
                if (localY < 0) {
                  // Вытягиваем верхний край (до 70 пикселей прогиба)
                  setState(() => _dragOffset = -localY.clamp(0, 70).toDouble());
                } else if (localY > _sliderHeight) {
                  // Вытягиваем нижний край
                  setState(() => _dragOffset = (localY - _sliderHeight).clamp(0, 70).toDouble());
                } else {
                  setState(() => _dragOffset = 0.0);
                  _updateVolume(localY);
                }
              },
              onVerticalDragEnd: (_) {
                if (_dragOffset != 0.0) {
                  // Супер-мягкая пружина для эффекта желе
                  final simulation = SpringSimulation(
                    const SpringDescription(mass: 0.4, stiffness: 450, damping: 12),
                    _dragOffset, 0, 0,
                  );
                  _controller.animateWith(simulation);
                }
              },
              child: CustomPaint(
                size: Size(_sliderWidth + 100, _sliderHeight), 
                painter: RealLiquidSliderPainter(
                  volume: _volume,
                  dragOffset: _dragOffset,
                  sliderWidth: _sliderWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class RealLiquidSliderPainter extends CustomPainter {
  final double volume;
  final double dragOffset;
  final double sliderWidth;

  RealLiquidSliderPainter({
    required this.volume,
    required this.dragOffset,
    required this.sliderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintFrame = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final paintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    
    double rightEdge = size.width; // Абсолютный край экрана
    double top = 0;
    double bottom = size.height;
    double leftEdge = rightEdge - sliderWidth;

    if (dragOffset == 0) {
      // Идеально сглаженная базовая плашка, влитая в грань
      path.moveTo(rightEdge, top);
      path.lineTo(leftEdge + 16, top);
      path.quadraticBezierTo(leftEdge, top, leftEdge, top + 16);
      path.lineTo(leftEdge, bottom - 16);
      path.quadraticBezierTo(leftEdge, bottom, leftEdge + 16, bottom);
      path.lineTo(rightEdge, bottom);
      path.close();
    } else {
      double bulge = dragOffset.abs();
      
      if (dragOffset < 0) {
        // --- ПРОГИБ ВВЕРХУ (Тянем вверх) ---
        path.moveTo(rightEdge, top);
        
        // Магия iOS 18: бесшовный S-образный вход из рамки в каплю
        path.cubicTo(
          rightEdge - bulge * 0.1, top + 5,
          leftEdge - bulge * 0.6, top + 15,
          leftEdge - bulge, top + 45,
        );
        // Плавный выход из капли обратно в ровную вертикальную линию
        path.cubicTo(
          leftEdge - bulge * 0.8, top + 85,
          leftEdge, top + 120,
          leftEdge, top + 160,
        );
        
        // Завершаем контур ровно
        path.lineTo(leftEdge, bottom - 16);
        path.quadraticBezierTo(leftEdge, bottom, leftEdge + 16, bottom);
        path.lineTo(rightEdge, bottom);
      } else {
        // --- ПРОГИБ ВНИЗУ (Тянем вниз) ---
        path.moveTo(rightEdge, top);
        path.lineTo(leftEdge + 16, top);
        path.quadraticBezierTo(leftEdge, top, leftEdge, top + 16);
        path.lineTo(leftEdge, bottom - 160);
        
        // Плавный разгон жидкой капли к нижней части экрана
        path.cubicTo(
          leftEdge, bottom - 120,
          leftEdge - bulge * 0.8, bottom - 85,
          leftEdge - bulge, bottom - 45,
        );
        // Бесшовное затекание капли обратно в правый пиксель матрицы
        path.cubicTo(
          leftEdge - bulge * 0.6, bottom - 15,
          rightEdge - bulge * 0.1, bottom - 5,
          rightEdge, bottom,
        );
      }
      path.close();
    }

    // Отрисовка черной структуры
    canvas.drawPath(path, paintFrame);

    // Отрисовка белого индикатора с обрезкой по форме жидкой маски
    canvas.save();
    canvas.clipPath(path);
    
    double fillHeight = size.height * volume;
    // Слайдер внутри капли
    canvas.drawRect(
      Rect.fromLTWH(leftEdge + 2, size.height - fillHeight, sliderWidth - 2, fillHeight),
      paintWhite,
    );
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RealLiquidSliderPainter oldDelegate) {
    return oldDelegate.volume != volume || oldDelegate.dragOffset != dragOffset;
  }
}
