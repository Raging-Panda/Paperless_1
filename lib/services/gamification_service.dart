import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gamification_profile.dart';

class GamificationService {
  static const int baseXPPerScan = 10;

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

  Future<GamificationProfile> awardXP(String uid, int xp) async {
    final current = await getProfile(uid);
    final updated = current.copyWith(totalXP: current.totalXP + xp);
    _cached = updated;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('profile')
        .set(updated.toFirestore(), SetOptions(merge: true))
        .ignore();
    return updated;
  }

  Future<GamificationProfile> onReceiptSaved(String uid) =>
      awardXP(uid, baseXPPerScan);

  void clearCache() => _cached = null;
}
