import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gamification_profile.dart';
import '../models/receipt.dart';

/// Result returned after awarding XP for a saved receipt.
class XpAwardResult {
  final int xpEarned;
  final bool isNewStore;
  final double multiplierApplied;
  final int newStreak;
  final GamificationProfile updatedProfile;

  const XpAwardResult({
    required this.xpEarned,
    required this.isNewStore,
    required this.multiplierApplied,
    required this.newStreak,
    required this.updatedProfile,
  });

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
  /// detailed [XpAwardResult].
  Future<XpAwardResult> onReceiptSaved(String uid, Receipt receipt) async {
    final current = await getProfile(uid);

    // ── Streak ──────────────────────────────────────────────────────────────
    final newStreak = _computeStreak(current);
    final double multiplier = _multiplierForStreak(newStreak);

    // ── New store ────────────────────────────────────────────────────────────
    final normalised = receipt.title.toLowerCase().trim();
    final isNewStore = !current.seenStores.contains(normalised);
    final updatedStores = isNewStore
        ? [...current.seenStores, normalised]
        : current.seenStores;

    // ── Quality bonus ────────────────────────────────────────────────────────
    int qualityBonus = 0;
    if (receipt.category != null) qualityBonus += _categoryBonus;
    if (receipt.notes.isNotEmpty) qualityBonus += _notesBonus;
    if (receipt.photoUrl != null) qualityBonus += _photoBonus;

    // ── XP calculation ───────────────────────────────────────────────────────
    final xpFromScan = ((baseXPPerScan + qualityBonus) * multiplier).round();
    final storeBonus = isNewStore ? _newStoreBonus : 0;
    final totalEarned = xpFromScan + storeBonus;

    final updated = current.copyWith(
      totalXP: current.totalXP + totalEarned,
      currentStreak: newStreak,
      lastScanDate: _todayStr(),
      seenStores: updatedStores,
    );
    _cached = updated;
    _persist(uid, updated);

    return XpAwardResult(
      xpEarned: totalEarned,
      isNewStore: isNewStore,
      multiplierApplied: multiplier,
      newStreak: newStreak,
      updatedProfile: updated,
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
    if (last == today) return profile.currentStreak; // already scanned today
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
}
