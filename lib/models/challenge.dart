import 'package:flutter/material.dart';

enum GoalType {
  totalScans,          // receipts scanned this week
  uniqueStores,        // different stores scanned this week
  singleAmount,        // one receipt with amount >= goalValue
  categorisedReceipts, // receipts with a category set
  notedReceipts,       // receipts with non-empty notes
  activeDays,          // distinct days scanned at least once
}

enum RewardType { xp, shield }

class ChallengeReward {
  final RewardType type;
  final int value;
  final String label; // e.g. "+50 XP" or "+1 Streak Shield"
  const ChallengeReward({required this.type, required this.value, required this.label});
}

class ChallengeDefinition {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final GoalType goalType;
  final int goalValue;
  const ChallengeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.goalType,
    required this.goalValue,
  });
}

class ChallengeCatalogue {
  ChallengeCatalogue._();
  static const List<ChallengeDefinition> all = [
    ChallengeDefinition(
      id: 'scan_5_receipts',
      title: 'Receipt Collector',
      description: 'Scan 5 receipts this week.',
      icon: Icons.receipt_long_outlined,
      goalType: GoalType.totalScans,
      goalValue: 5,
    ),
    ChallengeDefinition(
      id: 'scan_3_stores',
      title: 'Store Hopper',
      description: 'Scan at 3 different stores this week.',
      icon: Icons.store_outlined,
      goalType: GoalType.uniqueStores,
      goalValue: 3,
    ),
    ChallengeDefinition(
      id: 'big_spender',
      title: 'Big Spender',
      description: 'Log a receipt over R500.',
      icon: Icons.payments_outlined,
      goalType: GoalType.singleAmount,
      goalValue: 500,
    ),
    ChallengeDefinition(
      id: 'organised',
      title: 'Organised',
      description: 'Categorise 3 receipts this week.',
      icon: Icons.label_outlined,
      goalType: GoalType.categorisedReceipts,
      goalValue: 3,
    ),
    ChallengeDefinition(
      id: 'power_scanner',
      title: 'Power Scanner',
      description: 'Scan 7 receipts this week.',
      icon: Icons.bolt_outlined,
      goalType: GoalType.totalScans,
      goalValue: 7,
    ),
    ChallengeDefinition(
      id: 'detail_oriented',
      title: 'Detail Oriented',
      description: 'Add notes to 2 receipts this week.',
      icon: Icons.notes_outlined,
      goalType: GoalType.notedReceipts,
      goalValue: 2,
    ),
    ChallengeDefinition(
      id: 'consistent',
      title: 'Consistent',
      description: 'Scan on 3 different days this week.',
      icon: Icons.calendar_today_outlined,
      goalType: GoalType.activeDays,
      goalValue: 3,
    ),
    ChallengeDefinition(
      id: 'scan_2_stores',
      title: 'Explorer Lite',
      description: 'Scan at 2 different stores this week.',
      icon: Icons.explore_outlined,
      goalType: GoalType.uniqueStores,
      goalValue: 2,
    ),
    ChallengeDefinition(
      id: 'scan_10_receipts',
      title: 'Ultra Collector',
      description: 'Scan 10 receipts this week.',
      icon: Icons.inventory_2_outlined,
      goalType: GoalType.totalScans,
      goalValue: 10,
    ),
  ];
}

class WeeklyChallengeProgress {
  final int weekNumber;
  final Map<String, int> progress;      // challengeId → current value
  final List<String> completedIds;      // challenges completed this week
  final List<String> collectedIds;      // rewards already claimed
  final List<String> weeklySeenStores;  // normalised stores scanned this week
  final List<String> weeklyActiveDays;  // "YYYY-MM-DD" dates scanned this week

  const WeeklyChallengeProgress({
    required this.weekNumber,
    this.progress = const {},
    this.completedIds = const [],
    this.collectedIds = const [],
    this.weeklySeenStores = const [],
    this.weeklyActiveDays = const [],
  });

  factory WeeklyChallengeProgress.newWeek(int weekNumber) =>
      WeeklyChallengeProgress(weekNumber: weekNumber);

  factory WeeklyChallengeProgress.fromFirestore(Map<String, dynamic> data) =>
      WeeklyChallengeProgress(
        weekNumber: (data['weekNumber'] as num?)?.toInt() ?? 0,
        progress: Map<String, int>.from(
          (data['progress'] as Map?)
                  ?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ??
              {},
        ),
        completedIds: List<String>.from(data['completedIds'] as List? ?? []),
        collectedIds: List<String>.from(data['collectedIds'] as List? ?? []),
        weeklySeenStores:
            List<String>.from(data['weeklySeenStores'] as List? ?? []),
        weeklyActiveDays:
            List<String>.from(data['weeklyActiveDays'] as List? ?? []),
      );

  Map<String, dynamic> toFirestore() => {
        'weekNumber': weekNumber,
        'progress': progress,
        'completedIds': completedIds,
        'collectedIds': collectedIds,
        'weeklySeenStores': weeklySeenStores,
        'weeklyActiveDays': weeklyActiveDays,
      };

  WeeklyChallengeProgress copyWith({
    Map<String, int>? progress,
    List<String>? completedIds,
    List<String>? collectedIds,
    List<String>? weeklySeenStores,
    List<String>? weeklyActiveDays,
  }) =>
      WeeklyChallengeProgress(
        weekNumber: weekNumber,
        progress: progress ?? this.progress,
        completedIds: completedIds ?? this.completedIds,
        collectedIds: collectedIds ?? this.collectedIds,
        weeklySeenStores: weeklySeenStores ?? this.weeklySeenStores,
        weeklyActiveDays: weeklyActiveDays ?? this.weeklyActiveDays,
      );

  int getProgress(String id) => progress[id] ?? 0;
  bool isCompleted(String id) => completedIds.contains(id);
  bool isCollected(String id) => collectedIds.contains(id);
  int get pendingRewardCount =>
      completedIds.where((id) => !collectedIds.contains(id)).length;
}
