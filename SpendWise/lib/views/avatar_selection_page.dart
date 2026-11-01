import 'package:flutter/material.dart';

class AvatarSelectionPage extends StatelessWidget {
  const AvatarSelectionPage({super.key});

  static const _jade = Color(0xFF3EB489);

  // ── ALL 8 AVATARS EXACTLY AS YOU SAVED THEM ──
  final List<String> _avatars = const [
    'assets/avatars/avatar_1.png',
    'assets/avatars/avatar_2.png',
    'assets/avatars/avatar_3.png',
    'assets/avatars/avatar_4.png',
    'assets/avatars/avatar_5.png',
    'assets/avatars/avatar_6.png',
    'assets/avatars/avatar_7.png',
    'assets/avatars/avatar_8.png',
  ];

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Choose Avatar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 Avatars per row
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
        ),
        itemCount: _avatars.length,
        itemBuilder: (context, index) {
          final avatarPath = _avatars[index];
          return GestureDetector(
            onTap: () {
              // This instantly returns the chosen avatar back to the Profile or Onboarding page!
              Navigator.pop(context, avatarPath);
            },
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: _jade.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(color: _jade.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  avatarPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('🚨 MISSING IMAGE: $avatarPath'); // Helps debug if one is misspelled
                    return Icon(Icons.person, size: 50, color: Colors.white.withOpacity(0.3));
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}