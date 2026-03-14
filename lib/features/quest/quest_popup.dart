import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/providers/user_provider.dart';
import 'package:cityquest/providers/quest_provider.dart';
import 'package:cityquest/features/quest/quest_answer_input.dart';
import 'package:cityquest/services/firebase_service.dart';
import 'package:cityquest/providers/location_provider.dart' as cityquest_loc;
import 'package:cityquest/providers/lore_provider.dart';
import 'package:cityquest/providers/settings_provider.dart';
import 'package:cityquest/models/lore_entry.dart';

class QuestPopup extends StatefulWidget {
  final QuestNode quest;

  const QuestPopup({super.key, required this.quest});

  @override
  State<QuestPopup> createState() => _QuestPopupState();
}

class _QuestPopupState extends State<QuestPopup> {
  String? _selectedAnswer;
  bool _isSubmitting = false;
  bool? _isCorrect;
  String? _unlockedLore;
  String? _errorMessage;

  void _onAnswerSelected(String answer) {
    setState(() {
      _selectedAnswer = answer;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (widget.quest.questType == 'trivia' && _selectedAnswer == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final firebaseService = FirebaseService();
    // Use the user's actual current location
    final locProvider = context.read<cityquest_loc.LocationProvider>();
    final lat = locProvider.latitude;
    final lng = locProvider.longitude;
    final devMode = context.read<SettingsProvider>().devMode;

    final response = await firebaseService.completeQuest(
      locationId: widget.quest.id,
      lat: lat,
      lng: lng,
      selectedAnswer: widget.quest.questType == 'trivia' ? _selectedAnswer : null,
      devMode: devMode,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      final userProvider = context.read<UserProvider>();
      
      // Update UI with the dynamic reward back from the server
      final xpGained = data['xp_earned'] ?? widget.quest.xpReward;
      userProvider.addXp(xpGained);
      userProvider.completeQuest(widget.quest.title);

      // Remove only this quest from the map markers (keep others)
      if (mounted) {
        context.read<QuestProvider>().removeQuest(widget.quest.id);
      }

      // Push to Lore tab in real-time
      if (mounted) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        context.read<LoreProvider>().addLoreEntry(LoreEntry(
          id: widget.quest.id,
          title: widget.quest.title,
          locationName: widget.quest.locationName,
          description: widget.quest.unlockedLore.isNotEmpty
              ? widget.quest.unlockedLore
              : widget.quest.description,
          questType: widget.quest.questType,
          exploredDate: today,
          latitude: widget.quest.latitude,
          longitude: widget.quest.longitude,
        ));
      }

      setState(() {
        _isSubmitting = false;
        _isCorrect = true;
        _unlockedLore = data['unlocked_lore'];
      });
    } else {
      setState(() {
        _isSubmitting = false;
        // If it's a trivia wrong answer, Firebase functions generally return OK but we handled it via the backend throwing an error in this specific implementation, OR we display the standard HTTP error.
        _isCorrect = false; 
        _errorMessage = response['error'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag Handle ──
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Quest Title ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.accentGold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.quest.title,
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Quest Content ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.quest.questType == 'discovery'
                      ? Colors.green.withValues(alpha: 0.3)
                      : widget.quest.questType == 'exploration'
                          ? Colors.purple.withValues(alpha: 0.3)
                          : AppTheme.primaryBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quest type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: widget.quest.questType == 'trivia'
                          ? AppTheme.accentGold.withValues(alpha: 0.15)
                          : widget.quest.questType == 'discovery'
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.quest.questType == 'trivia' ? '❓ Trivia'
                          : widget.quest.questType == 'discovery' ? '📖 Discovery'
                          : '🧭 Exploration',
                      style: TextStyle(
                        color: widget.quest.questType == 'trivia'
                            ? AppTheme.accentGold
                            : widget.quest.questType == 'discovery'
                                ? Colors.green
                                : Colors.purple,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Content based on quest type
                  if (widget.quest.questType == 'trivia')
                    Text(
                      widget.quest.question,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                    )
                  else if (widget.quest.questType == 'discovery')
                    Text(
                      widget.quest.unlockedLore.isNotEmpty 
                          ? widget.quest.unlockedLore 
                          : widget.quest.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Text(
                      widget.quest.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Answer Input (Only for Trivia) ──
            if (_isCorrect == null && widget.quest.questType == 'trivia')
              QuestAnswerInput(
                options: widget.quest.options,
                selectedAnswer: _selectedAnswer,
                onAnswerSelected: _onAnswerSelected,
              ),

            // ── Result Message ──
            if (_isCorrect != null) _buildResult(),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 24),

            // ── Submit / Close Button ──
            if (_isCorrect == null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      (widget.quest.questType != 'trivia' || _selectedAnswer != null) && !_isSubmitting ? _submit : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(widget.quest.questType == 'trivia' 
                          ? 'Submit Answer' 
                          : (widget.quest.questType == 'discovery' 
                              ? 'Check In' 
                              : 'Claim Coordinates')),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentGold,
                    side: const BorderSide(color: AppTheme.accentGold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),

            const SizedBox(height: 12),

            // ── Reward Info ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded,
                      color: AppTheme.accentGold, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Reward: +${widget.quest.xpReward} XP',
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isCorrect!
            ? AppTheme.successGreen.withValues(alpha: 0.1)
            : AppTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCorrect!
              ? AppTheme.successGreen.withValues(alpha: 0.3)
              : AppTheme.errorRed.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            _isCorrect!
                ? Icons.celebration_rounded
                : Icons.close_rounded,
            color: _isCorrect! ? AppTheme.successGreen : AppTheme.errorRed,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _isCorrect! ? 'Success!' : 'Failed!',
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _isCorrect! ? AppTheme.successGreen : AppTheme.errorRed,
            ),
          ),
          const SizedBox(height: 8),
          
          if (_isCorrect! && _unlockedLore != null && _unlockedLore!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                _unlockedLore!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0, duration: 500.ms),
            ),

          if (_isCorrect!)
            Text(
              '+${widget.quest.xpReward} XP earned',
              style: TextStyle(
                color: AppTheme.accentGold,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.5, end: 0, duration: 400.ms)
          else
            Text(
              'Attempt Failed.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
        ],
      ),
    ).animate().scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
          curve: Curves.elasticOut,
        );
  }
}
