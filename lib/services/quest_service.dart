import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gamification_profile.dart';
import '../models/quest_definition.dart';
import '../models/receipt.dart';
import 'gamification_service.dart';

class QuestService {
  static final QuestService instance = QuestService._();
  QuestService._();

  List<String>? _completedIds;

  Future<List<String>> getCompletedIds(String uid) async {
    if (_completedIds != null) return _completedIds!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('gamification')
          .doc('quests')
          .get();
      _completedIds = List<String>.from(
          doc.data()?['completedQuestIds'] as List? ?? []);
    } catch (_) {
      _completedIds = [];
    }
    return _completedIds!;
  }

  /// Auto-completes the welcome quest silently on first launch.
  Future<void> onUserInit(String uid) async {
    final completed = await getCompletedIds(uid);
    if (completed.contains('welcome')) return;
    await _completeQuests(uid, ['welcome']);
  }

  /// Called after a receipt is saved. Checks receipt-based quest conditions.
  Future<List<QuestDefinition>> onReceiptSaved(
      String uid, Receipt receipt, GamificationProfile profile) async {
    final completed = await getCompletedIds(uid);
    final newIds = <String>[];

    void check(String id, bool condition) {
      if (!completed.contains(id) && condition) newIds.add(id);
    }

    check('first_scan', profile.totalScans >= 1);
    check('get_organised', receipt.category != null);
    check('add_detail', receipt.notes.isNotEmpty);
    check('build_a_streak', profile.currentStreak >= 2);

    return _completeQuests(uid, newIds);
  }

  /// Call when the Analytics screen is opened.
  Future<List<QuestDefinition>> onAnalyticsVisited(String uid) async {
    final completed = await getCompletedIds(uid);
    if (completed.contains('know_your_spending')) return [];
    return _completeQuests(uid, ['know_your_spending']);
  }

  /// Call when a budget is saved.
  Future<List<QuestDefinition>> onBudgetSaved(String uid) async {
    final completed = await getCompletedIds(uid);
    if (completed.contains('set_a_goal')) return [];
    return _completeQuests(uid, ['set_a_goal']);
  }

  void clearCache() => _completedIds = null;

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<List<QuestDefinition>> _completeQuests(
      String uid, List<String> newIds) async {
    if (newIds.isEmpty) return [];

    _completedIds = [...(_completedIds ?? []), ...newIds];

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('quests')
        .set({'completedQuestIds': _completedIds}, SetOptions(merge: true))
        .ignore();

    for (final id in newIds) {
      final quest = QuestCatalogue.findById(id);
      if (quest != null) {
        GamificationService.instance.awardXP(uid, quest.xpReward).ignore();
      }
    }

    return newIds
        .map((id) => QuestCatalogue.findById(id))
        .whereType<QuestDefinition>()
        .toList();
  }
}
