// lib/screens/client/client_support_chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/support_ticket.dart';
import '../../models/support_message.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/toast.dart';

class ClientSupportChatScreen extends StatefulWidget {
  final SupportTicket ticket;

  const ClientSupportChatScreen({super.key, required this.ticket});

  @override
  State<ClientSupportChatScreen> createState() => _ClientSupportChatScreenState();
}

class _ClientSupportChatScreenState extends State<ClientSupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<SupportMessage> _messages = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _currentStatus = '';
  
  Timer? _pollTimer;
  String? _lastMessageId;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.ticket.status;
    _loadMessages();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollNewMessages(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final result = await ApiService.get(
        '/api/support/messages?ticket_id=${widget.ticket.id}',
      );
      if (result['success'] == true && mounted) {
        final List messagesData = result['data'] ?? [];
        
        setState(() {
          _messages = messagesData.map((m) => SupportMessage.fromJson(m)).toList();
          _isLoading = false;
          
          if (_messages.isNotEmpty) {
            _lastMessageId = _messages.last.id.toString();
          }
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pollNewMessages() async {
    if (_isUploading) return;
    
    try {
      String path = '/api/support/messages?ticket_id=${widget.ticket.id}';
      if (_lastMessageId != null) {
        path += '&after_id=$_lastMessageId';
      }
      
      final result = await ApiService.get(path, forceRefresh: true);
      
      if (result['success'] == true && mounted) {
        final List messagesData = result['data'] ?? [];
        
        if (messagesData.isNotEmpty) {
          setState(() {
            final serverMessages = messagesData.map((m) => SupportMessage.fromJson(m)).toList();
            _messages = serverMessages;
            
            if (serverMessages.isNotEmpty) {
              _lastMessageId = serverMessages.last.id.toString();
            }
          });
          _scrollToBottom();
        }
      }
    } on ApiException catch (e) { if (mounted) showToast(context, e.message, isError: true); }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    final localMsg = SupportMessage(
      id: 0,
      userId: 0,
      message: text,
      createdAt: DateTime.now().toIso8601String(),
      isMine: true,
      isPending: true,
    );

    setState(() {
      _messages.add(localMsg);
      _messageController.clear();
    });
    
    _scrollToBottom();
    _focusNode.requestFocus();

    try {
      if (_currentStatus == 'closed') {
        await ApiService.post('/api/support/toggle-status', {'ticket_id': widget.ticket.id});
      }

      final result = await ApiService.post('/api/support/send', {
        'ticket_id': widget.ticket.id,
        'message': text,
      });

      if (result['success'] == true && mounted) {
        _currentStatus = result['data']['status'] ?? 'open';
        await _loadMessages();
      } else {
        _markMessageFailed(text);
      }
    } catch (_) {
      _markMessageFailed(text);
    }
  }

  void _markMessageFailed(String text) {
    if (!mounted) return;
    
    setState(() {
      final index = _messages.indexWhere(
        (m) => m.id == 0 && m.message == text && m.isPending
      );
      
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isPending: false,
          isFailed: true,
        );
      }
    });
    
    AppToast.show(context, 'Ошибка отправки', type: AppToastType.error);
  }

  Future<void> _attachFile() async {
    if (_currentStatus == 'closed') {
      final statusResult = await ApiService.post(
        '/api/support/toggle-status',
        {'ticket_id': widget.ticket.id},
      );
      if (statusResult['success'] != true) return;
      _currentStatus = 'open';
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Прикрепить фото', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFDD1847)),
                title: const Text('Сделать снимок'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleImagePick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFDD1847)),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleImagePick(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleImagePick(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: source, imageQuality: 80);
      
      if (file == null) return;
      
      if (await file.length() > 5 * 1024 * 1024) {
        if (mounted) {
          AppToast.show(context, 'Файл слишком большой', type: AppToastType.warning);
        }
        return;
      }

      setState(() => _isUploading = true);

      final result = await ApiService.uploadFile(
        '/api/support/upload-file',
        filePath: file.path,
        fileName: file.name,
        fieldName: 'file',
        additionalFields: {'ticket_id': widget.ticket.id.toString()},
      );

      if (result['success'] == true && mounted) {
        _currentStatus = result['data']['status'] ?? 'open';
        await _loadMessages();
      }

    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Ошибка загрузки', type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr.replaceFirst(' ', 'T'));
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  bool _isDifferentDay(String date1, String date2) {
    try {
      final d1 = DateTime.parse(date1.replaceFirst(' ', 'T'));
      final d2 = DateTime.parse(date2.replaceFirst(' ', 'T'));
      return d1.day != d2.day || d1.month != d2.month || d1.year != d2.year;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = _currentStatus == 'closed';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ticket.subject,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Text('Обращение #${widget.ticket.id}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isClosed ? Colors.white24 : const Color(0xFF4CAF50).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isClosed ? 'Закрыто' : 'Открыто',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDD1847),
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: Column(
          children: [
            if (_isUploading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFF3F4F6),
                child: const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDD1847))),
                    SizedBox(width: 12),
                    Text('Загрузка фото...', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
                  ],
                ),
              ),
            Expanded(child: _buildBody()),
            _buildInputArea(isClosed),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFDD1847)));
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 40, color: Color(0xFFDD1847)),
            ),
            const SizedBox(height: 20),
            const Text('Нет сообщений', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 6),
            const Text('Напишите первое сообщение', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: _messages.length,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final showDate = index == 0 || _isDifferentDay(_messages[index - 1].createdAt, msg.createdAt);
        return Column(
          children: [
            if (showDate) _DateDivider(date: msg.createdAt),
            _MessageBubble(message: msg, formatTime: _formatTime),
          ],
        );
      },
    );
  }

  Widget _buildInputArea(bool isClosed) {
    final hasText = _messageController.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isUploading ? null : _attachFile,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: Icon(Icons.camera_alt, size: 22, color: _isUploading ? const Color(0xFFCCCCCC) : const Color(0xFF999999)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _focusNode.hasFocus ? const Color(0xFFDD1847).withValues(alpha: 0.3) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), height: 1.4),
                    decoration: InputDecoration(
                      hintText: isClosed ? 'Обращение закрыто. Напишите, чтобы открыть...' : 'Сообщение...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasText ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: hasText ? _sendMessage : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: Icon(Icons.arrow_upward, color: hasText ? Colors.white : const Color(0xFF999999), size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final String date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    String label;
    try {
      final d = DateTime.parse(date.replaceFirst(' ', 'T'));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDate = DateTime(d.year, d.month, d.day);
      final diff = today.difference(msgDate).inDays;

      if (diff == 0) {
        label = 'Сегодня';
      } else if (diff == 1) {
        label = 'Вчера';
      } else {
        const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
        label = '${d.day} ${months[d.month - 1]}';
        if (d.year != now.year) label += ' ${d.year}';
      }
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE8E8E8))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF999999))),
          ),
          const Expanded(child: Divider(color: Color(0xFFE8E8E8))),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessage message;
  final String Function(String) formatTime;

  const _MessageBubble({required this.message, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final hasFile = message.isFile;
    final hasText = (message.message ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: const Color(0xFFFDF2F5), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.support_agent, size: 18, color: Color(0xFFDD1847)),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (hasFile && message.isImage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(18)),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
                        child: message.attachmentUrl!.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: message.displayUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  width: 200, height: 200,
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDD1847))),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  width: 200, height: 100,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Color(0xFF999999), size: 32),
                                ),
                              )
                            : Image.file(File(message.attachmentUrl!), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                if (hasFile && !message.isImage)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMine ? const Color(0xFFC9153E) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_file, size: 20, color: isMine ? Colors.white70 : const Color(0xFF666666)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              message.attachmentName ?? 'Файл',
                              style: TextStyle(color: isMine ? Colors.white : const Color(0xFF1A1A1A), fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (hasText)
                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMine ? const Color(0xFFDD1847) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (isMine ? const Color(0xFFDD1847) : Colors.black).withValues(alpha: isMine ? 0.15 : 0.04),
                          blurRadius: isMine ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message.message!,
                      style: TextStyle(color: isMine ? Colors.white : const Color(0xFF1A1A1A), fontSize: 15, height: 1.45),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isPending)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey[400]),
                          ),
                        ),
                      Text(
                        formatTime(message.createdAt),
                        style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}