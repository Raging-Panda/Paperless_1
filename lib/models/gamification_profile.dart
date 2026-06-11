import 'package:flutter/material.dart';

class GamificationProfile {
  final int totalXP;
  final int currentStreak;
  final String? lastScanDate; // "YYYY-MM-DD" date string
  final List<String> seenStores; // normalised (lowercase, trimmed) store names

  const GamificationProfile({
    required this.totalXP,
    this.currentStreak = 0,
    this.lastScanDate,
    this.seenStores = const [],
  });

  factory GamificationProfile.empty() => const GamificationProfile(totalXP: 0);

  factory GamificationProfile.fromFirestore(Map<String, dynamic> data) =>
      GamificationProfile(
        totalXP: (data['totalXP'] as num?)?.toInt() ?? 0,
        currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
        lastScanDate: data['lastScanDate'] as String?,
        seenStores: List<String>.from(data['seenStores'] as List? ?? []),
      );

  Map<String, dynamic> toFirestore() => {
        'totalXP': totalXP,
        'currentStreak': currentStreak,
        'lastScanDate': lastScanDate,
        'seenStores': seenStores,
      };

  GamificationProfile copyWith({
    int? totalXP,
    int? currentStreak,
    String? lastScanDate,
    List<String>? seenStores,
  }) =>
      GamificationProfile(
        totalXP: totalXP ?? this.totalXP,
        currentStreak: currentStreak ?? this.currentStreak,
        lastScanDate: lastScanDate ?? this.lastScanDate,
        seenStores: seenStores ?? this.seenStores,
      );

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

  /// Streak multiplier applied to (base + quality) XP.
  double get streakMultiplier {
    if (currentStreak >= 30) return 3.0;
    if (currentStreak >= 7) return 2.0;
    if (currentStreak >= 3) return 1.5;
    return 1.0;
  }

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

  /// Returns the tier name for a given level (mirrors the [tier] getter).
  static String tierForLevel(int level) {
    if (level <= 5) return 'Bronze';
    if (level <= 10) return 'Silver';
    if (level <= 20) return 'Gold';
    if (level <= 30) return 'Platinum';
    return 'Eco Elite';
  }

  /// Returns the tier colour for a given tier name.
  static Color colorForTier(String name) {
    switch (name) {
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

  /// Ordered list of all tier metadata used by UI components.
  static const List<Map<String, String>> tierDescriptions = [
    {
      'name': 'Bronze',
      'levels': '1–5',
      'description': 'Welcome to Paperless! Every receipt earns XP.',
    },
    {
      'name': 'Silver',
      'levels': '6–10',
      'description': 'Streak shields unlock — protect your streak once a week.',
    },
    {
      'name': 'Gold',
      'levels': '11–20',
      'description': 'Priority access to partner discount rewards.',
    },
    {
      'name': 'Platinum',
      'levels': '21–30',
      'description': 'Exclusive profile themes and premium rewards.',
    },
    {
      'name': 'Eco Elite',
      'levels': '31+',
      'description': 'Elite status — maximum streak multiplier and all perks unlocked.',
    },
  ];
}
