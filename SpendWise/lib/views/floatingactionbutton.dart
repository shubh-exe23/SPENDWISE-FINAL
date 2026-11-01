import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/transaction_controller.dart';
import '../models/transaction.dart';
import '../models/subscription.dart'; 
import '../services/api_service.dart'; 

class FloatingAction extends StatefulWidget {
  final TransactionController controller;
  const FloatingAction({super.key, required this.controller});

  @override
  State<FloatingAction> createState() => _FloatingActionState();
}

class _FloatingActionState extends State<FloatingAction> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food';
  String _selectedPaymentMethod = 'UPI'; 
  bool _isExpense = true;
  bool _isSaving = false;

  bool _isRecurring = false; 
  String _frequency = 'monthly'; 

  late List<String> _expenseCategories;
  late List<String> _incomeCategories;

  final List<String> _expensePaymentMethods = ['Cash', 'UPI', 'Credit Card', 'Debit Card']; 
  final List<String> _incomePaymentMethods = ['Bank Transfer', 'UPI', 'Cash']; 
  
  static const _jade = Color(0xFF3EB489);

  @override
  void initState() {
    super.initState();
    
    final defaultExpense = {'Food', 'Hobbies', 'Study', 'Travel', 'Extra'};
    final defaultIncome = {'Salary', 'Bank Interest', 'Selling', 'Business', 'Allowance'};
    
    final pastExpense = widget.controller.allTransactions.where((t) => t.isExpense).map((t) => t.category).toSet();
    final pastIncome = widget.controller.allTransactions.where((t) => !t.isExpense).map((t) => t.category).toSet();
    
    _expenseCategories = defaultExpense.union(pastExpense).toList();
    _incomeCategories = defaultIncome.union(pastIncome).toList();
    
    _fetchGoalsAsCategories();
    
    if (!_expenseCategories.contains(_selectedCategory)) {
      if (_expenseCategories.isNotEmpty) {
        _selectedCategory = _expenseCategories.first;
      } else {
        _selectedCategory = 'Food';
        _expenseCategories.add('Food');
      }
    }
    
    _selectedPaymentMethod = _expensePaymentMethods.first;
  }

  Future<void> _fetchGoalsAsCategories() async {
    final goalsList = await ApiService.getGoals();
    if (mounted) {
      setState(() {
        for (var goal in goalsList) {
          final goalName = goal['name'].toString().trim();
          if (goalName.isNotEmpty && !_expenseCategories.contains(goalName)) {
            _expenseCategories.add(goalName);
          }
        }
      });
    }
  }

  @override
  void dispose() { _title.dispose(); _amount.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: _jade)), child: child!),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showCreateCategoryDialog(Color cardBg, Color textColor) {
    final controller = TextEditingController();
    bool isSavingCategory = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('New Category', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
            content: TextField(
              controller: controller, 
              autofocus: true, 
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'e.g. Health', 
                hintStyle: TextStyle(color: Colors.grey.shade500), 
                filled: true, 
                fillColor: cardBg == Colors.white ? const Color(0xFFE8F5F0) : Colors.white12, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext), 
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _jade, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isSavingCategory ? null : () async {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    setDialogState(() => isSavingCategory = true);
                    final success = await ApiService.addCategory(name);
                    
                    if (success) {
                      setState(() { 
                        if (_isExpense) {
                          _expenseCategories.add(name);
                        } else {
                          _incomeCategories.add(name);
                        }
                        _selectedCategory = name; 
                      });
                      if (context.mounted) Navigator.pop(dialogContext);
                    } else {
                      setDialogState(() => isSavingCategory = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to save category.'), backgroundColor: Colors.redAccent)
                        );
                      }
                    }
                  }
                },
                child: isSavingCategory 
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _onCancel(Color cardBg, Color textColor) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Discard Expense?', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        content: Text('Are you sure you want to discard this expense?', style: TextStyle(color: textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No', style: TextStyle(color: _jade))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    
    final transaction = Transaction(
      title: _title.text.trim(), 
      amount: double.parse(_amount.text.trim()), 
      isExpense: _isExpense, 
      date: _selectedDate, 
      category: _selectedCategory,
      paymentMethod: _selectedPaymentMethod, 
    );
    final success = await widget.controller.addTransaction(transaction);

    if (success && _isRecurring) {
      DateTime nextDate = _frequency == 'monthly' 
          ? DateTime(_selectedDate.year, _selectedDate.month + 1, _selectedDate.day)
          : DateTime(_selectedDate.year + 1, _selectedDate.month, _selectedDate.day);

      final subscription = Subscription(
        title: _title.text.trim(),
        amount: double.parse(_amount.text.trim()),
        isExpense: _isExpense,
        category: _selectedCategory,
        paymentMethod: _selectedPaymentMethod,
        frequency: _frequency,
        nextBillingDate: nextDate,
      );
      
      await ApiService.addSubscription(subscription.toMap());
    }
    
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) { Navigator.pop(context); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save transaction. Try again.'), backgroundColor: Colors.redAccent)); }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
    final cardBg     = isDarkMode ? const Color(0xFF2A2A3E) : Colors.white;
    final textColor  = isDarkMode ? Colors.white : const Color(0xFF2A7D5F);
    final hintColor  = isDarkMode ? Colors.white54 : Colors.grey.shade400;
    final borderColor = isDarkMode ? Colors.white12 : const Color(0xFFCCEDE2);
    final chipBg     = isDarkMode ? const Color(0xFF3B3B4F) : const Color(0xFFCCEDE2);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        title: Text('Add Transaction', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 18)),
        leading: IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => _onCancel(cardBg, textColor)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Type', textColor), const SizedBox(height: 8),
              _typeToggle(isDarkMode, textColor), const SizedBox(height: 24),
              
              _sectionLabel('Purpose', textColor), const SizedBox(height: 8),
              _styledField(
  controller: _title, 
  hint: _isExpense ? 'e.g. Lunch, Books, Netflix' : 'e.g. Salary, Allowance, Returns', 
  icon: Icons.edit_outlined, 
  validator: (v) => (v == null || v.trim().isEmpty) ? 'Purpose cannot be empty' : null, 
  cardBg: cardBg, 
  textColor: textColor, 
  hintColor: hintColor, 
  borderColor: borderColor
),
              const SizedBox(height: 24),
              
              _sectionLabel('Amount', textColor), const SizedBox(height: 8),
              _styledField(controller: _amount, hint: '0.00', icon: Icons.currency_rupee, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], validator: (v) { if (v == null || v.trim().isEmpty) return 'Amount cannot be empty'; if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter a valid amount greater than 0'; return null; }, cardBg: cardBg, textColor: textColor, hintColor: hintColor, borderColor: borderColor),
              const SizedBox(height: 24),
              
              _sectionLabel('Payment Method', textColor), const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: (_isExpense ? _expensePaymentMethods : _incomePaymentMethods)
                    .map((method) => _paymentChip(method, chipBg, textColor, borderColor))
                    .toList(),
              ),
              const SizedBox(height: 24),
              
              _sectionLabel(_isExpense ? 'Recurring Bill' : 'Recurring Income', textColor), 
