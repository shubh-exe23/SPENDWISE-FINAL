class AppNotification {
  final int? id;
  final String title;
  final String message;
  final String type; // 'warning' or 'alert'
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    this.id,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'],
      title: map['title'],
      message: map['message'],
      type: map['type'],
      isRead: map['is_read'] ?? false,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
    };
  }
}