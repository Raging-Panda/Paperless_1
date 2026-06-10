import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  Future<String> _uploadPhoto(String uid, String localPath) async {
    final ref = FirebaseStorage.instance.ref(
      'users/$uid/receipts/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(File(localPath));
    return ref.getDownloadURL();
  }

  Future<Receipt> save(String uid, Receipt receipt, {String? localPhotoPath}) async {
    String? photoUrl = receipt.photoUrl;
    if (localPhotoPath != null) {
      photoUrl = await _uploadPhoto(uid, localPhotoPath);
    }
    final r = photoUrl != null ? receipt.copyWith(photoUrl: photoUrl) : receipt;
    final doc = await _col(uid).add(r.toFirestore());
    final saved = r.copyWith(firestoreId: doc.id);
    await ReceiptDatabase.instance.createReceipt(saved);
    return saved;
  }

  Future<List<Receipt>> syncFromFirestore(String uid) async {
    final snap = await _col(uid).orderBy('createdAt', descending: true).get();
    final receipts = snap.docs.map(Receipt.fromFirestore).toList();
    await ReceiptDatabase.instance.upsertAll(receipts);
    return receipts;
  }

  Future<Receipt> update(String uid, Receipt receipt, {String? localPhotoPath}) async {
    String? photoUrl = receipt.photoUrl;
    if (localPhotoPath != null) {
      photoUrl = await _uploadPhoto(uid, localPhotoPath);
    }
    final r = photoUrl != null ? receipt.copyWith(photoUrl: photoUrl) : receipt;
    if (r.firestoreId != null) {
      await _col(uid).doc(r.firestoreId).update({
        'title': r.title,
        'date': r.date,
        'amount': r.amount,
        'notes': r.notes,
        'category': r.category,
        'photo_url': r.photoUrl,
        'is_recurring': r.isRecurring,
        'recurring_interval': r.recurringInterval,
        'next_due_date': r.nextDueDate,
      });
    }
    if (r.id != null) {
      await ReceiptDatabase.instance.updateReceipt(r);
    }
    return r;
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
