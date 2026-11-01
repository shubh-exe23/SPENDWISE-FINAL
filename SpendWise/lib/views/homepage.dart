import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // ── NEW: IMPORT GOOGLE FONTS ──
import '../controllers/transaction_controller.dart';
import '../controllers/notification_controller.dart';
import '../models/transaction.dart';
import '../models/goals.dart';
import '../services/api_service.dart';
import 'floatingactionbutton.dart';
import 'settings.dart';
import 'analysis.dart';
import 'goals.dart';
import 'notification_page.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/export_service.dart';
import 'magic_entry_button.dart';
import 'outings_page.dart';
import '../themes/app_theme.dart';
import 'profile_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver{
  final TransactionController _controller = TransactionController();
  String _userName = 'User';
  String _userInitial = 'U';
  List<Goal> _goals = [];
  final NotificationController _notificationController = NotificationController();

  String selectDateFilter = 'Today';
  final List<String> dateoptions = ['Today', 'Yesterday', 'This week', 'This month', 'Custom'];
  DateTime? customDate;
  int _currentIndex = 0;

  List<Transaction> get filtered => _controller.getFiltered(selectDateFilter, customDate);
  double get totalIncome  => _controller.getTotalIncome(filtered);
  double get totalExpense => _controller.getTotalExpense(filtered);
  double get balance      => _controller.getBalance(filtered);

  @override
  void initState() {
    super.initState();
    ApiService.checkDailyDebtReminders();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); 
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData(); 
    }
  }

  Future<void> _loadData() async {
    await _controller.loadTransactions();
    
    final goalsData = await ApiService.getGoals();
    _goals = goalsData.map((g) => Goal.fromMap(g)).toList();

    await _notificationController.loadNotifications(); 

    // ── UPDATED: FETCH CURRENCY AND NAME FROM BACKEND ──
    final profile = await ApiService.getProfile();
    if (profile != null) {
      if (profile['currency'] != null) {
        currencyNotifier.value = profile['currency'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currency', profile['currency']);
      }
      if (profile['name'] != null && mounted) {
        setState(() {
          _userName = profile['name'];
          if (_userName.isNotEmpty) {
            final parts = _userName.trim().split(' ');
            if (parts.length >= 2) {
              _userInitial = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
            } else {
              _userInitial = parts[0][0].toUpperCase();
            }
          }
        });
      }
    }

    if (mounted) {
      setState(() {
        _notificationController.checkGoals(_goals, _controller);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Graphite black for the main screen background
    final bg = Theme.of(context).scaffoldBackgroundColor; 
    
    // ── RESTORED: Your original bluish-grey just for the bottom nav ──
    final bottomBg = isDarkMode ? const Color(0xFF2A2A3E) : Colors.white;

    return PopScope(
      canPop: _currentIndex == 0, // Only allow exit if we are on the Home tab (Index 0)
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        // If they press back on any other tab, send them to Home!
        setState(() => _currentIndex = 0);
      },

    child: SafeArea(
      child: Scaffold(
        drawer: _buildGeminiStyleDrawer(context),
        backgroundColor: bg,
        body: _currentIndex == 0
            ? _buildHome(isDarkMode)
            : _currentIndex == 1
                ? GoalsPage(
                    controller: _controller,
                    goals: _goals,
                    onGoalsChanged: () => _loadData(),
                    onBackToHome: () => setState(() => _currentIndex = 0), 
                  )
                : _currentIndex == 2
                    ? AnalysisPage(
                        controller: _controller,
                        onBackToHome: () => setState(() => _currentIndex = 0), 
                      )
                    : SettingsPage(
                        onBackToHome: () => setState(() => _currentIndex = 0), 
                      ), 

        floatingActionButton: _currentIndex == 0
            ? FloatingActionButton(
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    builder: (_) => FloatingAction(controller: _controller),
                  );
                  if (!mounted) return;
                  await _loadData();
                },
                backgroundColor: const Color(0xFF3EB489),
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: bottomBg,
          elevation: 10,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(icon: Icons.home_outlined,      filledIcon: Icons.home,              label: 'Home',     index: 0),
                _navItem(icon: Icons.golf_course_sharp,   filledIcon: Icons.golf_course_sharp,           label: 'Set Goals',  index: 1),
                if (_currentIndex == 0) const SizedBox(width: 48),
                _navItem(icon: Icons.bar_chart_outlined, filledIcon: Icons.bar_chart,         label: 'Analysis', index: 2),
                _navItem(icon: Icons.settings_outlined,  filledIcon: Icons.settings,          label: 'Settings', index: 3),
              ],
            ),
          ),
        ),
      ),
      )
    );
  }

  Widget _navItem({required IconData icon, required IconData filledIcon, required String label, required int index}) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 0) _loadData();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? filledIcon : icon,
            color: isActive ? const Color(0xFF3EB489) : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? const Color(0xFF3EB489) : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHome(bool isDarkMode) {
    final cardBg    = Theme.of(context).cardColor; 
    final textColor = Colors.white;
    final hintColor = Colors.white70;

    return ValueListenableBuilder<String>(
      valueListenable: currencyNotifier,
      builder: (context, currency, child) {
        final sym = currency.split(' ')[0]; 

        return Stack( // ── 1. STACK ADDED HERE ──
          children: [
            Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                // ── MATCHING GRADIENT ──
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
                  padding: const EdgeInsets.all(22),
                  
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Builder(
                            builder: (ctx) => IconButton(
                              // ── CHANGED TO HAMBURGER ICON ──
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ),
                          DropdownButton<String>(
                            value: selectDateFilter,
                            dropdownColor: const Color(0xFF3EB489),
                            style: const TextStyle(color: Colors.white),
                            iconEnabledColor: Colors.white,
                            underline: const SizedBox(),
                            items: dateoptions.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
                            onChanged: (value) async {
                              setState(() => selectDateFilter = value!);
                              if (value == 'Custom') {
                                DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                                if (picked != null) setState(() => customDate = picked);
                              }
                            },
                          ),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationPage(notificationController: _notificationController)));
                              setState(() {});
                            },
                            child: Stack(
                              children: [
                                const CircleAvatar(radius: 25, child: Icon(Icons.notifications_outlined)),
                                if (_notificationController.hasUnread)
                                  Positioned(
                                    top: 0, right: 0,
                                    child: Container(
                                      width: 12, height: 12,
                                      decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                                      child: Center(child: Text(_notificationController.unreadCount > 9 ? '9+' : '${_notificationController.unreadCount}', style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold))),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Current Balance', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text('$sym${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _moneyCard(
                              'Income', totalIncome, Icons.account_balance_wallet_outlined, 
                              AppTheme.jadeLight.withOpacity(0.15), // Neon Jade glow
                              AppTheme.jadeLight, cardBg, textColor, sym
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _moneyCard(
                              'Expenses', totalExpense, Icons.credit_card_outlined, 
                              Colors.redAccent.withOpacity(0.15), // Neon Red glow
                              Colors.redAccent, cardBg, textColor, sym
                            )
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _controller.isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF3EB489)))
                      : filtered.isEmpty
                          ? Center(child: Text('No transactions for this period', style: TextStyle(color: hintColor)))
                          : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Recent Transactions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                                     TextButton.icon(
                                        onPressed: () {
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: cardBg,
                                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                            builder: (sheetContext) => SafeArea(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 20),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                                                    const SizedBox(height: 20),
                                                    const Text('Export Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                                    const SizedBox(height: 20),
                                                    ListTile(
                                                      leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                                                      title: const Text('Export as PDF Document'),
                                                      subtitle: const Text('Best for printing or saving a formal statement'),
                                                      onTap: () async {
                                                        Navigator.pop(sheetContext); 
                                                        await Future.delayed(const Duration(milliseconds: 300));
                                                        try {
                                                          await ExportService.exportToPDF(filtered, currencySymbol: sym);
                                                          if (!context.mounted) return;
                                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF saved to Downloads folder! 📄'), backgroundColor: Color(0xFF3EB489), behavior: SnackBarBehavior.floating));
                                                        } catch (e) {
                                                          if (!context.mounted) return;
                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Error: $e'), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 5)));
                                                        }
                                                      },
                                                    ),
                                                    const Divider(height: 1),
                                                    ListTile(
                                                      leading: const Icon(Icons.table_chart_outlined, color: Colors.green),
                                                      title: const Text('Export as CSV Spreadsheet'),
                                                      subtitle: const Text('Best for viewing in Excel or Google Sheets'),
                                                      onTap: () async {
                                                        Navigator.pop(sheetContext); 
                                                        await Future.delayed(const Duration(milliseconds: 300));
                                                        try {
                                                          await ExportService.exportToCSV(filtered, currencySymbol: sym);
                                                          if (!context.mounted) return;
                                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV saved to Downloads folder! 📊'), backgroundColor: Color(0xFF3EB489), behavior: SnackBarBehavior.floating));
                                                        } catch (e) {
                                                          if (!context.mounted) return;
                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV Error: $e'), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 5)));
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.download, size: 18, color: Colors.grey),
                                        label: const Text("Save a copy", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                Expanded(
                                  child: RefreshIndicator(
                                    color: const Color(0xFF3EB489),
                                    onRefresh: _loadData,
                                    child: ListView.builder(
                                      itemCount: filtered.length,
                                      itemBuilder: (context, index) {
                                        final t = filtered[index];
                                        return ListTile(
                                          onLongPress: () => _showTransactionOptions(context, t, cardBg, textColor),
                                          leading: CircleAvatar(
                                              backgroundColor: t.isExpense ? const Color(0xFFFAECE7) : const Color(0xFFEAF3DE),
                                              child: Icon(t.isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                                                  color: t.isExpense ? const Color(0xFF993C1D) : const Color(0xFF3B6D11))),
                                          title: Text(t.title, style: TextStyle(color: textColor)),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 6.0),
                                            child: Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 6.0, // Space between items
                                              runSpacing: 4.0, // Space if it wraps to the next line
                                              children: [
                                                // ── ADDED DATE HERE ──
                                                Text(
                                                  '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}/${t.date.year}', 
                                                  style: TextStyle(color: hintColor, fontSize: 12, fontWeight: FontWeight.w500)
                                                ),
                                                Icon(Icons.circle, size: 4, color: hintColor.withOpacity(0.5)),
                                                
                                                Text(t.category, style: TextStyle(color: hintColor, fontSize: 12)),
                                                Icon(Icons.circle, size: 4, color: hintColor.withOpacity(0.5)),
                                                
                                                Text(t.paymentMethod, style: TextStyle(color: hintColor, fontStyle: FontStyle.italic, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          trailing: Text(
                                              '${t.isExpense ? '-' : '+'}$sym${t.amount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                  color: t.isExpense ? Colors.red : Colors.green,
                                                  fontWeight: FontWeight.w600)),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
            
            // ── 2. MAGIC BUTTON POSITIONED OVER THE LIST ──
            Positioned(
              bottom: 16,
              right: 16,
              child: MagicEntryButton(
                onTap: () {
                  _showMagicEntrySheet(context, cardBg, textColor);
                },
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _moneyCard(String label, double amount, IconData icon, Color iconBgColor, Color iconColor, Color cardBg, Color amountColor, String sym) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('$sym${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: amountColor)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // ── EDIT / DELETE METHODS ──
  // ════════════════════════════════════════════════════════════

  void _showTransactionOptions(BuildContext context, Transaction txn, Color cardBg, Color textColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Options for "${txn.title}"', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_outlined, color: Colors.blue),
                ),
                title: Text('Edit Transaction', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(sheetContext); 
                  _showEditSheet(txn, cardBg, textColor); 
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                title: const Text('Delete Transaction', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(sheetContext); 
                  _confirmDelete(txn, cardBg, textColor); 
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(Transaction txn, Color cardBg, Color textColor) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Transaction?', style: TextStyle(color: textColor)),
        content: Text('Are you sure you want to delete "${txn.title}"?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogContext); 
              if (txn.id != null) {
                final success = await ApiService.deleteTransaction(txn.id!); 
                if (success) {
                  _loadData(); 
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Color(0xFF3EB489)));
                } else {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete'), backgroundColor: Colors.redAccent));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(Transaction txn, Color cardBg, Color textColor) {
    final titleCtrl = TextEditingController(text: txn.title);
    final amountCtrl = TextEditingController(text: txn.amount.toString());
    DateTime selectedDate = txn.date; 
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final inputBg = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
          
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Transaction', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  TextFormField(
                    controller: titleCtrl,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFF3EB489), size: 18),
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020), 
                        lastDate: DateTime.now(), 
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(primary: Color(0xFF3EB489)),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, color: Color(0xFF3EB489), size: 18),
                          const SizedBox(width: 12),
                          Text(
                            '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                            style: TextStyle(color: textColor, fontSize: 16),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right, color: Color(0xFF3EB489)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3EB489), 
                        padding: const EdgeInsets.symmetric(vertical: 16), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: isSaving ? null : () async {
                        if (txn.id == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Transaction ID missing. Please restart app.'), backgroundColor: Colors.redAccent));
                          return;
                        }
                        
                        setSheetState(() => isSaving = true);
                        
                        try {
                          final updatedData = {
                            'title': titleCtrl.text.trim(),
                            'amount': double.tryParse(amountCtrl.text.trim()) ?? txn.amount,
                            'date': selectedDate.toIso8601String(), 
                          };
                          
                          final success = await ApiService.updateTransaction(txn.id!, updatedData);
                          
                          if (success) {
                            await _loadData(); 
                            if (context.mounted) Navigator.pop(context);
                          } else {
                            setSheetState(() => isSaving = false);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update failed. Check backend terminal.'), backgroundColor: Colors.redAccent));
                          }
                        } catch (e) {
                          setSheetState(() => isSaving = false);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
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

  // ════════════════════════════════════════════════════════════
  // ── MAGIC ENTRY UI ──
  // ════════════════════════════════════════════════════════════

  void _showMagicEntrySheet(BuildContext context, Color cardBg, Color textColor) {
    final textCtrl = TextEditingController();
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final inputBg = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24, 
              left: 24, right: 24, top: 24
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3EB489), Color(0xFFFFC300)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Magic Entry', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Type naturally. AI will extract the amount, category, and date.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                const SizedBox(height: 20),
                
                Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3EB489).withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 16.0),
                        child: Icon(Icons.auto_awesome, color: Color(0xFF3EB489), size: 18), 
                      ),
                      Expanded(
                        child: TextField(
                          controller: textCtrl,
                          autofocus: true,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: 'e.g., Spent ₹500 on Swiggy yesterday...',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onSubmitted: (val) async {
                             if (val.trim().isNotEmpty && !isProcessing) {
                                setSheetState(() => isProcessing = true);
                                
                                // ── FIX 1: KEYBOARD SUBMIT ACTION ──
                                final newTxnData = await ApiService.sendMagicEntry(val.trim());
                                
                                if (newTxnData != null) {
                                  // Parse map to object and add to memory
                                  final newTxn = Transaction.fromMap(newTxnData);
                                  _controller.allTransactions.add(newTxn);
                                  
                                  // Trigger the goals check!
                                  await _notificationController.checkGoals(_goals, _controller);
                                  
                                  await _loadData(); 
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ Magic Entry Saved!'), backgroundColor: Color(0xFF3EB489)));
                                  }
                                } else {
                                  setSheetState(() => isProcessing = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI could not understand. Try being more clear!'), backgroundColor: Colors.redAccent));
                                  }
                                }
                             }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: isProcessing
                          ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF3EB489), strokeWidth: 2)))
                          : IconButton(
                              icon: const Icon(Icons.send_rounded, color: Color(0xFF3EB489)),
                              onPressed: () {
                                if (textCtrl.text.trim().isEmpty) return;
                                
                                final textToProcess = textCtrl.text.trim();
                                
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ AI is processing...'), backgroundColor: Colors.blueAccent, duration: Duration(seconds: 2)));
                                
                                // ── FIX 2: BUTTON TAP ACTION ──
                                ApiService.sendMagicEntry(textToProcess).then((newTxnData) async {
                                  if (newTxnData != null) {
                                    // Parse map to object and add to memory
                                    final newTxn = Transaction.fromMap(newTxnData);
                                    _controller.allTransactions.add(newTxn);
                                    
                                    // Trigger the goals check!
                                    await _notificationController.checkGoals(_goals, _controller);
                                    
                                    _loadData(); 
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Magic Entry Saved!'), backgroundColor: Color(0xFF3EB489)));
                                    }
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ AI could not understand. Try being more clear!'), backgroundColor: Colors.redAccent));
                                    }
                                  }
                                });
                              },
                            ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Note: Try to be more specific for correct transactions to be saved. Unspecified payment methods will default to Cash.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      )
    );
  }
  // ════════════════════════════════════════════════════════════
  // ── GEMINI STYLE DRAWER ──
  // ════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════
  // ── PREMIUM FLAGSHIP DRAWER ──
  // ════════════════════════════════════════════════════════════

  Widget _buildGeminiStyleDrawer(BuildContext context) {
    // We can rely entirely on the permanent dark theme now!
    final drawerBg = Theme.of(context).scaffoldBackgroundColor;
    const iconColor = Colors.white70;
    const textColor = Colors.white;

    return Drawer(
      backgroundColor: drawerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. PREMIUM HEADER LOGO ──
            Padding(
              padding: const EdgeInsets.only(left: 24.0, top: 32.0, bottom: 24.0, right: 24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: AppTheme.jadeLight.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  
                  // ── NEW: DUAL-TONE TEXT LOGO FOR DRAWER ──
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'SPEND',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: textColor,
                          ),
                        ),
                        TextSpan(
                          text: 'WISE',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: const Color(0xFF3EB489),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── 2. SCROLLABLE MENU ITEMS ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  _drawerItem(Icons.home_outlined, 'Home', iconColor, textColor, index: 0),
                  _drawerItem(Icons.golf_course_sharp, 'Set Goals', iconColor, textColor, index: 1),
                  _drawerItem(Icons.bar_chart_outlined, 'Analysis', iconColor, textColor, index: 2),
                  
                  const SizedBox(height: 32),
                  
                  // ── LIFESTYLE SECTION ──
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
                    child: Text(
                      'LIFESTYLE',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ),
                  
                  _drawerItem(Icons.landscape_outlined, 'Outings', iconColor, textColor, isSpecial: true, onTap: () {
                    Navigator.pop(context); 
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const OutingsPage()));
                  }),
                ],
              ),
            ),

            // ── 3. INTERACTIVE PROFILE FOOTER ──
            Divider(height: 1, color: Colors.white.withOpacity(0.05)),
            InkWell(
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Row(
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: avatarNotifier,
                      builder: (context, avatar, child) {
                        return CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.jadeLight.withOpacity(0.15),
                          backgroundImage: avatar != null ? AssetImage(avatar) : null,
                          child: avatar == null ? Text(_userInitial, style: const TextStyle(color: AppTheme.jadeLight, fontWeight: FontWeight.bold, fontSize: 18)) : null,
                        );
                      }
                    ),
                    const SizedBox(width: 16),
                    
                    // Dynamic Name & Clickable Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName, 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'View Profile', 
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    
                    // Quick Settings Gear
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: iconColor, size: 24),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _currentIndex = 3);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to generate sleek, pill-shaped list items
  Widget _drawerItem(IconData icon, String title, Color iconColor, Color textColor, {int? index, bool isSpecial = false, VoidCallback? onTap}) {
    final bool isActive = !isSpecial && _currentIndex == index;
    final activeBg = AppTheme.jadeLight.withOpacity(0.15);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: isActive ? activeBg : Colors.transparent,
        leading: Icon(icon, color: isActive ? AppTheme.jadeLight : iconColor, size: 24),
        title: Text(
          title, 
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600, 
            fontSize: 15,
            color: isActive ? AppTheme.jadeLight : textColor,
          ),
        ),
        onTap: onTap ?? () {
          Navigator.pop(context);
          if (index != null) {
            setState(() => _currentIndex = index);
            if (index == 0) _loadData();
          }
        },
      ),
    );
  }
}