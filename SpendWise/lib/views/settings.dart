import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_page.dart';
import '../services/api_service.dart';
import 'welcome_screen.dart';
import '../main.dart'; 
import 'subscription_manager.dart';
import '../themes/app_theme.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onBackToHome;

  const SettingsPage({super.key, required this.onBackToHome});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _goalAlerts = true; 
  String _selectedCurrency = '₹ INR';
  String _userName = 'User';
  String _userInitial = 'U';

  final List<String> _currencies = ['₹ INR', '\$ USD', '€ EUR', '£ GBP', '¥ JPY'];

  @override
  void initState() {
    super.initState();
    _selectedCurrency = currencyNotifier.value;
    _loadUserProfile();
    _loadLocalSettings(); 
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _goalAlerts = prefs.getBool('goal_alerts') ?? true;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final profile = await ApiService.getProfile();
    if (profile != null && profile['name'] != null) {
      if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    // Relying on the global AppTheme background colors
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Theme.of(context).cardColor;
    final textPrimary = Colors.white;
    final textSecondary = Colors.white54;
    final divider = Colors.white12;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackToHome, 
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 120, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Profile', textSecondary),
            _card(cardBg, divider, [
              _avatarTile(textPrimary, textSecondary),
            ]),
            const SizedBox(height: 24),

            _sectionHeader('Preferences', textSecondary),
            _card(cardBg, divider, [
              ListTile(
                leading: const Icon(Icons.autorenew, color: AppTheme.jadeLight),
                title: Text('Recurring Bills & Subscriptions', style: TextStyle(color: textPrimary, fontSize: 15)),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.jadeLight),
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const SubscriptionManager()),
                  );
                },
              ),
              _divider(divider),
              _dropdownTile(
                icon: Icons.currency_exchange_outlined,
                label: 'Currency',
                value: _selectedCurrency,
                options: _currencies,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onChanged: (val) async {
                  if (val == null) return;
                  setState(() => _selectedCurrency = val);
                  currencyNotifier.value = val;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('currency', val);
                  await ApiService.updateProfile({'currency': val});
                },
              ),
              _divider(divider),
              _arrowTile(
                icon: Icons.language_outlined,
                label: 'Language (English)',
                textPrimary: textPrimary,
                iconColor: AppTheme.jadeLight,
                onTap: () => _showComingSoon('Support for other languages'),
              ),
            ]),
            const SizedBox(height: 24),

            _sectionHeader('Notifications', textSecondary),
            _card(cardBg, divider, [
              _toggleTile(
                icon: Icons.flag_outlined,
                label: 'Goal Exceeded Alerts',
                value: _goalAlerts,
                textPrimary: textPrimary,
                onChanged: (val) async {
                  setState(() => _goalAlerts = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('goal_alerts', val);
                },
              ),
            ]),
            const SizedBox(height: 24),

            _sectionHeader('Data', textSecondary),
            _card(cardBg, divider, [
              _arrowTile(
                icon: Icons.delete_outline,
                label: 'Clear Transactions',
                textPrimary: Colors.redAccent,
                iconColor: Colors.redAccent,
                onTap: () => _showClearTransactionsDialog(cardBg, textPrimary, textSecondary), 
              ),
            ]),
            const SizedBox(height: 24),

            _sectionHeader('General', textSecondary),
            _card(cardBg, divider, [
              _arrowTile(
                icon: Icons.info_outline,
                label: 'About',
                textPrimary: textPrimary,
                onTap: () => _showAboutDialog(cardBg, textPrimary, textSecondary),
              ),
              _divider(divider),
              _arrowTile(
                icon: Icons.lock_outline,
                label: 'Permissions',
                textPrimary: textPrimary,
                onTap: () => _showComingSoon('Permissions'),
              ),
              _divider(divider),
              _arrowTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                textPrimary: textPrimary,
                onTap: () => _showComingSoon('Privacy Policy'),
              ),
              _divider(divider),
              _arrowTile(
                icon: Icons.logout,
                label: 'Log Out',
                textPrimary: Colors.redAccent,
                iconColor: Colors.redAccent,
                onTap: () => _confirmLogout(cardBg, textPrimary),
              ),
            ]),
            const SizedBox(height: 32),

            Center(child: Text('Version 1.0.0', style: TextStyle(fontSize: 12, color: textSecondary))),
            const SizedBox(height: 8),
            Center(child: Text('Made with ♥ using Flutter', style: TextStyle(fontSize: 12, color: textSecondary))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.4)),
    );
  }

  Widget _card(Color bg, Color divider, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: divider)),
      child: Column(children: children),
    );
  }

  Widget _divider(Color color) => Padding(
        padding: const EdgeInsets.only(left: 52),
        child: Divider(height: 1, color: color),
      );

  Widget _avatarTile(Color textPrimary, Color textSecondary) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, 
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
        _loadUserProfile();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // ── NEW: DYNAMIC AVATAR WRAPPER ──
            ValueListenableBuilder<String?>(
              valueListenable: avatarNotifier,
              builder: (context, avatar, child) {
                return CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.jadeLight.withOpacity(0.2),
                  backgroundImage: avatar != null ? AssetImage(avatar) : null,
                  child: avatar == null ? Text(_userInitial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.jadeLight)) : null,
                );
              }
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_userName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 2),
                Text('Tap to edit profile', style: TextStyle(fontSize: 12, color: textSecondary)),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _toggleTile({required IconData icon, required String label, required bool value, required Color textPrimary, required Function(bool) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppTheme.jadeLight),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: textPrimary))),
          Switch(value: value, onChanged: onChanged, activeColor: AppTheme.jadeLight),
        ],
      ),
    );
  }

  Widget _dropdownTile({required IconData icon, required String label, required String value, required List<String> options, required Color textPrimary, required Color textSecondary, required Function(String?) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppTheme.jadeLight),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: textPrimary))),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: Icon(Icons.chevron_right, color: textSecondary, size: 20),
              style: TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.bold),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrowTile({required IconData icon, required String label, required Color textPrimary, Color? iconColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor ?? AppTheme.jadeLight),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: textPrimary))),
            Icon(Icons.chevron_right, color: iconColor ?? Colors.grey.shade600, size: 20),
          ],
        ),
      ),
    );
  }

  void _showClearTransactionsDialog(Color cardBg, Color textPrimary, Color textSecondary) {
    // ── FIXED: EXACT MATCH TO HOMEPAGE STRINGS ──
    String selectedPeriod = 'All time';
    final List<String> periods = ['Today', 'Yesterday', 'This week', 'This month', 'All time'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Clear Transactions', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select the timeframe you want to clear.', style: TextStyle(color: textSecondary, fontSize: 14)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPeriod,
                        isExpanded: true,
                        dropdownColor: cardBg,
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        icon: Icon(Icons.keyboard_arrow_down, color: textSecondary),
                        items: periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedPeriod = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.jadeLight)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.jadeLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); 
                    _showDeleteConfirmationDialog(selectedPeriod, cardBg, textPrimary, textSecondary);
                  },
                  child: const Text('Next', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(String period, Color cardBg, Color textPrimary, Color textSecondary) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text('Are you sure?', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 18)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: textPrimary, fontSize: 14, height: 1.4),
            children: [
              const TextSpan(text: 'You are about to permanently delete all transactions from '),
              TextSpan(text: '"$period"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
              const TextSpan(text: '.\n\nThis action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel', style: TextStyle(color: AppTheme.jadeLight))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () async {
              Navigator.pop(context); 
              
              final success = await ApiService.clearTransactions(period);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully deleted transactions for: $period'), backgroundColor: AppTheme.jadeLight),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete transactions.'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Yes, Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  void _showAboutDialog(Color cardBg, Color textPrimary, Color textSecondary) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.jadeLight.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.jadeLight, size: 24),
            ),
            const SizedBox(width: 12),
            Text('SPENDWISE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0', style: TextStyle(color: textPrimary)), const SizedBox(height: 4),
            Text('Build: 2026.1', style: TextStyle(color: textPrimary)), const SizedBox(height: 4),
            Text('Platform: Flutter', style: TextStyle(color: textPrimary)), const SizedBox(height: 12),
            Text('A premium, intuitive expense tracking experience.', style: TextStyle(color: textSecondary)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.jadeLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(Color cardBg, Color textPrimary) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out?', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
        content: Text('Are you sure you want to log out?', style: TextStyle(color: textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.jadeLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(context); 
              await ApiService.logout(); 

              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false, 
              );
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature — coming soon')));
  }
}