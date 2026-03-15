import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/models/lore_entry.dart';
import 'package:cityquest/providers/lore_provider.dart';

/// Post-quest Lore Capture Screen.
/// Opens the camera, lets the user photograph the location,
/// then fetches lore from Google Places API or generates a fallback.
class LoreCaptureScreen extends StatefulWidget {
  final QuestNode quest;

  const LoreCaptureScreen({super.key, required this.quest});

  @override
  State<LoreCaptureScreen> createState() => _LoreCaptureScreenState();
}

class _LoreCaptureScreenState extends State<LoreCaptureScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _cameraReady = false;
  bool _photoTaken = false;
  bool _fetchingLore = false;
  bool _loreReady = false;
  bool _loreFetched = false; // true if Places API returned actual lore
  bool _takenWithFrontCamera = false;
  String? _photoPath;

  // Fetched lore data
  String _locationName = '';
  String _loreDescription = '';

  static String get _mapsApiKey => dotenv.env['MAPS_API_KEY'] ?? '';

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      // Start with rear camera
      _currentCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_currentCameraIndex < 0) _currentCameraIndex = 0;
      await _startCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      debugPrint('[LoreCapture] Camera init error: $e');
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    setState(() => _cameraReady = false);
    _cameraController = CameraController(camera, ResolutionPreset.high, enableAudio: false);
    await _cameraController!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  void _flipCamera() {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    _startCamera(_cameras[_currentCameraIndex]);
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final xFile = await _cameraController!.takePicture();
      final isFront = _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;
      setState(() {
        _photoPath = xFile.path;
        _photoTaken = true;
        _fetchingLore = true;
        _takenWithFrontCamera = isFront;
      });

      // Fetch lore from Google Places
      await _fetchPlaceLore(widget.quest.latitude, widget.quest.longitude);

      setState(() {
        _fetchingLore = false;
        _loreReady = true;
      });
    } catch (e) {
      debugPrint('[LoreCapture] Photo error: $e');
      setState(() {
        _fetchingLore = false;
        _loreReady = true;
        _locationName = widget.quest.title;
        _loreDescription = widget.quest.description;
      });
    }
  }

  /// Reverse-lookup via Google Places searchNearby (50m radius).
  Future<void> _fetchPlaceLore(double lat, double lng) async {
    try {
      final url = 'https://places.googleapis.com/v1/places:searchNearby';
      final payload = json.encode({
        'includedTypes': ['tourist_attraction', 'park', 'museum', 'restaurant', 'point_of_interest'],
        'maxResultCount': 1,
        'locationRestriction': {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': 50.0,
          }
        }
      });

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'X-Goog-Api-Key': _mapsApiKey,
          'X-Goog-FieldMask': 'places.displayName,places.editorialSummary,places.reviews',
          'Content-Type': 'application/json',
        },
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data['places'] as List<dynamic>? ?? [];

        if (places.isNotEmpty) {
          final place = places[0];
          _locationName = place['displayName']?['text'] ?? widget.quest.title;

          // Try editorialSummary first, then first review, then description
          final editorial = place['editorialSummary']?['text'];
          if (editorial != null && editorial.isNotEmpty) {
            _loreDescription = editorial;
            _loreFetched = true;
          } else {
            final reviews = place['reviews'] as List<dynamic>? ?? [];
            if (reviews.isNotEmpty) {
              _loreDescription = reviews[0]['text']?['text'] ?? '';
              _loreFetched = true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LoreCapture] Places API error: $e');
    }

    // Fallback if nothing was found
    if (_locationName.isEmpty) _locationName = widget.quest.title;
    if (_loreDescription.isEmpty) {
      _loreDescription = widget.quest.description.isNotEmpty
          ? widget.quest.description
          : 'An ancient place of wonder, steeped in history. '
            'The stories etched into these walls speak of times long past, '
            'waiting for a worthy traveler to uncover their secrets.';
    }
  }

  void _saveLoreAndClose() {
    final now = DateTime.now();
    final entry = LoreEntry(
      id: 'lore_${now.millisecondsSinceEpoch}',
      title: widget.quest.title,
      locationName: _locationName,
      description: _loreDescription,
      questType: widget.quest.questType,
      exploredDate: DateFormat('d MMM yyyy, h:mm a').format(now),
      latitude: widget.quest.latitude,
      longitude: widget.quest.longitude,
      imagePath: _photoPath ?? '',
    );

    context.read<LoreProvider>().addLoreEntry(entry);
    Navigator.of(context).pop({'loreEntry': entry});
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera / Photo Preview ──
          if (_photoTaken && _photoPath != null)
            Positioned.fill(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..scale(_takenWithFrontCamera ? -1.0 : 1.0, 1.0),
                child: Image.file(File(_photoPath!), fit: BoxFit.cover),
              ),
            )
          else if (_cameraReady && _cameraController != null)
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize?.height ?? 1,
                    height: _cameraController!.value.previewSize?.width ?? 1,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
          else
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
            ),

          // ── Vignette overlay ──
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.2, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Top HUD ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.deepNavy.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.accentGold.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book, color: AppTheme.accentGold, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Capture Memory',
                            style: GoogleFonts.montserrat(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── State: Camera viewfinder frame ──
          if (!_photoTaken)
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, color: AppTheme.accentGold.withOpacity(0.4), size: 48),
                    const SizedBox(height: 8),
                    Text('Frame the location',
                      style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // ── State: Fetching lore animation ──
          if (_fetchingLore)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60, height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppTheme.accentGold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Decrypting ancient runes...',
                        style: GoogleFonts.montserrat(
                          color: AppTheme.accentGold,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ).animate(onPlay: (c) => c.repeat()).shimmer(
                        duration: 1500.ms,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 8),
                      Text('Searching the archives...',
                        style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── State: Lore result card ──
          if (_loreReady)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildLoreResultCard(),
            ),

          // ── Capture button + camera flip (before photo) ──
          if (!_photoTaken)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 64), // spacer for symmetry
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Camera flip button
                  if (_cameras.length >= 2)
                    GestureDetector(
                      onTap: _flipCamera,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoreResultCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.deepNavy.withOpacity(0.0),
            AppTheme.deepNavy.withOpacity(0.95),
            AppTheme.deepNavy,
          ],
          stops: const [0.0, 0.15, 0.3],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lore discovered / Memory captured banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_loreFetched ? AppTheme.accentGold : Colors.green).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (_loreFetched ? AppTheme.accentGold : Colors.green).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_loreFetched ? Icons.auto_stories : Icons.photo_camera,
                  color: _loreFetched ? AppTheme.accentGold : Colors.green, size: 16),
                const SizedBox(width: 6),
                Text(_loreFetched ? 'LORE DISCOVERED' : 'MEMORY CAPTURED',
                  style: GoogleFonts.montserrat(
                    color: _loreFetched ? AppTheme.accentGold : Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 12),

          // Date / Time stamp (always shown)
          Text(DateFormat('d MMM yyyy, h:mm a').format(DateTime.now()),
            style: GoogleFonts.poppins(
              color: Colors.white38,
              fontSize: 12,
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

          if (_loreFetched) ...[
            const SizedBox(height: 8),

            Text(_locationName,
              style: GoogleFonts.montserrat(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: 8),

            Text(_loreDescription,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: AppTheme.deepNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.bookmark_add, size: 20),
              label: Text('Save to Lore Collection',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              onPressed: _saveLoreAndClose,
            ),
          ).animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}
