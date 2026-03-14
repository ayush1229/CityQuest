import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/models/lore_entry.dart';
import 'package:cityquest/providers/lore_provider.dart';

class LoreScreen extends StatefulWidget {
  const LoreScreen({super.key});

  @override
  State<LoreScreen> createState() => _LoreScreenState();
}

class _LoreScreenState extends State<LoreScreen> {
  String _activeFilter = 'all'; // 'all', 'landmark', 'trivia', 'discovery', 'exploration'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoreProvider>().loadLoreEntries();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'trivia':
        return Icons.quiz_rounded;
      case 'exploration':
        return Icons.explore_rounded;
      case 'discovery':
        return Icons.auto_awesome;
      default:
        return Icons.place_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'trivia':
        return AppTheme.accentGold;
      case 'exploration':
        return AppTheme.primaryBlue;
      case 'discovery':
        return AppTheme.successGreen;
      default:
        return AppTheme.textSecondary;
    }
  }

  List<LoreEntry> _applyFilters(List<LoreEntry> entries) {
    List<LoreEntry> filtered = entries;

    // Apply type filter
    if (_activeFilter == 'landmark') {
      filtered = filtered.where((e) => e.isHardcoded).toList();
    } else if (_activeFilter != 'all') {
      filtered = filtered.where((e) => e.questType == _activeFilter && !e.isHardcoded).toList();
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((e) =>
          e.title.toLowerCase().contains(query) ||
          e.locationName.toLowerCase().contains(query) ||
          e.description.toLowerCase().contains(query)).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Lore Journal',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Consumer<LoreProvider>(
        builder: (context, loreProvider, _) {
          if (loreProvider.isLoading && loreProvider.entries.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
          }

          if (loreProvider.entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_rounded, size: 64, color: AppTheme.textSecondary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No lore discovered yet.\nComplete quests to unlock stories!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          final filteredEntries = _applyFilters(loreProvider.entries);

          // Counts for filter badges
          final allCount = loreProvider.entries.length;
          final landmarkCount = loreProvider.entries.where((e) => e.isHardcoded).length;
          final triviaCount = loreProvider.entries.where((e) => e.questType == 'trivia' && !e.isHardcoded).length;
          final discoveryCount = loreProvider.entries.where((e) => e.questType == 'discovery' && !e.isHardcoded).length;
          final explorationCount = loreProvider.entries.where((e) => e.questType == 'exploration' && !e.isHardcoded).length;

          return Column(
            children: [
              // ── Search Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search places, stories...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary.withOpacity(0.6)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.cardDark,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.accentGold, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // ── Filter Chips ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All', allCount, Colors.white70),
                    const SizedBox(width: 8),
                    _buildFilterChip('landmark', '★ Landmarks', landmarkCount, AppTheme.accentGold),
                    const SizedBox(width: 8),
                    _buildFilterChip('trivia', 'Trivia', triviaCount, AppTheme.accentGold),
                    const SizedBox(width: 8),
                    _buildFilterChip('discovery', 'Discovery', discoveryCount, AppTheme.successGreen),
                    const SizedBox(width: 8),
                    _buildFilterChip('exploration', 'Explore', explorationCount, AppTheme.primaryBlue),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Lore List ──
              Expanded(
                child: filteredEntries.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No results for "$_searchQuery"'
                              : 'No entries in this category.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.accentGold,
                        onRefresh: () => loreProvider.loadLoreEntries(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: filteredEntries.length,
                          itemBuilder: (context, index) {
                            final entry = filteredEntries[index];
                            return _buildLoreCard(context, entry);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label, int count, Color color) {
    final isActive = _activeFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : AppTheme.cardDark,
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.3) : Colors.white10,
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

  Widget _buildLoreCard(BuildContext context, LoreEntry entry) {
    final typeColor = _colorForType(entry.questType);
    final typeIcon = _iconForType(entry.questType);

    return Card(
      color: AppTheme.surfaceDark,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showLoreDetail(context, entry),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.locationName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.isHardcoded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                      ),
                      child: const Text(
                        '★ LANDMARK',
                        style: TextStyle(color: AppTheme.accentGold, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: typeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        entry.questType.toUpperCase(),
                        style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entry.description.isNotEmpty ? entry.description : 'No lore available for this location.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Text(
                    entry.exploredDate.isNotEmpty ? entry.exploredDate : 'Unknown date',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to read more →',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: typeColor.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoreDetail(BuildContext context, LoreEntry entry) {
    final typeColor = _colorForType(entry.questType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: typeColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_iconForType(entry.questType), color: typeColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          entry.isHardcoded ? 'LANDMARK' : entry.questType.toUpperCase(),
                          style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    entry.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.locationName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(height: 1, color: Colors.white12),
                  const SizedBox(height: 20),
                  Text(
                    entry.description.isNotEmpty
                        ? entry.description
                        : 'No detailed lore is available for this location yet. Complete more quests to discover hidden stories!',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (entry.exploredDate.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary.withOpacity(0.6)),
                        const SizedBox(width: 6),
                        Text(
                          'Explored: ${entry.exploredDate}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
