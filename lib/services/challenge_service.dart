import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge.dart';
import '../models/receipt.dart';

class ChallengeService {
  static final ChallengeService instance = ChallengeService._();
  ChallengeService._();

  WeeklyChallengeProgress? _cached;

  // ── Week number ────────────────────────────────────────────────────────────

  /// Returns a unique week identifier: year * 100 + week-of-year.
  static int currentWeekNumber() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final weekOfYear = (now.difference(startOfYear).inDays / 7).floor();
    return now.year * 100 + weekOfYear;
  }

  /// Days remaining until the next Monday (week reset).
  static int daysUntilReset() {
    final now = DateTime.now();
    final remaining = (8 - now.weekday) % 7;
    return remaining == 0 ? 7 : remaining;
  }

  // ── Active challenges ──────────────────────────────────────────────────────

  /// Returns the 3 challenges active for [weekNumber], rotating through the pool.
  static List<ChallengeDefinition> challengesForWeek(int weekNumber) {
    final pool = ChallengeCatalogue.all;
    final start = (weekNumber * 3) % pool.length;
    final indices = <int>[];
    for (var i = 0; indices.length < 3; i++) {
      final idx = (start + i) % pool.length;
      if (!indices.contains(idx)) indices.add(idx);
    }
    return indices.map((i) => pool[i]).toList();
  }

  List<ChallengeDefinition> getActiveChallenges() =>
      challengesForWeek(currentWeekNumber());

  // ── Progress ───────────────────────────────────────────────────────────────

  Future<WeeklyChallengeProgress> getProgress(String uid) async {
    final weekNum = currentWeekNumber();
    if (_cached != null && _cached!.weekNumber == weekNum) return _cached!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('gamification')
          .doc('weekly')
          .get();
      if (doc.exists && doc.data() != null) {
        final p = WeeklyChallengeProgress.fromFirestore(doc.data()!);
        if (p.weekNumber == weekNum) {
          _cached = p;
          return _cached!;
        }
      }
    } catch (_) {}
    // New week or no document yet
    _cached = WeeklyChallengeProgress.newWeek(weekNum);
    _persist(uid, _cached!);
    return _cached!;
  }

  Future<int> getPendingRewardCount(String uid) async {
    final progress = await getProgress(uid);
    return progress.pendingRewardCount;
  }

  /// Called after a receipt is saved. Updates progress and returns any
  /// newly completed [ChallengeDefinition]s.
  Future<List<ChallengeDefinition>> onReceiptSaved(
      String uid, Receipt receipt) async {
    final progress = await getProgress(uid);
    final active = challengesForWeek(progress.weekNumber);
    final today = _todayStr();
    final normalised = receipt.title.toLowerCase().trim();

    final updatedProg = Map<String, int>.from(progress.progress);
    final updatedStores = [...progress.weeklySeenStores];
    final updatedDays = [...progress.weeklyActiveDays];

    // Track weekly stores and days before updating challenge progress
    final isNewStoreThisWeek = !updatedStores.contains(normalised);
    final isNewDayThisWeek = !updatedDays.contains(today);
    if (isNewStoreThisWeek) updatedStores.add(normalised);
    if (isNewDayThisWeek) updatedDays.add(today);

    for (final challenge in active) {
      if (progress.isCompleted(challenge.id)) continue;
      switch (challenge.goalType) {
        case GoalType.totalScans:
          updatedProg[challenge.id] = (updatedProg[challenge.id] ?? 0) + 1;
          break;
        case GoalType.uniqueStores:
          if (isNewStoreThisWeek) {
            updatedProg[challenge.id] = (updatedProg[challenge.id] ?? 0) + 1;
          }
          break;
        case GoalType.singleAmount:
          if (receipt.amount >= challenge.goalValue) {
            updatedProg[challenge.id] = challenge.goalValue;
          }
          break;
        case GoalType.categorisedReceipts:
          if (receipt.category != null) {
            updatedProg[challenge.id] = (updatedProg[challenge.id] ?? 0) + 1;
          }
          break;
        case GoalType.notedReceipts:
          if (receipt.notes.isNotEmpty) {
            updatedProg[challenge.id] = (updatedProg[challenge.id] ?? 0) + 1;
          }
          break;
        case GoalType.activeDays:
          if (isNewDayThisWeek) {
            updatedProg[challenge.id] = (updatedProg[challenge.id] ?? 0) + 1;
          }
          break;
      }
    }

    // Detect newly completed
    final prevCompleted = progress.completedIds.toSet();
    final newlyCompleted = active
        .where((c) =>
            !prevCompleted.contains(c.id) &&
            (updatedProg[c.id] ?? 0) >= c.goalValue)
        .toList();

    final allCompleted = [
      ...progress.completedIds,
      ...newlyCompleted.map((c) => c.id),
    ];

    final updated = progress.copyWith(
      progress: updatedProg,
      completedIds: allCompleted,
      weeklySeenStores: updatedStores,
      weeklyActiveDays: updatedDays,
    );
    _cached = updated;
    _persist(uid, updated);
    return newlyCompleted;
  }

  // ── Reward ────────────────────────────────────────────────────────────────

  /// Deterministic reward for [challengeId] in [weekNumber].
  static ChallengeReward rewardFor(String challengeId, int weekNumber) {
    const rewards = [
      ChallengeReward(type: RewardType.xp, value: 25, label: '+25 XP'),
      ChallengeReward(type: RewardType.xp, value: 50, label: '+50 XP'),
      ChallengeReward(type: RewardType.xp, value: 75, label: '+75 XP'),
      ChallengeReward(type: RewardType.xp, value: 100, label: '+100 XP'),
      ChallengeReward(type: RewardType.shield, value: 1, label: '+1 Streak Shield'),
    ];
    final seed = (challengeId.hashCode ^ weekNumber).abs();
    return rewards[seed % rewards.length];
  }

  /// Marks [challengeId] as collected, persists, and returns the reward.
  Future<ChallengeReward> collectReward(String uid, String challengeId) async {
    final progress = await getProgress(uid);
    final updated = progress.copyWith(
      collectedIds: [...progress.collectedIds, challengeId],
    );
    _cached = updated;
    _persist(uid, updated);
    return rewardFor(challengeId, progress.weekNumber);
  }

  void clearCache() => _cached = null;

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _persist(String uid, WeeklyChallengeProgress progress) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('weekly')
        .set(progress.toFirestore(), SetOptions(merge: false))
        .ignore();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
