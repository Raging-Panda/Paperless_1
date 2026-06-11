import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/badge_definition.dart';
import '../models/gamification_profile.dart';
import '../models/receipt.dart';

/// Result returned after awarding XP for a saved receipt.
class XpAwardResult {
  final int xpEarned;
  final bool isNewStore;
  final double multiplierApplied;
  final int newStreak;
  final bool shieldUsed;
  final GamificationProfile updatedProfile;
  final int previousLevel;
  final List<BadgeDefinition> newlyUnlockedBadges;

  const XpAwardResult({
    required this.xpEarned,
    required this.isNewStore,
    required this.multiplierApplied,
    required this.newStreak,
    required this.shieldUsed,
    required this.updatedProfile,
    required this.previousLevel,
    this.newlyUnlockedBadges = const [],
  });

  bool get leveledUp => updatedProfile.level > previousLevel;

  bool get tieredUp =>
      leveledUp &&
      updatedProfile.tier != GamificationProfile.tierForLevel(previousLevel);

  /// Short human-readable summary, e.g. "+18 XP · New store! · 1.5x streak"
  String get message {
    final parts = <String>['+$xpEarned XP'];
    if (shieldUsed) parts.add('Shield saved your streak!');
    if (isNewStore) parts.add('New store!');
    if (multiplierApplied > 1.0) {
      final label = multiplierApplied == multiplierApplied.truncateToDouble()
          ? '${multiplierApplied.toInt()}x streak'
          : '${multiplierApplied}x streak';
      parts.add(label);
    }
    return parts.join(' · ');
  }
}

class GamificationService {
  static const int baseXPPerScan = 10;

  /// Quality bonus XP values (applied before streak multiplier).
  static const int _categoryBonus = 5;
  static const int _notesBonus = 3;
  static const int _photoBonus = 5;

  /// New-store flat bonus (applied after streak multiplier).
  static const int _newStoreBonus = 15;

  static final GamificationService instance = GamificationService._();
  GamificationService._();

  GamificationProfile? _cached;

