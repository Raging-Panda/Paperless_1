import 'package:flutter/material.dart';
import '../models/gamification_profile.dart';
import '../services/gamification_service.dart';

/// Shows a level-up or tier-up dialog if [result] indicates a level crossed.
/// Safe to call regardless — returns immediately if no level-up occurred.
Future<void> showLevelUpIfNeeded(
    BuildContext context, XpAwardResult result) async {
  if (!result.leveledUp) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LevelUpDialog(result: result),
  );
}

class LevelUpDialog extends StatelessWidget {
  final XpAwardResult result;
  const LevelUpDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final profile = result.updatedProfile;
    final tierColor = profile.tierColor;
    final isTierUp = result.tieredUp;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E2A4A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: tierColor.withValues(alpha: 0.5), width: 1.5),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Icon ───────────────────────────────────────────────────────
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tierColor.withValues(alpha: 0.15),
              border:
                  Border.all(color: tierColor.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(
              isTierUp ? Icons.emoji_events_rounded : Icons.arrow_upward_rounded,
              size: 36,
              color: tierColor,
            ),
          ),
          const SizedBox(height: 16),
          // ── Title ──────────────────────────────────────────────────────
          Text(
            isTierUp ? 'New Tier Unlocked!' : 'Level Up!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          // ── Tier badge + level ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tierColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  profile.tier,
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Level ${profile.level}',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Description ────────────────────────────────────────────────
          Text(
            _description(profile, isTierUp),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white54, fontSize: 13, height: 1.5),
          ),
        ],
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              isTierUp ? "Let's Go!" : 'Awesome!',
              style: TextStyle(
                  color: tierColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  String _description(GamificationProfile profile, bool isTierUp) {
    if (isTierUp) {
      return GamificationProfile.tierDescriptions
              .firstWhere((t) => t['name'] == profile.tier,
                  orElse: () => {'description': ''})['description'] ??
          '';
    }
    final idx = GamificationProfile.tierDescriptions
        .indexWhere((t) => t['name'] == profile.tier);
    if (idx >= 0 && idx < GamificationProfile.tierDescriptions.length - 1) {
      final next = GamificationProfile.tierDescriptions[idx + 1]['name']!;
      return 'Keep scanning to reach $next!';
    }
    return "You're at the top tier. Keep scanning!";
  }
}
