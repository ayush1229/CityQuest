import 'package:flutter/material.dart';
import 'package:cityquest/core/theme/app_theme.dart';

class QuestAnswerInput extends StatelessWidget {
  final List<String> options;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswerSelected;

  const QuestAnswerInput({
    super.key,
    required this.options,
    required this.selectedAnswer,
    required this.onAnswerSelected,
  });

  @override
  Widget build(BuildContext context) {
    // If options are provided, show multiple-choice buttons
    if (options.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: options.map((option) {
          final isSelected = selectedAnswer == option;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onAnswerSelected(option),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accentGold.withValues(alpha: 0.15)
                        : AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentGold
                          : AppTheme.cardDark.withValues(alpha: 0.5),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppTheme.accentGold
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.accentGold
                                : AppTheme.textSecondary,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.black)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.accentGold
                                : AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    // Fallback: free-form text input
    return TextField(
      onChanged: onAnswerSelected,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: 'Type your answer...',
        hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
        filled: true,
        fillColor: AppTheme.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accentGold, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
