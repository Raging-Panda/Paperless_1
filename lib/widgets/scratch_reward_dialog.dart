import 'package:flutter/material.dart';
import '../models/challenge.dart';

/// Shows a mystery-reveal reward dialog. Returns [true] when the user
/// collects, [false/null] if dismissed before collecting.
Future<bool> showScratchRewardDialog(
  BuildContext context, {
  required String challengeTitle,
  required ChallengeReward reward,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ScratchRewardDialog(
        challengeTitle: challengeTitle, reward: reward),
  );
  return result ?? false;
}

class _ScratchRewardDialog extends StatefulWidget {
  final String challengeTitle;
  final ChallengeReward reward;
  const _ScratchRewardDialog(
      {required this.challengeTitle, required this.reward});

  @override
  State<_ScratchRewardDialog> createState() => _ScratchRewardDialogState();
}

class _ScratchRewardDialogState extends State<_ScratchRewardDialog> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2A4A),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title ────────────────────────────────────────────────────
          Text(
            _revealed ? 'You Won!' : 'Challenge Complete!',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.challengeTitle,
            style:
                const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          // ── Animated card ────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _revealed
                ? _RewardCard(reward: widget.reward,
                    key: const ValueKey('revealed'))
                : _MysteryCard(key: const ValueKey('mystery')),
          ),
          const SizedBox(height: 20),
          // ── Action button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (!_revealed) {
                  setState(() => _revealed = true);
                } else {
                  Navigator.of(context).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _revealed
                    ? Colors.green.shade600
                    : Colors.deepPurple,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _revealed ? 'Collect!' : 'Tap to Reveal!',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MysteryCard extends StatelessWidget {
  const _MysteryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade800,
            Colors.indigo.shade700,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.5)),
      ),
      child: const Center(
        child: Text(
          '? ? ?',
          style: TextStyle(
              color: Colors.white38,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 12),
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final ChallengeReward reward;
  const _RewardCard({super.key, required this.reward});

  @override
  Widget build(BuildContext context) {
    final isXp = reward.type == RewardType.xp;
    final color = isXp ? Colors.amber : Colors.lightBlue.shade300;
    final icon = isXp ? Icons.star_rounded : Icons.shield_outlined;

    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 6),
          Text(
            reward.label,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