  Future<GamificationProfile> getProfile(String uid) async {
    if (_cached != null) return _cached!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('gamification')
          .doc('profile')
          .get();
      _cached = doc.exists && doc.data() != null
          ? GamificationProfile.fromFirestore(doc.data()!)
          : GamificationProfile.empty();
    } catch (_) {
      _cached = GamificationProfile.empty();
    }
    return _cached!;
  }

  /// Awards flat XP (e.g. for challenge completion). Does not update streak.
  Future<GamificationProfile> awardXP(String uid, int xp) async {
    final current = await getProfile(uid);
    final updated = current.copyWith(totalXP: current.totalXP + xp);
    _cached = updated;
    _persist(uid, updated);
    return updated;
  }

  /// Called when a new receipt is saved. Applies all bonuses and returns a
  /// detailed [XpAwardResult] including any newly unlocked badges.
  Future<XpAwardResult> onReceiptSaved(String uid, Receipt receipt) async {
    final current = await getProfile(uid);
    final previousLevel = current.level;

    // ── Streak + shield logic ────────────────────────────────────────────────
    final today = _todayStr();
    final last = current.lastScanDate;
    int newStreak;
    bool shieldUsed = false;

    if (last == null) {
      newStreak = 1;
    } else if (last == today) {
      newStreak = current.currentStreak; // already scanned today
    } else {
      final now = DateTime.now();
      final yesterdayStr = _dateStrOf(now.subtract(const Duration(days: 1)));
      final twoDaysAgoStr = _dateStrOf(now.subtract(const Duration(days: 2)));

      if (last == yesterdayStr) {
        newStreak = current.currentStreak + 1;
      } else if (last == twoDaysAgoStr && current.streakShields > 0) {
        // Shield absorbs exactly one missed day
        newStreak = current.currentStreak + 1;
        shieldUsed = true;
      } else {
        newStreak = 1;
      }
    }

    final double multiplier = _multiplierForStreak(newStreak);

    // ── New store ────────────────────────────────────────────────────────────
    final normalised = receipt.title.toLowerCase().trim();
    final isNewStore = !current.seenStores.contains(normalised);
    final updatedStores = isNewStore
        ? [...current.seenStores, normalised]
        : current.seenStores;

    // ── Store scan counts ────────────────────────────────────────────────────
    final updatedCounts = Map<String, int>.from(current.storeScanCounts);
    updatedCounts[normalised] = (updatedCounts[normalised] ?? 0) + 1;

    // ── Quality bonus ────────────────────────────────────────────────────────
    int qualityBonus = 0;
    if (receipt.category != null) qualityBonus += _categoryBonus;
    if (receipt.notes.isNotEmpty) qualityBonus += _notesBonus;
    if (receipt.photoUrl != null) qualityBonus += _photoBonus;

    // ── XP calculation ───────────────────────────────────────────────────────
    final xpFromScan = ((baseXPPerScan + qualityBonus) * multiplier).round();
    final storeBonus = isNewStore ? _newStoreBonus : 0;
    final totalEarned = xpFromScan + storeBonus;

    // ── Intermediate profile (before badge/shield-grant check) ───────────────
    final intermediate = current.copyWith(
      totalXP: current.totalXP + totalEarned,
      currentStreak: newStreak,
      lastScanDate: today,
      seenStores: updatedStores,
      storeScanCounts: updatedCounts,
      totalScans: current.totalScans + 1,
      streakShields: current.streakShields - (shieldUsed ? 1 : 0),
    );

    // ── Badge unlock check ───────────────────────────────────────────────────
    final newBadgeIds = _checkNewBadges(intermediate);
    final allBadgeIds = [...intermediate.earnedBadgeIds, ...newBadgeIds];
    final withBadges = intermediate.copyWith(earnedBadgeIds: allBadgeIds);

    // ── Tier-up shield grant ─────────────────────────────────────────────────
    int shieldGrant = 0;
    if (withBadges.tier != current.tier) {
      switch (withBadges.tier) {
        case 'Silver':
          shieldGrant = 1;
          break;
        case 'Gold':
          shieldGrant = 1;
          break;
        case 'Platinum':
          shieldGrant = 1;
          break;
        case 'Eco Elite':
          shieldGrant = 2;
          break;
      }
    }

    final updated = shieldGrant > 0
        ? withBadges.copyWith(
            streakShields: withBadges.streakShields + shieldGrant)
        : withBadges;

    _cached = updated;
    _persist(uid, updated);

    final newBadges = newBadgeIds
        .map((id) => BadgeCatalogue.findById(id))
        .whereType<BadgeDefinition>()
        .toList();

    return XpAwardResult(
      xpEarned: totalEarned,
      isNewStore: isNewStore,
      multiplierApplied: multiplier,
      newStreak: newStreak,
      shieldUsed: shieldUsed,
      updatedProfile: updated,
      previousLevel: previousLevel,
      newlyUnlockedBadges: newBadges,
    );
  }

  void clearCache() => _cached = null;

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _persist(String uid, GamificationProfile profile) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('profile')
        .set(profile.toFirestore(), SetOptions(merge: true))
        .ignore();
  }

  String _todayStr() => _dateStrOf(DateTime.now());

  String _dateStrOf(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  double _multiplierForStreak(int streak) {
    if (streak >= 30) return 3.0;
    if (streak >= 7) return 2.0;
    if (streak >= 3) return 1.5;
    return 1.0;
  }

  /// Returns IDs of badges newly earned by [profile] that are not yet in
  /// [profile.earnedBadgeIds]. Does NOT mutate the profile.
  List<String> _checkNewBadges(GamificationProfile profile) {
    final earned = profile.earnedBadgeIds.toSet();
    final newIds = <String>[];

    void check(String id, bool condition) {
      if (!earned.contains(id) && condition) newIds.add(id);
    }

    check('first_scan', profile.totalScans >= 1);
    check('streak_7', profile.currentStreak >= 7);
    check('streak_30', profile.currentStreak >= 30);
    check('explorer', profile.seenStores.length >= 10);
    check('loyal_regular',
        profile.storeScanCounts.values.any((c) => c >= 10));
    check('eco_warrior', profile.totalScans >= 100);
    check('green_giant', profile.totalScans >= 50);
    // 'budget_master' deferred until budget integration is complete.

    return newIds;
  }
}
