import 'package:flutter/material.dart';
import '../models/gamification_profile.dart';

class StreakCard extends StatelessWidget {
  final GamificationProfile profile;
  const StreakCard({super.key, required this.profile});

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  bool get _scannedToday => profile.lastScanDate == _todayStr();
  bool get _atRisk => profile.currentStreak > 0 && !_scannedToday;

  @override
  Widget build(BuildContext context) {
    final streak = profile.currentStreak;
    final hasStreak = streak > 0;
    final atRisk = _atRisk;
    final multiplier = profile.streakMultiplier;
    final shields = profile.streakShields;

    final borderColor = atRisk
        ? Colors.amber.withValues(alpha: 0.65)
        : hasStreak
            ? Colors.orange.withValues(alpha: 0.45)
            : Colors.white12;
    final fireColor = atRisk
        ? Colors.amber
        : hasStreak
            ? Colors.orange
            : Colors.white24;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: atRisk ? 1.5 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Flame icon ────────────────────────────────────────────────
          Icon(
            hasStreak
                ? Icons.local_fire_department
                : Icons.local_fire_department_outlined,
            color: fireColor,
            size: 38,
          ),
          const SizedBox(width: 12),
          // ── Streak info ───────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasStreak) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$streak',
                        style: TextStyle(
                          color: atRisk ? Colors.amber : Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'day streak',
                        style: TextStyle(
                          color: atRisk
                              ? Colors.amber.withValues(alpha: 0.75)
                              : Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      if (multiplier > 1.0) ...[
                        const SizedBox(width: 8),
                        _MultiplierChip(multiplier: multiplier),
                      ],
                    ],
                  ),
                  if (atRisk) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 13, color: Colors.amber),
                        const SizedBox(width: 4),
                        const Text(
                          'Scan today to keep your streak!',
                          style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  const Text(
                    'Start your streak!',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Scan a receipt to begin',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          // ── Shields ───────────────────────────────────────────────────
          if (shields > 0)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined,
                    color: Colors.lightBlue.shade300, size: 20),
                const SizedBox(height: 2),
                Text(
                  '×$shields',
                  style: TextStyle(
                      color: Colors.lightBlue.shade300,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MultiplierChip extends StatelessWidget {
  final double multiplier;
  const _MultiplierChip({required this.multiplier});

  @override
  Widget build(BuildContext context) {
    final label = multiplier == multiplier.truncateToDouble()
        ? '×${multiplier.toInt()}'
        : '×$multiplier';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
