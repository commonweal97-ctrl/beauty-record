// client_bookings_sheet.dart
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../business/booking_view_sheet.dart';
import '../../../widgets/skeletons.dart';

class ClientBookingsSheet extends StatefulWidget {
  final int clientId;
  final int projectId;
  final String clientName;

  const ClientBookingsSheet({
    super.key,
    required this.clientId,
    required this.projectId,
    required this.clientName,
  });

  @override
  State<ClientBookingsSheet> createState() => _ClientBookingsSheetState();
}

class _ClientBookingsSheetState extends State<ClientBookingsSheet> {
  List<Map<String, dynamic>> _allBookings = [];
  String _activeTab = 'all';
  bool _loading = true;

  static const Map<String, String> _statusLabels = {
    'pending': 'Ожидает',
    'confirmed': 'Подтверждена',
    'completed': 'Завершена',
    'cancelled': 'Отменена',
  };

  static const Map<String, Color> _statusColors = {
    'confirmed': Color(0xFFD4EDDA),
    'cancelled': Color(0xFFF8D7DA),
    'completed': Color(0xFFD1ECF1),
    'pending': Color(0xFFFFF3CD),
  };

  static const Map<String, Color> _statusTextColors = {
    'confirmed': Color(0xFF155724),
    'cancelled': Color(0xFF721C24),
    'completed': Color(0xFF0C5460),
    'pending': Color(0xFF856404),
  };

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.get(
        '/api/client/get?id=${widget.clientId}&project_id=${widget.projectId}',
      );
      if (result['success'] == true && result['data'] != null && mounted) {
        setState(() {
          _allBookings = List<Map<String, dynamic>>.from(
            result['data']['bookings'] ?? [],
          );
          _loading = false;
        });
      } else if (mounted) {
        setState(() {
          _allBookings = [];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки записей клиента: $e');
      if (mounted) {
        setState(() {
          _allBookings = [];
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final nowTimeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    switch (_activeTab) {
      case 'upcoming':
        return _allBookings.where((b) {
          final date = (b['date'] ?? '').toString();
          final time = ((b['start_time'] ?? '').toString().length >= 5
                  ? (b['start_time'] as String).substring(0, 5)
                  : '00:00');
          final status = (b['status'] ?? '').toString();
          return (date.compareTo(todayStr) > 0 ||
                  (date == todayStr && time.compareTo(nowTimeStr) > 0)) &&
              status != 'cancelled';
        }).toList();

      case 'cancelled':
        return _allBookings
            .where((b) => (b['status'] ?? '').toString() == 'cancelled')
            .toList();

      default: // 'all'
        return List<Map<String, dynamic>>.from(_allBookings);
    }
  }

  // В файле client_bookings_sheet.dart
// Заменяем метод _openBookingDetail полностью

Future<void> _openBookingDetail(int bookingId) async {
  final bookingData = _allBookings.firstWhere(
    (b) => b['id'] == bookingId,
    orElse: () => {},
  );

  if (bookingData.isEmpty) return;

  // Открываем BookingViewSheet как bottom sheet ПОВЕРХ текущего sheet
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BookingViewSheet(
          bookingId: bookingId,
          onSaved: () {
            _loadBookings();
            Navigator.pop(ctx); // Закрываем только BookingViewSheet
          },
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Заголовок
          _buildHeader(),
          // Табы
          _buildTabs(),
          // Список записей
          Expanded(
            child: _loading ? _buildLoader() : _buildBookingsList(),
          ),
          // Безопасный отступ
          SizedBox(height: bottomInset),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          // Кнопка назад (закрыть)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back,
                  color: Color(0xFF666666),
                  size: 20,
                ),
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Записи клиента',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const Spacer(),
          // Кнопка закрыть (крестик)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.close,
                  color: Color(0xFF666666),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          _buildTab('all', 'Все записи'),
          _buildTab('upcoming', 'Предстоящие'),
          _buildTab('cancelled', 'Отменённые'),
        ],
      ),
    );
  }

  Widget _buildTab(String key, String label) {
    final isActive = _activeTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFFDD1847) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? const Color(0xFFDD1847) : const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, i) => Padding(
        padding: EdgeInsets.only(bottom: i < 3 ? 8 : 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SkeletonBox(height: 14, width: 140),
                  const SkeletonBox(height: 20, width: 80, radius: 10),
                ],
              ),
              const SizedBox(height: 8),
              const SkeletonBox(height: 12, width: 200),
              const SizedBox(height: 6),
              const SkeletonBox(height: 12, width: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList() {
    final filtered = _filteredBookings;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              'Нет записей',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final booking = filtered[i];
        return _buildBookingCard(booking);
      },
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b) {
  final dateStr = (b['date'] ?? '').toString();
  final dateFormatted = _formatDate(dateStr);
  final startTime = ((b['start_time'] ?? '').toString().length >= 5
      ? (b['start_time'] as String).substring(0, 5)
      : '--:--');
  final endTime = ((b['end_time'] ?? '').toString().length >= 5
      ? (b['end_time'] as String).substring(0, 5)
      : '--:--');
  final time = '$startTime – $endTime';

  final services = b['services'] as List? ?? [];
  final serviceNames = services.isNotEmpty
      ? services.map((s) => s['name'] ?? '').join(', ')
      : (b['service_name'] ?? '').toString();

  // Правильный расчёт цены с учётом "от"
  final totalPrice = double.tryParse(b['total_price']?.toString() ?? '0') ?? 0;
  final hasPriceFrom = b['has_price_from'] == 1 || b['has_price_from'] == '1';
  final priceText = totalPrice > 0 
      ? '${hasPriceFrom ? 'от ' : ''}${totalPrice.toStringAsFixed(0)} ₽' 
      : '';

  final status = (b['status'] ?? 'confirmed').toString();
  final colorHex = (b['color'] ?? '#DD1847').toString();
  final color = _hexToColor(colorHex);

  final masterName =
      (b['master_name'] ?? b['employee_name'] ?? '').toString();

  return GestureDetector(
    onTap: () => _openBookingDetail(b['id']),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          border: Border(
            left: BorderSide(color: color, width: 4),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: const BorderSide(color: Color(0xFFF0F0F0)),
              top: const BorderSide(color: Color(0xFFF0F0F0)),
              bottom: const BorderSide(color: Color(0xFFF0F0F0)),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$dateFormatted $time',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 6),
              if (serviceNames.isNotEmpty)
                Text(
                  serviceNames,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (masterName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  masterName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFDD1847),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (priceText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  priceText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildStatusBadge(String status) {
    final label = _statusLabels[status] ?? status;
    final bgColor = _statusColors[status] ?? const Color(0xFFF5F5F5);
    final textColor = _statusTextColors[status] ?? const Color(0xFF666666);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}.${parts[1]}.${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  Color _hexToColor(String hex) {
    try {
      final stripped = hex.replaceAll('#', '');
      return Color(int.parse('FF$stripped', radix: 16));
    } catch (_) {
      return const Color(0xFFDD1847);
    }
  }
}