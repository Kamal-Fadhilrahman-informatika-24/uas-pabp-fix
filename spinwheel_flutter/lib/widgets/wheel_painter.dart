// ============================================================
// widgets/wheel_painter.dart
// FIX: shouldRepaint yang benar + outer ring polish
// Sudut datang dari spin_screen via _spinAngle (setState tiap frame)
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class WheelPainter extends CustomPainter {
  final List<String> options;
  final double angle;
  final int? highlightIndex;

  const WheelPainter({
    required this.options,
    required this.angle,
    this.highlightIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = cx - 12;

    if (options.isEmpty) {
      _drawEmpty(canvas, cx, cy, radius);
      return;
    }

    final arc = (math.pi * 2) / options.length;

    // ── Outer ring (dekorasi) ─────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      radius + 6,
      Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // ── Segmen-segmen roda ────────────────────────────────────
    for (int i = 0; i < options.length; i++) {
      final startAngle = arc * i + angle;
      final color = AppTheme.wheelColors[i % AppTheme.wheelColors.length];
      final isHighlighted = i == highlightIndex;
      final segRadius = isHighlighted ? radius + 4 : radius;

      final paint = Paint()
        ..color = isHighlighted ? _lighten(color, 0.25) : color
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(cx, cy)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: segRadius),
          startAngle,
          arc,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);

      // Garis pemisah
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // ── Label teks ──────────────────────────────────────────
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(startAngle + arc / 2);

      final label = options[i].length > 13
          ? '${options[i].substring(0, 11)}…'
          : options[i];

      final fontSize = options.length > 8 ? 10.0 : 12.5;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(blurRadius: 4, color: Colors.black87),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius - 28);

      tp.paint(canvas,
          Offset(radius - tp.width - 14, -tp.height / 2));
      canvas.restore();
    }

    // ── Lingkaran tengah ─────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      24,
      Paint()
        ..color = const Color(0xFF0F0F1A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      22,
      Paint()..color = const Color(0xFF1A1A2E),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      22,
      Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Emoji tengah
    final emojiPainter = TextPainter(
      text: const TextSpan(
        text: '🎯',
        style: TextStyle(fontSize: 15),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emojiPainter.paint(
      canvas,
      Offset(cx - emojiPainter.width / 2, cy - emojiPainter.height / 2),
    );
  }

  void _drawEmpty(Canvas canvas, double cx, double cy, double radius) {
    // Background circle
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()..color = const Color(0xFF1E1E2E),
    );
    // Border
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = const Color(0xFF333366)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Teks
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Tambahkan pilihan\nuntuk memulai!',
        style: TextStyle(
          color: Color(0xFF666688),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius * 1.5);
    tp.paint(canvas,
        Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  // FIX: shouldRepaint harus true kapanpun angle berubah
  @override
  bool shouldRepaint(WheelPainter old) =>
      old.angle != angle ||
      old.options.length != options.length ||
      old.highlightIndex != highlightIndex ||
      old.options != options;
}

// ── Pointer segitiga di sisi kanan roda ──────────────────────
class WheelPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Shadow pointer
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path()
      ..moveTo(4, size.height / 2)
      ..lineTo(size.width, size.height / 2 - 9)
      ..lineTo(size.width, size.height / 2 + 9)
      ..close();

    canvas.drawPath(path, shadowPaint);

    // Pointer putih
    canvas.drawPath(path, Paint()..color = Colors.white);

    // Outline biru
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF4D96FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
