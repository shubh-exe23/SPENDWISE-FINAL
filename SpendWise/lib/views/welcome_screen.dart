import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart'; 
import 'login_screen.dart';
import 'register_screen.dart';
import '../themes/spendwise_doodle.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _jade = Color(0xFF3EB489);

  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;

  final List<Map<String, String>> _carouselItems = [
    {
      'image': 'assets/illustrations/magic_entry.png',
      'text': 'Stay organised,\nwith less spending.'
    },
    {
      'image': 'assets/illustrations/alerts.png',
      'text': 'Have more money,\nby spending less.'
    },
    {
      'image': 'assets/illustrations/split_bills.png',
      'text': 'Track every rupee.\nBuild your future.'
    },
    {
      'image': 'assets/illustrations/analytics.png',
      'text': 'Know exactly where\nyour money goes.'
    },
    {
      'image': 'assets/illustrations/start.png',
      'text': 'Small savings today.\nBig dreams tomorrow!'
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _carouselTimer = Timer.periodic(const Duration(milliseconds: 3500), (Timer timer) {
      if (_currentPage < _carouselItems.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
    final textColor  = isDarkMode ? Colors.white : const Color(0xFF2A7D5F);
    final hintColor  = isDarkMode ? Colors.white54 : Colors.grey.shade500;
    final dotColor   = isDarkMode ? Colors.white24 : Colors.grey.shade300;
    final iconBg     = isDarkMode ? Colors.white12 : const Color(0xFFE8F5F0);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── NEW: SLEEK DUAL-TONE BRANDING HEADER ──
            Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'SPEND',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: textColor,
                      ),
                    ),
                    TextSpan(
                      text: 'WISE',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: _jade,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Expanded(
              flex: 6,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _carouselItems.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LayoutBuilder(
                      builder: (context, slotConstraints) {
                        // Reserve space for the 36px gap + caption text below
                        // the image, then size the (square) image to whichever
                        // is smaller: available width or available height —
                        // so it always fits, on any screen or frame size.
                        const reservedForTextAndGap = 130.0;
                        final double imageSize = [
                          slotConstraints.maxWidth,
                          slotConstraints.maxHeight - reservedForTextAndGap,
                        ].reduce((a, b) => a < b ? a : b).clamp(0.0, double.infinity);

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Container(
                          height: imageSize,
                          width: imageSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(36), 
                            border: Border.all(color: _jade.withOpacity(0.4), width: 1.5), 
                            boxShadow: [
                              BoxShadow(color: _jade.withOpacity(0.15), blurRadius: 24, spreadRadius: 2),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(34),
                            child: Image.asset(
                              _carouselItems[index]['image']!,
                              fit: BoxFit.cover, 
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: iconBg,
                                child: Icon(Icons.image_outlined, size: 50, color: hintColor.withOpacity(0.4)),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 36),
                        
                        Text(
                          _carouselItems[index]['text']!, 
                          textAlign: TextAlign.center, 
                          style: GoogleFonts.poppins(
                            fontSize: 24, 
                            fontWeight: FontWeight.w700, 
                            color: textColor, 
                            height: 1.3,
                            letterSpacing: -0.5, 
                          )
                        ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselItems.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width:  _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: _currentPage == index ? _jade : dotColor, borderRadius: BorderRadius.circular(4)),
                );
              }),
            ),
            
            const SizedBox(height: 32),
            
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                        style: ElevatedButton.styleFrom(backgroundColor: _jade, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                        child: Text(
                          'Login', 
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: const BorderSide(color: _jade, width: 1.5)),
                        child: Text(
                          'Sign Up', 
                          style: GoogleFonts.poppins(color: _jade, fontSize: 16, fontWeight: FontWeight.w600)
                        ),
                      ),
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
}