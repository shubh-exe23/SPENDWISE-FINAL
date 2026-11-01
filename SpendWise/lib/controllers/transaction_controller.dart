import '../models/transaction.dart';
import '../services/api_service.dart';

class TransactionController {
  List<Transaction> allTransactions = [];
  bool isLoading = false;

  // ── load from Flask ──
  Future<void> loadTransactions() async {
    isLoading = true;
    final data = await ApiService.getTransactions();
    allTransactions = data
        .map((map) => Transaction.fromMap(map))
        .toList();
    isLoading = false;
  }

  // ── add transaction ──
  Future<bool> addTransaction(Transaction t) async {
  print('Adding transaction: ${t.title}'); // ← add this
  final success = await ApiService.addTransaction(t.toMap());
  print('Success: $success'); // ← add this
  if (success) {
    allTransactions.add(t);
  }
  return success;
} 

  // ── filter ──
  List<Transaction> getFiltered(String filter, DateTime? customDate) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return allTransactions.where((t) {
      switch (filter) {
        case 'Today':
          return _isSameDay(t.date, now);
        case 'Yesterday':
          return _isSameDay(t.date, now.subtract(Duration(days: 1)));
        case 'This week':
        final now = DateTime.now();
        // Snap back to the most recent Sunday
        int daysToSubtract = now.weekday == 7 ? 0 : now.weekday;
        final startOfSunday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));
        
        // ONLY return true or false for this specific transaction (t)
        return t.date.isAfter(startOfSunday) || t.date.isAtSameMomentAs(startOfSunday);
        case 'This month':
          return t.date.month == now.month && t.date.year == now.year;
        case 'Custom':
          if (customDate == null) return false;
          return _isSameDay(t.date, customDate);
        default:
          return true;
      }
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double getTotalIncome(List<Transaction> filtered) =>
      filtered.where((t) => !t.isExpense).fold(0, (sum, t) => sum + t.amount);

  double getTotalExpense(List<Transaction> filtered) =>
      filtered.where((t) => t.isExpense).fold(0, (sum, t) => sum + t.amount);

  double getBalance(List<Transaction> filtered) =>
      getTotalIncome(filtered) - getTotalExpense(filtered);
}