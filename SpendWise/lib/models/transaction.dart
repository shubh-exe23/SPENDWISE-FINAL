class Transaction {
  final int? id; // ── 1. ADDED THIS (Nullable because new transactions don't have an ID yet) ──
  final String title;
  final double amount;
  final bool isExpense;
  final DateTime date;
  final String category;
  final String paymentMethod;

  Transaction({
    this.id, // ── 2. ADDED THIS ──
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.date,
    required this.category,
    required this.paymentMethod,
  });

  Map<String, dynamic> toMap() {
    return {
      // Notice we don't usually send the ID when creating, the database creates it!
      'title': title,
      'amount': amount,
      'is_expense': isExpense,
      'date': date.toIso8601String(),
      'category': category,
      'payment_method': paymentMethod,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'], // ── 3. ADDED THIS: Flutter now reads the ID from Flask ──
      title: map['title'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      isExpense: map['is_expense'] ?? true,
      date: DateTime.parse(map['date']),
      category: map['category'] ?? 'General',
      paymentMethod: map['payment_method'] ?? 'Cash',
    );
  }
}