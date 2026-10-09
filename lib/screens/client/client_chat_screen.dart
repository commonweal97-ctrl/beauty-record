// lib/client_chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import 'support_screen.dart';

class ClientChatScreen extends StatefulWidget {
  const ClientChatScreen({super.key});

  @override
  State<ClientChatScreen> createState() => _ClientChatScreenState();
}

class _ClientChatScreenState extends State<ClientChatScreen> {
  List<Map<String, dynamic>> _orgChats = [];
  Map<String, dynamic>? _activeChat;
  List<Map<String, dynamic>> _messages = [];
  bool _loadingChats = true;
  bool _loadingMessages = false;
  final _messageCtrl = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  String? _supportChatId;
  bool _isSupport = false;
  Map<String, dynamic>? _currentChatData;
  int _currentUserId = 0;

  static const String _baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadAllChats();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_activeChat != null && !_loadingMessages) _loadMessages();
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final result = await ApiService.get('/api/profile');
      if (result['success'] == true && mounted) {
        setState(() => _currentUserId = result['data']['id'] ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _loadAllChats() async {
    if (!mounted) return;
    setState(() => _loadingChats = true);
    
    await Future.wait([
      _loadOrgChats(),
      _loadSupportChatId(),
    ]);
    
    if (mounted) setState(() => _loadingChats = false);
  }

  Future<void> _loadOrgChats() async {
    try {
      final result = await ApiService.get('/api/chat/client-list');
      if (result['success'] == true && mounted) {
        setState(() {
          _orgChats = List<Map<String, dynamic>>.from(result['data'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSupportChatId() async {
    try {
      final result = await ApiService.get('/api/chat/list?project_id=0&type=support');
      if (result['success'] == true && mounted) {
        final chats = List<Map<String, dynamic>>.from(result['data'] ?? []);
        if (chats.isNotEmpty) {
          _supportChatId = chats.first['id'].toString();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    if (_activeChat == null || !mounted) return;
    setState(() => _loadingMessages = true);
    try {
      final chatId = _activeChat!['id'];
      final result = await ApiService.get('/api/chat/messages?chat_id=$chatId');
      if (result['success'] == true && mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _loadingMessages = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  void _openSupportChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientSupportScreen()),
    );
  }

  void _openOrgChat(Map<String, dynamic> chat) {
    setState(() {
      _activeChat = chat;
      _isSupport = false;
      _currentChatData = {
        'project_name': chat['project_name'] ?? '',
        'chat_name': (chat['chat_partner_name'] ?? chat['title'] ?? 'Чат').toString(),
      };
      _messages = [];
      _loadingMessages = true;
    });
    _loadMessages();
  }

  void _backToList() {
    setState(() {
      _activeChat = null;
      _messages = [];
      _currentChatData = null;
      _loadingMessages = false;
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageCtrl.text.trim();
    if (message.isEmpty || _activeChat == null) return;
    _messageCtrl.clear();
    try {
      await ApiService.post('/api/chat/send', {
        'chat_id': _activeChat!['id'],
        'message': message,
      });
      _loadMessages();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: _activeChat != null ? _buildChatView() : _buildChatList(),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    String chatTitle = 'Чаты';
    String? chatSubtitle;
    
    if (_activeChat != null) {
      if (_isSupport) {
        chatTitle = 'Поддержка Б-Запись';
      } else {
        chatTitle = _currentChatData?['project_name']?.toString() 
            ?? _activeChat!['project_name']?.toString() 
            ?? _activeChat!['chat_partner_name']?.toString() 
            ?? _activeChat!['title']?.toString() 
            ?? 'Чат';
        
        chatSubtitle = _activeChat!['chat_partner_name']?.toString();
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(children: [
        if (_activeChat != null)
          GestureDetector(
            onTap: _backToList,
            child: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chatTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (chatSubtitle != null && chatSubtitle.isNotEmpty)
                Text(
                  chatSubtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Color(0xFF666666)),
        ),
      ]),
    );
  }

  Widget _buildChatList() {
    if (_loadingChats) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey[100]!)),
          child: Row(children: [
            const SkeletonCircle(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SkeletonBox(height: 14, width: 150),
                const SizedBox(height: 6),
                const SkeletonBox(height: 12, width: 100),
              ]),
            ),
          ]),
        ),
      );
    }

    final allChats = <Map<String, dynamic>>[];
    
    allChats.add({
      'id': 'support',
      'title': 'Поддержка Б-Запись',
      'is_support': true,
      'avatar': '/assets/img/b-logotip.png',
    });
    
    allChats.addAll(_orgChats);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allChats.length,
      itemBuilder: (_, i) => _buildChatItem(allChats[i]),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final isSupport = chat['is_support'] == true;
    final name = (chat['chat_partner_name'] ?? chat['title'] ?? 'Чат').toString();
    final projectName = chat['project_name']?.toString();
    final avatar = chat['chat_avatar']?.toString();
    final unread = chat['unread'] ?? 0;

    return GestureDetector(
      onTap: () => isSupport ? _openSupportChat() : _openOrgChat(chat),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey[200],
            child: isSupport
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: '$_baseUrl/assets/img/b-logotip.png',
                      width: 44, height: 44, fit: BoxFit.cover,
                      placeholder: (_, __) => const SkeletonCircle(size: 44),
                      errorWidget: (_, __, ___) => const Icon(Icons.support_agent, color: Color(0xFFDD1847)),
                    ),
                  )
                : avatar != null && avatar.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: '$_baseUrl$avatar',
                          width: 44, height: 44, fit: BoxFit.cover,
                          placeholder: (_, __) => const SkeletonCircle(size: 44),
                          errorWidget: (_, __, ___) => Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDD1847))),
                        ),
                      )
                    : Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDD1847))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (projectName != null && projectName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(projectName, style: const TextStyle(fontSize: 11, color: Color(0xFF888888)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (unread > 0)
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFDD1847), borderRadius: BorderRadius.circular(10)), child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
        ]),
      ),
    );
  }

  Widget _buildMessagesLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      itemBuilder: (_, i) {
        final isLeft = i % 2 == 0;
        return Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
            decoration: BoxDecoration(
              color: isLeft ? Colors.white : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isLeft ? const Radius.circular(4) : const Radius.circular(16),
                bottomRight: isLeft ? const Radius.circular(16) : const Radius.circular(4),
              ),
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLeft)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: SkeletonBox(height: 11, width: 80, radius: 4),
                  ),
                SkeletonBox(height: 14, width: isLeft ? 200.0 : 140.0 + (i * 10)),
                const SizedBox(height: 6),
                const SkeletonBox(height: 10, width: 40, radius: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatView() {
    return Column(children: [
      Expanded(
        child: _loadingMessages
            ? _buildMessagesLoader()
            : _messages.isEmpty
                ? const Center(child: Text('Нет сообщений\nНачните общение', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF999999))))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessage(_messages[i]),
                  ),
      ),
      _buildInputArea(),
    ]);
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isMine = (msg['user_id'] ?? 0) == _currentUserId;
    final time = msg['created_at']?.toString().substring(11, 16) ?? '';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFDD1847) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: isMine ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!isMine && msg['user_name'] != null)
            Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(msg['user_name']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDD1847)))),
          Text(msg['message'] ?? '', style: TextStyle(fontSize: 14, color: isMine ? Colors.white : const Color(0xFF1A1A1A))),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(fontSize: 10, color: isMine ? Colors.white70 : const Color(0xFF999999))),
        ]),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _messageCtrl,
            decoration: InputDecoration(
              hintText: 'Сообщение...',
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              isDense: true,
            ),
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(color: Color(0xFFDD1847), shape: BoxShape.circle),
            child: const Icon(Icons.send, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}