const SizedBox(height: 8),
_recurringSelector(cardBg, textColor, borderColor, chipBg),
const SizedBox(height: 24),
              
             _sectionLabel(_isExpense ? 'Spending Date' : 'Income Date', textColor), const SizedBox(height: 8),
_dateSelector(cardBg, textColor, borderColor), const SizedBox(height: 24),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  _sectionLabel('Category', textColor),
                  const SizedBox(width: 8),
                  Text(
                    '(Long press to edit/delete)', 
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)
                  ),
                ],
              ), 
              const SizedBox(height: 12),
              _categorySelector(cardBg, chipBg, textColor, borderColor), 
              const SizedBox(height: 40),
              
              _actionButtons(borderColor, textColor, cardBg), const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recurringSelector(Color cardBg, Color textColor, Color borderColor, Color chipBg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.autorenew, color: _jade, size: 20), const SizedBox(width: 12),
                  Text(
  _isExpense ? 'Make this recurring bill' : 'Make this recurring income', 
  style: TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.w500)
),
                ],
              ),
              Switch(value: _isRecurring, onChanged: (val) => setState(() => _isRecurring = val), activeColor: _jade),
            ],
          ),
          if (_isRecurring) ...[
            const Divider(height: 16),
            Row(
              children: [
                Expanded(child: _frequencyChip('monthly', 'Monthly', chipBg, textColor)),
                const SizedBox(width: 12),
                Expanded(child: _frequencyChip('yearly', 'Yearly', chipBg, textColor)),
              ],
            ),
            const SizedBox(height: 8),
          ]
        ],
      ),
    );
  }

  Widget _frequencyChip(String value, String label, Color chipBg, Color textColor) {
    final selected = _frequency == value;
    return GestureDetector(
      onTap: () => setState(() => _frequency = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? _jade : chipBg, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(label, style: TextStyle(color: selected ? Colors.white : textColor, fontSize: 13, fontWeight: FontWeight.w600))),
      ),
    );
  }

  Widget _sectionLabel(String text, Color textColor) => Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 0.5));

  Widget _typeToggle(bool isDarkMode, Color textColor) {
    return Container(
      decoration: BoxDecoration(color: isDarkMode ? Colors.white12 : const Color(0xFFE8F5F0), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _toggleOption('Expense', true, textColor),
          _toggleOption('Income', false, textColor),
        ],
      ),
    );
  }

  Widget _toggleOption(String label, bool value, Color textColor) {
    final active = _isExpense == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpense = value;
            _selectedCategory = _isExpense ? _expenseCategories.first : _incomeCategories.first;
            _selectedPaymentMethod = _isExpense ? _expensePaymentMethods.first : _incomePaymentMethods.first;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: active ? _jade : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : textColor, fontWeight: FontWeight.w600, fontSize: 14))),
        ),
      ),
    );
  }

  Widget _styledField({required TextEditingController controller, required String hint, required IconData icon, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator, required Color cardBg, required Color textColor, required Color hintColor, required Color borderColor}) {
    return TextFormField(
      controller: controller, keyboardType: keyboardType, inputFormatters: inputFormatters, validator: validator, style: TextStyle(fontSize: 15, color: textColor),
      decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: hintColor), prefixIcon: Icon(icon, color: _jade, size: 20), filled: true, fillColor: cardBg, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _jade, width: 1.5)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent))),
    );
  }

  Widget _dateSelector(Color cardBg, Color textColor, Color borderColor) {
    final formatted = '${_selectedDate.day.toString().padLeft(2, '0')} / ${_selectedDate.month.toString().padLeft(2, '0')} / ${_selectedDate.year}';
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: _jade, size: 20), const SizedBox(width: 12),
            Text(formatted, style: TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.w500)),
            const Spacer(), const Icon(Icons.chevron_right, color: _jade),
          ],
        ),
      ),
    );
  }

  Widget _paymentChip(String label, Color chipBg, Color textColor, Color borderColor) {
    final selected = _selectedPaymentMethod == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _jade : Colors.transparent, 
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _jade : borderColor)
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : textColor, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _categorySelector(Color cardBg, Color chipBg, Color textColor, Color borderColor) {
    final currentCategories = _isExpense ? _expenseCategories : _incomeCategories;
    
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: [
        ...currentCategories.map((cat) => _categoryChip(cat, chipBg, textColor)),
        GestureDetector(
          onTap: () => _showCreateCategoryDialog(cardBg, textColor),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _jade, width: 1.2)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: _jade, size: 16), SizedBox(width: 4),
                Text('Create Category', style: TextStyle(color: _jade, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryChip(String label, Color chipBg, Color textColor) {
    final selected = _selectedCategory == label;
    final isDefault = {'Food', 'Hobbies', 'Study', 'Travel', 'Extra', 'Salary', 'Bank Interest', 'Selling', 'Business', 'Allowance'}.contains(label);

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      onLongPress: isDefault ? null : () {
        final cardBg = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A3E) : Colors.white;
        _showCategoryOptions(label, cardBg, textColor);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(color: selected ? _jade : chipBg, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : textColor, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _actionButtons(Color borderColor, Color textColor, Color cardBg) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => _onCancel(cardBg, textColor),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderColor))),
            child: Text('Cancel', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _onSave,
            style: ElevatedButton.styleFrom(backgroundColor: _jade, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(
  _isExpense ? 'Save Expense' : 'Save Income', 
  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)
),
          ),
        ),
      ],
    );
  }

  void _showCategoryOptions(String categoryName, Color cardBg, Color textColor) {
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
                child: Text('Options for "$categoryName"', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_outlined, color: Colors.blue),
                ),
                title: Text('Edit Category', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditCategoryDialog(categoryName, cardBg, textColor);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                title: const Text('Delete Category', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteCategory(categoryName, cardBg, textColor);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showEditCategoryDialog(String oldName, Color cardBg, Color textColor) {
    final controller = TextEditingController(text: oldName);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit Category', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
          content: TextField(
            controller: controller, 
            autofocus: true, 
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              filled: true, 
              fillColor: cardBg == Colors.white ? const Color(0xFFE8F5F0) : Colors.white12, 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _jade, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: isSaving ? null : () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty && newName != oldName) {
                  setDialogState(() => isSaving = true);
                  final success = await ApiService.updateCategoryByName(oldName, newName);
                  if (success) {
                    setState(() {
                      if (_isExpense) {
                        final index = _expenseCategories.indexOf(oldName);
                        if (index != -1) _expenseCategories[index] = newName;
                      } else {
                        final index = _incomeCategories.indexOf(oldName);
                        if (index != -1) _incomeCategories[index] = newName;
                      }
                      if (_selectedCategory == oldName) _selectedCategory = newName;
                    });
                    if (context.mounted) Navigator.pop(dialogContext);
                  } else {
                    setDialogState(() => isSaving = false);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update category.'), backgroundColor: Colors.redAccent));
                  }
                }
              },
              child: isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(String categoryName, Color cardBg, Color textColor) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "$categoryName"?', style: TextStyle(color: textColor)),
        content: Text('This will remove the category from your options. Existing transactions will keep their label.', style: const TextStyle(color: Colors.grey, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await ApiService.deleteCategoryByName(categoryName);
              if (success) {
                setState(() {
                  if (_isExpense) {
                    _expenseCategories.remove(categoryName);
                    if (_selectedCategory == categoryName) _selectedCategory = 'Food';
                  } else {
                    _incomeCategories.remove(categoryName);
                    if (_selectedCategory == categoryName) _selectedCategory = 'Salary';
                  }
                });
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category deleted'), backgroundColor: _jade));
              } else {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete category'), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}