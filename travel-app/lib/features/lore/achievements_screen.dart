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
//  Achievement Badge Model
// ──────────────────────────────────────────

class AchievementBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int maxProgress;
  final int currentProgress;
  final Color color;

  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.maxProgress,
    this.currentProgress = 0,
    this.color = AppTheme.accentGold,
  });

  bool get isUnlocked => currentProgress >= maxProgress;
  double get progress => maxProgress > 0 ? (currentProgress / maxProgress).clamp(0.0, 1.0) : 0.0;
  String get progressLabel => '$currentProgress / $maxProgress';
}

// ──────────────────────────────────────────
//  Mock Achievement Data
// ──────────────────────────────────────────

const List<AchievementBadge> kMockAchievements = [
  AchievementBadge(
    id: 'first_steps',
    title: 'First Steps',
    description: 'Walk 1km with the app',
    icon: Icons.directions_walk,
    maxProgress: 1,
    currentProgress: 1,
    color: Color(0xFF66BB6A),
  ),
  AchievementBadge(
    id: 'tavern_regular',
    title: 'Tavern Regular',
    description: 'Visit 5 Cafes',
    icon: Icons.local_cafe,
    maxProgress: 5,
    currentProgress: 5,
    color: Color(0xFFFFCA28),
  ),
  AchievementBadge(
    id: 'scribe_apprentice',
    title: "Scribe's Apprentice",
    description: 'Capture 1 Lore Photo',
    icon: Icons.menu_book,
    maxProgress: 1,
    currentProgress: 1,
    color: Color(0xFF7C4DFF),
  ),
  AchievementBadge(
    id: 'scholar_academy',
    title: 'Scholar of the Academy',
    description: 'Visit 3 Universities',
    icon: Icons.school,
    maxProgress: 3,
    currentProgress: 2,
    color: Color(0xFF29B6F6),
  ),
  AchievementBadge(
    id: 'artifact_hunter',
    title: 'Artifact Hunter',
    description: 'Catch 5 AR Objects',
    icon: Icons.camera_alt,
    maxProgress: 5,
    currentProgress: 1,
    color: Color(0xFFFF7043),
  ),
  AchievementBadge(
    id: 'guild_master',
    title: 'Master of the Guild',
    description: 'Complete 100 Quests',
    icon: Icons.emoji_events,
    maxProgress: 100,
    currentProgress: 12,
    color: Color(0xFFAB47BC),
  ),
];

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
    final unlockedCount = kMockAchievements.where((b) => b.isUnlocked).length;

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
              Text('$unlockedCount / ${kMockAchievements.length} Unlocked',
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
          itemCount: kMockAchievements.length,
          itemBuilder: (context, index) => _buildBadgeCard(kMockAchievements[index], index),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(AchievementBadge badge, int index) {
    final unlocked = badge.isUnlocked;

    // Grayscale matrix for locked badges
    const grayscaleMatrix = ColorFilter.matrix(<double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0,      0,      0,      1, 0,
    ]);

    Widget card = Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked ? badge.color.withOpacity(0.35) : Colors.white.withOpacity(0.04),
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(color: AppTheme.accentGold.withOpacity(0.2), blurRadius: 20, spreadRadius: 1),
                BoxShadow(color: badge.color.withOpacity(0.15), blurRadius: 12),
              ]
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
                    badge.icon,
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
                    minHeight: 5,
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

          // Unlocked: verified badge
          if (unlocked)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(Icons.verified, color: badge.color, size: 16),
            ),

          // Locked: padlock overlay
          if (!unlocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, color: AppTheme.lockedGrey, size: 12),
              ),
            ),
        ],
      ),
    );

    // Wrap locked badges with grayscale + reduced opacity
    if (!unlocked) {
      card = ColorFiltered(
        colorFilter: grayscaleMatrix,
        child: Opacity(opacity: 0.5, child: card),
      );
    }

    return card.animate().fadeIn(
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
