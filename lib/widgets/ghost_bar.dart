import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'YOU'),
        _bar(progress, scheme.primary),
        const SizedBox(height: 16),
        _label(context, hasGhost ? 'GHOST (your best)' : 'NO GHOST YET'),
        _bar(ghostProgress, Colors.white24),
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
      backgroundColor: Colors.white10,
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );
}