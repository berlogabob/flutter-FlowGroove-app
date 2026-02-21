import 'package:flutter/material.dart';

/// Widget to display song BPM with quick metronome start
class SongBPMBadge extends StatelessWidget {
  final int? bpm;
  final VoidCallback? onTap;
  final bool showLabel;

  const SongBPMBadge({
    super.key,
    this.bpm,
    this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    if (bpm == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speed,
              size: 16,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              '$bpm BPM',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.play_circle_outline,
                size: 16,
                color: Colors.blue.shade700,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
