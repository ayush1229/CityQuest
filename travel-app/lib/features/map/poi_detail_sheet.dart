import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cityquest/core/theme/app_theme.dart';

/// A Google Maps-style bottom sheet that shows static place details
/// when a user taps on a Point of Interest on the map.
class PoiDetailSheet extends StatefulWidget {
  final String placeName;
  final String placeId;
  final double? lat;
  final double? lng;
  final VoidCallback? onDirections;

  const PoiDetailSheet({
    super.key,
    required this.placeName,
    required this.placeId,
    this.lat,
    this.lng,
    this.onDirections,
  });

  @override
  State<PoiDetailSheet> createState() => _PoiDetailSheetState();
}

class _PoiDetailSheetState extends State<PoiDetailSheet> {
  static String get _mapsApiKey => dotenv.env['MAPS_API_KEY'] ?? '';
  _PoiData? _poiData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLivePlaceDetails();
  }

  Future<void> _fetchLivePlaceDetails() async {
    if (widget.placeId.isEmpty || widget.placeId.startsWith('poi_')) {
      if (mounted) {
        setState(() {
          _poiData = _getStaticPoiData(widget.placeName);
          _isLoading = false;
        });
      }
      return;
    }

    // Check if this is a valid Google Place ID (starts with ChI or contains /)
    final isGoogleId = widget.placeId.startsWith('ChI') || widget.placeId.contains('/');

    if (isGoogleId) {
      // ── Tier 1: Direct Place Details lookup ──
      final success = await _fetchByPlaceId(widget.placeId);
      if (success) return;
    }

    // ── Tier 2: Nearby Search by lat/lng ──
    if (widget.lat != null && widget.lng != null) {
      final nearbySuccess = await _fetchNearbyPlace(widget.lat!, widget.lng!);
      if (nearbySuccess) return;
    }

    // ── Tier 3: Generated description card ──
    if (mounted) {
      setState(() {
        _poiData = _PoiData(
          category: 'QUEST LOCATION',
          categoryIcon: Icons.explore,
          priceLevel: '',
          rating: 0,
          reviewCount: 0,
          isOpen: true,
          closesAt: '',
          hasBooking: false,
          hasPhone: false,
          themeColor: AppTheme.accentGold,
          address: widget.lat != null && widget.lng != null
              ? '${widget.lat!.toStringAsFixed(4)}, ${widget.lng!.toStringAsFixed(4)}'
              : 'Coordinates not available',
          phone: '',
          website: '',
          hours: 'Open area — visit anytime',
          imageUrls: ['Exterior'],
          imageLabels: ['Quest Location'],
          reviews: [],
        );
        _isLoading = false;
      });
    }
  }

  /// Fetch place details by a known Google Place ID.
  Future<bool> _fetchByPlaceId(String placeId) async {
    final url = 'https://places.googleapis.com/v1/places/$placeId';
    final fields = [
      'id', 'displayName', 'formattedAddress', 'regularOpeningHours', 'businessStatus',
      'nationalPhoneNumber', 'websiteUri', 'rating', 'userRatingCount',
      'reviews', 'photos', 'primaryType', 'priceLevel'
    ].join(',');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Goog-Api-Key': _mapsApiKey,
          'X-Goog-FieldMask': fields,
        },
      );

      if (response.statusCode == 200) {
        _parsePlaceData(json.decode(response.body));
        return true;
      }
    } catch (e) {
      // Fall through to next tier
    }
    return false;
  }

  /// Find the nearest place by lat/lng using Nearby Search, then fetch its details.
  Future<bool> _fetchNearbyPlace(double lat, double lng) async {
    try {
      final nearbyUrl = 'https://places.googleapis.com/v1/places:searchNearby';
      final payload = json.encode({
        'includedTypes': ['tourist_attraction', 'park', 'museum', 'restaurant', 'cafe', 'point_of_interest'],
        'maxResultCount': 1,
        'locationRestriction': {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': 200.0,
          }
        }
      });

      final response = await http.post(
        Uri.parse(nearbyUrl),
        headers: {
          'X-Goog-Api-Key': _mapsApiKey,
          'X-Goog-FieldMask': 'places.id',
          'Content-Type': 'application/json',
        },
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data['places'] as List<dynamic>? ?? [];
        if (places.isNotEmpty) {
          final foundId = places[0]['id'] as String;
          return await _fetchByPlaceId(foundId);
        }
      }
    } catch (e) {
      // Fall through to final fallback
    }
    return false;
  }

  /// Parse Google Places API response into _PoiData and update state.
  void _parsePlaceData(Map<String, dynamic> data) {
    final displayName = data['displayName']?['text'] as String? ?? widget.placeName;
    final address = data['formattedAddress'] as String? ?? 'Address not available';
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = data['userRatingCount'] as int? ?? 0;
    final phone = data['nationalPhoneNumber'] as String? ?? '';
    final website = data['websiteUri'] as String? ?? '';
    final businessStatus = data['businessStatus'] as String? ?? 'OPERATIONAL';
    final isOpen = businessStatus == 'OPERATIONAL';
    final primaryType = data['primaryType'] as String? ?? 'Point of interest';
    
    final hoursDict = data['regularOpeningHours'] ?? {};
    final weekdayDescriptions = List<String>.from(hoursDict['weekdayDescriptions'] ?? []);
    final hoursText = weekdayDescriptions.isNotEmpty ? weekdayDescriptions.take(3).join('\n') : 'Hours not available';

    final photosList = data['photos'] as List<dynamic>? ?? [];
    final imageUrls = photosList.take(5).map((p) {
      final photoName = p['name'] as String;
      return 'https://places.googleapis.com/v1/$photoName/media?maxHeightPx=400&maxWidthPx=400&key=$_mapsApiKey';
    }).toList();

    final liveReviews = data['reviews'] as List<dynamic>? ?? [];
    final parsedReviews = liveReviews.take(5).map((r) {
      final author = r['authorAttribution']?['displayName'] ?? 'Google User';
      final text = r['text']?['text'] ?? '';
      final rRating = (r['rating'] as num?)?.toInt() ?? 5;
      final timeStr = r['relativePublishTimeDescription'] ?? '';
      return _ReviewData(
        authorName: author,
        rating: rRating,
        text: text,
        timeAgo: timeStr,
        avatarColor: Colors.blueAccent,
        photoUrl: r['authorAttribution']?['photoUri'],
      );
    }).toList();

    if (mounted) {
      setState(() {
        _poiData = _PoiData(
          category: primaryType.replaceAll('_', ' ').toUpperCase(),
          categoryIcon: Icons.place,
          priceLevel: data['priceLevel'] ?? '',
          rating: rating,
          reviewCount: reviewCount,
          isOpen: isOpen,
          closesAt: '', 
          hasBooking: false,
          hasPhone: phone.isNotEmpty,
          themeColor: AppTheme.accentGold,
          address: address,
          phone: phone,
          website: website,
          hours: hoursText,
          imageUrls: imageUrls.isEmpty ? ['Exterior'] : imageUrls,
          imageLabels: imageUrls.isEmpty ? ['No Photos'] : List.generate(imageUrls.length, (i) => 'Photo ${i + 1}'),
          reviews: parsedReviews,
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // ── Drag Handle ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              if (_isLoading)
                const SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accentGold),
                  ),
                )
              else if (_error != null || _poiData == null)
                SizedBox(
                  height: 300,
                  child: Center(
                    child: Text(_error ?? 'Could not load details', style: const TextStyle(color: Colors.white54)),
                  ),
                )
              else ...[
                // ── Image Carousel ──
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _poiData!.imageUrls.length,
                    itemBuilder: (context, index) {
                      final url = _poiData!.imageUrls[index];
                      final isNetwork = url.startsWith('http');
                      return Container(
                        width: 260,
                        margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.cardDark,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isNetwork)
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(_poiData!, index),
                            )
                          else
                            _buildPlaceholder(_poiData!, index),
                          
                          // Photo count badge
                          if (index == 0)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_library, size: 14, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_poiData!.imageUrls.length} photos',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: (index * 100).ms);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ── Place Name & Category ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.placeName,
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _poiData!.category,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (_poiData!.priceLevel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('·', style: TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(width: 8),
                          Text(
                            _poiData!.priceLevel,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Rating ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      _poiData!.rating.toStringAsFixed(1),
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ...List.generate(5, (i) {
                      if (i < _poiData!.rating.floor()) {
                        return const Icon(Icons.star, color: AppTheme.accentGold, size: 16);
                      } else if (i < _poiData!.rating.ceil() && _poiData!.rating % 1 >= 0.5) {
                        return const Icon(Icons.star_half, color: AppTheme.accentGold, size: 16);
                      }
                      return const Icon(Icons.star_border, color: Colors.white24, size: 16);
                    }),
                    const SizedBox(width: 6),
                    Text(
                      '(${_poiData!.reviewCount})',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Status (Open/Closed) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      _poiData!.isOpen ? 'Open' : 'Closed',
                      style: TextStyle(
                        color: _poiData!.isOpen ? AppTheme.successGreen : Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (_poiData!.closesAt.isNotEmpty) ...[
                      Text(
                        ' · Closes ${_poiData!.closesAt}',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Action Buttons (Google Maps-style) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildActionButton(Icons.directions, 'Directions', AppTheme.accentGold, () {
                        if (widget.onDirections != null) {
                          Navigator.pop(context);
                          widget.onDirections!();
                        }
                      }),
                      if (_poiData!.hasBooking)
                        _buildActionButton(Icons.bookmark_border, 'Save', Colors.blue.shade400, () {}),
                      if (_poiData!.hasPhone)
                        _buildActionButton(Icons.phone, 'Call', Colors.green.shade400, () {}),
                      if (_poiData!.hasBooking)
                        _buildActionButton(Icons.restaurant_menu, 'Reserve', Colors.orange.shade400, () {}),
                      _buildActionButton(Icons.share, 'Share', Colors.purple.shade300, () {}),
                      if (_poiData!.website.isNotEmpty)
                        _buildActionButton(Icons.language, 'Website', Colors.teal.shade300, () {}),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Info Section ──
              _buildInfoSection(_poiData!),

              const SizedBox(height: 20),

              // ── Reviews Section ──
              if (_poiData!.reviews.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Reviews',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ..._poiData!.reviews.asMap().entries.map((entry) {
                  return _buildReviewCard(entry.value)
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (entry.key * 150).ms)
                      .slideY(begin: 0.1, end: 0, duration: 300.ms);
                }),
              ],

              const SizedBox(height: 24),
            ], // Close else block
            ], // Close children block
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(_PoiData poiData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildInfoRow(Icons.location_on, poiData.address),
            if (poiData.hasPhone) ...[
              const Divider(color: Colors.white12, height: 20),
              _buildInfoRow(Icons.phone, poiData.phone),
            ],
            if (poiData.website.isNotEmpty) ...[
              const Divider(color: Colors.white12, height: 20),
              _buildInfoRow(Icons.language, poiData.website),
            ],
            const Divider(color: Colors.white12, height: 20),
            _buildInfoRow(Icons.access_time, poiData.hours),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.accentGold),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(_ReviewData review) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (review.photoUrl != null)
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(review.photoUrl!),
                )
              else
                CircleAvatar(
                  radius: 16,
                  backgroundColor: review.avatarColor,
                  child: Text(
                    review.authorName.isNotEmpty ? review.authorName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < review.rating ? Icons.star : Icons.star_border,
                            size: 12,
                            color: AppTheme.accentGold,
                          );
                        }),
                        const SizedBox(width: 6),
                        Text(
                          review.timeAgo,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(_PoiData poiData, int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            poiData.themeColor.withValues(alpha: 0.3),
            poiData.themeColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            poiData.categoryIcon,
            size: 48,
            color: poiData.themeColor.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(
            poiData.imageLabels.length > index ? poiData.imageLabels[index] : 'Photo',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Generates static POI data based on place name keywords
  _PoiData _getStaticPoiData(String name) {
    final lowerName = name.toLowerCase();
    final random = Random(name.hashCode);

    // Determine category from name keywords
    String category = 'Point of interest';
    IconData categoryIcon = Icons.place;
    String priceLevel = '';
    bool hasBooking = false;
    bool hasPhone = true;
    Color themeColor = AppTheme.accentGold;
    List<String> imageLabels = ['Exterior', 'Interior', 'View', 'Details'];

    if (lowerName.contains('restaurant') || lowerName.contains('dhaba') || lowerName.contains('cafe') || lowerName.contains('food') || lowerName.contains('kitchen') || lowerName.contains('pizz') || lowerName.contains('burger')) {
      category = 'Restaurant';
      categoryIcon = Icons.restaurant;
      priceLevel = ['₹', '₹₹', '₹₹₹'][random.nextInt(3)];
      hasBooking = true;
      themeColor = Colors.orange.shade400;
      imageLabels = ['Food', 'Ambience', 'Menu', 'Interior'];
    } else if (lowerName.contains('temple') || lowerName.contains('mandir') || lowerName.contains('church') || lowerName.contains('mosque') || lowerName.contains('gurudwara')) {
      category = 'Place of worship';
      categoryIcon = Icons.temple_hindu;
      priceLevel = 'Free';
      themeColor = Colors.amber.shade600;
      imageLabels = ['Front View', 'Interior', 'Architecture', 'Surroundings'];
    } else if (lowerName.contains('park') || lowerName.contains('garden')) {
      category = 'Park';
      categoryIcon = Icons.park;
      priceLevel = 'Free';
      themeColor = Colors.green.shade400;
      imageLabels = ['Entrance', 'Garden', 'Walking Path', 'Playground'];
    } else if (lowerName.contains('hotel') || lowerName.contains('resort') || lowerName.contains('lodge')) {
      category = 'Hotel';
      categoryIcon = Icons.hotel;
      priceLevel = ['₹₹', '₹₹₹', '₹₹₹₹'][random.nextInt(3)];
      hasBooking = true;
      themeColor = Colors.indigo.shade400;
      imageLabels = ['Lobby', 'Room', 'Pool', 'Exterior'];
    } else if (lowerName.contains('hospital') || lowerName.contains('clinic') || lowerName.contains('medical')) {
      category = 'Hospital';
      categoryIcon = Icons.local_hospital;
      priceLevel = '';
      themeColor = Colors.red.shade400;
      imageLabels = ['Building', 'Reception', 'Entrance', 'Facilities'];
    } else if (lowerName.contains('school') || lowerName.contains('college') || lowerName.contains('university') || lowerName.contains('institute')) {
      category = 'Educational institution';
      categoryIcon = Icons.school;
      priceLevel = '';
      themeColor = Colors.blue.shade400;
      imageLabels = ['Campus', 'Main Building', 'Library', 'Grounds'];
    } else if (lowerName.contains('shop') || lowerName.contains('store') || lowerName.contains('mall') || lowerName.contains('market')) {
      category = 'Shopping';
      categoryIcon = Icons.shopping_bag;
      priceLevel = ['₹', '₹₹'][random.nextInt(2)];
      hasBooking = false;
      themeColor = Colors.pink.shade300;
      imageLabels = ['Storefront', 'Inside', 'Products', 'Entrance'];
    } else if (lowerName.contains('museum') || lowerName.contains('gallery')) {
      category = 'Museum';
      categoryIcon = Icons.museum;
      priceLevel = '₹';
      themeColor = Colors.brown.shade400;
      imageLabels = ['Exhibit', 'Hall', 'Artifact', 'Entrance'];
    } else if (lowerName.contains('post') || lowerName.contains('office')) {
      category = 'Government office';
      categoryIcon = Icons.business;
      priceLevel = '';
      themeColor = Colors.blueGrey.shade400;
      imageLabels = ['Building', 'Counter', 'Entrance', 'Sign'];
    } else if (lowerName.contains('atm') || lowerName.contains('bank')) {
      category = 'Bank';
      categoryIcon = Icons.account_balance;
      priceLevel = '';
      themeColor = Colors.teal.shade400;
      imageLabels = ['Branch', 'ATM', 'Interior', 'Signage'];
    } else if (lowerName.contains('stadium') || lowerName.contains('ground') || lowerName.contains('sport')) {
      category = 'Sports';
      categoryIcon = Icons.sports_soccer;
      priceLevel = '';
      themeColor = Colors.green.shade600;
      imageLabels = ['Field', 'Stands', 'Entrance', 'Facilities'];
    } else if (lowerName.contains('library')) {
      category = 'Library';
      categoryIcon = Icons.local_library;
      priceLevel = 'Free';
      themeColor = Colors.deepPurple.shade300;
      imageLabels = ['Reading Hall', 'Shelves', 'Study Area', 'Entrance'];
    }

    final rating = 3.5 + (random.nextDouble() * 1.5);
    final reviewCount = 50 + random.nextInt(950);

    return _PoiData(
      category: category,
      categoryIcon: categoryIcon,
      priceLevel: priceLevel.isNotEmpty ? priceLevel : '',
      rating: rating,
      reviewCount: reviewCount,
      isOpen: random.nextBool() || DateTime.now().hour < 20,
      closesAt: '${17 + random.nextInt(5)}:00',
      hasBooking: hasBooking,
      hasPhone: hasPhone,
      themeColor: themeColor,
      address: '${random.nextInt(200) + 1}, Main Road, Hamirpur, Himachal Pradesh 177005',
      phone: '+91 ${9000000000 + random.nextInt(999999999)}',
      website: hasBooking ? 'www.${name.toLowerCase().replaceAll(' ', '')}.com' : '',
      hours: 'Mon-Sat: 9:00 AM - ${17 + random.nextInt(5)}:00 PM\nSunday: ${random.nextBool() ? "Closed" : "10:00 AM - 4:00 PM"}',
      imageUrls: imageLabels,
      imageLabels: imageLabels,
      reviews: _generateStaticReviews(name, random),
    );
  }

  List<_ReviewData> _generateStaticReviews(String placeName, Random random) {
    final reviewTemplates = [
      _ReviewData(
        authorName: 'Arjun Sharma',
        rating: 5,
        text: 'Amazing place! Visited $placeName last weekend and it exceeded my expectations. The atmosphere is wonderful and the staff is very friendly. Highly recommended for everyone!',
        timeAgo: '2 weeks ago',
        avatarColor: Colors.blue.shade700,
      ),
      _ReviewData(
        authorName: 'Priya Verma',
        rating: 4,
        text: 'Good experience overall. $placeName has a nice vibe and is well-maintained. Could improve the parking situation but otherwise a solid visit.',
        timeAgo: '1 month ago',
        avatarColor: Colors.purple.shade600,
      ),
      _ReviewData(
        authorName: 'Rahul Thakur',
        rating: 4,
        text: 'Been coming here for years. $placeName never disappoints! Great location and worth the visit. Perfect for families and friends.',
        timeAgo: '3 months ago',
        avatarColor: Colors.green.shade700,
      ),
      _ReviewData(
        authorName: 'Sneha Gupta',
        rating: 5,
        text: 'One of the best places in the area. The views around $placeName are stunning, especially during sunset. Must-visit destination!',
        timeAgo: '2 months ago',
        avatarColor: Colors.orange.shade700,
      ),
      _ReviewData(
        authorName: 'Vikram Singh',
        rating: 3,
        text: '$placeName is decent. The location is good but could use some more maintenance. Hope they improve the facilities soon.',
        timeAgo: '5 months ago',
        avatarColor: Colors.red.shade600,
      ),
    ];

    // Shuffle and return 3-5 reviews
    final shuffled = List<_ReviewData>.from(reviewTemplates)..shuffle(random);
    return shuffled.take(3 + random.nextInt(2)).toList();
  }
}

class _PoiData {
  final String category;
  final IconData categoryIcon;
  final String priceLevel;
  final double rating;
  final int reviewCount;
  final bool isOpen;
  final String closesAt;
  final bool hasBooking;
  final bool hasPhone;
  final Color themeColor;
  final String address;
  final String phone;
  final String website;
  final String hours;
  final List<String> imageUrls;
  final List<String> imageLabels;
  final List<_ReviewData> reviews;

  _PoiData({
    required this.category,
    required this.categoryIcon,
    required this.priceLevel,
    required this.rating,
    required this.reviewCount,
    required this.isOpen,
    required this.closesAt,
    required this.hasBooking,
    required this.hasPhone,
    required this.themeColor,
    required this.address,
    required this.phone,
    required this.website,
    required this.hours,
    required this.imageUrls,
    required this.imageLabels,
    required this.reviews,
  });
}

class _ReviewData {
  final String authorName;
  final int rating;
  final String text;
  final String timeAgo;
  final Color avatarColor;
  final String? photoUrl;

  _ReviewData({
    required this.authorName,
    required this.rating,
    required this.text,
    required this.timeAgo,
    required this.avatarColor,
    this.photoUrl,
  });
}
