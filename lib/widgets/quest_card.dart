import 'package:flutter/material.dart';
import '../models/quest_definition.dart';
import '../screens/quest_screen.dart';

class QuestCard extends StatelessWidget {
  final List<String> completedQuestIds;
  const QuestCard({super.key, required this.completedQuestIds});

  @override
  Widget build(BuildContext context) {
    final total = QuestCatalogue.all.length;
    final done = completedQuestIds.length.clamp(0, total);
    final allDone = done >= total;
    final progress = done / total;

    final nextQuest = allDone
        ? null
        : QuestCatalogue.all
            .cast<QuestDefinition?>()
            .firstWhere((q) => !completedQuestIds.contains(q!.id),
                orElse: () => null);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const QuestScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: allDone
                ? Colors.green.withValues(alpha: 0.5)
                : Colors.deepPurpleAccent.withValues(alpha: 0.4),
          ),
        ),
        child: allDone
            ? _AllDoneRow(done: done, total: total)
            : _ProgressRow(
                done: done,
                total: total,
                progress: progress,
                nextQuest: nextQuest,
              ),
      ),
    );
  }
}

class _AllDoneRow extends StatelessWidget {
  final int done;
  final int total;
  const _AllDoneRow({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.celebration_outlined, color: Colors.green, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Journey Complete!  $done / $total',
                style: const TextStyle(
                    color: Colors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
              const Text(
                "You've mastered the basics of Paperless!",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle, color: Colors.green, size: 18),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final int done;
  final int total;
  final double progress;
  final QuestDefinition? nextQuest;
  const _ProgressRow({
    required this.done,
    required this.total,
    required this.progress,
    required this.nextQuest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.map_outlined,
                color: Colors.deepPurpleAccent, size: 16),
            const SizedBox(width: 6),
            Text(
              'Your Journey  $done / $total',
              style: const TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right,
                color: Colors.white38, size: 16),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.deepPurpleAccent),
          ),
        ),
        if (nextQuest != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(nextQuest!.icon, size: 12, color: nextQuest!.color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Next: ${nextQuest!.title} — ${nextQuest!.description}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
