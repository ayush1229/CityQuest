import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/models/lore_entry.dart';
import 'package:cityquest/providers/lore_provider.dart';
import 'package:cityquest/providers/user_provider.dart';

// ──────────────────────────────────────────
//  Badge Model
// ──────────────────────────────────────────

class BadgeModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;
  final double progress; // 0.0 – 1.0
  final String progressLabel; // e.g. "1/3"
  final Color color;

  const BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
    this.progress = 0.0,
    this.progressLabel = '',
    this.color = AppTheme.accentGold,
  });
}

// ──────────────────────────────────────────
//  Achievements Screen
// ──────────────────────────────────────────

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<BadgeModel> _badges = [
    BadgeModel(
      id: 'first_steps',
      title: 'First Steps',
      description: 'Reach Level 2',
      icon: Icons.directions_walk,
      isUnlocked: true,
      progress: 1.0,
      progressLabel: '2/2',
      color: Color(0xFF66BB6A),
    ),
    BadgeModel(
      id: 'scholar',
      title: 'Scholar of the Ancients',
      description: 'Collect 5 Lore Entries',
      icon: Icons.auto_stories,
      isUnlocked: true,
      progress: 1.0,
      progressLabel: '5/5',
      color: Color(0xFF7C4DFF),
    ),
    BadgeModel(
      id: 'hidden_seeker',
      title: 'Hidden Seeker',
      description: 'Find 3 secret locations',
      icon: Icons.explore,
      isUnlocked: false,
      progress: 0.33,
      progressLabel: '1/3',
      color: Color(0xFF29B6F6),
    ),
    BadgeModel(
      id: 'world_traveler',
      title: 'World Traveler',
      description: 'Walk 10km with the app',
      icon: Icons.public,
      isUnlocked: false,
      progress: 0.42,
      progressLabel: '4.2/10 km',
      color: Color(0xFFFF7043),
    ),
    BadgeModel(
      id: 'tavern_master',
      title: 'Tavern Master',
      description: 'Visit 5 Restaurants/Cafes',
      icon: Icons.restaurant,
      isUnlocked: true,
      progress: 1.0,
      progressLabel: '5/5',
      color: Color(0xFFFFCA28),
    ),
    BadgeModel(
      id: 'artifact_hunter',
      title: 'Artifact Hunter',
      description: 'Capture 10 AR Artifacts',
      icon: Icons.camera_alt,
      isUnlocked: false,
      progress: 0.2,
      progressLabel: '2/10',
      color: Color(0xFFAB47BC),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final profile = userProvider.profile;

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      body: SafeArea(
        child: Column(
          children: [
            // ── XP Header ──
            _buildXpHeader(profile.level, profile.xp, profile.xpForNextLevel, profile.levelProgress, profile.levelTitle),

            const SizedBox(height: 12),

            // ── Tab Bar ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelColor: AppTheme.deepNavy,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: '📜 COLLECTED LORE'),
                  Tab(text: '🏆 ACHIEVEMENTS'),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Tab Views ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoreTab(),
                  _buildAchievementsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  XP HEADER
  // ══════════════════════════════════════════

  Widget _buildXpHeader(int level, int xp, int xpForNext, double progress, String title) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.cardDark, const Color(0xFF1A1040)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),

          // Level badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.goldGradient,
              boxShadow: [
                BoxShadow(color: AppTheme.accentGold.withOpacity(0.3), blurRadius: 12),
              ],
            ),
            child: Center(
              child: Text('$level',
                style: GoogleFonts.montserrat(
                  color: AppTheme.deepNavy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // XP bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title.toUpperCase(),
                      style: GoogleFonts.montserrat(
                        color: AppTheme.accentGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text('${_formatNum(xp)} / ${_formatNum(xpForNext)} XP',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.accentGold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ══════════════════════════════════════════
  //  COLLECTED LORE TAB
  // ══════════════════════════════════════════

  Widget _buildLoreTab() {
    final entries = context.watch<LoreProvider>().entries;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, color: AppTheme.textSecondary.withOpacity(0.3), size: 64),
            const SizedBox(height: 12),
            Text('No lore collected yet',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 14),
            ),
            Text('Complete quests to discover ancient secrets!',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _buildLoreCard(entries[index], index);
      },
    );
  }

  Widget _buildLoreCard(LoreEntry entry, int index) {
    final hasImage = entry.imagePath.isNotEmpty && File(entry.imagePath).existsSync();

    return GestureDetector(
      onTap: () => _showLoreDetail(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.file(
                  File(entry.imagePath),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1A1040),
                      AppTheme.cardDark,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getLoreIcon(entry.questType),
                    color: AppTheme.accentGold.withOpacity(0.3),
                    size: 40,
                  ),
                ),
              ),

            // Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.title,
                          style: GoogleFonts.montserrat(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(entry.questType.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            color: AppTheme.accentGold,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: AppTheme.textSecondary, size: 12),
                      const SizedBox(width: 4),
                      Text(entry.locationName,
                        style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(entry.exploredDate,
                        style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10),
                      ),
                    ],
                  ),
                  if (entry.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary.withOpacity(0.7),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: 100 * index),
      duration: 350.ms,
    ).slideY(begin: 0.1);
  }

  void _showLoreDetail(LoreEntry entry) {
    final hasImage = entry.imagePath.isNotEmpty && File(entry.imagePath).existsSync();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.deepNavy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Photo
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(entry.imagePath),
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 16),

              // Title
              Text(entry.title,
                style: GoogleFonts.montserrat(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.accentGold, size: 14),
                  const SizedBox(width: 4),
                  Text(entry.locationName,
                    style: GoogleFonts.poppins(color: AppTheme.accentGold, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(entry.exploredDate,
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white10),
              const SizedBox(height: 16),

              // Full description
              Text(entry.description,
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.7,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  ACHIEVEMENTS TAB
  // ══════════════════════════════════════════

  Widget _buildAchievementsTab() {
    final unlockedCount = _badges.where((b) => b.isUnlocked).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accentGold.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 10),
              Text('$unlockedCount / ${_badges.length} Unlocked',
                style: GoogleFonts.montserrat(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 16),

        // Badge grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: _badges.length,
          itemBuilder: (context, index) => _buildBadgeCard(_badges[index], index),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(BadgeModel badge, int index) {
    final unlocked = badge.isUnlocked;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked ? badge.color.withOpacity(0.35) : Colors.white.withOpacity(0.04),
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: unlocked
            ? [BoxShadow(color: badge.color.withOpacity(0.15), blurRadius: 16)]
            : [],
      ),
      child: Stack(
        children: [
          // Glow background for unlocked
          if (unlocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      badge.color.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (unlocked ? badge.color : AppTheme.lockedGrey).withOpacity(0.15),
                    border: Border.all(
                      color: (unlocked ? badge.color : AppTheme.lockedGrey).withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    unlocked ? badge.icon : Icons.lock,
                    color: unlocked ? badge.color : AppTheme.lockedGrey,
                    size: 26,
                  ),
                ),

                const SizedBox(height: 10),

                // Title
                Text(badge.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: unlocked ? AppTheme.textPrimary : AppTheme.lockedGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Description
                Text(badge.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: unlocked ? AppTheme.textSecondary : AppTheme.lockedGrey.withOpacity(0.6),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: badge.progress,
                    minHeight: 4,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation(
                      unlocked ? badge.color : AppTheme.lockedGrey,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Text(badge.progressLabel,
                  style: GoogleFonts.poppins(
                    color: unlocked ? badge.color.withOpacity(0.8) : AppTheme.lockedGrey.withOpacity(0.5),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Unlocked glow shimmer
          if (unlocked)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(Icons.verified, color: badge.color, size: 16),
            ),
        ],
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: 100 * index),
      duration: 350.ms,
    ).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  IconData _getLoreIcon(String questType) {
    switch (questType) {
      case 'discovery': return Icons.auto_stories;
      case 'exploration': return Icons.explore;
      case 'trivia': return Icons.quiz;
      default: return Icons.menu_book;
    }
  }

  String _formatNum(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
