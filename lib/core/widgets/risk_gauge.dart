import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RiskGauge extends StatelessWidget {
  final double score; // 0.0 - 1.0
  final String label; // NEW: Driven dynamically by the AI backend
  final double size;

  const RiskGauge({
    super.key,
    required this.score,
    required this.label,
    this.size = 240,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedScore, _) {
        final animatedColor = AppColors.riskColor(animatedScore);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: animatedColor.withValues(alpha: 0.35),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CustomPaint(
            painter:
                _GaugePainter(progress: animatedScore, color: animatedColor),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(animatedScore * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: animatedColor,
                      fontSize: size * 0.2,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "AI GENERATED",
                    style: TextStyle(
                      color: animatedColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
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
}

class _GaugePainter extends CustomPainter {
  final double progress; // 0.0 - 1.0
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    const startAngle = -pi / 2 - (pi * 0.75); // gauge starts at ~135deg mark
    const sweepTotal = pi * 1.5; // 270 degree gauge

    // Background track
    final trackPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: 0.0,
        endAngle: pi * 2,
        colors: [
          AppColors.safeGreen, // 0.0 - Start
          AppColors.cautionAmber, // 0.375 - Middle
          AppColors.dangerRed, // 0.75 - End of visible 270deg arc
          AppColors.dangerRed, // 0.85 - Buffer so the end cap stays red
          AppColors.safeGreen, // 0.8501 - Hard transition back to green
          AppColors
              .safeGreen, // 1.0 - Wraps to 0.0, making the start cap green!
        ],
        stops: [0.0, 0.375, 0.75, 0.85, 0.8501, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (progress > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress,
        false,
        progressPaint,
      );
    }

    // Leading dot
    final dotAngle = startAngle + sweepTotal * progress;
    final dotOffset = Offset(
      center.dx + radius * cos(dotAngle),
      center.dy + radius * sin(dotAngle),
    );

    final dotPaint = Paint()..color = color;
    canvas.drawCircle(dotOffset, 8, dotPaint);
    canvas.drawCircle(
      dotOffset,
      8,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
