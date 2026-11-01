class Subscription {
  final int? id;
  final String title;
  final double amount;
  final bool isExpense;
  final String category;
  final String paymentMethod;
  final String frequency; // 'monthly' or 'yearly'
  final DateTime nextBillingDate;

  Subscription({
    this.id,
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.category,
    required this.paymentMethod,
    required this.frequency,
    required this.nextBillingDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'is_expense': isExpense,
      'category': category,
      'payment_method': paymentMethod,
      'frequency': frequency,
      'next_billing_date': nextBillingDate.toIso8601String(),
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'],
      title: map['title'],
      amount: (map['amount'] as num).toDouble(),
      isExpense: map['is_expense'],
      category: map['category'],
      paymentMethod: map['payment_method'] ?? 'Cash',
      frequency: map['frequency'] ?? 'monthly',
      nextBillingDate: DateTime.parse(map['next_billing_date']),
    );
  }
}