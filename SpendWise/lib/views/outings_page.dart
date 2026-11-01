import 'package:flutter/material.dart';
import 'new_outings_page.dart'; 
import '../services/api_service.dart';
import '../themes/app_theme.dart'; 

class OutingsPage extends StatefulWidget {
  const OutingsPage({super.key});

  @override
  State<OutingsPage> createState() => _OutingsPageState();
}

class _OutingsPageState extends State<OutingsPage> {
  List<Map<String, dynamic>> _outings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOutings();
  }

  Future<void> _loadOutings() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getOutings();
    setState(() {
      _outings = data;
      _isLoading = false;
    });
  }

  void _showSettleDialog(int outingIndex, int friendIndex) {
    final friend = _outings[outingIndex]['friends'][friendIndex];
    if (friend['is_settled']) return; 

    double currentAmount = (friend['amount'] as num).toDouble();
    bool isOwedToMe = friend['is_owed_to_me'];
    bool showPartialInput = false;
    final partialCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final bg = Theme.of(context).cardColor;
        final textColor = Colors.white;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Settle Debt', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isOwedToMe
                        ? 'How much did ${friend['name']} pay you?'
                        : 'How much did you pay ${friend['name']}?',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  if (!showPartialInput) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.jadeLight,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        _applyPayment(outingIndex, friendIndex, currentAmount);
                        Navigator.pop(dialogContext);
                      },
                      child: Text('Complete (₹${currentAmount.toStringAsFixed(0)})', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.jadeLight, width: 1.5),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => setDialogState(() => showPartialInput = true),
                      child: const Text('Partial Payment', style: TextStyle(color: AppTheme.jadeLight, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ] 
                  else ...[
                    TextField(
                      controller: partialCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_rupee, size: 18, color: AppTheme.jadeLight),
                        hintText: 'Enter amount paid',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.jadeLight,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus(); 
                        
                        double? paid = double.tryParse(partialCtrl.text);
                        if (paid != null && paid > 0) {
                          _applyPayment(outingIndex, friendIndex, paid);
                          Navigator.pop(dialogContext);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount!'), backgroundColor: Colors.redAccent));
                        }
                      },
                      child: const Text('Save Payment', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ], // <-- Closes the 'else' array
                ], // ── THIS WAS THE MISSING BRACKET! Closes 'children' array ──
              ), 
            );
          },
        );
      },
    );
  }

  Future<void> _applyPayment(int oIndex, int fIndex, double paidAmount) async {
    final friend = _outings[oIndex]['friends'][fIndex];
    int debtId = friend['id'];
    double current = (friend['amount'] as num).toDouble();
    double remaining = current - paidAmount;
    
    bool isSettled = remaining <= 0.01;
    double newAmount = isSettled ? 0.0 : remaining;

    setState(() {
      _outings[oIndex]['friends'][fIndex]['amount'] = newAmount;
      _outings[oIndex]['friends'][fIndex]['is_settled'] = isSettled;
    });

    final success = await ApiService.updateOutingDebt(debtId, {
      'amount': newAmount,
      'is_settled': isSettled
    });

    if (!success && mounted) {
      _loadOutings(); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to sync payment with server!'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _openOutingForm({Map<String, dynamic>? existingOuting}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewOutingPage(existingOuting: existingOuting)),
    );

    if (result != null && result['debts'] != null) {
      final List<dynamic> rawDebts = result['debts'];
      
      final List<Map<String, dynamic>> friendsData = rawDebts.map((dynamic item) {
        final debt = item as CalculatedDebt;
        return {
          'name': debt.friendName,
          'amount': debt.amount,
          'is_owed_to_me': debt.isOwedToMe,
          'is_settled': false,
        };
      }).toList();

      final payload = {
        'title': result['title'],
        'location': result['location'] ?? 'Unknown Location',
        'date': result['date'],
        'raw_events': result['raw_events'], 
        'friends': friendsData,
      };

      setState(() => _isLoading = true);
      
      bool success;
      if (existingOuting == null) {
        success = await ApiService.addOuting(payload); 
      } else {
        success = await ApiService.updateOuting(existingOuting['id'], payload); 
      }
      
      if (success) {
        await _loadOutings();
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save outing!'), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _showOutingOptions(Map<String, dynamic> outing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Options for "${outing['title']}"', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_outlined, color: Colors.blue),
                ),
                title: const Text('Edit Outing & Events', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openOutingForm(existingOuting: outing);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                title: const Text('Delete Outing', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  setState(() => _isLoading = true);
                  final success = await ApiService.deleteOuting(outing['id']);
                  if (success) {
                    _loadOutings();
                  } else {
                    setState(() => _isLoading = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete.'), backgroundColor: Colors.redAccent));
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── 1. GLOBAL BACKGROUND ──
    final bg = Theme.of(context).scaffoldBackgroundColor;

    double totalToReceive = 0.0;
    double totalToPay = 0.0;

    for (var outing in _outings) {
      for (var friend in outing['friends']) {
        if (!friend['is_settled']) {
          if (friend['is_owed_to_me']) {
            totalToReceive += (friend['amount'] as num).toDouble();
          } else {
            totalToPay += (friend['amount'] as num).toDouble();
          }
        }
      }
    }
    
    double netBalance = totalToReceive - totalToPay; 

    return Scaffold(
      backgroundColor: bg,
      // ── 2. UPGRADED APPBAR ──
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Completely transparent to show bg
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Outings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.jadeLight))
        : Column(
            children: [
              // ── THE NET BALANCE TOP CARD ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient, 
                  borderRadius: BorderRadius.circular(30), 
                  boxShadow: [
                    BoxShadow(color: AppTheme.jadeLight.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
                  ]
                ),
                child: Column(
                  children: [
                    const Text('Net Resultant Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      netBalance >= 0 ? '₹${netBalance.toStringAsFixed(0)}' : '-₹${netBalance.abs().toStringAsFixed(0)}', 
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                const Text('To Receive', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('-₹${totalToReceive.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                const Text('To Pay', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('+₹${totalToPay.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFA5D6A7), fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Expanded(
                child: _outings.isEmpty 
                    ? Center(child: Text('No active outings. Tap + to split a bill!', style: TextStyle(color: Colors.grey.shade500)))
                    : RefreshIndicator(
                        color: AppTheme.jadeLight,
                        onRefresh: _loadOutings,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _outings.length,
                          itemBuilder: (context, index) {
                            return OutingCard(
                              outing: _outings[index],
                              outingIndex: index,
                              onSettleTap: _showSettleDialog,
                              onLongPress: _showOutingOptions,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openOutingForm(),
        backgroundColor: AppTheme.jadeLight,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Outing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// ── EXPANDABLE OUTING CARD WIDGET ──
// ════════════════════════════════════════════════════════════

class OutingCard extends StatefulWidget {
  final Map<String, dynamic> outing;
  final int outingIndex;
  final Function(int, int) onSettleTap;
  final Function(Map<String, dynamic>) onLongPress;

  const OutingCard({
    super.key,
    required this.outing,
    required this.outingIndex,
    required this.onSettleTap,
    required this.onLongPress,
  });

  @override
  State<OutingCard> createState() => _OutingCardState();
}

class _OutingCardState extends State<OutingCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // ── 3. INDIVIDUAL CARDS USE ELEVATED CARD COLOR ──
    final cardBg = Theme.of(context).cardColor;
    const textColor = Colors.white;
    final hintColor = Colors.white54;

    double cardToReceive = 0.0;
    double cardToPay = 0.0;
    
    for (var friend in widget.outing['friends']) {
      if (!friend['is_settled']) {
        if (friend['is_owed_to_me']) {
          cardToReceive += (friend['amount'] as num).toDouble();
        } else {
          cardToPay += (friend['amount'] as num).toDouble();
        }
      }
    }

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      onLongPress: () => widget.onLongPress(widget.outing), 
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20), // Slightly rounder to match overall theme
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFFC300).withOpacity(0.15), 
                  child: const Icon(Icons.groups_outlined, color: Color(0xFFFFC300), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.outing['title'], style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('${widget.outing['date']} @ ${widget.outing['location']}', style: TextStyle(color: hintColor, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (cardToReceive > 0)
                      Text('-₹${cardToReceive.toStringAsFixed(0)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                    if (cardToPay > 0)
                      Text('+₹${cardToPay.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.jadeLight, fontWeight: FontWeight.bold, fontSize: 15)),
                    if (cardToReceive == 0 && cardToPay == 0)
                      const Text('Settled', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ],
            ),
            
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
              
              ...List.generate(widget.outing['friends'].length, (fIndex) {
                final friend = widget.outing['friends'][fIndex];
                final isSettled = friend['is_settled'];
                final isOwedToMe = friend['is_owed_to_me'];
                
                final amountColor = isOwedToMe ? Colors.redAccent : AppTheme.jadeLight;
                final sign = isOwedToMe ? '-' : '+';
                final actionText = isOwedToMe ? 'Receive from' : 'Pay to';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(isOwedToMe ? Icons.arrow_downward : Icons.arrow_upward, size: 16, color: amountColor),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(friend['name'], style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(actionText, style: TextStyle(color: hintColor, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      Text('$sign₹${(friend['amount'] as num).toDouble().toStringAsFixed(0)}', style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 16),
                      
                      GestureDetector(
                        onTap: () => widget.onSettleTap(widget.outingIndex, fIndex), 
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSettled ? Colors.white12 : AppTheme.jadeLight.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isSettled ? 'Settled' : 'Settle', 
                            style: TextStyle(color: isSettled ? Colors.grey : AppTheme.jadeLight, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}