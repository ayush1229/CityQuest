import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/models/quest_node.dart';
import 'package:cityquest/providers/location_provider.dart';
import 'package:cityquest/providers/quest_provider.dart';
import 'package:cityquest/features/quest/quest_popup.dart';

class QuestPinWidget extends StatelessWidget {
  final QuestNode quest;

  const QuestPinWidget({super.key, required this.quest});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = quest.isUnlocked;

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Pin Label ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppTheme.accentGold.withValues(alpha: 0.9)
                  : AppTheme.cardDark.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                if (isUnlocked)
                  BoxShadow(
                    color: AppTheme.accentGold.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Text(
              quest.title,
              style: TextStyle(
                color: isUnlocked ? Colors.black : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Pin Icon ──
          _buildPin(isUnlocked),
        ],
      ),
    );
  }

  Widget _buildPin(bool isUnlocked) {
    final pin = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUnlocked ? AppTheme.accentGold : AppTheme.lockedGrey,
        border: Border.all(
          color: isUnlocked
              ? AppTheme.accentGold
              : AppTheme.lockedGrey.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          if (isUnlocked)
            BoxShadow(
              color: AppTheme.accentGold.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isUnlocked ? Icons.place_rounded : Icons.lock_rounded,
        color: isUnlocked ? Colors.black : Colors.white38,
        size: 18,
      ),
    );

    if (isUnlocked) {
      return pin
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.12, 1.12),
            duration: 1200.ms,
          );
    }
    return pin;
  }

  void _handleTap(BuildContext context) {
    final locProvider = context.read<LocationProvider>();
    final questProvider = context.read<QuestProvider>();

    final distance = locProvider.distanceTo(quest.latitude, quest.longitude);

    if (distance <= 50 || quest.isUnlocked) {
      // Unlock the quest if not unlocked yet
      if (!quest.isUnlocked) {
        questProvider.unlockQuest(quest.id);
      }
      questProvider.setActiveQuest(quest);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ChangeNotifierProvider.value(
          value: questProvider,
          child: QuestPopup(quest: quest),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.directions_walk_rounded,
                  color: AppTheme.accentGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Move closer to unlock this quest (${distance.toInt()}m away)',
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
