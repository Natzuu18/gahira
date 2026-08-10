import 'package:flutter/material.dart';

import 'appColor.dart';

/// A small line-art icon of a man mid-swing with a pickaxe, striking down
/// toward a sparkling gold nugget. Drawn with [CustomPainter] so it scales
/// cleanly at any size without needing an SVG asset or extra package.
///
/// Usage:
///
/// const MinerIcon(size: 40)
/// MinerIcon(size: 28, color: kGold, opacity: 0.6)
class MinerIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const MinerIcon({
    super.key,
    this.size = 32,
    this.color = kGold,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MinerPainter(color: color, opacity: opacity),
      ),
    );
  }
}

class _MinerPainter extends CustomPainter {
  final Color color;
  final double opacity;

  _MinerPainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeColor = color.withOpacity(opacity);

    Offset p(double fx, double fy) => Offset(fx * w, fy * h);

    final figurePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    final sparklePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;

    // --- Head ---
    canvas.drawCircle(p(0.58, 0.16), w * 0.09, figurePaint);

    // --- Torso, leaning forward into the swing ---
    canvas.drawLine(p(0.56, 0.25), p(0.46, 0.55), figurePaint);

    // --- Legs, bent in a mining stance ---
    final leftLeg = Path()
      ..moveTo(p(0.46, 0.55).dx, p(0.46, 0.55).dy)
      ..lineTo(p(0.36, 0.74).dx, p(0.36, 0.74).dy)
      ..lineTo(p(0.30, 0.93).dx, p(0.30, 0.93).dy);
    canvas.drawPath(leftLeg, figurePaint);

    final rightLeg = Path()
      ..moveTo(p(0.46, 0.55).dx, p(0.46, 0.55).dy)
      ..lineTo(p(0.55, 0.76).dx, p(0.55, 0.76).dy)
      ..lineTo(p(0.63, 0.93).dx, p(0.63, 0.93).dy);
    canvas.drawPath(rightLeg, figurePaint);

    // --- Back arm, braced near the torso ---
    canvas.drawLine(p(0.53, 0.32), p(0.44, 0.46), figurePaint);

    // --- Front arm + pickaxe handle, swinging down toward the ground ---
    final handleTop = p(0.58, 0.05); // top of handle, above/behind the head
    final grip = p(0.18, 0.62); // hands gripping the handle, low and forward
    canvas.drawLine(handleTop, grip, figurePaint);
    canvas.drawLine(p(0.53, 0.30), grip, figurePaint);

    // --- Pickaxe head: small curved blade at the working end ---
    final pickHead = Path()
      ..moveTo(p(0.09, 0.58).dx, p(0.09, 0.58).dy)
      ..quadraticBezierTo(
        p(0.18, 0.63).dx,
        p(0.18, 0.63).dy,
        p(0.27, 0.56).dx,
        p(0.27, 0.56).dy,
      );
    canvas.drawPath(pickHead, figurePaint);

    // --- Gold nugget on the ground, mid-strike ---
    canvas.drawCircle(p(0.13, 0.90), w * 0.06, fillPaint);

    // --- Sparkle above the nugget ---
    final sparkleLen = w * 0.06;
    final sparkleCenter = p(0.13, 0.78);
    canvas.drawLine(
      sparkleCenter.translate(-sparkleLen / 2, 0),
      sparkleCenter.translate(sparkleLen / 2, 0),
      sparklePaint,
    );
    canvas.drawLine(
      sparkleCenter.translate(0, -sparkleLen / 2),
      sparkleCenter.translate(0, sparkleLen / 2),
      sparklePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MinerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.opacity != opacity;
  }
}