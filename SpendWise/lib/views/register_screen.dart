import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart'; // ── IMPORT THE NEW WIZARD ──
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _jade     = Color(0xFF3EB489);

  final _formKey        = GlobalKey<FormState>();
  final _emailCtrl      = TextEditingController();
  final _passCtrl       = TextEditingController();
  final _confirmCtrl    = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose(); super.dispose();
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // 1. Create the account (Passing an empty string for the name initially)
    final result = await ApiService.register(
      '',
      _emailCtrl.text.trim(),
      _passCtrl.text.trim(),
    );

    if (result['success']) {
      // 2. Silently log the user in to get their JWT Token
      final loginResult = await ApiService.login(
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (loginResult['success']) {
        // 3. Route them to the new Setup Wizard
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      } else {
        // Fallback just in case auto-login fails
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created! Please login.'), backgroundColor: Color(0xFF3EB489)));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Registration failed'), backgroundColor: Colors.redAccent));
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
    final iconBg     = isDarkMode ? Colors.white12 : const Color(0xFFE8F5F0);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.arrow_back_ios_new, size: 18, color: textColor),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Create\nAccount! 🎉', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textColor, height: 1.2)),
                const SizedBox(height: 8),
                Text('Start your journey to financial freedom', style: TextStyle(fontSize: 14, color: hintColor)),
                const SizedBox(height: 40),
                
                // NAME FIELD REMOVED

                _label('Email Address', textColor), const SizedBox(height: 8),
                _inputField(controller: _emailCtrl, hint: 'you@example.com', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress, cardBg: cardBg, textColor: textColor, hintColor: hintColor, borderColor: borderColor, validator: (v) { if (v == null || v.trim().isEmpty) return 'Email cannot be empty'; if (!v.contains('@')) return 'Enter a valid email'; return null; }),
                const SizedBox(height: 20),

                _label('Password', textColor), const SizedBox(height: 8),
                _inputField(
                  controller: _passCtrl, hint: '••••••••', icon: Icons.lock_outline, obscure: _obscurePass, cardBg: cardBg, textColor: textColor, hintColor: hintColor, borderColor: borderColor,
                  suffixIcon: GestureDetector(onTap: () => setState(() => _obscurePass = !_obscurePass), child: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: hintColor, size: 20)),
                  validator: (v) { if (v == null || v.trim().isEmpty) return 'Password cannot be empty'; if (v.length < 6) return 'Password must be at least 6 characters'; return null; },
                ),
                const SizedBox(height: 20),

                _label('Confirm Password', textColor), const SizedBox(height: 8),
                _inputField(
                  controller: _confirmCtrl, hint: '••••••••', icon: Icons.lock_outline, obscure: _obscureConfirm, cardBg: cardBg, textColor: textColor, hintColor: hintColor, borderColor: borderColor,
                  suffixIcon: GestureDetector(onTap: () => setState(() => _obscureConfirm = !_obscureConfirm), child: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: hintColor, size: 20)),
                  validator: (v) { if (v == null || v.trim().isEmpty) return 'Please confirm your password'; if (v != _passCtrl.text) return 'Passwords do not match'; return null; },
                ),
                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(backgroundColor: _jade, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ', style: TextStyle(color: hintColor, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text('Login', style: TextStyle(color: _jade, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color textColor) => Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 0.4));

  Widget _inputField({required TextEditingController controller, required String hint, required IconData icon, TextInputType? keyboardType, bool obscure = false, Widget? suffixIcon, String? Function(String?)? validator, required Color cardBg, required Color textColor, required Color hintColor, required Color borderColor}) {
    return TextFormField(
      controller: controller, keyboardType: keyboardType, obscureText: obscure, validator: validator, style: TextStyle(fontSize: 15, color: textColor),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: hintColor), prefixIcon: Icon(icon, color: _jade, size: 20), suffixIcon: suffixIcon, filled: true, fillColor: cardBg, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _jade, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }
}