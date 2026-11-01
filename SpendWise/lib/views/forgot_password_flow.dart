import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

// ════════════════════════════════════════════
// ── SCREEN 1: REQUEST EMAIL ──
// ════════════════════════════════════════════
class ForgotPasswordEmailScreen extends StatefulWidget {
  const ForgotPasswordEmailScreen({super.key});

  @override
  State<ForgotPasswordEmailScreen> createState() => _ForgotPasswordEmailScreenState();
}

class _ForgotPasswordEmailScreenState extends State<ForgotPasswordEmailScreen> {
  static const _jade = Color(0xFF3EB489);
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  void _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim();
    final result = await ApiService.forgotPassword(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyOtpScreen(email: email)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to send OTP'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
    final cardBg = isDark ? const Color(0xFF2A2A3E) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF2A7D5F);
    final hintCol = isDark ? Colors.white54 : Colors.grey.shade500;
    final borderCol = isDark ? Colors.white12 : const Color(0xFFCCEDE2);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 42, height: 42, decoration: BoxDecoration(color: isDark ? Colors.white12 : const Color(0xFFE8F5F0), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.arrow_back_ios_new, size: 18, color: textCol)),
                ),
                const SizedBox(height: 32),
                Text('Forgot Password? 🔒', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textCol)),
                const SizedBox(height: 8),
                Text('Enter your email address and we will send you a 6-digit verification code.', style: TextStyle(fontSize: 14, color: hintCol)),
                const SizedBox(height: 40),
                Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textCol)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: TextStyle(fontSize: 15, color: textCol),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  decoration: InputDecoration(hintText: 'you@example.com', hintStyle: TextStyle(color: hintCol), prefixIcon: const Icon(Icons.mail_outline, color: _jade, size: 20), filled: true, fillColor: cardBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderCol)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderCol)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _jade, width: 1.5))),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(backgroundColor: _jade, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send OTP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// ── SCREEN 2: VERIFY OTP ONLY ──
// ════════════════════════════════════════════
class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  static const _jade = Color(0xFF3EB489);
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  
  int _start = 30;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() { _start = 30; _canResend = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) { setState(() { _timer?.cancel(); _canResend = true; }); } 
      else { setState(() => _start--); }
    });
  }

  @override
  void dispose() { _timer?.cancel(); _otpCtrl.dispose(); super.dispose(); }

  void _resendOtp() async {
    if (!_canResend) return;
    await ApiService.forgotPassword(widget.email);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New OTP sent!')));
    _startTimer();
  }

  void _verifyOtpAndNext() {
    if (!_formKey.currentState!.validate()) return;
    // Pass the OTP and Email to the final screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateNewPasswordScreen(email: widget.email, otp: _otpCtrl.text.trim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
    final cardBg = isDark ? const Color(0xFF2A2A3E) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF2A7D5F);
    final hintCol = isDark ? Colors.white54 : Colors.grey.shade500;
    final borderCol = isDark ? Colors.white12 : const Color(0xFFCCEDE2);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 42, height: 42, decoration: BoxDecoration(color: isDark ? Colors.white12 : const Color(0xFFE8F5F0), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.arrow_back_ios_new, size: 18, color: textCol)),
                ),
                const SizedBox(height: 32),
                Text('Enter Code 🔑', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textCol)),
                const SizedBox(height: 8),
                Text('We sent a 6-digit code to ${widget.email}', style: TextStyle(fontSize: 14, color: hintCol)),
                const SizedBox(height: 40),
                
                Text('6-Digit OTP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textCol)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _otpCtrl, keyboardType: TextInputType.number, inputFormatters: [LengthLimitingTextInputFormatter(6), FilteringTextInputFormatter.digitsOnly], style: TextStyle(fontSize: 18, letterSpacing: 8, color: textCol, fontWeight: FontWeight.bold),
                  validator: (v) => (v == null || v.length != 6) ? 'Enter the 6-digit code' : null,
                  decoration: InputDecoration(hintText: '123456', hintStyle: TextStyle(color: hintCol, letterSpacing: 8), prefixIcon: const Icon(Icons.lock_clock_outlined, color: _jade, size: 20), filled: true, fillColor: cardBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderCol)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderCol)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _jade, width: 1.5))),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Didn't receive code?", style: TextStyle(color: hintCol, fontSize: 13)),
                    TextButton(onPressed: _canResend ? _resendOtp : null, child: Text(_canResend ? 'Resend OTP' : 'Resend in 0:${_start.toString().padLeft(2, '0')}', style: TextStyle(color: _canResend ? _jade : hintCol, fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verifyOtpAndNext,
                    style: ElevatedButton.styleFrom(backgroundColor: _jade, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: const Text('Verify Code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// ── SCREEN 3: CREATE NEW PASSWORD ──
// ════════════════════════════════════════════
class CreateNewPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;
  const CreateNewPasswordScreen({super.key, required this.email, required this.otp});

  @override
  State<CreateNewPasswordScreen> createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  static const _jade = Color(0xFF3EB489);
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() { _passCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  void _saveNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Call the API with the stored Email and OTP from previous screens
    final result = await ApiService.resetPassword(
      widget.email,
      widget.otp,
      _passCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully! Please login.'), backgroundColor: _jade));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Invalid or expired OTP'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
    final cardBg = isDark ? const Color(0xFF2A2A3E) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF2A7D5F);
    final hintCol = isDark ? Colors.white54 : Colors.grey.shade500;
    final borderCol = isDark ? Colors.white12 : const Color(0xFFCCEDE2);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 42, height: 42, decoration: BoxDecoration(color: isDark ? Colors.white12 : const Color(0xFFE8F5F0), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.arrow_back_ios_new, size: 18, color: textCol)),
                ),
                const SizedBox(height: 32),
                Text('New Password 🛡️', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textCol)),
                const SizedBox(height: 8),
                Text('Your new password must be unique from those previously used.', style: TextStyle(fontSize: 14, color: hintCol)),
                const SizedBox(height: 40),

                Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textCol)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passCtrl, obscureText: _obscurePass, style: TextStyle(fontSize: 15, color: textCol),
                  validator: (v) => (v == null || v.length < 6) ? 'Must be at least 6 characters' : null,
                  decoration: InputDecoration(hintText: '••••••••', hintStyle: TextStyle(color: hintCol), prefixIcon: const Icon(Icons.lock_outline, color: _jade, size: 20), suffixIcon: GestureDetector(onTap: () => setState(() => _obscurePass = !_obscurePass), child: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: hintCol, size: 20)), filled: true, fillColor: cardBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderCol)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderCol)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _jade, width: 1.5))),
                ),
                const SizedBox(height: 20),

                Text('Confirm Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textCol)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmCtrl, obscureText: _obscureConfirm, style: TextStyle(fontSize: 15, color: textCol),
                  validator: (v) { if (v == null || v.isEmpty) return 'Please confirm password'; if (v != _passCtrl.text) return 'Passwords do not match'; return null; },
                  decoration: InputDecoration(hintText: '••••••••', hintStyle: TextStyle(color: hintCol), prefixIcon: const Icon(Icons.lock_outline, color: _jade, size: 20), suffixIcon: GestureDetector(onTap: () => setState(() => _obscureConfirm = !_obscureConfirm), child: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: hintCol, size: 20)), filled: true, fillColor: cardBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderCol)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderCol)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _jade, width: 1.5))),
                ),
                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveNewPassword,
                    style: ElevatedButton.styleFrom(backgroundColor: _jade, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save New Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}