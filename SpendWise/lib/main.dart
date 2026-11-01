import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'views/splashscreen.dart';
import 'services/notification_service.dart';
import 'themes/app_theme.dart';

// ── GLOBAL NOTIFIERS ──
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> currencyNotifier = ValueNotifier('₹ INR');
final ValueNotifier<String?> avatarNotifier  = ValueNotifier(null); // NEW: Avatar State

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  await NotificationService.requestPermission();

  final prefs = await SharedPreferences.getInstance();
  
  // Load Theme
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // Load Currency
  currencyNotifier.value = prefs.getString('currency') ?? '₹ INR';

  // Load Avatar
  avatarNotifier.value = prefs.getString('avatar');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'SPENDWISE',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme, 
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          // ── WRAPS THE APP IN A PHONE FRAME ON WIDE (DESKTOP/WEB) SCREENS ──
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: Scaffold(
                backgroundColor: const Color(0xFF0F0F1A),
                body: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 480) {
                        const frameWidth = 420.0;
                        const frameHeight = 850.0;
                        return Container(
                          width: frameWidth,
                          height: frameHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 8,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            // Make everything inside believe the screen is
                            // exactly the frame size, not the real browser window.
                            child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                size: const Size(frameWidth, frameHeight),
                              ),
                              child: child!,
                            ),
                          ),
                        );
                      }
                      return child!;
                    },
                  ),
                ),
              ),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}