import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Two bars filling against the same clock.
/// The ghost bar fills faster when your best time is faster than your estimate.
class GhostBar extends StatelessWidget {
  final double progress;
  final double ghostProgress;
  final bool hasGhost;

  const GhostBar({
    super.key,
    required this.progress,
    required this.ghostProgress,
    required this.hasGhost,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'YOU'),
        _bar(progress, AppColors.primaryBar),
        const SizedBox(height: 16),
        _label(context, hasGhost ? 'GHOST (your best)' : 'NO GHOST YET'),
        _bar(ghostProgress, AppColors.ghostBar),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelSmall),
  );

  Widget _bar(double value, Color color) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 14,
      backgroundColor: AppColors.surface,
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );
}