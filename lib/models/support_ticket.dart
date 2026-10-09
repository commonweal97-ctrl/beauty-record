// lib/models/support_ticket.dart
class SupportTicket {
  final int id;
  final String subject;
  final String status;
  final int unread;
  final String createdAt;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.unread,
    required this.createdAt,
  });

  bool get isClosed => status == 'closed';

  String get statusText {
    switch (status) {
      case 'open': return 'Открыто';
      case 'waiting_reply': return 'Ждёт ответа';
      case 'closed': return 'Закрыто';
      default: return 'Открыто';
    }
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] ?? 0,
      subject: json['subject'] ?? '',
      status: json['status'] ?? 'open',
      unread: json['unread'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}