import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/models/campaign.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/providers/campaign_provider.dart';
import 'package:cityquest/providers/location_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CampaignBuilderScreen extends StatefulWidget {
  const CampaignBuilderScreen({super.key});

  @override
  State<CampaignBuilderScreen> createState() => _CampaignBuilderScreenState();
}

class _CampaignBuilderScreenState extends State<CampaignBuilderScreen> {
  final _titleController = TextEditingController(text: 'My Epic Campaign');
  DateTimeRange? _dateRange;
  bool _isCreated = false;

  @override
  void initState() {
    super.initState();
    final cp = context.read<CampaignProvider>();
    // Resume from active or draft campaign
    if (cp.activeCampaign != null) {
      _titleController.text = cp.activeCampaign!.title;
      _dateRange = DateTimeRange(start: cp.activeCampaign!.startDate, end: cp.activeCampaign!.endDate);
      _isCreated = true;
    } else {
      // Try to load draft
      cp.loadDraft().then((draft) {
        if (draft != null && mounted) {
          cp.createCampaign(draft.title, draft.startDate, draft.endDate);
          // Restore day destinations from draft
          for (int d = 0; d < draft.days.length; d++) {
            final dayDests = draft.days[d].destinations;
            for (final dest in dayDests) {
              if (d < cp.activeCampaign!.days.length) {
                cp.addDestination(d, dest);
              }
            }
          }
          setState(() {
            _titleController.text = draft.title;
            _dateRange = DateTimeRange(start: draft.startDate, end: draft.endDate);
            _isCreated = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('💾 Draft restored! Your progress has been recovered.'),
              backgroundColor: AppTheme.cardDark,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dateRange ?? DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 2)),
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentGold,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() => _dateRange = result);
      if (_isCreated) {
        context.read<CampaignProvider>().updateDates(result.start, result.end);
      }
    }
  }

  void _createCampaign() {
    if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick your campaign dates first!')),
      );
      return;
    }
    context.read<CampaignProvider>().createCampaign(
      _titleController.text.trim().isEmpty ? 'Untitled Campaign' : _titleController.text.trim(),
      _dateRange!.start,
      _dateRange!.end,
    );
    setState(() => _isCreated = true);
  }

