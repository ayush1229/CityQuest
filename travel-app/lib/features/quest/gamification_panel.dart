import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cityquest/core/theme/app_theme.dart';

/// RPG-themed Gamification Panel — bottom sheet with Leaderboard + Daily Challenges.
/// Pass [isTraveling] to gate challenges. Debug toggle in top-right corner.
class GamificationPanel extends StatefulWidget {
  final bool isTraveling;

  const GamificationPanel({super.key, this.isTraveling = false});

  /// Show this panel as a bottom sheet
  static void show(BuildContext context, {bool isTraveling = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GamificationPanel(isTraveling: isTraveling),
    );
  }

  @override
  State<GamificationPanel> createState() => _GamificationPanelState();
}

class _GamificationPanelState extends State<GamificationPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _isTraveling;

  // Debug tap counter (5 taps on the shield icon to toggle)
  int _debugTapCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isTraveling = widget.isTraveling;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleDebugTap() {
    _debugTapCount++;
    if (_debugTapCount >= 5) {
      _debugTapCount = 0;
      setState(() => _isTraveling = !_isTraveling);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTraveling ? '🧪 DEBUG: Travel mode ON' : '🧪 DEBUG: Travel mode OFF',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: _isTraveling ? AppTheme.successGreen : AppTheme.errorRed,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.deepNavy,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGold.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Drag Handle ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentGold.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.emoji_events, color: AppTheme.deepNavy, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GUILD HALL',
                            style: GoogleFonts.montserrat(
                              color: AppTheme.accentGold,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          Text('Rankings & Quests',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Debug toggle (hidden — 5 taps to activate)
                    GestureDetector(
                      onTap: _handleDebugTap,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          color: AppTheme.textSecondary.withOpacity(0.3),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Tab Bar ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
                  labelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
                  unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: '⚔ LEADERBOARD'),
                    Tab(text: '🎯 CHALLENGES'),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Tab Views ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLeaderboard(scrollController),
                    _buildChallenges(scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  //  LEADERBOARD TAB
  // ══════════════════════════════════════════

  Widget _buildLeaderboard(ScrollController controller) {
    final leaderboardData = [
      _LeaderEntry(rank: 1, name: 'DragonSlayer', xp: 15000, avatar: '🐉'),
      _LeaderEntry(rank: 2, name: 'MapWalker', xp: 14200, avatar: '🗺️'),
      _LeaderEntry(rank: 3, name: 'TempleHunter', xp: 13800, avatar: '⛩️'),
      _LeaderEntry(rank: 4, name: 'CosmicRider', xp: 12500, avatar: '🌌'),
      _LeaderEntry(rank: 5, name: 'TrailBlazer', xp: 11900, avatar: '🔥'),
      _LeaderEntry(rank: 6, name: 'ShadowSeeker', xp: 11200, avatar: '🌑'),
      _LeaderEntry(rank: 7, name: 'GoldDigger', xp: 10800, avatar: '💰'),
      _LeaderEntry(rank: 8, name: 'WandererX', xp: 10300, avatar: '🧭'),
      _LeaderEntry(rank: 9, name: 'MysticMage', xp: 9800, avatar: '🧙'),
      _LeaderEntry(rank: 10, name: 'StormChaser', xp: 9200, avatar: '⛈️'),
    ];

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // Top 3 podium
        _buildPodium(leaderboardData.sublist(0, 3)),
        const SizedBox(height: 16),

        // Remaining ranks
        ...leaderboardData.sublist(3).asMap().entries.map((entry) =>
          _buildLeaderRow(entry.value, isAnimated: true, delay: entry.key * 80),
        ),

        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Expanded(child: Divider(color: Colors.white12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('• • •', style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),
              const Expanded(child: Divider(color: Colors.white12)),
            ],
          ),
        ),

        // Current user pinned at #14
        _buildLeaderRow(
          _LeaderEntry(rank: 14, name: 'You', xp: 4850, avatar: '⭐'),
          isCurrentUser: true,
        ),
      ],
    );
  }

  Widget _buildPodium(List<_LeaderEntry> top3) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.cardDark,
            const Color(0xFF1A1040),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          _buildPodiumSlot(top3[1], height: 80, medal: '🥈', color: const Color(0xFFC0C0C0)),
          // 1st place
          _buildPodiumSlot(top3[0], height: 110, medal: '🥇', color: AppTheme.accentGold),
          // 3rd place
          _buildPodiumSlot(top3[2], height: 65, medal: '🥉', color: const Color(0xFFCD7F32)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildPodiumSlot(_LeaderEntry entry, {required double height, required String medal, required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(entry.avatar, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(entry.name,
          style: GoogleFonts.montserrat(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text('${_formatXp(entry.xp)} XP',
          style: GoogleFonts.poppins(
            color: AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.08),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text('#${entry.rank}',
              style: GoogleFonts.montserrat(
                color: color.withOpacity(0.7),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderRow(_LeaderEntry entry, {bool isCurrentUser = false, bool isAnimated = false, int delay = 0}) {
    final widget = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppTheme.accentGold.withOpacity(0.1) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser ? AppTheme.accentGold.withOpacity(0.5) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('#${entry.rank}',
              style: GoogleFonts.montserrat(
                color: isCurrentUser ? AppTheme.accentGold : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(entry.avatar, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(entry.name,
              style: GoogleFonts.poppins(
                color: isCurrentUser ? AppTheme.accentGold : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: isCurrentUser ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text('${_formatXp(entry.xp)} XP',
            style: GoogleFonts.montserrat(
              color: AppTheme.accentGold,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 6),
            const Icon(Icons.arrow_upward, color: AppTheme.successGreen, size: 16),
          ],
        ],
      ),
    );

    if (isAnimated) {
      return widget.animate().fadeIn(delay: Duration(milliseconds: delay), duration: 300.ms).slideX(begin: 0.15);
    }
    if (isCurrentUser) {
      return widget.animate().fadeIn(duration: 400.ms).shimmer(
        delay: 400.ms,
        duration: 1500.ms,
        color: AppTheme.accentGold.withOpacity(0.15),
      );
    }
    return widget;
  }

  // ══════════════════════════════════════════
  //  DAILY CHALLENGES TAB
  // ══════════════════════════════════════════

  Widget _buildChallenges(ScrollController controller) {
    final challenges = [
      _ChallengeData(
        icon: Icons.camera_alt,
        title: 'Find 2 AR Artifacts',
        description: 'Capture 2 hidden artifacts using the AR scanner.',
        progress: 0,
        goal: 2,
        xpReward: 200,
        color: const Color(0xFF7C4DFF),
      ),
      _ChallengeData(
        icon: Icons.temple_hindu,
        title: 'Visit a Temple',
        description: 'Discover and check in at any temple or shrine.',
        progress: 0,
        goal: 1,
        xpReward: 150,
        color: const Color(0xFFFF6D00),
      ),
      _ChallengeData(
        icon: Icons.directions_walk,
        title: 'Walk 2 Kilometers',
        description: 'Explore the world on foot. Every step counts!',
        progress: 0,
        goal: 2000,
        xpReward: 300,
        color: const Color(0xFF00E676),
        unit: 'm',
      ),
    ];

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // Travel gate banner
        if (!_isTraveling) _buildLockedBanner(),

        // Daily challenges header
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Row(
            children: [
              const Icon(Icons.today, color: AppTheme.accentGold, size: 18),
              const SizedBox(width: 8),
              Text("Today's Quests",
                style: GoogleFonts.montserrat(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Resets in 8h',
                  style: GoogleFonts.poppins(
                    color: AppTheme.accentGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Challenge cards
        ...challenges.asMap().entries.map((entry) =>
          _buildChallengeCard(entry.value, entry.key),
        ),
      ],
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.errorRed.withOpacity(0.15),
            const Color(0xFF2A1020),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_outline, color: AppTheme.errorRed, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Challenges Locked!',
                  style: GoogleFonts.montserrat(
                    color: AppTheme.errorRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Start moving or traveling to activate daily quests.',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).shake(hz: 2, offset: const Offset(2, 0));
  }

  Widget _buildChallengeCard(_ChallengeData challenge, int index) {
    final isLocked = !_isTraveling;

    return Opacity(
      opacity: isLocked ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? Colors.white.withOpacity(0.05)
                : challenge.color.withOpacity(0.25),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isLocked ? AppTheme.lockedGrey : challenge.color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isLocked ? Icons.lock : challenge.icon,
                    color: isLocked ? AppTheme.lockedGrey : challenge.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(challenge.title,
                        style: GoogleFonts.montserrat(
                          color: isLocked ? AppTheme.lockedGrey : AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(challenge.description,
                        style: GoogleFonts.poppins(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('+${challenge.xpReward}',
                    style: GoogleFonts.montserrat(
                      color: isLocked ? AppTheme.lockedGrey : AppTheme.accentGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: challenge.goal > 0 ? challenge.progress / challenge.goal : 0,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation(
                  isLocked ? AppTheme.lockedGrey : challenge.color,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${challenge.progress}${challenge.unit != null ? challenge.unit! : ''} / ${challenge.goal}${challenge.unit != null ? challenge.unit! : ''}',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
                Text(
                  isLocked ? '🔒 Locked' : 'In Progress',
                  style: GoogleFonts.poppins(
                    color: isLocked ? AppTheme.lockedGrey : challenge.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: 150 * index),
      duration: 350.ms,
    ).slideX(begin: 0.15);
  }

  String _formatXp(int xp) {
    if (xp >= 1000) return '${(xp / 1000).toStringAsFixed(1)}k';
    return xp.toString();
  }
}

// ── Data classes ──

class _LeaderEntry {
  final int rank;
  final String name;
  final int xp;
  final String avatar;

  const _LeaderEntry({
    required this.rank,
    required this.name,
    required this.xp,
    required this.avatar,
  });
}

class _ChallengeData {
  final IconData icon;
  final String title;
  final String description;
  final int progress;
  final int goal;
  final int xpReward;
  final Color color;
  final String? unit;

  const _ChallengeData({
    required this.icon,
    required this.title,
    required this.description,
    required this.progress,
    required this.goal,
    required this.xpReward,
    required this.color,
    this.unit,
  });
}
