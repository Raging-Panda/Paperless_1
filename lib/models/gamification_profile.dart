import 'package:flutter/material.dart';

class GamificationProfile {
  final int totalXP;

  const GamificationProfile({required this.totalXP});

  factory GamificationProfile.empty() => const GamificationProfile(totalXP: 0);

  factory GamificationProfile.fromFirestore(Map<String, dynamic> data) =>
      GamificationProfile(totalXP: (data['totalXP'] as num?)?.toInt() ?? 0);

  Map<String, dynamic> toFirestore() => {'totalXP': totalXP};

  GamificationProfile copyWith({int? totalXP}) =>
      GamificationProfile(totalXP: totalXP ?? this.totalXP);

  /// XP required to reach level N: 50 * N * (N - 1)
  /// Level 1: 0, Level 2: 100, Level 3: 300, Level 4: 600, Level 5: 1000 …
  static int xpThresholdForLevel(int level) => 50 * level * (level - 1);

  int get level {
    int l = 1;
    while (xpThresholdForLevel(l + 1) <= totalXP) {
      l++;
    }
    return l;
  }

  int get xpInCurrentLevel => totalXP - xpThresholdForLevel(level);

  int get xpForNextLevel =>
      xpThresholdForLevel(level + 1) - xpThresholdForLevel(level);

  double get levelProgress =>
      xpForNextLevel > 0 ? (xpInCurrentLevel / xpForNextLevel).clamp(0.0, 1.0) : 1.0;

  String get tier {
    final l = level;
    if (l <= 5) return 'Bronze';
    if (l <= 10) return 'Silver';
    if (l <= 20) return 'Gold';
    if (l <= 30) return 'Platinum';
    return 'Eco Elite';
  }

  Color get tierColor {
    switch (tier) {
      case 'Bronze':
        return const Color(0xFFCD7F32);
      case 'Silver':
        return const Color(0xFFC0C0C0);
      case 'Gold':
        return const Color(0xFFFFD700);
      case 'Platinum':
        return const Color(0xFFE5E4E2);
      case 'Eco Elite':
        return const Color(0xFF00C853);
      default:
        return Colors.grey;
    }
  }
}
