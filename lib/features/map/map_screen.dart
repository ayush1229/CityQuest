import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/providers/location_provider.dart';
import 'package:cityquest/providers/quest_provider.dart';
import 'package:cityquest/providers/campaign_provider.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/providers/settings_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cityquest/features/profile/profile_screen.dart';
import 'package:cityquest/features/settings/settings_screen.dart';
import 'package:cityquest/core/widgets/loading_widget.dart';
import 'package:cityquest/core/widgets/app_error_widget.dart';
import 'package:cityquest/features/quest/quest_popup.dart';
import 'package:cityquest/features/quest/quests_list_screen.dart';
import 'package:cityquest/features/lore/lore_screen.dart';
import 'package:cityquest/features/map/poi_detail_sheet.dart';
import 'package:cityquest/features/campaign/campaign_builder_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  bool _spritesLoaded = false;

  // Background POI markers (low zIndex, scenery)
  final Set<Marker> _poiMarkers = {};
  static const String _mapsApiKey = 'AIzaSyCZ7KPFxLqOCfTPHwumDcZyNpOcYJAHYf8';
  double _lastPoiRadius = 0;

  // POI filter state
  String? _activePoiFilter;
  bool _filterExpanded = false;
  final Map<String, String> _poiCategories = {};
  Set<Polyline> _emergencyRoute = {};
  List<LatLng> _emergencyRoutePoints = []; // decoded street-level points

  // Sparkle marquee trail (replaces breathing aura)
  BitmapDescriptor? _sparkleIcon;
  int _sparklePhase = 0;
  Timer? _sparkleTimer;
  int _sparkleSpacing = 8;

  // Dual-line routing: magical pointer = straight line, street route = Directions API
  List<LatLng> _magicalPointerPoints = [];

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;
  List<Map<String, dynamic>> _autocompleteResults = [];

  // Sprite decks: category → list of BitmapDescriptors
  final Map<String, List<BitmapDescriptor>> _spriteDecks = {
    'hospital': [],
    'park': [],
    'petrol_pump': [],
    'mall': [],
    'restaurant': [],
    'buildings': [],
    'coins': [],
    'trees': [],
    'vehicles': [],
  };

  @override
  void initState() {
    super.initState();
    _loadAllSprites();
    _initLocation();

    // Sparkle marquee timer — shifts sparkle phase every 800ms (very cheap)
    _sparkleTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted) return;
      // Only rebuild if there's an active route with sparkles
      if (_magicalPointerPoints.length >= 2 && _sparkleIcon != null) {
        setState(() {
          _sparklePhase = (_sparklePhase + 1) % _sparkleSpacing;
        });
      }
    });

    // Register focus callback so QuestsListScreen can animate map camera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cp = context.read<CampaignProvider>();
      cp.focusQuestCallback = (quest) {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(quest.latitude, quest.longitude),
              zoom: 17,
              tilt: 60,
              bearing: 30,
            ),
          ),
        );
      };
    });
  }

  Future<void> _loadAllSprites() async {
    const config = ImageConfiguration(size: Size(80, 80));

    try {
      // Hospital (1 image)
      _spriteDecks['hospital']!.add(
        await BitmapDescriptor.fromAssetImage(config, 'assets/hospital/hospital.png'),
      );

      // Park (1 image)
      _spriteDecks['park']!.add(
        await BitmapDescriptor.fromAssetImage(config, 'assets/park/park.png'),
      );

      // Petrol Pump (1 image)
      _spriteDecks['petrol_pump']!.add(
        await BitmapDescriptor.fromAssetImage(config, 'assets/petrol_pump/petrol.png'),
      );

      // Mall (1 image)
      _spriteDecks['mall']!.add(
        await BitmapDescriptor.fromAssetImage(config, 'assets/mall/mall.png'),
      );

      // Restaurant (1 image)
      _spriteDecks['restaurant']!.add(
        await BitmapDescriptor.fromAssetImage(config, 'assets/restaurant/restaurant.png'),
      );

      // Buildings (20 images: building-a through building-t)
      for (final letter in 'abcdefghijklmnopqrst'.split('')) {
        _spriteDecks['buildings']!.add(
          await BitmapDescriptor.fromAssetImage(config, 'assets/buildings/building-$letter.png'),
        );
      }

      // Coins (3 images)
      for (final type in ['bronze', 'gold', 'silver']) {
        _spriteDecks['coins']!.add(
          await BitmapDescriptor.fromAssetImage(config, 'assets/coins/item-coin-$type.png'),
        );
      }

      // Trees (2 images)
      _spriteDecks['trees']!.add(
        await BitmapDescriptor.fromAssetImage(config, 'assets/Trees/tree.png'),
      );
      _spriteDecks['trees']!.add(
        await BitmapDescriptor.fromAssetImage(config, 'assets/Trees/tree-pine.png'),
      );

      // Vehicles (8 images)
      for (final name in [
        'drag-racer', 'monster-truck', 'racer-low', 'racer',
        'speedster', 'suv', 'truck', 'vintage-racer',
      ]) {
        _spriteDecks['vehicles']!.add(
          await BitmapDescriptor.fromAssetImage(config, 'assets/vehicles/vehicle-$name.png'),
        );
      }

      if (mounted) setState(() => _spritesLoaded = true);
      print('✅ All sprite decks loaded into memory!');

      // Load sparkle icon with 50% transparency
      try {
        final sparkleBytes = await DefaultAssetBundle.of(context)
            .load('assets/sparkle/Picsart_26-03-14_00-59-25-766 (1).png');
        final codec = await ui.instantiateImageCodec(
          sparkleBytes.buffer.asUint8List(),
          targetWidth: 32, targetHeight: 32,
        );
        final frame = await codec.getNextFrame();
        final original = frame.image;

        // Apply 50% opacity via canvas
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final paint = Paint()..colorFilter = const ColorFilter.mode(
          Color(0x80FFFFFF), BlendMode.modulate,
        );
        canvas.drawImage(original, Offset.zero, paint);
        final picture = recorder.endRecording();
        final img = await picture.toImage(original.width, original.height);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted) {
          _sparkleIcon = BitmapDescriptor.bytes(
            byteData.buffer.asUint8List(),
            width: 24, height: 24,
          );
          print('✨ Sparkle icon loaded!');
        }
      } catch (e) {
        print('⚠️ Sparkle load error: $e');
      }
    } catch (e) {
      print('⚠️ Sprite loading error: $e');
      // Sprites failed to load; markers will use defaults
    }
  }

  /// Maps a quest title to a sprite category using keyword matching.
  /// Unrecognized places default to 'buildings'.
  String _getSpriteCategory(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('hospital') || lower.contains('clinic') || lower.contains('medical') ||
        lower.contains('dispensary') || lower.contains('health') || lower.contains('pharma')) return 'hospital';
    if (lower.contains('park') || lower.contains('garden')) return 'park';
    if (lower.contains('petrol') || lower.contains('fuel') || lower.contains('gas')) return 'petrol_pump';
    if (lower.contains('mall') || lower.contains('shopping') || lower.contains('market')) return 'mall';
    if (lower.contains('restaurant') || lower.contains('cafe') || lower.contains('coffee') ||
        lower.contains('food') || lower.contains('dhaba') || lower.contains('kitchen') ||
        lower.contains('pizz') || lower.contains('burger') || lower.contains('bakery') ||
        lower.contains('canteen') || lower.contains('mess') || lower.contains('hotel') ||
        lower.contains('tea') || lower.contains('chai') || lower.contains('biryani') ||
        lower.contains('sweet') || lower.contains('juice') || lower.contains('eatery') ||
        lower.contains('diner')) return 'restaurant';
    // Default: use buildings sprite
    return 'buildings';
  }

  /// Gets a random sprite from the specified category deck.
  BitmapDescriptor _getSprite(String category, String questId) {
    final deck = _spriteDecks[category];
    if (deck == null || deck.isEmpty) return BitmapDescriptor.defaultMarker;
    // Use quest ID hash for consistent random selection
    final index = questId.hashCode.abs() % deck.length;
    return deck[index];
  }

  @override
  void dispose() {
    _sparkleTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _autocompleteResults = []);
      return;
    }
    
    final url = 'https://places.googleapis.com/v1/places:autocomplete';
    final locProvider = context.read<LocationProvider>();
    final questProvider = context.read<QuestProvider>();
    
    final Map<String, dynamic> requestBody = {'input': query};
    
    // Add location bias to prioritize nearby places
    if (locProvider.latitude != 0.0 && locProvider.longitude != 0.0) {
      requestBody['locationBias'] = {
        'circle': {
          'center': {
            'latitude': locProvider.latitude,
            'longitude': locProvider.longitude,
          },
          'radius': questProvider.searchRadius,
        }
      };
    }
        
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _mapsApiKey,
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('suggestions')) {
          setState(() {
            _autocompleteResults = List<Map<String, dynamic>>.from(data['suggestions']);
          });
        } else {
          setState(() => _autocompleteResults = []);
        }
      } else {
        print('⚠️ Autocomplete error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('⚠️ Autocomplete error: $e');
    }
  }

  Future<void> _navigateToPlace(String placeId, String placeName) async {
    setState(() {
      _isSearchExpanded = false;
      _autocompleteResults = [];
      _searchController.clear();
    });
    _searchFocusNode.unfocus();

    // Fetch details for lat/lng using New Places API
    final url = 'https://places.googleapis.com/v1/places/$placeId';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Goog-Api-Key': _mapsApiKey,
          'X-Goog-FieldMask': 'location',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('location')) {
          final lat = (data['location']['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (data['location']['longitude'] as num?)?.toDouble() ?? 0.0;
          
          if (lat != 0.0 && lng != 0.0 && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: LatLng(lat, lng), zoom: 17, tilt: 45),
              ),
            );
            
            // Show POI detail sheet after animation
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) _showPoiDetails(placeId, placeName);
            });
          }
        }
      } else {
         print('⚠️ Place details error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('⚠️ Place details error: $e');
    }
  }

  Future<void> _initLocation() async {
    final locProvider = context.read<LocationProvider>();
    await locProvider.startTracking();

    if (!mounted) return;

    // Load existing active quests from Firestore
    final questProvider = context.read<QuestProvider>();
    await questProvider.loadQuests();

    if (!mounted) return;

    // Auto-scan for new quests if none exist yet (first launch / new user)
    if (questProvider.quests.isEmpty && locProvider.latitude != 0.0) {
      await questProvider.fetchQuestsFromAI(locProvider.latitude, locProvider.longitude);
    }

    // Populate background POI sprites
    if (locProvider.latitude != 0.0) {
      final radius = questProvider.searchRadius;
      await _populateNearbySprites(locProvider.latitude, locProvider.longitude, radius);
    }
  }

  /// Fetches real-world POIs from Google Places API (New) and creates background sprite markers.
  Future<void> _populateNearbySprites(double lat, double lng, double radius) async {
    if (!_spritesLoaded) {
      // Wait a bit for sprites to load
      await Future.delayed(const Duration(seconds: 2));
    }
    if (_lastPoiRadius == radius && _poiMarkers.isNotEmpty) return; // Already loaded for this radius
    _lastPoiRadius = radius;

    try {
      final typesToFetch = [
        'hospital', 'doctor', 'dentist', 'pharmacy', 'physiotherapist',
        'park', 'gas_station', 'shopping_mall', 'restaurant', 'cafe',
        'school', 'bank', 'supermarket',
      ];
      final futures = typesToFetch.map((type) async {
        final url = 'https://places.googleapis.com/v1/places:searchNearby';
        try {
          final response = await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _mapsApiKey,
              'X-Goog-FieldMask': 'places.id,places.displayName,places.location,places.types',
            },
            body: json.encode({
              'includedTypes': [type],
              'maxResultCount': 10,
              'locationRestriction': {
                'circle': {
                  'center': {'latitude': lat, 'longitude': lng},
                  'radius': radius,
                }
              }
            }),
          );
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            return data['places'] as List<dynamic>? ?? [];
          }
        } catch (e) {
          print('⚠️ Places API error for $type: $e');
        }
        return [];
      }).toList();

      final resultsLists = await Future.wait(futures);
      final allResults = resultsLists.expand((list) => list).toList();
      
      final Set<Marker> newPoiMarkers = {};

      // Collect quest marker IDs to avoid duplicates
      final questIds = context.read<QuestProvider>().quests.map((q) => q.id).toSet();
      final seenIds = <String>{};

      for (final place in allResults) {
        final placeId = place['id'] as String? ?? '';
        if (placeId.isEmpty || questIds.contains(placeId) || seenIds.contains(placeId)) continue;
        seenIds.add(placeId);

        final location = place['location'] ?? {};
        final placeLat = (location['latitude'] as num?)?.toDouble() ?? 0.0;
        final placeLng = (location['longitude'] as num?)?.toDouble() ?? 0.0;
        if (placeLat == 0.0 || placeLng == 0.0) continue;

        final placeName = place['displayName']?['text'] as String? ?? 'Unknown Place';
        final types = List<String>.from(place['types'] ?? []);
        final lowerName = placeName.toLowerCase();

        // Map Google Place types to sprite categories (check types first, then name fallback)
        String category = 'buildings';
        if (types.any((t) => t.contains('hospital') || t.contains('health') || t.contains('doctor') || t.contains('dentist') || t.contains('pharmacy') || t.contains('physiotherapist') || t.contains('medical') || t.contains('clinic'))) {
          category = 'hospital';
        } else if (types.any((t) => t.contains('park') || t == 'natural_feature')) {
          category = 'park';
        } else if (types.any((t) => t.contains('gas_station'))) {
          category = 'petrol_pump';
        } else if (types.any((t) => t.contains('shopping') || t == 'department_store' || t == 'supermarket')) {
          category = 'mall';
        } else if (types.any((t) => t.contains('restaurant') || t.contains('cafe') || t.contains('food') || t == 'bakery' || t == 'meal_takeaway' || t == 'bar')) {
          category = 'restaurant';
        }
        
        // Fallback: if still 'buildings', check the place NAME for keywords
        if (category == 'buildings') {
          if (lowerName.contains('hospital') || lowerName.contains('health') || lowerName.contains('clinic') || lowerName.contains('dispensary') || lowerName.contains('medical') || lowerName.contains('doctor')) {
            category = 'hospital';
          } else if (lowerName.contains('park') || lowerName.contains('garden')) {
            category = 'park';
          } else if (lowerName.contains('petrol') || lowerName.contains('fuel') || lowerName.contains('gas station')) {
            category = 'petrol_pump';
          } else if (lowerName.contains('mall') || lowerName.contains('market') || lowerName.contains('shop') || lowerName.contains('store')) {
            category = 'mall';
          } else if (lowerName.contains('restaurant') || lowerName.contains('cafe') || lowerName.contains('dhaba') || lowerName.contains('kitchen') || lowerName.contains('food')) {
            category = 'restaurant';
          }
        }

        // Track category for filtering
        _poiCategories[placeId] = category;

        final icon = _spritesLoaded
            ? _getSprite(category, placeId)
            : BitmapDescriptor.defaultMarker;

        newPoiMarkers.add(
          Marker(
            markerId: MarkerId('poi_$placeId'),
            position: LatLng(placeLat, placeLng),
            icon: icon,
            zIndex: 1, // Below quest markers (quest markers default to higher zIndex)
            onTap: () => _showPoiDetails(placeId, placeName, lat: placeLat, lng: placeLng),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _poiMarkers.clear();
          _poiMarkers.addAll(newPoiMarkers);
        });
        print('✅ Loaded ${newPoiMarkers.length} POI sprites on map');
      }
    } catch (e) {
      print('⚠️ POI population error: $e');
    }
  }

  MapType _getMapType(String style) {
    switch (style) {
      case 'satellite':
        return MapType.satellite;
      case 'terrain':
        return MapType.terrain;
      case 'hybrid':
        return MapType.hybrid;
      default:
        return MapType.normal;
    }
  }

  void _updateCameraFor3D(bool is3D, LocationProvider locProvider) {
    if (_mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(locProvider.latitude, locProvider.longitude),
          zoom: is3D ? 17 : 15,
          tilt: is3D ? 60 : 0,
          bearing: is3D ? 30 : 0,
        ),
      ),
    );
  }

  void _showPoiDetails(String placeId, String placeName, {double? lat, double? lng}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PoiDetailSheet(
        placeName: placeName,
        placeId: placeId,
        lat: lat,
        lng: lng,
        onDirections: (lat != null && lng != null)
            ? () => _fetchDirectionsRoute(lat, lng)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildMapTab(),
    );
  }

  // ── Hamburger Navigation Overlay ──
  void _showNavigationOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Nav Overlay',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              height: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30),
                ],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              gradient: AppTheme.goldGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.shield, color: Colors.black87, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Text('CITYQUEST',
                            style: GoogleFonts.montserrat(
                              fontSize: 20, fontWeight: FontWeight.w800,
                              letterSpacing: 3, color: AppTheme.accentGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text('Your adventure awaits',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(height: 1, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    const SizedBox(height: 16),

                    _navItem(Icons.map_rounded, 'Map', AppTheme.accentGold, () {
                      Navigator.pop(context); // Just close — we're already on map
                    }),
                    _navItem(Icons.auto_fix_high, 'Campaign Builder', Colors.purple.shade300, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CampaignBuilderScreen()));
                    }),
                    _navItem(Icons.explore_outlined, 'Active Quests', Colors.orange.shade300, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestsListScreen()));
                    }),
                    _navItem(Icons.menu_book_outlined, 'Lore', Colors.teal.shade300, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoreScreen()));
                    }),
                    _navItem(Icons.person_rounded, 'Profile', Colors.blue.shade300, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    }),
                    _navItem(Icons.settings_rounded, 'Settings', Colors.grey.shade400, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    }),

                    const Spacer(),
                    Container(height: 1, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    const SizedBox(height: 12),
                    // Active campaign badge
                    Consumer<CampaignProvider>(builder: (context, cp, _) {
                      if (cp.activeCampaign == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shield, color: AppTheme.accentGold, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ACTIVE CAMPAIGN', style: TextStyle(color: AppTheme.accentGold, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                                    Text(cp.activeCampaign!.title,
                                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Text('${cp.activeCampaign!.totalDestinations} stops',
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    );
  }

  Widget _navItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
        style: GoogleFonts.montserrat(
          fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.white12, size: 18),
      onTap: onTap,
    );
  }

  Widget _buildMapTab() {
    return Consumer3<LocationProvider, QuestProvider, SettingsProvider>(
      builder: (context, locProvider, questProvider, settings, _) {
        if (locProvider.error != null && !locProvider.isTracking) {
          return AppErrorWidget(
            message: locProvider.error!,
            onRetry: _initLocation,
          );
        }

        if (!locProvider.isTracking) {
           return const LoadingWidget(message: 'Acquiring GPS Signal...');
        }

        final initialCameraPosition = CameraPosition(
          target: LatLng(locProvider.latitude, locProvider.longitude),
          zoom: settings.is3DMode ? 17 : 15,
          tilt: settings.is3DMode ? 60 : 0,
          bearing: settings.is3DMode ? 30 : 0,
        );

        final Set<Marker> markers = {};
        
        // Side quest markers (from scan)
        for (final quest in questProvider.quests) {
          double hue;
          switch (quest.questType) {
            case 'discovery':
              hue = BitmapDescriptor.hueGreen;
              break;
            case 'exploration':
              hue = BitmapDescriptor.hueViolet;
              break;
            default:
              hue = BitmapDescriptor.hueOrange;
          }
          
          markers.add(
            Marker(
              markerId: MarkerId(quest.id),
              position: LatLng(quest.latitude, quest.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(hue),
              zIndex: 10, // Above background POI markers
              onTap: () {
                questProvider.setActiveQuest(quest);
                _showPlaceInfoCard(context, quest, locProvider, questProvider);
              },
            ),
          );
        }

        // Campaign main quest markers — level-gated with ghosting
        final campaignProvider = context.watch<CampaignProvider>();
        final activeLevel = campaignProvider.getActiveLevel();
        final campaignLevels = campaignProvider.activeCampaign?.levels ?? [];
        for (final level in campaignLevels) {
          final isFutureLevel = level.levelNumber > activeLevel;
          for (final mq in level.destinations) {
            markers.add(
              Marker(
                markerId: MarkerId('campaign_${mq.id}'),
                position: LatLng(mq.latitude, mq.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  isFutureLevel ? BitmapDescriptor.hueRose : BitmapDescriptor.hueYellow,
                ),
                alpha: isFutureLevel ? 0.4 : 1.0,
                zIndex: isFutureLevel ? 15 : 20,
                onTap: () {
                  if (isFutureLevel) {
                    // Locked intercept dialog
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surfaceDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('🔒 Level Locked',
                          style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.w700),
                        ),
                        content: Text(
                          'This quest belongs to Level ${level.levelNumber}. Complete your active level to unlock it!',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close', style: TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showPoiDetails(mq.id, mq.title,
                                  lat: mq.latitude, lng: mq.longitude);
                            },
                            child: const Text('View Place Info',
                              style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    questProvider.setActiveQuest(mq);
                    _showPlaceInfoCard(context, mq, locProvider, questProvider);
                  }
                },
              ),
            );
          }
        }

        // Campaign polyline (connect main quests in order)
        final Set<Polyline> polylines = {};
        final mainQuests = campaignProvider.mainQuests;
        if (mainQuests.length >= 2) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('campaign_route'),
              points: mainQuests.map((q) => LatLng(q.latitude, q.longitude)).toList(),
              color: AppTheme.accentGold,
              width: 4,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          );
        }

        // Existing quest route polyline
        if (questProvider.routePoints.isNotEmpty) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('quest_route'),
              points: questProvider.routePoints,
              color: const Color(0xFF2196F3),
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          );
        }

        final radiusOptions = [250.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0];
        final radiusLabels = ['250m', '500m', '1km', '2km', '5km', '10km'];

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: initialCameraPosition,
              cloudMapId: '7d2b67b4d6eb9bfe795f0378',
              onMapCreated: (controller) {
                _mapController = controller;
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: {
                ...(_activePoiFilter == null
                    ? _poiMarkers
                    : _poiMarkers.where((m) {
                        final pid = m.markerId.value.replaceFirst('poi_', '');
                        return _poiCategories[pid] == _activePoiFilter;
                      }).toSet()),
                ...markers,
                ..._buildSparkleMarkers(_magicalPointerPoints),
              },
              polylines: {...polylines, ..._emergencyRoute},
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              mapType: _getMapType(settings.mapStyle),
              buildingsEnabled: settings.showBuildingsLayer,
              trafficEnabled: settings.showTraffic,
              circles: {
                Circle(
                  circleId: const CircleId('search_radius'),
                  center: LatLng(locProvider.latitude, locProvider.longitude),
                  radius: questProvider.searchRadius,
                  fillColor: AppTheme.accentGold.withValues(alpha: 0.05),
                  strokeColor: AppTheme.accentGold.withValues(alpha: 0.2),
                  strokeWidth: 1,
                ),
              },
              onTap: (LatLng position) async {
                // Reverse-lookup: find the nearest real place at the tapped location
                try {
                  final url = 'https://places.googleapis.com/v1/places:searchNearby';
                  final response = await http.post(
                    Uri.parse(url),
                    headers: {
                      'Content-Type': 'application/json',
                      'X-Goog-Api-Key': _mapsApiKey,
                      'X-Goog-FieldMask': 'places.id,places.displayName',
                    },
                    body: json.encode({
                      'maxResultCount': 1,
                      'locationRestriction': {
                        'circle': {
                          'center': {'latitude': position.latitude, 'longitude': position.longitude},
                          'radius': 50.0,
                        }
                      }
                    }),
                  );
                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                    final places = data['places'] as List<dynamic>? ?? [];
                    if (places.isNotEmpty) {
                      final place = places[0];
                      final realId = place['id'] as String? ?? '';
                      final realName = place['displayName']?['text'] as String? ?? 'Unknown Place';
                      if (realId.isNotEmpty) {
                        _showPoiDetails(realId, realName);
                        return;
                      }
                    }
                  }
                } catch (e) {
                  print('⚠️ Reverse lookup error: $e');
                }
                // Fallback: no place found nearby
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No place found at this location'), duration: Duration(seconds: 2)),
                );
              },
            ),
            
            // ── Search Bar at the top ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Hamburger menu button
                        GestureDetector(
                          onTap: _showNavigationOverlay,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 4),
                            child: Icon(Icons.menu, color: AppTheme.accentGold, size: 22),
                          ),
                        ),
                        Container(width: 1, height: 24, color: Colors.white12),
                        const SizedBox(width: 10),
                        const Icon(Icons.search, color: AppTheme.accentGold, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _searchPlaces,
                            onTap: () => setState(() => _isSearchExpanded = true),
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: 'Search Google Maps...',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_isSearchExpanded)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isSearchExpanded = false;
                                _autocompleteResults = [];
                                _searchController.clear();
                              });
                              _searchFocusNode.unfocus();
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.close, color: Colors.white54, size: 20),
                            ),
                          )
                        else
                          const SizedBox(width: 14),
                      ],
                    ),
                  ),

                  // ── Search Results Dropdown ──
                  if (_isSearchExpanded && _autocompleteResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _autocompleteResults.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1, indent: 50),
                        itemBuilder: (context, index) {
                          final prediction = _autocompleteResults[index];
                          final placePrediction = prediction['placePrediction'] ?? {};
                          final placeId = placePrediction['placeId'] as String? ?? '';
                          // The new Places API provides text.text
                          final textObj = placePrediction['text'] ?? {};
                          final mainText = textObj['text'] as String? ?? 'Unknown Place';
                          final secondaryText = ''; // You could parse structuredFormat here, but simple text works well.

                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.place, color: AppTheme.accentGold, size: 20),
                            ),
                            title: Text(
                              mainText,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: secondaryText.isNotEmpty
                                ? Text(
                                    secondaryText,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: const Icon(Icons.north_west, color: Colors.white30, size: 16),
                            onTap: () => _navigateToPlace(placeId, mainText),
                          );
                        },
                      ),
                    ),

                  // ── "No results" message ──
                  if (_isSearchExpanded && _searchController.text.isNotEmpty && _autocompleteResults.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, color: Colors.white30, size: 18),
                          SizedBox(width: 8),
                          Text('No places found on Google Maps', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Radius Selector at the top ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar, color: AppTheme.accentGold, size: 18),
                    const SizedBox(width: 6),
                    const Text('Range:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: List.generate(radiusOptions.length, (i) {
                            final isSelected = questProvider.searchRadius == radiusOptions[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: GestureDetector(
                                onTap: () {
                                  questProvider.setSearchRadius(radiusOptions[i]);
                                  if (locProvider.latitude != 0.0) {
                                    _populateNearbySprites(locProvider.latitude, locProvider.longitude, radiusOptions[i]);
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.accentGold : AppTheme.cardDark,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.accentGold : Colors.white24,
                                    ),
                                  ),
                                  child: Text(
                                    radiusLabels[i],
                                    style: TextStyle(
                                      color: isSelected ? AppTheme.deepNavy : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Quick POI Filter (Right-side speed dial) ──
            Positioned(
              right: 16,
              bottom: 170,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category buttons (shown when expanded)
                  if (_filterExpanded) ...[
                    _poiFilterButton(
                      icon: Icons.local_hospital,
                      label: 'Hospital',
                      color: Colors.redAccent,
                      category: 'hospital',
                    ),
                    const SizedBox(height: 8),
                    _poiFilterButton(
                      icon: Icons.restaurant,
                      label: 'Food',
                      color: Colors.orange,
                      category: 'restaurant',
                    ),
                    const SizedBox(height: 8),
                    _poiFilterButton(
                      icon: Icons.local_gas_station,
                      label: 'Fuel',
                      color: Colors.lightBlue,
                      category: 'petrol_pump',
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Main toggle button
                  FloatingActionButton.small(
                    heroTag: 'poi_filter',
                    backgroundColor: _activePoiFilter != null
                        ? Colors.redAccent
                        : AppTheme.surfaceDark.withValues(alpha: 0.9),
                    onPressed: () {
                      if (_activePoiFilter != null) {
                        _clearFilter();
                      } else {
                        setState(() => _filterExpanded = !_filterExpanded);
                      }
                    },
                    child: Icon(
                      _activePoiFilter != null ? Icons.close : Icons.layers,
                      color: _activePoiFilter != null ? Colors.white : AppTheme.accentGold,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // ── 3D Toggle Button ──
            Positioned(
              bottom: 90,
              right: 24,
              child: FloatingActionButton.small(
                heroTag: '3d_toggle',
                backgroundColor: settings.is3DMode 
                    ? AppTheme.accentGold 
                    : AppTheme.surfaceDark.withValues(alpha: 0.9),
                onPressed: () {
                  settings.toggle3DMode(!settings.is3DMode);
                  _updateCameraFor3D(!settings.is3DMode ? false : true, locProvider);
                },
                child: Icon(
                  settings.is3DMode ? Icons.view_in_ar : Icons.map_outlined,
                  color: settings.is3DMode ? AppTheme.deepNavy : Colors.white70,
                  size: 20,
                ),
              ),
            ),
            
            // ── Scan for Quests FAB ──
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton.extended(
                heroTag: 'scan_quests',
                backgroundColor: AppTheme.accentGold,
                onPressed: questProvider.isLoading 
                    ? null 
                    : () async {
                  await questProvider.fetchQuestsFromAI(locProvider.latitude, locProvider.longitude);
                },
                icon: questProvider.isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.deepNavy)
                    )
                  : const Icon(Icons.explore, color: AppTheme.deepNavy),
                label: Text(
                  questProvider.isLoading ? 'Scanning...' : 'Side Quests',
                  style: const TextStyle(
                    color: AppTheme.deepNavy, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPlaceInfoCard(BuildContext context, QuestNode quest, LocationProvider locProvider, QuestProvider questProvider) {
    double distance = 0;
    if (locProvider.latitude != 0.0) {
      const R = 6371e3;
      final dLat = (quest.latitude - locProvider.latitude) * pi / 180;
      final dLon = (quest.longitude - locProvider.longitude) * pi / 180;
      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(locProvider.latitude * pi / 180) * cos(quest.latitude * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      distance = R * c;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        Color typeColor;
        IconData typeIcon;
        switch (quest.questType) {
          case 'trivia':
            typeColor = AppTheme.accentGold;
            typeIcon = Icons.quiz_rounded;
            break;
          case 'discovery':
            typeColor = AppTheme.successGreen;
            typeIcon = Icons.auto_awesome;
            break;
          case 'exploration':
            typeColor = AppTheme.primaryBlue;
            typeIcon = Icons.explore_rounded;
            break;
          default:
            typeColor = Colors.white;
            typeIcon = Icons.place;
        }

        String preview = '';
        if (quest.questType == 'trivia') {
          preview = quest.question;
        } else if (quest.questType == 'discovery') {
          preview = quest.unlockedLore.isNotEmpty ? quest.unlockedLore : quest.description;
        } else {
          preview = quest.description;
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quest.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quest.locationName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: typeColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      quest.questType.toUpperCase(),
                      style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _infoChip(Icons.directions_walk, '${distance.toStringAsFixed(0)}m away', AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  _infoChip(Icons.star_rounded, '+${quest.xpReward} XP', AppTheme.accentGold),
                ],
              ),
              const SizedBox(height: 14),
              if (preview.isNotEmpty)
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentGold,
                        side: const BorderSide(color: AppTheme.accentGold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Show Route', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        if (locProvider.latitude == 0.0) return;
                        await questProvider.constructRoute(locProvider.latitude, locProvider.longitude, quest);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: AppTheme.deepNavy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Start Quest', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.of(context).pop();
                        showModalBottomSheet(
                          context: this.context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => QuestPopup(quest: quest),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _poiFilterButton({
    required IconData icon,
    required String label,
    required Color color,
    required String category,
  }) {
    final isActive = _activePoiFilter == category;
    return GestureDetector(
      onTap: () => _filterAndRouteToNearest(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.25) : AppTheme.surfaceDark.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : Colors.white12,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _filterAndRouteToNearest(String category) async {
    final locProvider = context.read<LocationProvider>();
    if (locProvider.latitude == 0.0) return;

    final userLat = locProvider.latitude;
    final userLng = locProvider.longitude;
    final userPos = LatLng(userLat, userLng);

    // Find nearest POI of this category
    double nearestDist = double.infinity;
    LatLng? nearestPos;
    String? nearestPlaceId;

    for (final marker in _poiMarkers) {
      final pid = marker.markerId.value.replaceFirst('poi_', '');
      if (_poiCategories[pid] != category) continue;

      final dist = _haversineDistance(userLat, userLng,
          marker.position.latitude, marker.position.longitude);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestPos = marker.position;
        nearestPlaceId = pid;
      }
    }

    if (nearestPos == null) {
      setState(() {
        _activePoiFilter = category;
        _filterExpanded = false;
        _emergencyRoute = {};
        _emergencyRoutePoints = [];
        _magicalPointerPoints = [];
      });
      return;
    }

    // ── Magical Pointer (straight line, always available) ──
    final Color magicColor = category == 'hospital'
        ? const Color(0xFF00E5FF)
        : category == 'restaurant'
            ? Colors.orange
            : Colors.lightBlue;

    _magicalPointerPoints = [userPos, nearestPos];
    final pointerPolylines = _buildStaticPointerPolylines(_magicalPointerPoints, magicColor);

    // ── Street Route (Directions API) ──
    Set<Polyline> streetPolyline = {};
    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$userLat,$userLng'
          '&destination=${nearestPos.latitude},${nearestPos.longitude}'
          '&mode=driving'
          '&key=$_mapsApiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>? ?? [];
        if (routes.isNotEmpty) {
          final encoded = routes[0]['overview_polyline']['points'] as String;
          final decoded = PolylinePoints.decodePolyline(encoded);
          if (decoded.isNotEmpty) {
            final streetPoints = decoded
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList();
            _emergencyRoutePoints = streetPoints;
            streetPolyline = {
              Polyline(
                polylineId: const PolylineId('street_route'),
                points: streetPoints,
                color: const Color(0xFF2196F3),
                width: 6,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                zIndex: 3,
              ),
            };
          }
        }
      }
    } catch (e) {
      print('⚠️ Directions API error: $e');
    }

    setState(() {
      _activePoiFilter = category;
      _filterExpanded = false;
      _emergencyRoute = {...streetPolyline, ...pointerPolylines};
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: nearestPos,
          zoom: 16,
          tilt: 45,
        ),
      ),
    );

    // Open the nearest POI's info card after camera settles
    if (nearestPlaceId != null) {
      final displayName = category == 'hospital' ? 'Nearest Hospital'
          : category == 'restaurant' ? 'Nearest Restaurant'
          : category == 'petrol_pump' ? 'Nearest Petrol Pump'
          : 'Nearest Place';
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _showPoiDetails(nearestPlaceId!, displayName,
              lat: nearestPos!.latitude, lng: nearestPos.longitude);
        }
      });
    }
  }

  /// Build static double-stacked "Magical Pointer" polylines (no animation).
  /// Layer 1 (aura): thicker line, fixed width 12, opacity 0.15.
  /// Layer 2 (core): thin solid line, width 3.
  Set<Polyline> _buildStaticPointerPolylines(List<LatLng> points, Color magicColor) {
    if (points.length < 2) return {};

    return {
      // Layer 1: Aura (bottom, fixed width, low opacity)
      Polyline(
        polylineId: const PolylineId('magical_pointer_aura'),
        points: points,
        width: 12,
        color: magicColor.withOpacity(0.15),
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        zIndex: 1,
      ),
      // Layer 2: Core (top, thin solid line)
      Polyline(
        polylineId: const PolylineId('magical_pointer_core'),
        points: points,
        width: 3,
        color: magicColor,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        zIndex: 2,
      ),
    };
  }

  /// Build sparkle markers along the straight magical pointer line.
  /// Interpolates points along the line, then shifts with _sparklePhase for marquee.
  Set<Marker> _buildSparkleMarkers(List<LatLng> linePoints) {
    if (linePoints.length < 2 || _sparkleIcon == null) return {};

    // Interpolate ~20 evenly spaced points along the straight line
    const totalSteps = 20;
    final start = linePoints.first;
    final end = linePoints.last;
    final List<LatLng> interpolated = [];
    for (int s = 0; s <= totalSteps; s++) {
      final t = s / totalSteps;
      interpolated.add(LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t,
      ));
    }

    final Set<Marker> sparkles = {};
    for (int i = _sparklePhase; i < interpolated.length; i += _sparkleSpacing) {
      sparkles.add(
        Marker(
          markerId: MarkerId('sparkle_$i'),
          position: interpolated[i],
          icon: _sparkleIcon!,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndex: 4,
        ),
      );
    }
    return sparkles;
  }

  /// Fetch street-level directions from user location to a destination.
  Future<void> _fetchDirectionsRoute(double destLat, double destLng) async {
    final locProvider = context.read<LocationProvider>();
    if (locProvider.latitude == 0.0) return;

    final userLat = locProvider.latitude;
    final userLng = locProvider.longitude;

    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$userLat,$userLng'
          '&destination=$destLat,$destLng'
          '&mode=driving'
          '&key=$_mapsApiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List<dynamic>? ?? [];
        if (routes.isNotEmpty) {
          final encoded = routes[0]['overview_polyline']['points'] as String;
          final decoded = PolylinePoints.decodePolyline(encoded);
          if (decoded.isNotEmpty) {
            final routePoints = decoded
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList();

            // Dual-line: street route + magical pointer
            final userPos = LatLng(userLat, userLng);
            final destPos = LatLng(destLat, destLng);
            _magicalPointerPoints = [userPos, destPos];
            _emergencyRoutePoints = routePoints;

            final streetPolyline = Polyline(
              polylineId: const PolylineId('street_route'),
              points: routePoints,
              color: const Color(0xFF2196F3),
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              zIndex: 3,
            );
            final pointerPolylines = _buildStaticPointerPolylines(
              _magicalPointerPoints, AppTheme.accentGold,
            );

            setState(() {
              _emergencyRoute = {streetPolyline, ...pointerPolylines};
            });


            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(
                _boundsFromPoints(routePoints),
                80,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('⚠️ Directions route error: $e');
    }
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _clearFilter() {
    setState(() {
      _activePoiFilter = null;
      _filterExpanded = false;
      _emergencyRoute = {};
      _emergencyRoutePoints = [];
      _magicalPointerPoints = [];
    });
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
