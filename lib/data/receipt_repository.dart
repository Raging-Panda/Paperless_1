import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receipt.dart';
import 'receipt_database.dart';

class ReceiptRepository {
  static final instance = ReceiptRepository._();
  ReceiptRepository._();

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('receipts');

  Future<Receipt> save(String uid, Receipt receipt) async {
    final doc = await _col(uid).add(receipt.toFirestore());
    final saved = receipt.copyWith(firestoreId: doc.id);
    await ReceiptDatabase.instance.createReceipt(saved);
    return saved;
  }

  Future<List<Receipt>> syncFromFirestore(String uid) async {
    final snap = await _col(uid).orderBy('createdAt', descending: true).get();
    final receipts = snap.docs.map(Receipt.fromFirestore).toList();
    await ReceiptDatabase.instance.upsertAll(receipts);
    return receipts;
  }

  Future<Receipt> update(String uid, Receipt receipt) async {
    if (receipt.firestoreId != null) {
      await _col(uid).doc(receipt.firestoreId).update({
        'title': receipt.title,
        'date': receipt.date,
        'amount': receipt.amount,
        'notes': receipt.notes,
        'category': receipt.category,
      });
    }
    if (receipt.id != null) {
      await ReceiptDatabase.instance.updateReceipt(receipt);
    }
    return receipt;
  }

  Future<void> delete(String uid, Receipt receipt) async {
    if (receipt.firestoreId != null) {
      await _col(uid).doc(receipt.firestoreId).delete();
    }
    if (receipt.id != null) {
      await ReceiptDatabase.instance.deleteReceipt(receipt.id!);
    }
  }

  Future<void> clearCache() => ReceiptDatabase.instance.clearAll();
}
