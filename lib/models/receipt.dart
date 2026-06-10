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
  final String? photoUrl;
  final bool isRecurring;
  final String? recurringInterval; // 'weekly' | 'monthly'
  final String? nextDueDate;       // ISO-8601 date string

  Receipt({
    this.id,
    this.firestoreId,
    required this.title,
    required this.date,
    required this.amount,
    required this.notes,
    this.category,
    this.photoUrl,
    this.isRecurring = false,
    this.recurringInterval,
    this.nextDueDate,
  });

  Receipt copyWith({
    int? id,
    String? firestoreId,
    String? title,
    String? date,
    double? amount,
    String? notes,
    String? category,
    String? photoUrl,
    bool? isRecurring,
    String? recurringInterval,
    String? nextDueDate,
  }) {
    return Receipt(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      title: title ?? this.title,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      photoUrl: photoUrl ?? this.photoUrl,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringInterval: recurringInterval ?? this.recurringInterval,
      nextDueDate: nextDueDate ?? this.nextDueDate,
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
      'photo_url': photoUrl,
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_interval': recurringInterval,
      'next_due_date': nextDueDate,
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
      photoUrl: map['photo_url'] as String?,
      isRecurring: (map['is_recurring'] as int? ?? 0) == 1,
      recurringInterval: map['recurring_interval'] as String?,
      nextDueDate: map['next_due_date'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'date': date,
      'amount': amount,
      'notes': notes,
      'category': category,
      'photo_url': photoUrl,
      'is_recurring': isRecurring,
      'recurring_interval': recurringInterval,
      'next_due_date': nextDueDate,
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
      photoUrl: data['photo_url'] as String?,
      isRecurring: data['is_recurring'] as bool? ?? false,
      recurringInterval: data['recurring_interval'] as String?,
      nextDueDate: data['next_due_date'] as String?,
    );
  }
}
