import 'package:firebase_auth/firebase_auth.dart';
import '../data/receipt_database.dart';
import '../data/receipt_repository.dart';
import '../models/receipt.dart';

class RecurringService {
  /// Called on app start. Creates new entries for any overdue recurring receipts.
  static Future<void> processOverdue() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final receipts = await ReceiptDatabase.instance.readAllReceipts();
      final now = DateTime.now();
      for (final r in receipts) {
        if (!r.isRecurring || r.nextDueDate == null) continue;
        final due = DateTime.tryParse(r.nextDueDate!);
        if (due == null || due.isAfter(now)) continue;

        final newNextDue = r.recurringInterval == 'weekly'
            ? due.add(const Duration(days: 7))
            : DateTime(due.year, due.month + 1, due.day);

        // Create the new recurring occurrence
        final newEntry = Receipt(
          title: r.title,
          date: now.toIso8601String(),
          amount: r.amount,
          notes: r.notes,
          category: r.category,
          photoUrl: r.photoUrl,
          isRecurring: true,
          recurringInterval: r.recurringInterval,
          nextDueDate: newNextDue.toIso8601String(),
        );
        await ReceiptRepository.instance.save(uid, newEntry);

        // Mark original as no longer the active recurring entry
        final updated = r.copyWith(isRecurring: false, nextDueDate: null);
        await ReceiptRepository.instance.update(uid, updated);
      }
    } catch (_) {
      // Never crash the app if recurring processing fails
    }
  }

  static DateTime nextDue(DateTime from, String interval) {
    return interval == 'weekly'
        ? from.add(const Duration(days: 7))
        : DateTime(from.year, from.month + 1, from.day);
  }
}
