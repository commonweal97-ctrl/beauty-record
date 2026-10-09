import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import 'rate_booking_screen.dart';
import 'repeat_booking_screen.dart';
import 'contact_screen.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/toast.dart';
import '../../utils/app_logger.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  bool _isUpcoming = true;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _archive = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() async {
    try {
      final result = await ApiService.get('/api/client/bookings');
      AppLogger.debug('Bookings result: $result');
      if (result['success'] == true && mounted) {
        setState(() {
          _upcoming = List<Map<String, dynamic>>.from(result['data']['upcoming'] ?? []);
          _archive = List<Map<String, dynamic>>.from(result['data']['archive'] ?? []);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, 'Ошибка загрузки записей', isError: true);
      }
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    const days = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$hч $mмин';
    if (h > 0) return '$hч';
    return '$mмин';
  }

  Widget _photoPlaceholder({double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.2),
        child: SvgPicture.asset('assets/photo-none.svg'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(15)),
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = (constraints.maxWidth) / 2;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      left: _isUpcoming ? 0 : tabWidth,
                      top: 0, bottom: 0, width: tabWidth,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isUpcoming = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(child: Text('Предстоящие', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _isUpcoming ? Colors.black : const Color(0xFF666666)))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isUpcoming = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(child: Text('Архивные', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: !_isUpcoming ? Colors.black : const Color(0xFF666666)))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 3,
                  itemBuilder: (_, _) => const SkeletonBookingCard(),
                )
              : _isUpcoming
                  ? _upcoming.isEmpty
                      ? const Center(child: Text('Нет предстоящих записей', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _upcoming.length, itemBuilder: (_, i) => _buildCard(_upcoming[i]))
                  : _archive.isEmpty
                      ? const Center(child: Text('Нет архивных записей', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _archive.length, itemBuilder: (_, i) => _buildCard(_archive[i])),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> b) {
    final services = (b['service_names'] ?? '').toString().split(', ');
    final prices = (b['service_prices'] ?? '').toString().split(', ');
    final durations = (b['service_durations'] ?? '').toString().split(', ');
    final photo = b['project_photo'];
    final masterAvatar = b['master_avatar'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEDF2F7))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: photo != null && photo.toString().isNotEmpty
                    ? CachedAvatar(url: photo, size: 48, radius: 14)
                    : _photoPlaceholder(size: 48),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(b['project_name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${b['start_time']}–${b['end_time']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_formatDate(b['date'] ?? ''), style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                  const SizedBox(height: 14),
                  ...List.generate(services.length, (i) {
                    final name = services[i].trim();
                    if (name.isEmpty) return const SizedBox.shrink();
                    final price = i < prices.length ? prices[i].trim() : '';
                    final dur = i < durations.length ? int.tryParse(durations[i].trim()) ?? 0 : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(children: [
                          if (price.isNotEmpty) Text('от $price ₽', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFDD1847))),
                          if (price.isNotEmpty && dur > 0) const SizedBox(width: 12),
                          if (dur > 0) Row(children: [const Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)), const SizedBox(width: 4), Text(_formatDuration(dur), style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)))]),
                        ]),
                      ]),
                    );
                  }),
                  const SizedBox(height: 4),
                  Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: masterAvatar != null && masterAvatar.toString().isNotEmpty
                          ? CachedAvatar(url: masterAvatar, size: 36, radius: 12)
                          : _photoPlaceholder(size: 36),
                    ),
                    const SizedBox(width: 10),
                    Text(b['master_name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
              SizedBox(
                width: 130,
                child: Column(children: [
                  _buildActionBtn('Профиль', Icons.layers, () {}),
                  const SizedBox(height: 8),
                  _buildActionBtn('Связаться', Icons.chat_bubble_outline, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ContactScreen(projectId: b['project_id'])));
                  }),
                  if (!_isUpcoming) ...[
                    const SizedBox(height: 8),
                    _buildActionBtn('Оценить', Icons.star, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RateBookingScreen(bookingId: b['id'])));
                    }, isReview: true),
                    const SizedBox(height: 8),
                    _buildActionBtn('Повторить', Icons.refresh, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RepeatBookingScreen(bookingId: b['id'])));
                    }),
                  ],
                  if (_isUpcoming) ...[
                    const SizedBox(height: 8),
                    _buildActionBtn('Перенести', Icons.calendar_month, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RepeatBookingScreen(bookingId: b['id'], isReschedule: true)));
                    }),
                    const SizedBox(height: 8),
                    _buildActionBtn('Отменить', Icons.close, () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Отменить запись?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await ApiService.deleteBooking(b['id'], b['project_id']);
                          if (mounted) {
                            showToast(context, 'Запись отменена');
                            _loadBookings();
                          }
                        } catch (_) {
                          if (mounted) showToast(context, 'Ошибка отмены', isError: true);
                        }
                      }
                    }, isCancel: true),
                  ],
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, VoidCallback onTap, {bool isCancel = false, bool isReview = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isCancel ? const Color(0xFFFFF0F3) : isReview ? const Color(0xFFFFF8E1) : const Color(0xFFF8FAFC),
          border: Border.all(color: isCancel ? const Color(0xFFFECDD3) : isReview ? const Color(0xFFFFE082) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(40),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: isCancel ? const Color(0xFFDD1847) : isReview ? const Color(0xFFF57F17) : const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isCancel ? const Color(0xFFDD1847) : isReview ? const Color(0xFFF57F17) : const Color(0xFF475569))),
        ]),
      ),
    );
  }
}