import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cityquest/core/theme/app_theme.dart';

class LoadingWidget extends StatelessWidget {
  final String message;

  const LoadingWidget({
    super.key,
    this.message = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.explore,
            size: 48,
            color: AppTheme.accentGold,
          )
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 2000.ms)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 20),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),
        ],
      ),
    );
  }
}
