import 'package:flutter/material.dart';
import '../models/badge_definition.dart';
import 'badge_widget.dart';

/// Shows a badge-unlock celebration dialog if [badges] is non-empty.
/// Safe to call with an empty list — returns immediately.
Future<void> showBadgeUnlocksIfAny(
    BuildContext context, List<BadgeDefinition> badges) async {
  if (badges.isEmpty) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BadgeUnlockDialog(badges: badges),
  );
}

class BadgeUnlockDialog extends StatelessWidget {
  final List<BadgeDefinition> badges;
  const BadgeUnlockDialog({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    final single = badges.length == 1;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2A4A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Text(
            single ? 'Badge Unlocked!' : 'Badges Unlocked!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // ── Badge list ────────────────────────────────────────────────
          ...badges.map((b) => _BadgeRow(badge: b)),
        ],
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Collect',
              style: TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final BadgeDefinition badge;
  const _BadgeRow({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          BadgeWidget(badge: badge, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.name,
                  style: TextStyle(
                    color: badge.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  badge.description,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
