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
  final GamificationProfile updatedProfile;
  final int previousLevel;
  final List<BadgeDefinition> newlyUnlockedBadges;

  const XpAwardResult({
    required this.xpEarned,
    required this.isNewStore,
    required this.multiplierApplied,
    required this.newStreak,
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

    // ── Streak ──────────────────────────────────────────────────────────────
    final newStreak = _computeStreak(current);
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

    // ── Intermediate profile (before badge check) ────────────────────────────
    final intermediate = current.copyWith(
      totalXP: current.totalXP + totalEarned,
      currentStreak: newStreak,
      lastScanDate: _todayStr(),
      seenStores: updatedStores,
      storeScanCounts: updatedCounts,
      totalScans: current.totalScans + 1,
    );

    // ── Badge unlock check ───────────────────────────────────────────────────
    final newBadgeIds = _checkNewBadges(intermediate);
    final allBadgeIds = [...intermediate.earnedBadgeIds, ...newBadgeIds];
    final updated = intermediate.copyWith(earnedBadgeIds: allBadgeIds);

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

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  int _computeStreak(GamificationProfile profile) {
    final today = _todayStr();
    final last = profile.lastScanDate;
    if (last == null) return 1;
    if (last == today) return profile.currentStreak;
    final lastDate = DateTime.tryParse(last);
    if (lastDate == null) return 1;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final isYesterday = lastDate.year == yesterday.year &&
        lastDate.month == yesterday.month &&
        lastDate.day == yesterday.day;
    return isYesterday ? profile.currentStreak + 1 : 1;
  }

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
    // 'budget_master' is deferred until budget integration is complete.

    return newIds;
  }
}
