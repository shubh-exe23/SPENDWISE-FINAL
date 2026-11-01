import 'package:flutter/material.dart';
import 'dart:async';
import 'welcome_screen.dart';
import 'homepage.dart'; 
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key}); 

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;

      final loggedIn = await ApiService.isLoggedIn();

      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => loggedIn
              ? const MyHomePage()      
              : const WelcomeScreen(),  
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDarkMode ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        // ── SLEEK LOGO CONTAINER WITH A GLOW ──
        child: Container(
          height: 140,
          width: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3EB489).withOpacity(0.3), 
                blurRadius: 30, 
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset(
              'assets/logo.png', // ── Make sure this matches your file name! ──
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}