// lib/models/support_message.dart
class SupportMessage {
  final int id;
  final int userId;
  final String? message;
  final String? attachmentUrl;
  final String? attachmentName;
  final String createdAt;
  final bool isMine;
  final bool isPending;
  final bool isFailed;
  final bool isSent;
  final String? tempId;

  SupportMessage({
    required this.id,
    required this.userId,
    this.message,
    this.attachmentUrl,
    this.attachmentName,
    required this.createdAt,
    required this.isMine,
    this.isPending = false,
    this.isFailed = false,
    this.isSent = false,
    this.tempId,
  });

  bool get isFile => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImage {
    if (!isFile) return false;
    final name = attachmentName?.toLowerCase() ?? attachmentUrl!.toLowerCase();
    return name.contains('.jpg') || name.contains('.jpeg') || name.contains('.png') || name.contains('.webp') || name.contains('.gif');
  }

  String get displayUrl {
    if (attachmentUrl == null) return '';
    if (attachmentUrl!.startsWith('http')) return attachmentUrl!;
    if (attachmentUrl!.startsWith('/uploads')) return 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai$attachmentUrl';
    return attachmentUrl!;
  }

  SupportMessage copyWith({
    bool? isPending,
    bool? isFailed,
    bool? isSent,
    int? id,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      userId: userId,
      message: message,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      createdAt: createdAt,
      isMine: isMine,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
      isSent: isSent ?? this.isSent,
      tempId: tempId,
    );
  }

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      message: json['message'],
      attachmentUrl: json['attachment_url'],
      attachmentName: json['attachment_name'],
      createdAt: json['created_at'] ?? '',
      isMine: json['is_mine'] ?? false,
      isSent: true,
    );
  }
}