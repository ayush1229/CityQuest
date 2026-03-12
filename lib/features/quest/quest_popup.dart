import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/providers/user_provider.dart';
import 'package:cityquest/features/quest/quest_answer_input.dart';

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

  void _onAnswerSelected(String answer) {
    setState(() => _selectedAnswer = answer);
  }

  Future<void> _submit() async {
    if (_selectedAnswer == null) return;

    setState(() => _isSubmitting = true);

    // Simulate backend call delay
    await Future.delayed(const Duration(milliseconds: 800));

    final correct =
        _selectedAnswer!.trim().toLowerCase() ==
        widget.quest.correctAnswer.trim().toLowerCase();

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _isCorrect = correct;
    });

    if (correct) {
      final userProvider = context.read<UserProvider>();
      userProvider.addXp(widget.quest.xpReward);
      userProvider.completeQuest(widget.quest.title);
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

            // ── Question ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                widget.quest.question,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                    ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Answer Input ──
            if (_isCorrect == null)
              QuestAnswerInput(
                options: widget.quest.options,
                selectedAnswer: _selectedAnswer,
                onAnswerSelected: _onAnswerSelected,
              ),

            // ── Result Message ──
            if (_isCorrect != null) _buildResult(),

            const SizedBox(height: 24),

            // ── Submit / Close Button ──
            if (_isCorrect == null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _selectedAnswer != null && !_isSubmitting ? _submit : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Submit Answer'),
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
            _isCorrect! ? 'Correct!' : 'Incorrect!',
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _isCorrect! ? AppTheme.successGreen : AppTheme.errorRed,
            ),
          ),
          const SizedBox(height: 8),
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
              'The correct answer was: ${widget.quest.correctAnswer}',
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
