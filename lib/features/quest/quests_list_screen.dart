import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/models/campaign.dart';
import 'package:cityquest/providers/quest_provider.dart';
import 'package:cityquest/providers/campaign_provider.dart';
import 'package:cityquest/providers/location_provider.dart';
import 'dart:math';

class QuestsListScreen extends StatefulWidget {
  const QuestsListScreen({super.key});

  @override
  State<QuestsListScreen> createState() => _QuestsListScreenState();
}

class _QuestsListScreenState extends State<QuestsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _sideQuestFilter = 'all';
  bool _campaignExpanded = false;

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

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AppTheme.deepNavy,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'QUEST LOG',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: AppTheme.accentGold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentGold,
          indicatorWeight: 3,
          labelColor: AppTheme.accentGold,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: GoogleFonts.montserrat(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1),
          unselectedLabelStyle:
              GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: '⚔️  CAMPAIGN'),
            Tab(text: '🗡️  SIDE QUESTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCampaignTab(),
          _buildSideQuestsTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1: CAMPAIGN TIMELINE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCampaignTab() {
    return Consumer<CampaignProvider>(
      builder: (context, cp, _) {
        final campaign = cp.activeCampaign;

        if (campaign == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 64, color: Colors.white12),
                const SizedBox(height: 16),
                Text(
                  'No Active Campaign',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Open the Campaign Builder from\nthe hamburger menu to start one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── Campaign Card ──
              _buildCampaignCard(campaign, cp),
              const SizedBox(height: 16),

              // ── Timeline (expanded) ──
              if (_campaignExpanded) _buildTimeline(campaign, cp),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCampaignCard(Campaign campaign, CampaignProvider cp) {
    String status;
    Color statusColor;
    final activeLevel = cp.getActiveLevel();
    final totalLevels = campaign.levels.length;
    final allComplete = campaign.levels.isNotEmpty && campaign.levels.every((l) => l.isCompleted);

    if (allComplete) {
      status = 'All Levels Complete!';
      statusColor = AppTheme.successGreen;
    } else {
      status = 'Level $activeLevel of $totalLevels';
      statusColor = AppTheme.accentGold;
    }

    return GestureDetector(
      onTap: () => setState(() => _campaignExpanded = !_campaignExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.surfaceDark,
              AppTheme.accentGold.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _campaignExpanded
                ? AppTheme.accentGold.withOpacity(0.4)
                : Colors.white10,
            width: _campaignExpanded ? 1.5 : 1,
          ),
          boxShadow: [
            if (_campaignExpanded)
              BoxShadow(
                color: AppTheme.accentGold.withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield, color: Colors.black87, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.title.isEmpty ? 'Untitled Campaign' : campaign.title,
                        style: GoogleFonts.montserrat(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${DateFormat('dd MMM').format(campaign.startDate)} — ${DateFormat('dd MMM').format(campaign.endDate)}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _campaignExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: AppTheme.accentGold, size: 26),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _statChip(Icons.flag_rounded, '${campaign.totalDestinations} stops',
                    Colors.white54),
                const SizedBox(width: 12),
                _statChip(Icons.layers, '${campaign.levels.length} levels',
                    Colors.white54),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  // ── TIMELINE ──

  Widget _buildTimeline(Campaign campaign, CampaignProvider cp) {
    final activeLevel = cp.getActiveLevel();

    return Column(
      children: List.generate(campaign.levels.length, (levelIdx) {
        final level = campaign.levels[levelIdx];
        final isLevelUnlocked = level.levelNumber <= activeLevel;
        final isActiveLevel = level.levelNumber == activeLevel;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Level Header ──
            Container(
              margin: const EdgeInsets.only(bottom: 12, top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActiveLevel
                    ? AppTheme.accentGold.withOpacity(0.12)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActiveLevel
                      ? AppTheme.accentGold.withOpacity(0.3)
                      : Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isLevelUnlocked ? Icons.shield : Icons.lock,
                    size: 16,
                    color: isActiveLevel ? AppTheme.accentGold : (isLevelUnlocked ? AppTheme.successGreen : Colors.white38),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LEVEL ${level.levelNumber}',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: isLevelUnlocked ? AppTheme.accentGold : Colors.white30,
                    ),
                  ),
                  if (level.isCompleted) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle, size: 14, color: AppTheme.successGreen),
                    const SizedBox(width: 4),
                    const Text('Complete', style: TextStyle(color: AppTheme.successGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                  if (isActiveLevel && !level.isCompleted) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                  if (!isLevelUnlocked) ...[
                    const Spacer(),
                    Text(
                      'Complete Level ${level.levelNumber - 1} to unlock',
                      style: const TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: (levelIdx * 100).ms),

            // ── Quest Nodes for this level ──
            if (level.destinations.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 16),
                child: Text(
                  'No stops planned',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...level.destinations.asMap().entries.map((entry) {
                final questIdx = entry.key;
                final quest = entry.value;
                final isQuestLocked = !isLevelUnlocked;
                final isLast = questIdx == level.destinations.length - 1;

                return _buildTimelineNode(
                  quest: quest,
                  isLocked: isQuestLocked,
                  isLast: isLast,
                  levelIdx: levelIdx,
                  questIdx: questIdx,
                  cp: cp,
                ).animate().fadeIn(
                      duration: 300.ms,
                      delay: (levelIdx * 100 + questIdx * 80).ms,
                    );
              }),
          ],
        );
      }),
    );
  }

  Widget _buildTimelineNode({
    required QuestNode quest,
    required bool isLocked,
    required bool isLast,
    required int levelIdx,
    required int questIdx,
    required CampaignProvider cp,
  }) {
    final nodeColor = isLocked ? Colors.white24 : AppTheme.accentGold;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Vertical line + dot ──
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLocked
                        ? Colors.white10
                        : AppTheme.accentGold.withOpacity(0.2),
                    border: Border.all(color: nodeColor, width: 2),
                  ),
                  child: isLocked
                      ? const Icon(Icons.lock, size: 9, color: Colors.white30)
                      : const Icon(Icons.place, size: 9, color: AppTheme.accentGold),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLocked ? Colors.white10 : AppTheme.accentGold.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),

          // ── Quest Card ──
          Expanded(
            child: GestureDetector(
              onTap: isLocked
                  ? null
                  : () {
                      // Focus on quest via map callback
                      if (cp.focusQuestCallback != null) {
                        Navigator.pop(context);
                        cp.focusQuestCallback!(quest);
                      }
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isLocked
                      ? Colors.white.withOpacity(0.03)
                      : AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isLocked
                        ? Colors.white10
                        : AppTheme.accentGold.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quest.title,
                            style: TextStyle(
                              color: isLocked
                                  ? Colors.white24
                                  : AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration:
                                  isLocked ? TextDecoration.none : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (isLocked)
                            Row(
                              children: [
                                const Icon(Icons.lock,
                                    size: 13, color: Colors.white30),
                                const SizedBox(width: 4),
                                const Text(
                                  'Level locked',
                                  style: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              quest.description.isNotEmpty
                                  ? quest.description
                                  : quest.questType.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLocked)
                      const Icon(Icons.lock, size: 18, color: Color(0x29FFFFFF))
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                size: 12, color: AppTheme.accentGold),
                            const SizedBox(width: 3),
                            Text(
                              '+${quest.xpReward}',
                              style: const TextStyle(
                                color: AppTheme.accentGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2: SIDE QUESTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSideQuestsTab() {
    return Consumer2<QuestProvider, LocationProvider>(
      builder: (context, questProvider, locProvider, _) {
        // Filter only side quests (non main-quest)
        final allSideQuests =
            questProvider.quests.where((q) => !q.isMainQuest).toList();

        List<QuestNode> filtered = _sideQuestFilter == 'all'
            ? List.from(allSideQuests)
            : allSideQuests
                .where((q) => q.questType == _sideQuestFilter)
                .toList();

        // Sort by proximity
        if (locProvider.latitude != 0.0 && locProvider.longitude != 0.0) {
          filtered.sort((a, b) {
            final dA = _haversine(locProvider.latitude, locProvider.longitude,
                a.latitude, a.longitude);
            final dB = _haversine(locProvider.latitude, locProvider.longitude,
                b.latitude, b.longitude);
            return dA.compareTo(dB);
          });
        }

        final allCount = allSideQuests.length;
        final triviaCount =
            allSideQuests.where((q) => q.questType == 'trivia').length;
        final discoveryCount =
            allSideQuests.where((q) => q.questType == 'discovery').length;
        final explorationCount =
            allSideQuests.where((q) => q.questType == 'exploration').length;

        return Column(
          children: [
            // ── Filter Chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All', allCount, Colors.white70),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                      'trivia', 'Trivia', triviaCount, AppTheme.accentGold),
                  const SizedBox(width: 8),
                  _buildFilterChip('discovery', 'Discovery', discoveryCount,
                      AppTheme.successGreen),
                  const SizedBox(width: 8),
                  _buildFilterChip('exploration', 'Explore', explorationCount,
                      AppTheme.primaryBlue),
                ],
              ),
            ),

            // ── Quest List ──
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.explore_off, size: 48, color: Colors.white12),
                          const SizedBox(height: 12),
                          Text(
                            _sideQuestFilter == 'all'
                                ? 'No side quests found.\nGo to the map and scan!'
                                : 'No ${_sideQuestFilter} quests found.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final quest = filtered[index];
                        double dist = 0;
                        if (locProvider.latitude != 0.0) {
                          dist = _haversine(
                              locProvider.latitude,
                              locProvider.longitude,
                              quest.latitude,
                              quest.longitude);
                        }
                        return _buildSideQuestCard(
                                context, quest, dist, questProvider, locProvider)
                            .animate()
                            .fadeIn(duration: 300.ms, delay: (index * 60).ms)
                            .slideX(begin: 0.05, end: 0);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSideQuestCard(BuildContext context, QuestNode quest, double dist,
      QuestProvider questProvider, LocationProvider locProvider) {
    final typeColor = _colorForType(quest.questType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconForType(quest.questType),
                    color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dist.toStringAsFixed(0)}m away',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: typeColor.withOpacity(0.3)),
                ),
                child: Text(
                  quest.questType.toUpperCase(),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '+${quest.xpReward} XP',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 34,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: AppTheme.deepNavy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('Route',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  onPressed: () async {
                    if (locProvider.latitude == 0.0) return;
                    await questProvider.constructRoute(
                      locProvider.latitude,
                      locProvider.longitude,
                      quest,
                    );
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Color _colorForType(String type) {
    switch (type) {
      case 'trivia':
        return AppTheme.accentGold;
      case 'discovery':
        return AppTheme.successGreen;
      case 'exploration':
        return AppTheme.primaryBlue;
      default:
        return Colors.white;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'trivia':
        return Icons.quiz_rounded;
      case 'discovery':
        return Icons.auto_awesome;
      case 'exploration':
        return Icons.explore_rounded;
      default:
        return Icons.place;
    }
  }

  Widget _buildFilterChip(
      String filter, String label, int count, Color color) {
    final isActive = _sideQuestFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _sideQuestFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : Colors.white12,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.white54,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.25) : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isActive ? color : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
