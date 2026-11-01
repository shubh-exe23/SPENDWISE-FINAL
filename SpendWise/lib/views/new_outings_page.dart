import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;

class OutingEvent {
  final String title;
  final Map<String, double> amountsPaid;
  OutingEvent({required this.title, required this.amountsPaid});
}

class CalculatedDebt {
  final String friendName;
  final double amount;
  final bool isOwedToMe;
  CalculatedDebt({required this.friendName, required this.amount, required this.isOwedToMe});
}

class NewOutingPage extends StatefulWidget {
  final Map<String, dynamic>? existingOuting; 
  const NewOutingPage({super.key, this.existingOuting});

  @override
  State<NewOutingPage> createState() => _NewOutingPageState();
}

class _NewOutingPageState extends State<NewOutingPage> {
  static const _jade = Color(0xFF3EB489);
  
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _memberCtrl = TextEditingController();

  List<String> members = ['Me'];
  List<OutingEvent> events = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingOuting != null) {
      _titleCtrl.text = widget.existingOuting!['title'] ?? '';
      _locationCtrl.text = widget.existingOuting!['location'] ?? '';
      
      if (widget.existingOuting!['raw_events'] != null) {
        try {
          List<dynamic> parsed = jsonDecode(widget.existingOuting!['raw_events']);
          events = parsed.map((e) {
            Map<String, double> amounts = {};
            (e['amountsPaid'] as Map).forEach((k, v) => amounts[k.toString()] = (v as num).toDouble());
            return OutingEvent(title: e['title'], amountsPaid: amounts);
          }).toList();
          
          Set<String> memberSet = {'Me'};
          for (var ev in events) {
            memberSet.addAll(ev.amountsPaid.keys);
          }
          members = memberSet.toList();
        } catch (e) {
           debugPrint('Could not parse historical events');
        }
      }
    }
  }

  void _addMember() {
    final name = _memberCtrl.text.trim();
    if (name.isNotEmpty && !members.contains(name)) {
      setState(() => members.add(name));
      _memberCtrl.clear();
    }
  }

  void _calculateAndSave() {
    FocusScope.of(context).unfocus(); // Hides keyboard

    if (_titleCtrl.text.isEmpty || events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a title and at least one event!'), backgroundColor: Colors.redAccent));
      return;
    }

    // ── 1. EXACT PAIRWISE LEDGER ──
    // This tracks exactly who owes whom: debts[debtor][creditor]
    Map<String, Map<String, double>> pairwiseDebts = {};
    for (var m1 in members) {
      pairwiseDebts[m1] = {};
      for (var m2 in members) {
        pairwiseDebts[m1]![m2] = 0.0;
      }
    }

    // ── 2. DISTRIBUTE EXACT SHARES ──
    // If you pay ₹200 for 4 people, everyone owes you exactly ₹50.
    for (var event in events) {
      int n = members.length;
      for (var payer in members) {
        double paidAmount = event.amountsPaid[payer] ?? 0.0;
        
        if (paidAmount > 0) {
          double sharePerPerson = paidAmount / n;
          for (var debtor in members) {
            if (debtor != payer) {
              // Add the debt to the ledger
              pairwiseDebts[debtor]![payer] = pairwiseDebts[debtor]![payer]! + sharePerPerson;
            }
          }
        }
      }
    }

    // ── 3. CONSOLIDATE MY DEBTS ──
    List<CalculatedDebt> myDebts = [];
    
    for (var friend in members) {
      if (friend == 'Me') continue;

      // Check the two-way relationship between Me and this Friend
      double friendOwesMe = pairwiseDebts[friend]!['Me']!;
      double iOweFriend = pairwiseDebts['Me']![friend]!;

      // Find the net difference
      double net = friendOwesMe - iOweFriend;

      if (net > 0.01) {
        // Friend owes me more than I owe them (I receive money / Red)
        myDebts.add(CalculatedDebt(friendName: friend, amount: net, isOwedToMe: true));
      } else if (net < -0.01) {
        // I owe friend more than they owe me (I pay money / Green)
        myDebts.add(CalculatedDebt(friendName: friend, amount: net.abs(), isOwedToMe: false));
      }
    }

    // Convert events to JSON for database storage
    String rawEventsJson = jsonEncode(events.map((e) => {'title': e.title, 'amountsPaid': e.amountsPaid}).toList());

    Navigator.pop(context, {
      'title': _titleCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'date': widget.existingOuting != null ? widget.existingOuting!['date'] : 'Today',
      'debts': myDebts,
      'raw_events': rawEventsJson,
    });
  }

  void _showAddEventSheet({int? editIndex}) {
    final eventTitleCtrl = TextEditingController();
    Map<String, TextEditingController> amountCtrls = {for (var m in members) m: TextEditingController()};

    if (editIndex != null) {
      eventTitleCtrl.text = events[editIndex].title;
      events[editIndex].amountsPaid.forEach((key, val) {
        if (amountCtrls.containsKey(key)) amountCtrls[key]!.text = val.toStringAsFixed(0);
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A3E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(editIndex == null ? 'Add Event' : 'Edit Event', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: eventTitleCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Movie Tickets',
                  filled: true, fillColor: Colors.grey.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Who paid how much?', style: TextStyle(fontWeight: FontWeight.w600, color: _jade)),
              const SizedBox(height: 12),
              
              ...members.map((member) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(child: Text(member, style: const TextStyle(fontSize: 15))),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: amountCtrls[member],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                          hintText: '0', // Visual cue for zero
                          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                          filled: true, fillColor: Colors.grey.withOpacity(0.1),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _jade, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    FocusScope.of(context).unfocus(); // Hides keyboard

                    Map<String, double> paid = {};
                    for (var m in members) {
                      double val = double.tryParse(amountCtrls[m]!.text) ?? 0.0;
                      if (val > 0) paid[m] = val;
                    }

                    if (eventTitleCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an event title!'), backgroundColor: Colors.redAccent));
                      return;
                    }
                    if (paid.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Someone must pay an amount!'), backgroundColor: Colors.redAccent));
                      return;
                    }

                    setState(() {
                      if (editIndex == null) {
                        events.add(OutingEvent(title: eventTitleCtrl.text, amountsPaid: paid));
                      } else {
                        events[editIndex] = OutingEvent(title: eventTitleCtrl.text, amountsPaid: paid);
                      }
                    });
                    Navigator.pop(sheetContext); // Closes the bottom sheet safely
                  },
                  child: Text(editIndex == null ? 'Save Event' : 'Update Event', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
    final cardBg = isDark ? const Color(0xFF2A2A3E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg, elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(widget.existingOuting != null ? 'Edit Outing' : 'New Outing', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Outing Name', border: InputBorder.none, icon: Icon(Icons.celebration, color: _jade))),
                  const Divider(),
                  TextField(controller: _locationCtrl, decoration: const InputDecoration(hintText: 'Location (Optional)', border: InputBorder.none, icon: Icon(Icons.location_on_outlined, color: _jade))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ...members.map((m) => Chip(
                  label: Text(m), backgroundColor: _jade.withOpacity(0.1), labelStyle: const TextStyle(color: _jade, fontWeight: FontWeight.w600),
                  deleteIcon: m == 'Me' ? null : const Icon(Icons.close, size: 16),
                  onDeleted: m == 'Me' ? null : () => setState(() => members.remove(m)), 
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _memberCtrl, decoration: InputDecoration(hintText: 'Add friend name...', filled: true, fillColor: cardBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                const SizedBox(width: 8),
                IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add, color: _jade), style: IconButton.styleFrom(backgroundColor: _jade.withOpacity(0.1)))
              ],
            ),
            const SizedBox(height: 32),

            const Text('Events / Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...List.generate(events.length, (index) {
              double total = events[index].amountsPaid.values.fold(0, (a, b) => a + b);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _jade.withOpacity(0.3))),
                child: ListTile(
                  title: Text(events[index].title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Total: ₹${total.toStringAsFixed(0)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.grey), onPressed: () => _showAddEventSheet(editIndex: index)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => setState(() => events.removeAt(index))),
                    ],
                  ),
                ),
              );
            }),
            
            OutlinedButton.icon(
              onPressed: () => _showAddEventSheet(),
              icon: const Icon(Icons.add_shopping_cart, color: _jade), label: const Text('Add Event', style: TextStyle(color: _jade)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _jade), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _calculateAndSave,
              style: ElevatedButton.styleFrom(backgroundColor: _jade, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text(widget.existingOuting != null ? 'Update Outing' : 'Calculate & Save Outing', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}