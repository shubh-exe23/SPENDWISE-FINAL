import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../main.dart'; // To access avatarNotifier
import 'avatar_selection_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _jade     = Color(0xFF3EB489);

  final TextEditingController _nameCtrl  = TextEditingController();
  String? _selectedAvatar;

  bool _isEditing = false;
  bool _isLoading = true; 
  bool _isSaving  = false; 
  final _formKey  = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final profile = await ApiService.getProfile();
    final prefs = await SharedPreferences.getInstance();
    
    if (profile != null) {
      setState(() {
        _nameCtrl.text  = profile['name'] ?? 'User';
        // Check API first, fallback to local storage
        _selectedAvatar = profile['avatar'] ?? prefs.getString('avatar'); 
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); 
    super.dispose();
  }

  String get _initials {
    final parts = _nameCtrl.text.trim().split(' ');
    if (parts.length >= 2) { return '${parts[0][0]}${parts[1][0]}'.toUpperCase(); }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    final success = await ApiService.updateProfile({
      'name': _nameCtrl.text.trim(),
      if (_selectedAvatar != null) 'avatar': _selectedAvatar,
    });

    if (!mounted) return;

    if (success) {
      // Broadcast change globally
      avatarNotifier.value = _selectedAvatar;
      final prefs = await SharedPreferences.getInstance();
      if (_selectedAvatar != null) await prefs.setString('avatar', _selectedAvatar!);

      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile'), backgroundColor: Colors.redAccent));
    }
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
        backgroundColor: _jade, elevation: 0, centerTitle: true, iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() => _isEditing = true);
                }
              },
              child: _isSaving 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_isEditing ? 'Save' : 'Edit', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: _jade)) 
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity, color: _jade, padding: const EdgeInsets.only(bottom: 32, top: 8),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 54, backgroundColor: chipBg,
                                backgroundImage: _selectedAvatar != null ? AssetImage(_selectedAvatar!) : null,
                                child: _selectedAvatar == null ? Text(_initials, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: textColor)) : null,
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final chosen = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AvatarSelectionPage()));
                                  if (chosen != null) {
                                    setState(() {
                                      _selectedAvatar = chosen;
                                      _isEditing = true; // Auto-trigger unsaved state
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: _jade, width: 2)),
                                  child: const Icon(Icons.edit, color: _jade, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(_nameCtrl.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Personal Info', textColor),
                          const SizedBox(height: 12),
                          _card(cardBg, borderColor, [
                            _fieldTile(icon: Icons.person_outline, label: 'Full Name', controller: _nameCtrl, enabled: _isEditing, validator: (v) => (v == null || v.trim().isEmpty) ? 'Name cannot be empty' : null, onChanged: (_) => setState(() {}), textColor: textColor, hintColor: hintColor),
                          ]),
                          const SizedBox(height: 24),
                          if (_isEditing)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(backgroundColor: _jade, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                                child: _isSaving 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                              ),
                            ),
                          if (_isEditing) const SizedBox(height: 12),
                          if (_isEditing)
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => setState(() {
                                  _isEditing = false;
                                  _loadUserData(); 
                                }),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderColor))),
                                child: Text('Cancel', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, Color textColor) => Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 0.4));
  Widget _card(Color cardBg, Color borderColor, List<Widget> children) => Container(decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)), child: Column(children: children));
  Widget _fieldTile({required IconData icon, required String label, required TextEditingController controller, required bool enabled, TextInputType? keyboardType, String? hint, String? Function(String?)? validator, Function(String)? onChanged, required Color textColor, required Color hintColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: _jade), 
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: hintColor, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                enabled
                    ? TextFormField(
                        controller: controller, keyboardType: keyboardType, validator: validator, onChanged: onChanged, style: TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: hintColor), isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _jade, width: 1.5))),
                      )
                    : Text(
                        controller.text.isEmpty ? (hint ?? 'Not set') : controller.text,
                        style: TextStyle(fontSize: 15, color: controller.text.isEmpty ? hintColor : textColor, fontWeight: FontWeight.w500),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}