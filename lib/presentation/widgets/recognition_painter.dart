import 'package:flutter/material.dart';

class RecognitionPainter extends CustomPainter {
  final List<dynamic> recognitions;
  final Size imageSize;

  RecognitionPainter({required this.recognitions, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.blue;

    for (final dynamic recognition in recognitions) {
      final Rect rect = recognition['rect'];
      final Rect scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );

      canvas.drawRect(scaledRect, paint);

      final TextSpan span = TextSpan(
        text:
            '${recognition['detectedClass']} ${(recognition['confidenceInClass'] * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 14.0,
          fontWeight: FontWeight.bold,
        ),
      );

      final TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(scaledRect.left, scaledRect.top - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
