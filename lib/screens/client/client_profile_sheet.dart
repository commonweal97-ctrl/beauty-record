import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import '../business/booking_view_sheet.dart';
import '../business/create_booking_for_client_sheet.dart';
import 'client_bookings_sheet.dart';
import 'client_notification_settings_sheet.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';
import '../business/edit_client_sheet.dart';

class ClientProfileSheet extends StatefulWidget {
  final int clientId;
  final int projectId;
  final VoidCallback onSaved;
  const ClientProfileSheet({super.key, required this.clientId, required this.projectId, required this.onSaved});

  @override
  State<ClientProfileSheet> createState() => _ClientProfileSheetState();
}

class _ClientProfileSheetState extends State<ClientProfileSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final result = await ApiService.get('/api/client/get?id=${widget.clientId}&project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        setState(() {
          _data = result['data'];
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openBooking(int bookingId) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => BookingViewSheet(bookingId: bookingId, onSaved: _load),
    );
  }

  void _createBookingForClient() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CreateBookingForClientSheet(
        projectId: widget.projectId,
        clientId: widget.clientId,
        clientName: _data!['name'] ?? '',
        onSaved: widget.onSaved,
      ),
    );
  }

  void _openEditClient() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditClientSheet(
        clientId: widget.clientId,
        projectId: widget.projectId,
        onSaved: () {
          widget.onSaved();
          _load();
        },
      ),
    );
  }

  void _openNotificationSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ClientNotificationSettingsSheet(
        clientId: widget.clientId,
        projectId: widget.projectId,
      ),
    ).then((_) {
      _load();
    });
  }

  String _getNotificationStatus() {
    if (_data == null) return 'Загрузка...';
    return 'Настроить';
  }

  void _callClient() {
    final phone = (_data?['phone'] ?? '').toString();
    if (phone.isNotEmpty) {
      ApiService.openUrl('tel:$phone');
    }
  }

  void _deleteClient() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить клиента?'),
        content: const Text('Это действие нельзя отменить. Все данные клиента будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Color(0xFFF44336))),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final result = await ApiService.post('/api/client/delete', {
        'id': widget.clientId,
        'project_id': widget.projectId,
      });
      
      if (result['success'] == true && mounted) {
        Navigator.pop(context);
        widget.onSaved();
        showToast(context, 'Клиент удалён');
      } else if (mounted) {
        showToast(context, result['message'] ?? 'Ошибка удаления', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Ошибка удаления клиента', isError: true);
      }
    }
  }

  void _openContactOptions() {
    final c = _data!;
    final phone = (c['phone'] ?? '').toString();
    List<Map<String, dynamic>> socialLinks = [];
    
    try {
      final raw = c['social_links'];
      if (raw is String && raw.isNotEmpty) {
        socialLinks = List<Map<String, dynamic>>.from(
          jsonDecode(raw) as List,
        );
      } else if (raw is List) {
        socialLinks = List<Map<String, dynamic>>.from(raw);
      }
    } catch (_) {}

    String? telegramUrl;
    String? vkUrl;
    for (final link in socialLinks) {
      final type = (link['type'] ?? '').toString();
      final url = (link['url'] ?? '').toString();
      if (type == 'telegram' && url.isNotEmpty) telegramUrl = url;
      if (type == 'vk' && url.isNotEmpty) vkUrl = url;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Написать',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (phone.isNotEmpty)
                _contactOption(
                  icon: 'assets/chat.svg',
                  label: 'SMS',
                  onTap: () {
                    Navigator.pop(ctx);
                    ApiService.openUrl('sms:$phone');
                  },
                ),
              if (telegramUrl != null)
                _contactOption(
                  icon: 'assets/telegram.svg',
                  label: 'Telegram',
                  onTap: () {
                    Navigator.pop(ctx);
                    ApiService.openUrl(telegramUrl!);
                  },
                ),
              if (vkUrl != null)
                _contactOption(
                  icon: 'assets/vk-outline.svg',
                  label: 'ВКонтакте',
                  onTap: () {
                    Navigator.pop(ctx);
                    ApiService.openUrl(vkUrl!);
                  },
                ),
              if (phone.isEmpty && telegramUrl == null && vkUrl == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Нет контактов',
                    style: TextStyle(color: Color(0xFF999999)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactOption({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: SvgPicture.asset(
                  icon,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(Color(0xFF666666), BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonCircle(size: 72),
            SizedBox(height: 16),
            SkeletonBox(height: 20, width: 160),
            SizedBox(height: 8),
            SkeletonBox(height: 14, width: 120),
            SizedBox(height: 24),
            SkeletonBox(height: 44, radius: 12),
            SizedBox(height: 8),
            SkeletonBox(height: 14, width: 200),
            SizedBox(height: 8),
            SkeletonBox(height: 14, width: 150),
          ],
        ),
      ),
    );
    
    if (_data == null) return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      child: const Center(child: Text('Клиент не найден')),
    );

    final c = _data!;
    final name = (c['name'] ?? '').toString();
    final initials = name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    final bookings = c['bookings'] as List? ?? [];
    final avgPrice = bookings.isEmpty ? 0 : bookings.fold<double>(0, (s, b) => s + (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0)) ~/ bookings.length;
    final avatarUrl = c['avatar']?.toString() ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Spacer(),
            const Text('Профиль клиента', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Row(children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFDF2F5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarUrl.isNotEmpty
                    ? CachedAvatar(url: avatarUrl, size: 72, radius: 36)
                    : Center(
                        child: Text(initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFFDD1847))),
                      ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    Text((c['phone'] ?? '').toString(), style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
                  ],
                )),
                _pillBtn('Изменить', _openEditClient),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _actionBtn('Записать', 'assets/calendar.svg', primary: true, onTap: _createBookingForClient),
                const SizedBox(width: 8),
                _actionBtn('Написать', 'assets/chat.svg', onTap: () => _openContactOptions()),
                const SizedBox(width: 8),
                _actionBtn('Позвонить', Icons.phone, onTap: () => _callClient()),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                _stat('${bookings.length}', 'Визитов'),
                const SizedBox(width: 8),
                _stat('$avgPrice ₽', 'Средний чек'),
                const SizedBox(width: 8),
                _stat('${c['discount'] ?? 0}%', 'Скидка'),
              ]),
              if (c['notes'] != null && c['notes'].toString().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(c['notes'].toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF8B6914))),
                ),
              const SizedBox(height: 16),
              _row('Записи', '${bookings.length}', onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => ClientBookingsSheet(
                    clientId: widget.clientId,
                    projectId: widget.projectId,
                    clientName: name,
                  ),
                ).then((_) {
                  _load();
                });
              }),
              _row('Уведомления', _getNotificationStatus(), onTap: _openNotificationSettings),
              if (bookings.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Последние записи', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ...bookings.take(5).map((b) => GestureDetector(
                  onTap: () => _openBooking(b['id']),
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((b['service_name'] ?? '').toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          Text(
                            '${b['date'] ?? ''} ${((b['start_time'] ?? '').toString().length >= 5 ? (b['start_time'] as String).substring(0, 5) : '')}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                          ),
                        ],
                      )),
                      Text((b['master_name'] ?? '').toString(), style: const TextStyle(fontSize: 13, color: Color(0xFFDD1847), fontWeight: FontWeight.w500)),
                    ]),
                  ),
                )),
              ],
              // Кнопка удаления
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deleteClient,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Удалить клиента'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF44336),
                      side: const BorderSide(color: Color(0xFFF44336)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _actionBtn(String label, dynamic icon, {bool primary = false, VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: primary ? const Color(0xFFDD1847) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: primary ? null : Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon is IconData
                ? Icon(icon, size: 16, color: primary ? Colors.white : Colors.black)
                : SvgPicture.asset(icon as String, width: 16, height: 16, colorFilter: ColorFilter.mode(primary ? Colors.white : Colors.black, BlendMode.srcIn)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary ? Colors.white : Colors.black)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
        ]),
      ),
    );
  }

  Widget _pillBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
      ),
    );
  }
}