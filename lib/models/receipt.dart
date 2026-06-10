import 'package:cloud_firestore/cloud_firestore.dart';

const kCategories = [
  'Food', 'Travel', 'Transport', 'Shopping',
  'Office', 'Health', 'Entertainment', 'Other',
];

class Receipt {
  final int? id;
  final String? firestoreId;
  final String title;
  final String date;
  final double amount;
  final String notes;
  final String? category;

  Receipt({
    this.id,
    this.firestoreId,
    required this.title,
    required this.date,
    required this.amount,
    required this.notes,
    this.category,
  });

  Receipt copyWith({
    int? id,
    String? firestoreId,
    String? title,
    String? date,
    double? amount,
    String? notes,
    String? category,
  }) {
    return Receipt(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      title: title ?? this.title,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'date': date,
      'amount': amount,
      'notes': notes,
      'firestore_id': firestoreId,
      'category': category,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    final amountValue = map['amount'];
    return Receipt(
      id: map['id'] as int?,
      firestoreId: map['firestore_id'] as String?,
      title: map['title'] as String,
      date: map['date'] as String,
      amount: amountValue is int ? amountValue.toDouble() : amountValue as double,
      notes: map['notes'] as String,
      category: map['category'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'date': date,
      'amount': amount,
      'notes': notes,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final amountValue = data['amount'];
    return Receipt(
      firestoreId: doc.id,
      title: data['title'] as String,
      date: data['date'] as String,
      amount: amountValue is int ? amountValue.toDouble() : amountValue as double,
      notes: data['notes'] as String,
      category: data['category'] as String?,
    );
  }
}
