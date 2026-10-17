class AppNotification {
  final String id;
  final String recipientId;
  final String? reportId;
  final String title;
  final String message;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.recipientId,
    this.reportId,
    required this.title,
    required this.message,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      reportId: json['report_id'] as String?,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
