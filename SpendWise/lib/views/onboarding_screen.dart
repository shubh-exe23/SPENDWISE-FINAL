import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'homepage.dart';
import '../main.dart'; // To update the global currencyNotifier
import 'avatar_selection_page.dart'; // ── MAKE SURE THIS IMPORT MATCHES YOUR FILE NAME ──

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _jade = Color(0xFF3EB489);
  
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // ── USER DATA ──
  final TextEditingController _nameCtrl = TextEditingController();
  String _selectedCurrency = '₹ INR';
  final List<String> _currencies = ['₹ INR', '\$ USD', '€ EUR', '£ GBP', '¥ JPY'];
  
  // ── NEW: AVATAR SELECTION STATE ──
  String? _selectedAvatar; 

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Validate Name before moving to page 2
    if (_currentPage == 0 && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your name'), backgroundColor: Colors.redAccent));
      return;
    }
    
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _finishSetup() async {
    setState(() => _isLoading = true);

    // 1. Save preferences to database (Now including the avatar!)
    final success = await ApiService.updateProfile({
      'name': _nameCtrl.text.trim(),
      'currency': _selectedCurrency,
      if (_selectedAvatar != null) 'avatar': _selectedAvatar,
    });

    if (success) {
      // 2. Update the global state & local storage
      currencyNotifier.value = _selectedCurrency;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency', _selectedCurrency);
      
      // Save the avatar locally so the homepage can display it immediately
      if (_selectedAvatar != null) {
        await prefs.setString('avatar', _selectedAvatar!);
      }

      if (!mounted) return;
      
      // 3. Navigate to Homepage and destroy the onboarding stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MyHomePage()),
        (route) => false,
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save settings. Please try again.'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── DARK MODE FORMULA ──
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
    final cardBg     = isDarkMode ? const Color(0xFF2A2A3E) : Colors.white;
    final textColor  = isDarkMode ? Colors.white : const Color(0xFF2A7D5F);
    final hintColor  = isDarkMode ? Colors.white54 : Colors.grey.shade500;
    final borderColor = isDarkMode ? Colors.white12 : const Color(0xFFCCEDE2);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── PROGRESS INDICATOR ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage >= index ? _jade : borderColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── SLIDING PAGES ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disables manual swiping
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildNamePage(textColor, hintColor, cardBg, borderColor),
                  _buildCurrencyPage(textColor, hintColor, cardBg, borderColor),
                  _buildProfilePicPage(textColor, hintColor, cardBg),
                ],
              ),
            ),

            // ── BOTTOM BUTTON ──
            Padding(
              padding: const EdgeInsets.all(32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading 
                      ? null 
                      : (_currentPage == 2 ? _finishSetup : _nextPage),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _jade,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _currentPage == 2 ? 'Go to Dashboard' : 'Continue',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PAGE 1: NAME ──
  Widget _buildNamePage(Color textColor, Color hintColor, Color cardBg, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          Text('What should we call you?', style: TextStyle(fontSize: 16, color: hintColor)),
          const SizedBox(height: 40),
          TextFormField(
            controller: _nameCtrl,
            style: TextStyle(fontSize: 16, color: textColor),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g. John Doe',
              hintStyle: TextStyle(color: hintColor),
              prefixIcon: const Icon(Icons.person_outline, color: _jade, size: 22),
              filled: true, fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _jade, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  // ── PAGE 2: CURRENCY ──
  Widget _buildCurrencyPage(Color textColor, Color hintColor, Color cardBg, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Localize', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          Text('Choose your primary currency', style: TextStyle(fontSize: 16, color: hintColor)),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCurrency,
                isExpanded: true,
                dropdownColor: cardBg,
                icon: const Icon(Icons.keyboard_arrow_down, color: _jade),
                style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.w500),
                items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCurrency = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PAGE 3: PROFILE PICTURE ──
  Widget _buildProfilePicPage(Color textColor, Color hintColor, Color cardBg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Make it yours', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          Text('Choose a profile picture (Optional)', style: TextStyle(fontSize: 16, color: hintColor)),
          const SizedBox(height: 40),
          
          // ── TAP TO OPEN AVATAR SELECTION ──
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AvatarSelectionPage()),
              );
              
              // If the user selected an avatar and didn't just hit the back button
              if (result != null && result is String) {
                setState(() {
                  _selectedAvatar = result;
                });
              }
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: cardBg,
                  // Show the selected avatar if one exists, otherwise null
                  backgroundImage: _selectedAvatar != null ? AssetImage(_selectedAvatar!) : null,
                  // Show the default icon only if no avatar is selected
                  child: _selectedAvatar == null 
                      ? Icon(Icons.person, size: 70, color: hintColor.withOpacity(0.3))
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: _jade, shape: BoxShape.circle),
                  // Changed the camera icon to an edit icon since they are choosing an avatar
                  child: const Icon(Icons.edit, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}