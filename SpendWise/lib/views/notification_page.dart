import 'package:flutter/material.dart';
import '../controllers/notification_controller.dart';
import '../models/app_notifications.dart';

class NotificationPage extends StatefulWidget {
  final NotificationController notificationController;

  const NotificationPage({
    super.key,
    required this.notificationController,
  });

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  static const _jade     = Color(0xFF3EB489);

  @override
  void initState() {
    super.initState();
    widget.notificationController.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    // ── DARK MODE FORMULA ──
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF6FDFB);
    final cardBg     = isDarkMode ? const Color(0xFF2A2A3E) : Colors.white;
    final textColor  = isDarkMode ? Colors.white : const Color(0xFF2A7D5F);
    final hintColor  = isDarkMode ? Colors.white54 : Colors.grey.shade600;
    final borderColor = isDarkMode ? Colors.white12 : const Color(0xFFCCEDE2);

    final notifications = widget.notificationController.all;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: _jade,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  widget.notificationController.markAllRead();
                });
              },
              child: const Text('Mark all read', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _emptyState(hintColor)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _notificationCard(n, isDarkMode, cardBg, textColor, hintColor, borderColor);
              },
            ),
    );
  }

  Widget _emptyState(Color hintColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_outlined, size: 72, color: hintColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No notifications yet', style: TextStyle(fontSize: 15, color: hintColor)),
        ],
      ),
    );
  }

  Widget _notificationCard(AppNotification n, bool isDark, Color cardBg, Color textColor, Color hintColor, Color borderColor) {
    final isWarning  = n.type == 'warning';
    final color      = isWarning ? Colors.orange : Colors.red;
    
    // Dynamic background for unread notifications based on theme
    final unreadBgColor = isWarning
        ? (isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50)
        : (isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50);
        
    final icon       = isWarning ? Icons.warning_amber_rounded : Icons.error_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: n.isRead ? cardBg : unreadBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: n.isRead ? borderColor : color.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(n.title,
            style: TextStyle(fontSize: 14, fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700, color: textColor)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(n.message, style: TextStyle(fontSize: 13, color: hintColor)),
            const SizedBox(height: 4),
            Text(_timeAgo(n.createdAt), style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade400)),
          ],
        ),
        trailing: !n.isRead
            ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: _jade, shape: BoxShape.circle))
            : null,
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}