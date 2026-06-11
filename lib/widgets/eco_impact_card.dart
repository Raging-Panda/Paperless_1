import 'package:flutter/material.dart';
import '../models/gamification_profile.dart';

class EcoImpactCard extends StatelessWidget {
  final GamificationProfile profile;
  const EcoImpactCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF00C853);
    final scans = profile.totalScans;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: green.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.eco, color: green, size: 18),
              const SizedBox(width: 6),
              const Text(
                'ECO IMPACT',
                style: TextStyle(
                  color: Color(0xFF00C853),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Stat row ───────────────────────────────────────────────────
          Row(
            children: [
              _EcoStat(
                icon: Icons.description_outlined,
                value: GamificationProfile.paperSavedLabel(scans),
                label: 'Paper saved',
                color: green,
              ),
              const SizedBox(width: 10),
              _EcoStat(
                icon: Icons.cloud_outlined,
                value: GamificationProfile.co2SavedLabel(scans),
                label: 'CO₂ avoided',
                color: Colors.lightBlue,
              ),
              const SizedBox(width: 10),
              _EcoStat(
                icon: Icons.receipt_long_outlined,
                value: '$scans',
                label: 'Receipts',
                color: Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Tagline ────────────────────────────────────────────────────
          Text(
            GamificationProfile.ecoTagline(scans),
            style: TextStyle(
              color: green.withValues(alpha: 0.75),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _EcoStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _EcoStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
