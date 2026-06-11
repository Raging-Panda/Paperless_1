import 'package:flutter/material.dart';
import '../models/challenge.dart';

class ChallengeCard extends StatelessWidget {
  final ChallengeDefinition challenge;
  final int currentProgress;
  final bool isCompleted;
  final bool isCollected;
  final VoidCallback? onCollect;

  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.currentProgress,
    required this.isCompleted,
    required this.isCollected,
    this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        (currentProgress / challenge.goalValue).clamp(0.0, 1.0);
    final accentColor = isCompleted
        ? (isCollected ? Colors.green : Colors.amber)
        : Colors.deepPurpleAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted && !isCollected
              ? Colors.amber.withValues(alpha: 0.6)
              : Colors.white12,
          width: isCompleted && !isCollected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Icon(challenge.icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      challenge.description,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isCollected)
                const Icon(Icons.check_circle, color: Colors.green, size: 22)
              else if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    '?? Reward',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Progress bar ─────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currentProgress.clamp(0, challenge.goalValue)} / ${challenge.goalValue}',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              if (isCompleted && !isCollected) ...[
                GestureDetector(
                  onTap: onCollect,
                  child: const Row(
                    children: [
                      Text(
                        'Collect Reward',
                        style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios,
                          size: 11, color: Colors.amber),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
