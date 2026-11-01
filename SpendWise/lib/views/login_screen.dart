import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'homepage.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'forgot_password_flow.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _jade     = Color(0xFF3EB489);
  static const _jadeDark = Color(0xFF2A7D5F);

  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading       = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await ApiService.login(
      _emailCtrl.text.trim(),
      _passCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      await NotificationService.requestPermission();
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MyHomePage(), 
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Login failed'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
    final cardBg     = isDarkMode ? const Color(0xFF2A2A3E) : Colors.white;
    final textColor  = isDarkMode ? Colors.white : _jadeDark;
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
                const SizedBox(height: 10),
                
                // ── BACK BUTTON ──
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.arrow_back_ios_new, size: 18, color: isDarkMode ? Colors.white : _jadeDark),
                  ),
                ),
                
                const SizedBox(height: 48),

                // ── HEADER ──
                Text('Welcome\nBack! 👋', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: textColor, height: 1.2)),
                const SizedBox(height: 8),
                Text('Login to continue tracking your expenses', style: TextStyle(fontSize: 14, color: hintColor)),
                
                const SizedBox(height: 48),

                // ── EMAIL ──
                _label('Email Address', textColor),
                const SizedBox(height: 8),
                _inputField(
                  controller: _emailCtrl, hint: 'you@example.com', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress, cardBg: cardBg, textColor: textColor, hintColor: hintColor, borderColor: borderColor,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email cannot be empty';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── PASSWORD ──
                _label('Password', textColor),
                const SizedBox(height: 8),
                _inputField(
                  controller: _passCtrl, hint: '••••••••', icon: Icons.lock_outline, obscure: _obscurePassword, cardBg: cardBg, textColor: textColor, hintColor: hintColor, borderColor: borderColor,
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: hintColor, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Password cannot be empty';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── FORGOT PASSWORD ──
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordEmailScreen()),
                      );
                    },
                    child: const Text('Forgot Password?', style: TextStyle(color: _jade, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 40),

                // ── LOGIN BUTTON ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _jade, padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Login', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),

                // ── SIGNUP LINK ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: TextStyle(color: hintColor, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context, MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('Sign Up', style: TextStyle(color: _jade, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color textColor) => Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 0.4));

  Widget _inputField({
    required TextEditingController controller, required String hint, required IconData icon, TextInputType? keyboardType, bool obscure = false, Widget? suffixIcon, String? Function(String?)? validator, required Color cardBg, required Color textColor, required Color hintColor, required Color borderColor,
  }) {
    return TextFormField(
      controller: controller, keyboardType: keyboardType, obscureText: obscure, validator: validator, style: TextStyle(fontSize: 15, color: textColor),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: hintColor), prefixIcon: Icon(icon, color: _jade, size: 20), suffixIcon: suffixIcon, filled: true, fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _jade, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }
}