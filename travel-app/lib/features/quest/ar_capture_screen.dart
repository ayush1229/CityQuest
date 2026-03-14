import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/models/quest_node.dart';

/// Pseudo-AR Capture Screen — camera + gyroscope driven artifact catch mechanic.
/// The item sprite floats in 3D space; the user must align the reticle to capture it.
class ArCaptureScreen extends StatefulWidget {
  final QuestNode quest;
  final String artifactAsset; // e.g. 'assets/coins/gold_coin.png'

  const ArCaptureScreen({
    super.key,
    required this.quest,
    this.artifactAsset = 'assets/coins/gold_coin.png',
  });

  @override
  State<ArCaptureScreen> createState() => _ArCaptureScreenState();
}

class _ArCaptureScreenState extends State<ArCaptureScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _cameraReady = false;

  // Gyroscope-driven item position (pixels from center)
  double _itemX = 80;
  double _itemY = -60;
  // Velocity for smooth damping
  double _velX = 0;
  double _velY = 0;
  StreamSubscription? _gyroSub;

  // Capture state
  bool _captured = false;
  bool _showMissToast = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _captureController;
  late AnimationController _glowController;

  // Item float animation
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _captureController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _initCamera();
    _initGyroscope();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final rearCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        rearCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('[AR] Camera init error: $e');
    }
  }

  void _initGyroscope() {
    const sensitivity = 4.0;
    const damping = 0.85;
    const maxOffset = 120.0;

    // Update at ~60fps
    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _velX *= damping;
        _velY *= damping;
        _itemX = (_itemX + _velX).clamp(-maxOffset, maxOffset);
        _itemY = (_itemY + _velY).clamp(-maxOffset, maxOffset);
      });
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 16),
    ).listen((event) {
      if (_captured) return;
      // Invert: phone turns right → item moves left (anchored in world)
      _velX -= event.y * sensitivity;
      _velY += event.x * sensitivity;
    });
  }

  void _onCaptureTap() {
    if (_captured) return;

    final threshold = 80.0;
    final dist = sqrt(_itemX * _itemX + _itemY * _itemY);

    if (dist < threshold) {
      // SUCCESS!
      HapticFeedback.heavyImpact();
      setState(() => _captured = true);
      _captureController.forward();

      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) {
          Navigator.of(context).pop({
            'captured': true,
            'xp': widget.quest.xpReward,
          });
        }
      });
    } else {
      // MISS
      HapticFeedback.lightImpact();
      setState(() => _showMissToast = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showMissToast = false);
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _gyroSub?.cancel();
    _pulseController.dispose();
    _captureController.dispose();
    _glowController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Layer 1: Camera Preview ──
          if (_cameraReady && _cameraController != null)
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize?.height ?? size.width,
                    height: _cameraController!.value.previewSize?.width ?? size.height,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A0E1A), Color(0xFF1A2040)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentGold),
                ),
              ),
            ),

          // ── Layer 2: Dark vignette overlay ──
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 3: Floating artifact item ──
          if (!_captured)
            AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                final floatOffset = sin(_floatController.value * 2 * pi) * 8;
                return Positioned(
                  left: centerX - 35 + _itemX,
                  top: centerY - 35 + _itemY + floatOffset,
                  child: _buildArtifactSprite(),
                );
              },
            ),

          // ── Layer 4: Capture explosion ──
          if (_captured)
            Positioned(
              left: centerX - 100,
              top: centerY - 100,
              child: _buildCaptureExplosion(),
            ),

          // ── Layer 5: Targeting reticle ──
          if (!_captured)
            Center(child: _buildReticle()),

          // ── Layer 6: Top HUD ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _buildTopHUD(),
          ),

          // ── Layer 7: Bottom capture button ──
          if (!_captured)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(child: _buildCaptureButton()),
            ),

          // ── Layer 8: Success overlay ──
          if (_captured)
            _buildSuccessOverlay(),

          // ── Layer 9: Miss toast ──
          if (_showMissToast)
            Positioned(
              top: size.height * 0.15,
              left: 40,
              right: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accentGold.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.explore, color: AppTheme.accentGold, size: 20),
                    const SizedBox(width: 10),
                    Text('Look around! Align the artifact with the reticle.',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.3),
            ),

          // ── Back button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactSprite() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowIntensity = 0.3 + _glowController.value * 0.5;
        return Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGold.withOpacity(glowIntensity),
                blurRadius: 30,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(glowIntensity * 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            widget.artifactAsset,
            width: 70,
            height: 70,
            errorBuilder: (_, __, ___) => Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.accentGold, Color(0xFFFF8F00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentGold.withOpacity(0.6),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReticle() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + _pulseController.value * 0.08;
        final opacity = 0.6 + _pulseController.value * 0.4;
        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            size: const Size(120, 120),
            painter: _ReticlePainter(opacity: opacity),
          ),
        );
      },
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _onCaptureTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final glowRadius = 8 + _pulseController.value * 12;
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.goldGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentGold.withOpacity(0.5),
                  blurRadius: glowRadius,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gps_fixed, color: AppTheme.deepNavy, size: 28),
                Text('CATCH',
                  style: GoogleFonts.montserrat(
                    color: AppTheme.deepNavy,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopHUD() {
    return SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 40), // offset for back button
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.deepNavy.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.accentGold, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.quest.title,
                      style: GoogleFonts.montserrat(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('+${widget.quest.xpReward} XP',
                      style: GoogleFonts.montserrat(
                        color: AppTheme.accentGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureExplosion() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding ring
          AnimatedBuilder(
            animation: _captureController,
            builder: (context, child) {
              final ringSize = 40 + _captureController.value * 160;
              return Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentGold.withOpacity(1.0 - _captureController.value),
                    width: 3,
                  ),
                ),
              );
            },
          ),
          // Bright flash
          AnimatedBuilder(
            animation: _captureController,
            builder: (context, child) {
              return Opacity(
                opacity: (1.0 - _captureController.value).clamp(0.0, 1.0),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGold.withOpacity(0.8),
                        blurRadius: 40,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: _captured ? 1.0 : 0.0,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: AppTheme.accentGold, size: 72)
                  .animate()
                  .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text('ARTIFACT CAPTURED!',
                style: GoogleFonts.montserrat(
                  color: AppTheme.accentGold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
                ),
                child: Text('+${widget.quest.xpReward} XP',
                  style: GoogleFonts.montserrat(
                    color: AppTheme.accentGold,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(begin: 0.3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the targeting reticle
class _ReticlePainter extends CustomPainter {
  final double opacity;
  _ReticlePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppTheme.accentGold.withOpacity(opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Outer circle
    canvas.drawCircle(center, 50, paint);

    // Inner circle
    paint.strokeWidth = 1.5;
    paint.color = AppTheme.accentGold.withOpacity(opacity * 0.5);
    canvas.drawCircle(center, 30, paint);

    // Crosshair lines
    paint.strokeWidth = 1.5;
    paint.color = AppTheme.accentGold.withOpacity(opacity * 0.7);
    const gap = 15.0;
    const lineLen = 22.0;

    // Top
    canvas.drawLine(Offset(center.dx, center.dy - gap - lineLen), Offset(center.dx, center.dy - gap), paint);
    // Bottom
    canvas.drawLine(Offset(center.dx, center.dy + gap), Offset(center.dx, center.dy + gap + lineLen), paint);
    // Left
    canvas.drawLine(Offset(center.dx - gap - lineLen, center.dy), Offset(center.dx - gap, center.dy), paint);
    // Right
    canvas.drawLine(Offset(center.dx + gap, center.dy), Offset(center.dx + gap + lineLen, center.dy), paint);

    // Center dot
    paint.style = PaintingStyle.fill;
    paint.color = AppTheme.accentGold.withOpacity(opacity);
    canvas.drawCircle(center, 3, paint);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) => oldDelegate.opacity != opacity;
}
