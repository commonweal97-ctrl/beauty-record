import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';

/// Попап ручной отправки уведомлений (аналог ns-popup из веб-версии)
class ManualNotificationSheet extends StatefulWidget {
  final int projectId;
  final VoidCallback? onComplete;

  const ManualNotificationSheet({
    super.key,
    required this.projectId,
    this.onComplete,
  });

  static Future<bool> checkAndShow(BuildContext context, int projectId, {int afterId = 0}) async {
    try {
      final r = await ApiService.get('/api/notification/list?project_id=$projectId');
      if (r['success'] == true) {
        final items = List<Map<String, dynamic>>.from(r['data'] ?? []);
        if (items.isNotEmpty && context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Colors.transparent,
            builder: (_) => ManualNotificationSheet(
              projectId: projectId,
              onComplete: () {},
            ),
          );
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  @override
  State<ManualNotificationSheet> createState() => _ManualNotificationSheetState();
}

class _ManualNotificationSheetState extends State<ManualNotificationSheet> {
  List<Map<String, dynamic>> _allItems = [];
  int _currentIndex = 0;
  bool _loading = true;

  bool _showBufferStep = false;
  bool _showConfirm = false;
  bool _showCloseActions = false;
  bool _showPostponeList = false;
  String? _pendingChannel;
  Map<String, dynamic>? _pendingSocial;

  final PageController _pageController = PageController();

  static const String _baseImageUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.get('/api/notification/list?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        final items = List<Map<String, dynamic>>.from(r['data'] ?? []);
        setState(() {
          _allItems = items;
          _loading = false;
          _currentIndex = 0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _currentItem {
    if (_currentIndex < 0 || _currentIndex >= _allItems.length) return null;
    return _allItems[_currentIndex];
  }

  String get _title {
    if (_showConfirm) return 'Подтверждение отправки';
    if (_showBufferStep) return 'Переход в Telegram';
    if (_showCloseActions) return 'Выберите действие';
    return 'Отправить уведомление';
  }

  void _goToSlide(int index) {
    if (index < 0 || index >= _allItems.length) return;
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  Future<void> _removeCurrentSlide() async {
    if (_allItems.isEmpty) return;
    final removedIndex = _currentIndex;
    setState(() {
      _allItems.removeAt(removedIndex);
      if (_allItems.isEmpty) {
        _currentIndex = -1;
      } else if (_currentIndex >= _allItems.length) {
        _currentIndex = _allItems.length - 1;
      }
    });

    if (_allItems.isEmpty) {
      Navigator.pop(context);
      widget.onComplete?.call();
      showToast(context, 'Все уведомления обработаны');
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      });
    }
  }

  void _showMainScreen() {
    setState(() {
      _showBufferStep = false;
      _showConfirm = false;
      _showCloseActions = false;
      _showPostponeList = false;
      _pendingSocial = null;
      _pendingChannel = null;
    });
  }

  void _showConfirmScreen() {
    setState(() {
      _showConfirm = true;
      _showBufferStep = false;
      _showCloseActions = false;
      _showPostponeList = false;
      _pendingSocial = null;
      _pendingChannel = null;
    });
  }

  void _showCloseActionsScreen() {
    setState(() {
      _showCloseActions = true;
      _showConfirm = false;
      _showBufferStep = false;
      _showPostponeList = false;
    });
  }

  Future<void> _sendSMS(Map<String, dynamic> item) async {
    final phone = (item['client_phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final message = item['message'] ?? '';
    await Clipboard.setData(ClipboardData(text: message));
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    _showConfirmScreen();
  }

  Future<void> _sendWhatsApp(Map<String, dynamic> item, {bool business = false}) async {
    final phone = (item['client_phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final message = item['message'] ?? '';
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (item['id'] != null) {
      try {
        await ApiService.post('/api/notification/update-channel', {
          'id': item['id'],
          'channel': business ? 'whatsapp_business' : 'whatsapp',
        });
      } catch (_) {}
    }
    _showConfirmScreen();
  }

  Future<void> _sendTelegram(Map<String, dynamic> item) async {
    final message = item['message'] ?? '';
    await Clipboard.setData(ClipboardData(text: message));
    setState(() {
      _pendingSocial = item;
      _pendingChannel = 'telegram';
      _showBufferStep = true;
      _showConfirm = false;
      _showCloseActions = false;
      _showPostponeList = false;
    });
  }

  Future<void> _sendCopy(Map<String, dynamic> item) async {
    await Clipboard.setData(ClipboardData(text: item['message'] ?? ''));
    if (!mounted) return;
    showToast(context, 'Скопировано в буфер обмена');
    _showConfirmScreen();
  }

  Future<void> _continueToSocial() async {
    if (_pendingChannel == 'telegram' && _pendingSocial != null) {
      final telegramLink = _pendingSocial!['telegram_link']?.toString();
      if (telegramLink != null && telegramLink.isNotEmpty) {
        await launchUrl(Uri.parse(telegramLink), mode: LaunchMode.externalApplication);
      }
    }
    _showConfirmScreen();
  }

  Future<void> _postpone(int minutes) async {
    final item = _currentItem;
    if (item == null || item['id'] == null) return;
    try {
      await ApiService.post('/api/notification/update-status', {
        'id': item['id'],
        'status': 'postponed',
        'minutes': minutes,
      });
    } catch (_) {}
    if (mounted) {
      showToast(context, 'Отложено на $minutes мин');
    }
    setState(() => _showPostponeList = false);
    await _removeCurrentSlide();
    if (_allItems.isNotEmpty && mounted) _showMainScreen();
  }

  Future<void> _skip() async {
    final item = _currentItem;
    if (item == null || item['id'] == null) return;
    try {
      await ApiService.post('/api/notification/update-status', {
        'id': item['id'],
        'status': 'skipped',
      });
    } catch (_) {}
    await _removeCurrentSlide();
    if (_allItems.isNotEmpty && mounted) _showMainScreen();
  }

  Future<void> _confirmYes() async {
    final item = _currentItem;
    if (item == null || item['id'] == null) return;
    try {
      await ApiService.post('/api/notification/update-status', {
        'id': item['id'],
        'status': 'sent',
      });
    } catch (_) {}
    await _removeCurrentSlide();
    if (_allItems.isNotEmpty && mounted) _showMainScreen();
  }

  void _confirmNo() => _showMainScreen();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonCircle(size: 48),
              SizedBox(height: 16),
              SkeletonBox(height: 14, width: 160),
            ],
          ),
        ),
      );
    }

    if (_allItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: _showConfirm
                    ? _buildConfirmScreen()
                    : _showBufferStep
                        ? _buildBufferScreen()
                        : _showCloseActions
                            ? _buildCloseActionsScreen()
                            : _buildMainContent(),
              ),
            ],
          ),
        ),
        if (_showPostponeList) Positioned.fill(child: _buildPostponeOverlay()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          SizedBox(
            width: 32, height: 32,
            child: (_showBufferStep || _showCloseActions)
                ? _iconBtn(Icons.arrow_back, _showMainScreen)
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: Text(_title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 32, height: 32,
            child: _showCloseActions
                ? const SizedBox.shrink()
                : _showConfirm || _showBufferStep || _showPostponeList
                    ? const SizedBox.shrink()
                    : _iconBtn(Icons.close, _showCloseActionsScreen),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final item = _currentItem;
    if (item == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          child: PageView.builder(
            controller: _pageController,
            itemCount: _allItems.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (_, index) => SingleChildScrollView(
              child: _buildNotificationCard(_allItems[index]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildPostponeButton(),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildSkipButton(),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final initials = _getInitials(item['client_name']?.toString() ?? '?');
    final avatarPath = item['client_avatar']?.toString();
    final hasTelegram = item['telegram_link'] != null && item['telegram_link'].toString().isNotEmpty;
    final String? avatarUrl = (avatarPath != null && avatarPath.isNotEmpty) ? '$_baseImageUrl$avatarPath' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 52, height: 52,
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFF0F0F0),
                  child: avatarUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl, width: 52, height: 52, fit: BoxFit.cover,
                            placeholder: (_, _) => const SkeletonCircle(size: 52),
                            errorWidget: (_, _, _) => Center(
                              child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDD1847), fontSize: 20)),
                            ),
                          ),
                        )
                      : Center(child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDD1847), fontSize: 20))),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item['client_name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(item['client_phone'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                  ],
                ),
              ),
              if (_allItems.length > 1) ...[
                Text('${_currentIndex + 1}/${_allItems.length}', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                _pageArrow(Icons.chevron_left, _currentIndex > 0 ? () => _goToSlide(_currentIndex - 1) : null),
                const SizedBox(width: 4),
                _pageArrow(Icons.chevron_right, _currentIndex < _allItems.length - 1 ? () => _goToSlide(_currentIndex + 1) : null),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(item['message'] ?? '', style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF1E293B))),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildActionButtons(item, hasTelegram),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> item, bool hasTelegram) {
    final allButtons = <Widget>[
      _sendBtn('assets/chat.svg', 'SMS', () => _sendSMS(item)),
      _sendBtn('assets/whatsapp.svg', 'WhatsApp', () => _sendWhatsApp(item)),
      _sendBtn('assets/whatsapp-business.svg', 'WA Business', () => _sendWhatsApp(item, business: true)),
      if (hasTelegram) _sendBtn('assets/telegram-nf.svg', 'Telegram', () => _sendTelegram(item)),
      _sendBtnCopy(() => _sendCopy(item)),
    ];

    const int maxPerRow = 3;
    if (allButtons.length <= maxPerRow) {
      return Row(children: [
        for (int i = 0; i < allButtons.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: allButtons[i]),
        ],
      ]);
    }

    final firstRow = allButtons.sublist(0, maxPerRow);
    final secondRow = allButtons.sublist(maxPerRow);

    return Column(children: [
      Row(children: [
        for (int i = 0; i < firstRow.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: firstRow[i]),
        ],
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (int i = 0; i < secondRow.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: secondRow[i]),
        ],
        for (int i = secondRow.length; i < maxPerRow; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          const Expanded(child: SizedBox.shrink()),
        ],
      ]),
    ]);
  }

  Widget _buildBufferScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          SvgPicture.asset('assets/telegram-nf.svg', width: 64, height: 64, colorFilter: const ColorFilter.mode(Color(0xFF4ECDC4), BlendMode.srcIn)),
          const SizedBox(height: 16),
          Text(_pendingSocial?['client_name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text('Текст сообщения скопирован в буфер обмена. После перехода в Telegram вставьте текст в поле ввода.', style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.6), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _continueToSocial,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Продолжить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildConfirmScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Удалось отправить уведомление?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Подтвердите, если ваше уведомление дошло до получателя.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: _confirmYes, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Да, отправлено', style: TextStyle(fontWeight: FontWeight.w600)))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: _confirmNo, style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFFECACA)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Нет', style: TextStyle(fontWeight: FontWeight.w500)))),
          ]),
        ],
      ),
    );
  }

  Widget _buildCloseActionsScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildPostponeButton(),
        const SizedBox(height: 10),
        _buildSkipButton(),
      ]),
    );
  }

  Widget _buildPostponeButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => setState(() {
          _showPostponeList = true;
          _showCloseActions = false;
        }),
        icon: SvgPicture.asset('assets/schedule.svg', width: 16, height: 16, colorFilter: const ColorFilter.mode(Color(0xFF64748B), BlendMode.srcIn)),
        label: const Text('Отложить'),
        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF64748B), side: const BorderSide(color: Color(0xFFE2E8F0)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildPostponeOverlay() {
    const times = [
      {'minutes': 5, 'label': '5 мин'},
      {'minutes': 10, 'label': '10 мин'},
      {'minutes': 30, 'label': '30 мин'},
      {'minutes': 60, 'label': '1 час'},
      {'minutes': 120, 'label': '2 часа'},
      {'minutes': 180, 'label': '3 часа'},
      {'minutes': 240, 'label': '4 часа'},
      {'minutes': 480, 'label': '8 часов'},
      {'minutes': 720, 'label': '12 часов'},
    ];

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Expanded(child: Text('Отложить отправку', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            IconButton(icon: const Icon(Icons.close, color: Color(0xFF94A3B8)), onPressed: () => setState(() => _showPostponeList = false)),
          ]),
        ),
        Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFEF3C7))), child: const Text('Отложите отправку уведомления. Через указанное время вы получите напоминание об отправке', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4))),
        const SizedBox(height: 8),
        ...times.map((t) => ListTile(
          title: Text(t['label'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
          onTap: () => _postpone(t['minutes'] as int),
        )),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildSkipButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _skip,
        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFFECACA)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('Не отправлять'),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: const Color(0xFF666666))),
    );
  }

  Widget _pageArrow(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: onTap != null ? const Color(0xFFF1F5F9) : const Color(0xFFF8F8F8)), child: Icon(icon, size: 16, color: onTap != null ? const Color(0xFF64748B) : const Color(0xFFCBD5E1))),
    );
  }

  Widget _sendBtn(String assetPath, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SvgPicture.asset(assetPath, width: 22, height: 22, colorFilter: const ColorFilter.mode(Color(0xFF334155), BlendMode.srcIn)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _sendBtnCopy(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.copy, size: 22, color: Color(0xFF334155)),
          SizedBox(height: 6),
          Text('Копировать', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}