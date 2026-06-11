import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/quest_definition.dart';
import '../services/quest_service.dart';

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  List<String> _completedIds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final ids = await QuestService.instance.getCompletedIds(uid);
    if (mounted) setState(() { _completedIds = ids; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final total = QuestCatalogue.all.length;
    final done = _completedIds.length.clamp(0, total);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Your Journey'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$done / $total',
                style: const TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // ── Overall progress bar ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: done / total,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.deepPurpleAccent),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          done >= total
                              ? 'All missions complete — well done!'
                              : '${total - done} mission${total - done == 1 ? '' : 's'} remaining',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // ── Quest list ───────────────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      itemCount: QuestCatalogue.all.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final quest = QuestCatalogue.all[i];
                        final isCompleted =
                            _completedIds.contains(quest.id);
                        // Next quest = first incomplete
                        final isCurrent = !isCompleted &&
                            QuestCatalogue.all
                                .take(i)
                                .every((q) => _completedIds.contains(q.id));
                        return _QuestTile(
                          quest: quest,
                          isCompleted: isCompleted,
                          isCurrent: isCurrent,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  final QuestDefinition quest;
  final bool isCompleted;
  final bool isCurrent;
  const _QuestTile({
    required this.quest,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = !isCompleted && !isCurrent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isCurrent ? 0.09 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? quest.color.withValues(alpha: 0.4)
              : isCurrent
                  ? quest.color.withValues(alpha: 0.6)
                  : Colors.white12,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // ── Status icon ────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLocked
                  ? Colors.white.withValues(alpha: 0.04)
                  : quest.color.withValues(alpha: 0.15),
              border: Border.all(
                color: isLocked
                    ? Colors.white12
                    : quest.color.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              isCompleted
                  ? Icons.check
                  : isLocked
                      ? Icons.lock_outline
                      : quest.icon,
              size: 18,
              color: isLocked ? Colors.white24 : quest.color,
            ),
          ),
          const SizedBox(width: 12),
          // ── Text ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: TextStyle(
                    color: isLocked ? Colors.white38 : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quest.description,
                  style: TextStyle(
                    color: isLocked ? Colors.white24 : Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── XP reward ──────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${quest.xpReward} XP',
                style: TextStyle(
                  color: isCompleted
                      ? quest.color
                      : isLocked
                          ? Colors.white24
                          : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isCompleted)
                Text(
                  'earned',
                  style: TextStyle(
                      color: quest.color.withValues(alpha: 0.7),
                      fontSize: 9),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
