import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/providers/location_provider.dart';
import 'package:cityquest/providers/quest_provider.dart';
import 'package:cityquest/features/map/quest_pin_widget.dart';

class MockMapWidget extends StatelessWidget {
  const MockMapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationProvider, QuestProvider>(
      builder: (context, locProvider, questProvider, _) {
        return Stack(
          children: [
            // ── Map Background ──
            CustomPaint(
              size: Size.infinite,
              painter: _MapGridPainter(),
            ),

            // ── Subtle map overlay ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      Colors.transparent,
                      AppTheme.deepNavy.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),

            // ── Quest Pins ──
            ...questProvider.quests.map((quest) {
              final offset = _questOffset(
                quest.latitude,
                quest.longitude,
                locProvider.latitude,
                locProvider.longitude,
                context,
              );
              return Positioned(
                left: offset.dx - 28,
                top: offset.dy - 56,
                child: QuestPinWidget(quest: quest),
              );
            }),

            // ── User Dot (centered) ──
            Center(child: _buildUserDot()),

            // ── Location Info ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: _buildLocationBar(context, locProvider),
            ),
          ],
        );
      },
    );
  }

  /// Calculate screen offset for a quest pin relative to the user.
  Offset _questOffset(
    double questLat,
    double questLng,
    double userLat,
    double userLng,
    BuildContext context,
  ) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Scale: 1 degree ≈ 111km, so 0.001 ≈ 111m
    // We scale generously so mock pins spread nicely on screen.
    const scale = 500000.0;

    final dx = (questLng - userLng) * scale;
    final dy = -(questLat - userLat) * scale; // invert Y for screen coords

    return Offset(
      (cx + dx).clamp(40, size.width - 40),
      (cy + dy).clamp(120, size.height - 160),
    );
  }

  Widget _buildUserDot() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.15),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.5, 1.5),
              duration: 1500.ms,
            )
            .fadeOut(begin: 1, duration: 1500.ms),
        // Inner dot
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade400,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationBar(BuildContext context, LocationProvider locProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.accentGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            locProvider.isTracking
                ? Icons.gps_fixed_rounded
                : Icons.gps_off_rounded,
            color: locProvider.isTracking
                ? AppTheme.successGreen
                : AppTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              locProvider.isTracking
                  ? '${locProvider.latitude.toStringAsFixed(4)}, ${locProvider.longitude.toStringAsFixed(4)}'
                  : 'GPS not available — using mock location',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'LIVE',
              style: TextStyle(
                color: AppTheme.accentGold,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for a subtle map grid background.
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppTheme.deepNavy;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = AppTheme.primaryBlue.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    const spacing = 40.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Subtle "road" lines for visual interest
    final roadPaint = Paint()
      ..color = AppTheme.primaryBlue.withValues(alpha: 0.12)
      ..strokeWidth = 2;

    final random = Random(42); // deterministic seed
    for (int i = 0; i < 8; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final endX = startX + (random.nextDouble() - 0.5) * size.width * 0.6;
      final endY = startY + (random.nextDouble() - 0.5) * size.height * 0.6;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), roadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
