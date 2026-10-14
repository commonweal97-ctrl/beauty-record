// lib/chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/common/avatar_initials.dart';
import '../../../utils/phone_display.dart';
import '../client/support_screen.dart';

class ChatScreen extends StatefulWidget {
  final int projectId;
  const ChatScreen({super.key, required this.projectId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _chats = [];
  Map<String, dynamic>? _activeChat;
  List<Map<String, dynamic>> _messages = [];
  bool _loadingChats = true;
  final _messageCtrl = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  bool _showNewChat = false;
  List<Map<String, dynamic>> _contacts = [];
  List<int> _selectedContacts = [];
  String _newChatType = 'client';
  String _contactSearch = '';
  bool _loadingContacts = false;
  final String _groupName = '';

  static const String _baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadChats();
      }
    });
    _loadChats();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageCtrl.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_activeChat != null) _loadMessages();
      if (mounted) setState(() {});
    });
  }

  String _tabType() {
    switch (_tabController.index) {
      case 0: return 'all';
      case 1: return 'client';
      case 2: return 'employees';
      case 3: return 'group';
      default: return 'client';
    }
  }

  Future<void> _loadChats() async {
    if (!mounted) return;
    setState(() => _loadingChats = true);
    try {
      final type = _tabType();
      final result = await ApiService.get('/api/chat/list?project_id=${widget.projectId}&type=$type');
      if (result['success'] == true && mounted) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _loadingChats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChats = false);
    }
  }

  Future<void> _loadMessages() async {
    if (_activeChat == null || !mounted) return;
    try {
      final chatId = _activeChat!['id'];
      final result = await ApiService.get('/api/chat/messages?chat_id=$chatId');
      if (result['success'] == true && mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(result['data'] ?? []);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {}
  }

  void _openChat(Map<String, dynamic> chat) {
    setState(() {
      _activeChat = chat;
      _showNewChat = false;
    });
    _loadMessages();
  }

  void _backToList() {
    setState(() {
      _activeChat = null;
      _messages = [];
    });
    _loadChats();
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

  void _openSupportChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientSupportScreen()),
    );
  }

  Future<void> _searchContacts() async {
    if (!mounted) return;
    setState(() => _loadingContacts = true);
    try {
      final url = '/api/chat/contacts?project_id=${widget.projectId}&type=$_newChatType${_contactSearch.isNotEmpty ? '&search=${Uri.encodeComponent(_contactSearch)}' : ''}';
      final result = await ApiService.get(url);
      if (result['success'] == true && mounted) {
        final data = result['data'] ?? {};
        setState(() {
          _contacts = List<Map<String, dynamic>>.from(data['contacts'] ?? data['clients'] ?? []);
          _loadingContacts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  void _toggleContact(int id) {
    setState(() {
      if (_newChatType == 'client') {
        _selectedContacts = [id];
      } else {
        if (_selectedContacts.contains(id)) {
          _selectedContacts.remove(id);
        } else {
          _selectedContacts.add(id);
        }
      }
    });
  }

  Future<void> _createNewChat() async {
    if (_selectedContacts.isEmpty) return;
    
    String name = '';
    if (_newChatType == 'group') {
      name = _groupName.isNotEmpty ? _groupName : 'Групповой чат';
    }
    
    try {
      final result = await ApiService.post('/api/chat/create', {
        'project_id': widget.projectId,
        'type': _newChatType == 'employee' && _selectedContacts.length >= 2 ? 'group' : _newChatType,
        'participants': _selectedContacts,
        'name': name,
      });
      if (result['success'] == true && mounted) {
        setState(() {
          _showNewChat = false;
          _selectedContacts = [];
        });
        _loadChats();
        if (result['data'] != null) {
          final newChat = {'id': result['data']['chat_id']};
          _openChat(newChat);
        }
      }
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
        Text(
          _activeChat != null ? (_activeChat!['title'] ?? 'Чат') : 'Чаты',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (_activeChat == null)
          GestureDetector(
            onTap: () => setState(() => _showNewChat = !_showNewChat),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit, size: 18, color: Color(0xFFDD1847)),
            ),
          ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Color(0xFF666666)),
        ),
      ]),
    );
  }

  Widget _buildChatList() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.white,
        child: Row(children: [
          _tabBtn('Все', 0),
          _tabBtn('Клиенты', 1),
          _tabBtn('Сотрудники', 2),
          _tabBtn('Группы', 3),
        ]),
      ),
      GestureDetector(
    onTap: _openSupportChat,
    child: Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/b-logotip.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 44,
              height: 44,
              color: Colors.grey[200],
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('Поддержка Б-Запись', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
      ]),
    ),
),
      Expanded(
        child: _loadingChats
            ? ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        const SkeletonBox(height: 12, width: 200),
                      ]),
                    ),
                  ]),
                ),
              )
            : _chats.isEmpty
                ? const Center(child: Text('Нет чатов', style: TextStyle(color: Color(0xFF999999))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _chats.length,
                    itemBuilder: (_, i) => _buildChatItem(_chats[i]),
                  ),
      ),
      if (_showNewChat) _buildNewChatModal(),
    ]);
  }

  Widget _tabBtn(String label, int index) {
    final active = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFDD1847) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? Colors.white : const Color(0xFF666666))),
        ),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final name = chat['title'] ?? chat['chat_partner_name'] ?? 'Чат';
    final avatar = chat['chat_avatar']?.toString();
    final lastMsg = chat['last_message']?.toString() ?? 'Нет сообщений';
    final unread = chat['unread'] ?? 0;

    return GestureDetector(
      onTap: () => _openChat(chat),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF0F0F0))),
        child: Row(children: [
          (avatar != null && avatar.isNotEmpty)
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: '$_baseUrl$avatar',
                    width: 44, height: 44, fit: BoxFit.cover,
                    placeholder: (_, _) => const SkeletonCircle(size: 44),
                    errorWidget: (_, _, _) => AvatarInitials(name: name, size: 44),
                  ),
                )
              : AvatarInitials(name: name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(lastMsg, style: const TextStyle(fontSize: 12, color: Color(0xFF888888)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (unread > 0)
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFDD1847), borderRadius: BorderRadius.circular(10)), child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  Widget _buildChatView() {
    return Column(children: [
      Expanded(
        child: ListView.builder(
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
    final isMine = msg['user_id'] == 0;
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
          boxShadow: isMine ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

  Widget _buildNewChatModal() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Text('Новый чат', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(onTap: () => setState(() => _showNewChat = false), child: const Icon(Icons.close, color: Color(0xFF999999))),
        ]),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) { _contactSearch = v; _searchContacts(); },
          decoration: InputDecoration(hintText: 'Поиск...', prefixIcon: const Icon(Icons.search, size: 18), filled: true, fillColor: const Color(0xFFF8F8F8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 10), isDense: true),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _typeBtn('Клиент', 'client'),
          _typeBtn('Сотрудник', 'employee'),
          _typeBtn('Группа', 'group'),
        ])),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: _loadingContacts
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkeletonCircle(size: 32),
                      SizedBox(height: 8),
                      SkeletonBox(height: 12, width: 120),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (_, i) {
                    final c = _contacts[i];
                    final sel = _selectedContacts.contains(c['id']);
                    return ListTile(
                      leading: AvatarInitials(name: (c['name'] ?? '').toString(), size: 40),
                      title: Text(c['name'] ?? '', style: const TextStyle(fontSize: 14)),
                      subtitle: Text(formatPhoneDisplay((c['phone'] ?? '').toString()), style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                      trailing: Icon(sel ? Icons.check_circle : Icons.circle_outlined, color: sel ? const Color(0xFFDD1847) : const Color(0xFFCCCCCC)),
                      onTap: () => _toggleContact(c['id'] as int),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _selectedContacts.isEmpty ? null : _createNewChat,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Создать чат', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        )),
      ]),
    );
  }

  Widget _typeBtn(String label, String type) {
    final active = _newChatType == type;
    return GestureDetector(
      onTap: () => setState(() { _newChatType = type; _selectedContacts = []; _searchContacts(); }),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: active ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? const Color(0xFFDD1847) : Colors.transparent)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? const Color(0xFFDD1847) : const Color(0xFF666666))),
      ),
    );
  }
}