  Future<void> _addDestination(int dayIndex) async {
    final cp = context.read<CampaignProvider>();
    // Get context from previous day's last stop
    final previousStop = cp.getPreviousDayLastStop(dayIndex);
    // Also check current day's last stop as fallback
    final currentDayLast = cp.getLastDestinationOfDay(dayIndex);
    final contextStop = currentDayLast ?? previousStop;

    final result = await showModalBottomSheet<QuestNode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceSearchSheet(
        previousStopLat: contextStop?.latitude,
        previousStopLng: contextStop?.longitude,
        previousStopName: contextStop?.title,
      ),
    );
    if (result != null && mounted) {
      cp.addDestination(dayIndex, result);
    }
  }

  void _showClassSelection(int dayIndex) {
    final cp = context.read<CampaignProvider>();
    final previousStop = cp.getPreviousDayLastStop(dayIndex);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClassSelectionSheet(
        dayIndex: dayIndex,
        previousStopName: previousStop?.title,
        previousStopLat: previousStop?.latitude,
        previousStopLng: previousStop?.longitude,
        onClassSelected: (classType, targetArea, lat, lng) async {
          Navigator.pop(context);
          await context.read<CampaignProvider>().generateDayPlan(
            classType,
            dayIndex,
            lat,
            lng,
            targetArea: targetArea,
          );
        },
      ),
    );
  }

  Future<void> _forgeCampaign() async {
    final provider = context.read<CampaignProvider>();
    if (provider.activeCampaign == null) return;
    if (provider.activeCampaign!.totalDestinations == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one destination to your campaign!')),
      );
      return;
    }

    await provider.forgeCampaign();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚔️ Campaign forged! Your quest awaits on the map.'),
          backgroundColor: AppTheme.cardDark,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AppTheme.deepNavy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CAMPAIGN BUILDER',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: AppTheme.accentGold,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<CampaignProvider>(
        builder: (context, campaignProvider, _) {
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  // Campaign Header
                  _buildHeader(campaignProvider),
                  const SizedBox(height: 24),

                  if (!_isCreated)
                    _buildCreateButton()
                  else ...[
                    // Day Timeline
                    ...List.generate(
                      campaignProvider.activeCampaign?.days.length ?? 0,
                      (i) => _buildDayCard(
                        campaignProvider.activeCampaign!.days[i],
                        i,
                        campaignProvider,
                      ),
                    ),
                  ],
                ],
              ),

              // Forge Button
              if (_isCreated)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildForgeButton(campaignProvider),
                ),

              // Loading Overlay
              if (campaignProvider.isLoading)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.accentGold),
                        const SizedBox(height: 16),
                        Text(
                          'Consulting the Oracle...',
                          style: GoogleFonts.montserrat(
                            color: AppTheme.accentGold,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ).animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 1500.ms, color: Colors.white24),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(CampaignProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGold.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CAMPAIGN NAME',
            style: GoogleFonts.montserrat(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 2, color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            onChanged: (_) => provider.updateTitle(_titleController.text),
            style: GoogleFonts.montserrat(
              fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'Name your epic journey...',
              hintStyle: TextStyle(color: Colors.white24),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: _pickDates,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: AppTheme.accentGold),
                  const SizedBox(width: 12),
                  Text(
                    _dateRange != null
                        ? '${_formatDate(_dateRange!.start)} — ${_formatDate(_dateRange!.end)}'
                        : 'Select campaign dates...',
                    style: TextStyle(
                      color: _dateRange != null ? AppTheme.textPrimary : Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_dateRange != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_dateRange!.end.difference(_dateRange!.start).inDays + 1} days',
                        style: const TextStyle(color: AppTheme.accentGold, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: _createCampaign,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentGold.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, color: Colors.black87, size: 24),
            const SizedBox(width: 12),
            Text(
              'BEGIN CAMPAIGN',
              style: GoogleFonts.montserrat(
                fontSize: 16, fontWeight: FontWeight.w800,
                letterSpacing: 2, color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildDayCard(DayPlan day, int dayIndex, CampaignProvider provider) {
    final campaign = provider.activeCampaign!;
    final date = campaign.startDate.add(Duration(days: dayIndex));

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGold.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${day.dayNumber}',
                      style: GoogleFonts.montserrat(
                        fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black,
                      ),
                    ),
                  ),
                ),
                if (dayIndex < campaign.days.length - 1)
                  Container(
                    width: 2,
                    height: day.destinations.isEmpty ? 100 : (day.destinations.length * 70 + 120).toDouble(),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accentGold, AppTheme.accentGold.withValues(alpha: 0.2)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Day Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('DAY ${day.dayNumber}',
                        style: GoogleFonts.montserrat(
                          fontSize: 14, fontWeight: FontWeight.w800,
                          letterSpacing: 1.5, color: AppTheme.accentGold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_formatDate(date),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const Spacer(),
                      Text('${day.destinations.length} stops',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (day.destinations.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Center(
                        child: Text(
                          'No destinations yet. Add stops or summon the Oracle!',
                          style: TextStyle(color: Colors.white30, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...day.destinations.asMap().entries.map((entry) {
                      final quest = entry.value;
                      final qIndex = entry.key;
                      return GestureDetector(
                        onTap: () {
                          // Pop to map and focus on this destination
                          final cp = context.read<CampaignProvider>();
                          if (quest.latitude != 0 && quest.longitude != 0) {
                            cp.focusQuestCallback?.call(quest);
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${qIndex + 1}',
                                    style: const TextStyle(color: AppTheme.accentGold, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(quest.title,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                    if (quest.description.isNotEmpty)
                                      Text(quest.description,
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.map_outlined, size: 14, color: Colors.white30),
                              const SizedBox(width: 6),
                              Text('+${quest.xpReward} XP',
                                style: TextStyle(color: AppTheme.accentGold.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => provider.removeDestination(dayIndex, qIndex),
                                child: const Icon(Icons.close, size: 16, color: Colors.white30),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 200.ms, delay: (qIndex * 80).ms);
                    }),

                  const SizedBox(height: 12),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _addDestination(dayIndex),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_location_alt, size: 16, color: AppTheme.accentGold.withValues(alpha: 0.7)),
                                const SizedBox(width: 6),
                                Text('Add Stop',
                                  style: TextStyle(color: AppTheme.accentGold.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _showClassSelection(dayIndex),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade700.withValues(alpha: 0.4),
                                Colors.deepPurple.shade900.withValues(alpha: 0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.purple.shade400.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_fix_high, size: 16, color: Colors.purple.shade200),
                              const SizedBox(width: 6),
                              Text('Oracle',
                                style: TextStyle(color: Colors.purple.shade200, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (dayIndex * 150).ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildForgeButton(CampaignProvider provider) {
    final totalDests = provider.activeCampaign?.totalDestinations ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, AppTheme.deepNavy.withValues(alpha: 0.95), AppTheme.deepNavy],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: GestureDetector(
        onTap: provider.isLoading ? null : _forgeCampaign,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: totalDests > 0 ? AppTheme.goldGradient : null,
            color: totalDests > 0 ? null : Colors.white12,
            borderRadius: BorderRadius.circular(16),
            boxShadow: totalDests > 0 ? [
              BoxShadow(
                color: AppTheme.accentGold.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, size: 22, color: totalDests > 0 ? Colors.black87 : Colors.white24),
              const SizedBox(width: 12),
              Text(
                'FORGE CAMPAIGN',
                style: GoogleFonts.montserrat(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: totalDests > 0 ? Colors.black87 : Colors.white24,
                ),
              ),
              if (totalDests > 0) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$totalDests stops',
                    style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }
}

// ═══════════════════════════════════════════
//  CLASS SELECTION MODAL (Upgraded with Target Area)
// ═══════════════════════════════════════════

class _ClassSelectionSheet extends StatefulWidget {
  final int dayIndex;
  final String? previousStopName;
  final double? previousStopLat;
  final double? previousStopLng;
  final Function(String classType, String targetArea, double lat, double lng) onClassSelected;

  const _ClassSelectionSheet({
    required this.dayIndex,
    required this.onClassSelected,
    this.previousStopName,
    this.previousStopLat,
    this.previousStopLng,
  });

  @override
  State<_ClassSelectionSheet> createState() => _ClassSelectionSheetState();
}

class _ClassSelectionSheetState extends State<_ClassSelectionSheet> {
  late final TextEditingController _areaController;

  @override
  void initState() {
    super.initState();
    // Auto-fill with previous day's last stop name
    _areaController = TextEditingController(
      text: widget.previousStopName ?? '',
    );
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  void _selectClass(String classType) {
    final loc = context.read<LocationProvider>();
    // Use previous stop coords as starting point, fallback to user GPS
    final lat = widget.previousStopLat ?? loc.latitude;
    final lng = widget.previousStopLng ?? loc.longitude;
    widget.onClassSelected(classType, _areaController.text.trim(), lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            Text(
              'SUMMON THE ORACLE',
              style: GoogleFonts.montserrat(
                fontSize: 18, fontWeight: FontWeight.w800,
                letterSpacing: 2, color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 6),
            Text('AI will generate stops for Day ${widget.dayIndex + 1}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Target Destination / Area TextField
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.25)),
              ),
              child: TextField(
                controller: _areaController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'TARGET DESTINATION / AREA',
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 1.5, color: AppTheme.accentGold.withValues(alpha: 0.7),
                  ),
                  hintText: 'e.g. Shimla, Old Town, NIT Campus...',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                  prefixIcon: const Icon(Icons.location_on, color: AppTheme.accentGold, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
            if (widget.previousStopName != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.white24),
                    const SizedBox(width: 6),
                    Text(
                      'Auto-filled from Day ${widget.dayIndex}\'s last stop',
                      style: const TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),

            // Class selection label
            Align(
              alignment: Alignment.centerLeft,
              child: Text('CHOOSE YOUR CLASS',
                style: GoogleFonts.montserrat(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5, color: Colors.white38,
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildClassCard(
              icon: '⚔️',
              title: 'The Adventurer',
              description: 'Hiking trails, parks, and outdoor explorations',
              color: Colors.green.shade400,
              onTap: () => _selectClass('adventurer'),
            ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1),
            const SizedBox(height: 12),

            _buildClassCard(
              icon: '📜',
              title: 'The Scholar',
              description: 'History, monuments, museums, and ancient lore',
              color: Colors.blue.shade400,
              onTap: () => _selectClass('scholar'),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideX(begin: -0.1),
            const SizedBox(height: 12),

            _buildClassCard(
              icon: '🍗',
              title: 'The Tavern Hunter',
              description: 'Cafes, famous food, and local restaurants',
              color: Colors.orange.shade400,
              onTap: () => _selectClass('tavern_hunter'),
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideX(begin: -0.1),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard({
    required String icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.montserrat(
                      fontSize: 16, fontWeight: FontWeight.w700, color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  PLACE SEARCH SHEET (with Smart Proximity Suggestions)
// ═══════════════════════════════════════════

class _PlaceSearchSheet extends StatefulWidget {
  final double? previousStopLat;
  final double? previousStopLng;
  final String? previousStopName;

  const _PlaceSearchSheet({
    this.previousStopLat,
    this.previousStopLng,
    this.previousStopName,
  });

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  List<QuestNode> _nearbySuggestions = [];
  bool _isSearching = false;
  static const String _mapsApiKey = 'AIzaSyCZ7KPFxLqOCfTPHwumDcZyNpOcYJAHYf8';

  @override
  void initState() {
    super.initState();
    // Preload nearby suggestions if previous stop exists
    if (widget.previousStopLat != null && widget.previousStopLng != null) {
      _nearbySuggestions = context.read<CampaignProvider>()
          .fetchNearbySuggestions(widget.previousStopLat!, widget.previousStopLng!);
    }
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);

    try {
      // Bias search toward previous stop location if available, else user GPS
      final locProvider = context.read<LocationProvider>();
      final biasLat = widget.previousStopLat ?? locProvider.latitude;
      final biasLng = widget.previousStopLng ?? locProvider.longitude;

      const url = 'https://places.googleapis.com/v1/places:autocomplete';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _mapsApiKey,
        },
        body: json.encode({
          'input': query,
          'locationBias': {
            'circle': {
              'center': {'latitude': biasLat, 'longitude': biasLng},
              'radius': 50000.0,
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final suggestions = data['suggestions'] as List<dynamic>? ?? [];
        setState(() {
          _suggestions = suggestions
              .where((s) => s['placePrediction'] != null)
              .map<Map<String, dynamic>>((s) => {
                    'placeId': s['placePrediction']['placeId'] as String,
                    'text': s['placePrediction']['text']?['text'] as String? ?? '',
                    'secondary': s['placePrediction']['structuredFormat']?['secondaryText']?['text'] as String? ?? '',
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }

    setState(() => _isSearching = false);
  }

  Future<void> _selectPlace(String placeId, String name) async {
    try {
      final url = 'https://places.googleapis.com/v1/places/$placeId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Goog-Api-Key': _mapsApiKey,
          'X-Goog-FieldMask': 'id,displayName,location',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final loc = data['location'];
        final quest = QuestNode(
          id: placeId,
          title: data['displayName']?['text'] ?? name,
          latitude: (loc['latitude'] as num).toDouble(),
          longitude: (loc['longitude'] as num).toDouble(),
          isMainQuest: true,
          questType: 'exploration',
          description: 'Visit $name',
          xpReward: 75,
        );
        if (mounted) Navigator.pop(context, quest);
      }
    } catch (e) {
      debugPrint('Place details error: $e');
    }
  }

  void _selectNearbyQuest(QuestNode quest) {
    Navigator.pop(context, quest);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasNearby = _nearbySuggestions.isNotEmpty;
    final showNearby = hasNearby && _searchController.text.isEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (q) {
                setState(() {}); // Refresh to toggle nearby vs search results
                _search(q);
              },
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: widget.previousStopName != null
                    ? 'Search near ${widget.previousStopName}...'
                    : 'Search for a destination...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: AppTheme.accentGold),
                filled: true,
                fillColor: AppTheme.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Suggested Nearby (before user types) ──
          if (showNearby) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.near_me, size: 14, color: AppTheme.accentGold.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Text('SUGGESTED NEARBY',
                    style: GoogleFonts.montserrat(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 1.5, color: AppTheme.accentGold.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  if (widget.previousStopName != null)
                    Text('near ${widget.previousStopName}',
                      style: const TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _nearbySuggestions.length,
                itemBuilder: (context, index) {
                  final quest = _nearbySuggestions[index];
                  return GestureDetector(
                    onTap: () => _selectNearbyQuest(quest),
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('+${quest.xpReward} XP',
                              style: const TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(quest.title,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(quest.description,
                            style: const TextStyle(color: Colors.white30, fontSize: 10),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 200.ms, delay: (index * 80).ms).slideX(begin: 0.1);
                },
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: Container(height: 1, color: Colors.white10)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or search below', style: TextStyle(color: Colors.white24, fontSize: 11)),
                  ),
                  Expanded(child: Container(height: 1, color: Colors.white10)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── Search Results ──
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppTheme.accentGold, strokeWidth: 2),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _suggestions.length,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemBuilder: (context, index) {
                  final s = _suggestions[index];
                  return ListTile(
                    leading: Icon(Icons.location_on, color: AppTheme.accentGold.withValues(alpha: 0.7)),
                    title: Text(s['text'], style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    subtitle: (s['secondary'] as String).isNotEmpty
                        ? Text(s['secondary'], style: const TextStyle(color: Colors.white38, fontSize: 12))
                        : null,
                    onTap: () => _selectPlace(s['placeId'], s['text']),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
