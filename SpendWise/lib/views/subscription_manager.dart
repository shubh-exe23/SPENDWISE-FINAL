import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../services/api_service.dart';

class SubscriptionManager extends StatefulWidget {
  const SubscriptionManager({super.key});

  @override
  State<SubscriptionManager> createState() => _SubscriptionManagerState();
}

class _SubscriptionManagerState extends State<SubscriptionManager> {
  List<Subscription> _subscriptions = [];
  bool _isLoading = true;
  static const _jade = Color(0xFF3EB489);

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getSubscriptions();
    setState(() {
      _subscriptions = data.map((s) => Subscription.fromMap(s)).toList();
      _isLoading = false;
    });
  }

  Future<void> _deleteSubscription(int id) async {
    final success = await ApiService.deleteSubscription(id);
    if (success) {
      setState(() => _subscriptions.removeWhere((s) => s.id == id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription deleted.'), backgroundColor: _jade),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete. Try again.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _confirmDelete(int id, String title, Color cardBg, Color textColor, Color hintColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Subscription?', style: TextStyle(color: textColor)),
        content: Text('Are you sure you want to completely remove $title?', style: TextStyle(color: hintColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _deleteSubscription(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(Subscription sub, Color bg, Color cardBg, Color textColor, Color hintColor) {
    final titleCtrl = TextEditingController(text: sub.title);
    final amountCtrl = TextEditingController(text: sub.amount.toString());
    String selectedFreq = sub.frequency;
    DateTime selectedDate = sub.nextBillingDate; // ── ADDED DATE VARIABLE ──
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24, right: 24, top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Subscription', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // Title Edit
                  TextFormField(
                    controller: titleCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: hintColor),
                      filled: true,
                      fillColor: bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Amount Edit
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      labelStyle: TextStyle(color: hintColor),
                      prefixIcon: const Icon(Icons.currency_rupee, color: _jade, size: 18),
                      filled: true,
                      fillColor: bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── NEW: Date Selector ──
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
  context: context,
  // Ensure the initial date isn't in the past (in case an old bugged date is saved)
  initialDate: selectedDate.isBefore(DateTime.now()) ? DateTime.now() : selectedDate,
  
  // ── THIS BLOCKS PAST DATES ──
  firstDate: DateTime.now(), 
  
  lastDate: DateTime(2100),
  builder: (context, child) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: const ColorScheme.light(primary: _jade),
    ),
    child: child!,
  ),
);
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, color: _jade, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Next Bill: ${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                            style: TextStyle(fontSize: 15, color: textColor),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right, color: _jade),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Frequency Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedFreq,
                    dropdownColor: cardBg,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Billing Cycle',
                      labelStyle: TextStyle(color: hintColor),
                      filled: true,
                      fillColor: bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (v) => setSheetState(() => selectedFreq = v!),
                  ),
                  const SizedBox(height: 30),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _jade,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving ? null : () async {
                        setSheetState(() => isSaving = true);
                        
                        // Prep updated data mapping to Flask backend keys
                        final updatedMap = {
                          'title': titleCtrl.text.trim(),
                          'amount': double.tryParse(amountCtrl.text.trim()) ?? sub.amount,
                          'frequency': selectedFreq,
                          'next_billing_date': selectedDate.toIso8601String(), // ── ADDED DATE TO PAYLOAD ──
                        };
                        
                        final success = await ApiService.updateSubscription(sub.id!, updatedMap);
                        
                        if (success) {
                          _loadSubscriptions(); 
                          if (context.mounted) Navigator.pop(context);
                        } else {
                          setSheetState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to update.'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
                      child: isSaving 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
    final cardBg     = isDarkMode ? const Color(0xFF2A2A3E) : Colors.white;
    final textColor  = isDarkMode ? Colors.white : const Color(0xFF2A7D5F);
    final hintColor  = isDarkMode ? Colors.white54 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Manage Subscriptions', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _jade))
          : _subscriptions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.autorenew, size: 64, color: hintColor.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('No active subscriptions', style: TextStyle(color: hintColor, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subscriptions.length,
                  itemBuilder: (context, index) {
                    final sub = _subscriptions[index];
                    final dateStr = "${sub.nextBillingDate.day.toString().padLeft(2, '0')}/${sub.nextBillingDate.month.toString().padLeft(2, '0')}/${sub.nextBillingDate.year}";
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardBg, 
                        borderRadius: BorderRadius.circular(16), 
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // ── ICON ──
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFE8F5F0),
                              child: const Icon(Icons.autorenew, color: _jade),
                            ),
                            const SizedBox(width: 16),
                            
                            // ── DETAILS ──
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sub.title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${sub.frequency.toUpperCase()} • ${sub.paymentMethod}', style: TextStyle(color: hintColor, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text('Next bill: $dateStr', style: TextStyle(color: _jade, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            
                            // ── ACTION ICONS & AMOUNT ──
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${sub.amount.toStringAsFixed(2)}',
                                  style: TextStyle(color: sub.isExpense ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showEditSheet(sub, bg, cardBg, textColor, hintColor),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                                        child: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _confirmDelete(sub.id!, sub.title, cardBg, textColor, hintColor),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                                        child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}