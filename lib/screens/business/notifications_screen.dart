import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/common/avatar_initials.dart';
import '../../../widgets/toast.dart';
import '../../widgets/common/time_picker_sheet.dart';

class NotificationsScreen extends StatefulWidget {
  final int projectId;
  const NotificationsScreen({super.key, required this.projectId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text('Уведомления',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08), blurRadius: 3)
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF1A1A1A),
              unselectedLabelColor: const Color(0xFF666666),
              labelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Статистика'),
                Tab(text: 'История отправки'),
                Tab(text: 'Каналы отправки'),
                Tab(text: 'Виды уведомлений'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StatsTab(projectId: widget.projectId),
                _HistoryTab(projectId: widget.projectId),
                _ChannelsTab(projectId: widget.projectId),
                _TypesTab(projectId: widget.projectId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== СТАТИСТИКА ====================
class _StatsTab extends StatefulWidget {
  final int projectId;
  const _StatsTab({required this.projectId});
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _period = 'week';
  DateTime _currentDate = DateTime.now();

  static const _typeLabels = {
    'new_booking': 'Создание записи',
    'transfer': 'Перенос записи',
    'cancel': 'Отмена записи',
    'reminder': 'Напоминание',
    'return_visit': 'Повторный визит',
    'after_cancel': 'После отмены',
    'birthday': 'День рождения',
    'review_request': 'Запрос отзыва',
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Map<String, String> _getPeriodDates() {
    final from = DateTime(
        _currentDate.year, _currentDate.month, _currentDate.day);
    DateTime to;

    switch (_period) {
      case 'day':
        to = from;
        break;
      case 'week':
        final day = from.weekday;
        from.subtract(Duration(days: day - 1));
        to = from.add(const Duration(days: 6));
        break;
      case 'month':
        from.copyWith(day: 1);
        to = DateTime(from.year, from.month + 1, 0);
        break;
      case 'year':
        from.copyWith(month: 1, day: 1);
        to = DateTime(from.year, 12, 31);
        break;
      default:
        final day = from.weekday;
        from.subtract(Duration(days: day - 1));
        to = from.add(const Duration(days: 6));
        break;
    }

    return {
      'from': DateFormat('yyyy-MM-dd').format(from),
      'to': DateFormat('yyyy-MM-dd').format(to),
    };
  }

  String _getPeriodLabel() {
    switch (_period) {
      case 'day':
        return 'За день';
      case 'week':
        return 'За неделю';
      case 'month':
        return 'За месяц';
      case 'year':
        return 'За год';
      default:
        return 'За неделю';
    }
  }

  String _formatPeriodDates() {
    final dates = _getPeriodDates();
    final from = DateTime.parse(dates['from']!);
    final to = DateTime.parse(dates['to']!);
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return '${from.day} ${months[from.month - 1]} – ${to.day} ${months[to.month - 1]}';
  }

  void _cyclePeriod() {
    const periods = ['day', 'week', 'month', 'year'];
    final idx = periods.indexOf(_period);
    _period = periods[(idx + 1) % 4];
    _currentDate = DateTime.now();
    _loadStats();
  }

  void _shiftPeriod(int dir) {
    switch (_period) {
      case 'day':
        _currentDate = _currentDate.add(Duration(days: dir));
        break;
      case 'week':
        _currentDate = _currentDate.add(Duration(days: dir * 7));
        break;
      case 'month':
        _currentDate = DateTime(
            _currentDate.year, _currentDate.month + dir, 1);
        break;
      case 'year':
        _currentDate =
            DateTime(_currentDate.year + dir, 1, 1);
        break;
    }
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final dates = _getPeriodDates();
      final r = await ApiService.get(
          '/api/notification/history?project_id=${widget.projectId}&date_from=${dates['from']}&date_to=${dates['to']}&per_page=1000');
      if (r['success'] == true && mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(r['data'] ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _countByStatus(String status) {
    if (status == 'skipped') {
      return _items
          .where((i) =>
              i['status'] == 'skipped' || i['status'] == 'postponed')
          .length;
    }
    return _items.where((i) => i['status'] == status).length;
  }

  Map<String, Map<String, int>> _getTypeStats() {
    final types = <String, Map<String, int>>{};
    for (final item in _items) {
      final t = item['type'] ?? 'unknown';
      final s = item['status'] ?? 'pending';
      types.putIfAbsent(t, () => {'sent': 0, 'pending': 0, 'skipped': 0, 'total': 0});
      if (s == 'sent') {
        types[t]!['sent'] = (types[t]!['sent'] ?? 0) + 1;
      } else if (s == 'pending') {
        types[t]!['pending'] = (types[t]!['pending'] ?? 0) + 1;
      } else {
        types[t]!['skipped'] = (types[t]!['skipped'] ?? 0) + 1;
      }
      types[t]!['total'] = (types[t]!['total'] ?? 0) + 1;
    }
    return types;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonCircle(size: 48),
            SizedBox(height: 16),
            SkeletonBox(height: 14, width: 160),
          ],
        ),
      );
    }

    final total = _items.length;
    final sent = _countByStatus('sent');
    final pending = _countByStatus('pending');
    final skipped = _countByStatus('skipped');
    final typeStats = _getTypeStats();
    final sortedTypes = typeStats.entries.toList()
      ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));

    return RefreshIndicator(
      color: const Color(0xFFDD1847),
      onRefresh: () async { await _loadStats(); },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodRow(),
            const SizedBox(height: 16),
            _buildMetricCards(sent, pending, skipped, total),
            const SizedBox(height: 16),
            _buildDonutChart(sent, pending, skipped, total),
            const SizedBox(height: 12),
            _buildTypeBars(sortedTypes),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _cyclePeriod,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Text(
              _getPeriodLabel(),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Row(
          children: [
            Text(
              _formatPeriodDates(),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _shiftPeriod(-1),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: const Icon(Icons.chevron_left,
                    size: 16, color: Color(0xFF666666)),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _shiftPeriod(1),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: const Icon(Icons.chevron_right,
                    size: 16, color: Color(0xFF666666)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCards(
      int sent, int pending, int skipped, int total) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            icon: Icons.check,
            iconBgColor: const Color(0xFFE0F7F5),
            iconColor: const Color(0xFF4ECDC4),
            value: sent.toString(),
            label: 'Отправлено',
            percent: total > 0 ? '${(sent / total * 100).round()}%' : '0%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            icon: Icons.access_time,
            iconBgColor: const Color(0xFFFFF4E5),
            iconColor: const Color(0xFFFFB347),
            value: pending.toString(),
            label: 'Ожидают',
            percent:
                total > 0 ? '${(pending / total * 100).round()}%' : '0%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            icon: Icons.close,
            iconBgColor: const Color(0xFFFFE8EA),
            iconColor: const Color(0xFFFF8B94),
            value: skipped.toString(),
            label: 'Не отправлено',
            percent:
                total > 0 ? '${(skipped / total * 100).round()}%' : '0%',
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String value,
    required String label,
    required String percent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A)),
                ),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  percent,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFAAAAAA),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(
      int sent, int pending, int skipped, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Распределение по статусам',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _DonutPainter(
                    sent: sent,
                    pending: pending,
                    skipped: skipped,
                    total: total,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          total.toString(),
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A)),
                        ),
                        const Text(
                          'всего',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF999999)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _legendItem(
                        const Color(0xFF4ECDC4), 'Отправлено', sent),
                    _legendItem(
                        const Color(0xFFFFB347), 'Ожидают', pending),
                    _legendItem(const Color(0xFFFF8B94),
                        'Не отправлено', skipped),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF555555))),
          const Spacer(),
          Text(
            value.toString(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBars(
      List<MapEntry<String, Map<String, int>>> sortedTypes) {
    if (sortedTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxTotal = sortedTypes
        .map((e) => e.value['total']!)
        .reduce(math.max)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('По типам уведомлений',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...sortedTypes.map((entry) {
            final type = entry.key;
            final stats = entry.value;
            final label = _typeLabels[type] ?? type;
            final sentWidth =
                maxTotal > 0 ? stats['sent']! / maxTotal * 100 : 0.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          label,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius:
                                BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: sentWidth / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ECDC4),
                                borderRadius:
                                    BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 32,
                        child: Text(
                          stats['total'].toString(),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A)),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                if (stats['pending']! > 0)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 120, bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFF3F4F6),
                              borderRadius:
                                  BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment:
                                  Alignment.centerLeft,
                              widthFactor: maxTotal > 0
                                  ? stats['pending']! /
                                      maxTotal *
                                      100 /
                                      100
                                  : 0.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                      0xFFFFB347),
                                  borderRadius:
                                      BorderRadius
                                          .circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 32,
                          child: Text(
                            stats['pending'].toString(),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w600,
                                color: Color(0xFFFFB347)),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (stats['skipped']! > 0)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 120, bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFF3F4F6),
                              borderRadius:
                                  BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment:
                                  Alignment.centerLeft,
                              widthFactor: maxTotal > 0
                                  ? stats['skipped']! /
                                      maxTotal *
                                      100 /
                                      100
                                  : 0.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                      0xFFFF8B94),
                                  borderRadius:
                                      BorderRadius
                                          .circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 32,
                          child: Text(
                            stats['skipped'].toString(),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w600,
                                color: Color(0xFFFF8B94)),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ==================== ДОНУТ-ПАЙНТЕР ====================
class _DonutPainter extends CustomPainter {
  final int sent;
  final int pending;
  final int skipped;
  final int total;

  _DonutPainter({
    required this.sent,
    required this.pending,
    required this.skipped,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    const strokeWidth = 30.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (total == 0) return;

    double sentAngle = (sent / total) * 2 * math.pi;
    double pendingAngle = (pending / total) * 2 * math.pi;
    double skippedAngle = (skipped / total) * 2 * math.pi;

    double startAngle = -math.pi / 2;

    if (sent > 0) {
      final sentPaint = Paint()
        ..color = const Color(0xFF4ECDC4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sentAngle, false, sentPaint);
      startAngle += sentAngle;
    }

    if (pending > 0) {
      final pendingPaint = Paint()
        ..color = const Color(0xFFFFB347)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, pendingAngle, false, pendingPaint);
      startAngle += pendingAngle;
    }

    if (skipped > 0) {
      final skippedPaint = Paint()
        ..color = const Color(0xFFFF8B94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, skippedAngle, false, skippedPaint);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      sent != oldDelegate.sent ||
      pending != oldDelegate.pending ||
      skipped != oldDelegate.skipped ||
      total != oldDelegate.total;
}

// ==================== ИСТОРИЯ ОТПРАВКИ ====================
class _HistoryTab extends StatefulWidget {
  final int projectId;
  const _HistoryTab({required this.projectId});
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<Map<String, dynamic>> _items = [];
  final Map<int, Map<String, dynamic>> _itemsCache = {};
  bool _loading = true;
  String _period = 'week';
  DateTime _currentDate = DateTime.now();
  String _statusFilter = '';
  String _channelFilter = '';
  String _typeFilter = '';
  String _search = '';
  int _page = 1;
  int _totalPages = 1;

  static const _typeLabels = {
    'new_booking': 'Создание записи',
    'transfer': 'Перенос записи',
    'cancel': 'Отмена записи',
    'reminder': 'Напоминание',
    'return_visit': 'Повторный визит',
    'after_cancel': 'После отмены',
    'birthday': 'День рождения',
    'review_request': 'Запрос отзыва',
  };
  static const _channelLabels = {
    'manual': 'Ручная',
    'telegram': 'Telegram',
    'internal': 'Внутренние',
    'whatsapp': 'WhatsApp',
    'whatsapp_business': 'WhatsApp Business',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, String> _getPeriodDates() {
    final from = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
    DateTime to;
    switch (_period) {
      case 'day':
        to = from;
        break;
      case 'week':
        final day = from.weekday;
        from.subtract(Duration(days: day - 1));
        to = from.add(const Duration(days: 6));
        break;
      case 'month':
        from.copyWith(day: 1);
        to = DateTime(from.year, from.month + 1, 0);
        break;
      case 'year':
        from.copyWith(month: 1, day: 1);
        to = DateTime(from.year, 12, 31);
        break;
      default:
        final day = from.weekday;
        from.subtract(Duration(days: day - 1));
        to = from.add(const Duration(days: 6));
    }
    return {
      'from': DateFormat('yyyy-MM-dd').format(from),
      'to': DateFormat('yyyy-MM-dd').format(to),
    };
  }

  String _getPeriodLabel() {
    switch (_period) {
      case 'day': return 'За день';
      case 'week': return 'За неделю';
      case 'month': return 'За месяц';
      case 'year': return 'За год';
      default: return 'За неделю';
    }
  }

  String _formatPeriodDates() {
    final dates = _getPeriodDates();
    final from = DateTime.parse(dates['from']!);
    final to = DateTime.parse(dates['to']!);
    return '${_formatDateShort(from)} – ${_formatDateShort(to)}';
  }

  String _formatDateShort(DateTime d) {
    const months = ['янв','фев','мар','апр','мая','июн','июл','авг','сен','окт','ноя','дек'];
    return '${d.day} ${months[d.month - 1]}';
  }

  String _formatDateFull(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
      final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      return '${d.day} ${months[d.month - 1]} ${d.year}, $time';
    } catch (_) {
      return dateStr;
    }
  }

  void _cyclePeriod() {
    const periods = ['day', 'week', 'month', 'year'];
    final idx = periods.indexOf(_period);
    _period = periods[(idx + 1) % 4];
    _currentDate = DateTime.now();
    _page = 1;
    _itemsCache.clear();
    _load();
  }

  void _shiftPeriod(int dir) {
    switch (_period) {
      case 'day': _currentDate = _currentDate.add(Duration(days: dir));
      case 'week': _currentDate = _currentDate.add(Duration(days: dir * 7));
      case 'month': _currentDate = DateTime(_currentDate.year, _currentDate.month + dir, 1);
      case 'year': _currentDate = DateTime(_currentDate.year + dir, 1, 1);
    }
    _page = 1;
    _itemsCache.clear();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dates = _getPeriodDates();
      final params = <String, String>{
        'project_id': widget.projectId.toString(),
        'date_from': dates['from']!,
        'date_to': dates['to']!,
        'page': _page.toString(),
      };
      if (_statusFilter.isNotEmpty) params['status'] = _statusFilter;
      if (_channelFilter.isNotEmpty) params['channel'] = _channelFilter;
      if (_typeFilter.isNotEmpty) params['type'] = _typeFilter;
      if (_search.isNotEmpty) params['search'] = _search;
      
      final uri = '/api/notification/history?${Uri(queryParameters: params).query}';
      final r = await ApiService.get(uri);
      
      if (r['success'] == true && mounted) {
        final items = List<Map<String, dynamic>>.from(r['data'] ?? []);
        for (final item in items) {
          _itemsCache[item['id']] = item;
        }
        setState(() {
          _items = items;
          _totalPages = r['total_pages'] ?? 1;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendNow(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отправить сейчас?'),
        content: const Text('Отправить уведомление сейчас?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отправить')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final r = await ApiService.post('/api/notification/update-status', {
        'id': id,
        'status': 'sent',
      });
      if (r['success'] == true && mounted) {
        showToast(context, 'Уведомление отправлено');
        _itemsCache.clear();
        _load();
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Ошибка', isError: true);
      }
    }
  }

  Future<void> _markAsSent(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отметить как отправленное?'),
        content: const Text('Отметить уведомление как отправленное?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final r = await ApiService.post('/api/notification/update-status', {
        'id': id,
        'status': 'sent',
      });
      if (r['success'] == true && mounted) {
        showToast(context, 'Статус изменён на «Отправлено»');
        _itemsCache.clear();
        _load();
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Ошибка', isError: true);
      }
    }
  }

  Future<void> _resendNotification(int id) async {
    final item = _itemsCache[id];
    if (item == null) {
      showToast(context, 'Уведомление не найдено. Обновите страницу.', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пересоздать уведомление?'),
        content: const Text('Пересоздать уведомление для повторной отправки?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final r = await ApiService.post('/api/notification/resend', {
        'id': id,
        'project_id': widget.projectId,
      });
      if (r['success'] == true && mounted) {
        showToast(context, 'Уведомление пересоздано и готово к отправке');
        _itemsCache.clear();
        _load();
      } else {
        if (mounted) {
          showToast(context, 'Ошибка: ${r['message'] ?? ''}', isError: true);
        }
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Ошибка', isError: true);
      }
    }
  }

  void _openDetail(int id) {
    final item = _itemsCache[id];
    if (item == null) return;
    _showDetail(item);
  }

  void _showDetail(Map<String, dynamic> item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _NotificationDetailPopup(item: item, formatDateTime: _formatDateTime),
    );
  }

  @override
Widget build(BuildContext context) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final dateKey = (item['send_at'] ?? item['created_at'] ?? '').toString().substring(0, 10);
      groups.putIfAbsent(dateKey, () => []).add(item);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: TextField(
            onChanged: (v) {
              _search = v;
              _page = 1;
              _itemsCache.clear();
              _load();
            },
            decoration: InputDecoration(
              hintText: 'Поиск по имени, фамилии или номеру',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: _cyclePeriod,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                  ),
                  child: Text(
                    _getPeriodLabel(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Spacer(),
              Text(_formatPeriodDates(), style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _shiftPeriod(-1),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: const Icon(Icons.chevron_left, size: 16, color: Color(0xFF666666)),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _shiftPeriod(1),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF666666)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _filterChip('СТАТУС', _statusFilter, {
                '': 'Все',
                'sent': 'Отправлено',
                'pending': 'Ожидают',
                'skipped': 'Не отправлено',
              }, (v) { _statusFilter = v; _page = 1; _itemsCache.clear(); _load(); }),
              const SizedBox(width: 8),
              _filterChip('КАНАЛ', _channelFilter, {
                '': 'Все',
                'manual': 'Ручная',
                'telegram': 'Telegram',
                'internal': 'Внутренние',
                'whatsapp': 'WhatsApp',
                'whatsapp_business': 'WhatsApp Business',
              }, (v) { _channelFilter = v; _page = 1; _itemsCache.clear(); _load(); }),
              const SizedBox(width: 8),
              _filterChip('ВИД УВЕДОМЛЕНИЯ', _typeFilter, {
                '': 'Все',
                ..._typeLabels,
              }, (v) { _typeFilter = v; _page = 1; _itemsCache.clear(); _load(); }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFDD1847),
            onRefresh: () async { _page = 1; _itemsCache.clear(); await _load(); },
            child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: 5,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Row(
                      children: [
                        const SkeletonCircle(size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonBox(height: 14, width: 150),
                              const SizedBox(height: 6),
                              const SkeletonBox(height: 12, width: 200),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text('Нет уведомлений за этот период', style: TextStyle(color: Color(0xFF999999)))),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: sortedKeys.length + (_totalPages > 1 ? 1 : 0),
                      itemBuilder: (_, sectionIndex) {
                        if (sectionIndex == sortedKeys.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_page > 1)
                                  TextButton(
                                    onPressed: () { _page--; _itemsCache.clear(); _load(); },
                                    child: const Text('←'),
                                  ),
                                Text(' $_page / $_totalPages ', style: const TextStyle(color: Color(0xFF666666))),
                                if (_page < _totalPages)
                                  TextButton(
                                    onPressed: () { _page++; _itemsCache.clear(); _load(); },
                                    child: const Text('→'),
                                  ),
                              ],
                            ),
                          );
                        }

                        final dateKey = sortedKeys[sectionIndex];
                        final dayItems = groups[dateKey]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, left: 4),
                              child: Text(
                                _formatDateFull(dateKey),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF999999),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            ...dayItems.map((item) => _buildHistoryItem(item)),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final clientName = (item['client_name'] ?? '').toString();
    final status = item['status'] ?? 'pending';
    final time = (item['send_at'] ?? item['created_at'] ?? '').toString().length >= 16
        ? (item['send_at'] ?? item['created_at']).toString().substring(11, 16)
        : '';
final avatarUrl = item['client_avatar']?.toString() ?? item['master_avatar']?.toString();
    return GestureDetector(
      onTap: () => _openDetail(item['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Row(
          children: [
            (avatarUrl != null && avatarUrl.isNotEmpty)
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: '${ApiService.baseUrl}$avatarUrl',
                      width: 40, height: 40, fit: BoxFit.cover,
                      placeholder: (_, _) => const SkeletonCircle(size: 40),
                      errorWidget: (_, _, _) => AvatarInitials(name: clientName, size: 40, textColor: const Color(0xFF999999)),
                    ),
                  )
                : AvatarInitials(name: clientName, size: 40, textColor: const Color(0xFF999999)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['client_name'] ?? 'Без имени',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['client_phone'] ?? ''} · ${_typeLabels[item['type']] ?? item['type']}${item['channel'] != 'manual' ? ' · ${_channelLabels[item['channel']] ?? item['channel']}' : ''}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                const SizedBox(width: 6),
                _buildStatusIcon(status),
                const SizedBox(width: 4),
                if (status == 'pending')
                  _actionButton(
                    color: const Color(0xFFE8F5E9),
                    iconColor: const Color(0xFF2E7D32),
                    icon: Icons.send,
                    onTap: () => _sendNow(item['id']),
                  )
                else if (status == 'skipped' || status == 'postponed')
                  _actionButton(
                    color: const Color(0xFFF5F5F5),
                    iconColor: const Color(0xFF666666),
                    icon: Icons.check,
                    onTap: () => _markAsSent(item['id']),
                  )
                else if (status == 'sent')
                  _actionButton(
                    color: const Color(0xFFE3F2FD),
                    iconColor: const Color(0xFF1565C0),
                    icon: Icons.refresh,
                    onTap: () => _resendNotification(item['id']),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;
    switch (status) {
      case 'sent':
        icon = Icons.check_circle;
        color = const Color(0xFF2E7D32);
        break;
      case 'skipped':
        icon = Icons.cancel;
        color = const Color(0xFFC62828);
        break;
      case 'postponed':
        icon = Icons.schedule;
        color = const Color(0xFF6A1B9A);
        break;
      default:
        icon = Icons.access_time;
        color = const Color(0xFFE65100);
    }
    return Icon(icon, size: 14, color: color);
  }

  Widget _actionButton({
    required Color color,
    required Color iconColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }

  Widget _filterChip(String label, String value, Map<String, String> options, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF999999), letterSpacing: 0.5)),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
              items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ПОПАП ДЕТАЛЕЙ УВЕДОМЛЕНИЯ ====================
class _NotificationDetailPopup extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(String) formatDateTime;

  const _NotificationDetailPopup({
    required this.item,
    required this.formatDateTime,
  });

  static const _channelLabels = {
    'manual': 'Ручная отправка',
    'telegram': 'Telegram',
    'internal': 'Внутренние',
    'whatsapp': 'WhatsApp',
    'whatsapp_business': 'WhatsApp Business',
  };

  @override
  Widget build(BuildContext context) {
    final clientName = (item['client_name'] ?? '').toString();
    final status = item['status'] ?? 'pending';
    final channelName = _channelLabels[item['channel']] ?? 'Ручная отправка';
    final dateToShow = item['sent_at'] ?? item['send_at'] ?? item['created_at'] ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'sent':
        statusColor = const Color(0xFF2E7D32);
        statusIcon = Icons.check_circle;
        statusText = 'Отправлено';
        break;
      case 'skipped':
        statusColor = const Color(0xFFC62828);
        statusIcon = Icons.cancel;
        statusText = 'Не отправлено';
        break;
      case 'postponed':
        statusColor = const Color(0xFF6A1B9A);
        statusIcon = Icons.schedule;
        statusText = 'Отложено';
        break;
      default:
        statusColor = const Color(0xFFE65100);
        statusIcon = Icons.access_time;
        statusText = 'Ожидает отправки';
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    channelName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Color(0xFF666666), size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarInitials(
                        name: clientName,
                        size: 52,
                        bgColor: const Color(0xFFF0F0F0),
                        textColor: const Color(0xFFDD1847),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['client_name'] ?? 'Без имени',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['client_phone'] ?? '',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      item['message'] ?? item['template'] ?? '',
                      style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF1E293B)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(statusText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor)),
                      const Spacer(),
                      Text(
                        formatDateTime(dateToShow),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ДЕТАЛЬНЫЙ ПРОСМОТР УВЕДОМЛЕНИЯ ====================

// ==================== КАНАЛЫ ОТПРАВКИ ====================
class _ChannelsTab extends StatefulWidget {
  final int projectId;
  const _ChannelsTab({required this.projectId});
  @override
  State<_ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<_ChannelsTab> {
  bool _telegramEnabled = false;
  Map<String, bool> _telegramTypes = {};
  bool _manualEnabled = true;
  bool _internalEnabled = false;
  Map<String, bool> _internalTypes = {};
  final Map<String, bool> _channels = {
    'sms': true,
    'telegram': true,
    'whatsapp': true,
    'whatsapp_business': true
  };

  Widget _buildSvgIcon(String assetName, {double size = 24, Color? color}) {
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.get(
          '/api/notification/get-telegram-settings?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        setState(() {
          _telegramEnabled = r['data']['enabled'] == true;
          _telegramTypes =
              Map<String, bool>.from(r['data']['types'] ?? {});
        });
      }
      final ir = await ApiService.get(
          '/api/notification/get-internal-settings?project_id=${widget.projectId}');
      if (ir['success'] == true && mounted) {
        setState(() {
          _internalEnabled = ir['data']['enabled'] == true;
          _internalTypes =
              Map<String, bool>.from(ir['data']['types'] ?? {});
        });
      }
      final cr = await ApiService.get(
          '/api/notification/get-manual-channels?project_id=${widget.projectId}');
      if (cr['success'] == true && mounted) {
        final list =
            List<Map<String, dynamic>>.from(cr['data'] ?? []);
        for (final c in list) {
          _channels[c['channel']] = c['enabled'] == 1;
        }
        _manualEnabled = _channels.values.any((v) => v);
      }
    } catch (_) {}
  }

  Future<void> _saveTelegram({bool? enabled, Map<String, bool>? types}) async {
    await ApiService.post('/api/notification/save-telegram-settings', {
      'project_id': widget.projectId,
      'enabled': enabled ?? _telegramEnabled,
      'types': types ?? _telegramTypes,
    });
  }

  Future<void> _saveInternal({bool? enabled, Map<String, bool>? types}) async {
    await ApiService.post('/api/notification/save-internal-settings', {
      'project_id': widget.projectId,
      'enabled': enabled ?? _internalEnabled,
      'types': types ?? _internalTypes,
    });
  }

  Future<void> _saveChannel(String channel, bool enabled) async {
    await ApiService.post('/api/notification/save-manual-channel', {
      'project_id': widget.projectId,
      'channel': channel,
      'enabled': enabled ? 1 : 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFFDD1847),
      onRefresh: () async { await _load(); },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Каналы отправки',
            style:
                TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
            'Подключите отправку уведомлений по SMS, WhatsApp, Telegram или полуавтоматически',
            style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('ПОДКЛЮЧЕННЫЕ',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF888888),
                  letterSpacing: 0.5)),
        ),
        _buildChannelCard(
          iconPath: 'assets/check-manual.svg',
          title: 'Ручная отправка',
          subtitle:
              'SMS, WhatsApp, Telegram, Вконтакте — отправка с вашего устройства',
          statusText: _manualEnabled ? 'Подключено' : 'Подключить',
          statusOn: _manualEnabled,
          onTap: () => _showManualSettings(),
        ),
        const SizedBox(height: 8),
        _buildChannelCard(
          iconPath: 'assets/telegram-nf.svg',
          title: 'Telegram',
          subtitle:
              'Автоматическая отправка уведомлений клиентам в Telegram',
          statusText: _telegramEnabled ? 'Подключено' : 'Подключить',
          statusOn: _telegramEnabled,
          onTap: () => _showTelegramSettingsModal(),
        ),
        const SizedBox(height: 8),
        _buildChannelCard(
          iconPath: 'assets/b-logotip.png',
          isSvg: false,
          title: 'Внутренние уведомления',
          subtitle: 'Автоматическая отправка уведомлений клиентам в приложении Б-Запись',
          statusText: _internalEnabled ? 'Подключено' : 'Подключить',
          statusOn: _internalEnabled,
          onTap: () => _showInternalSettingsModal(),
        ),
        ],
      ),
    );
  }

  Widget _buildChannelCard({
    required String iconPath,
    required String title,
    required String subtitle,
    required String statusText,
    required bool statusOn,
    required VoidCallback onTap,
    bool isSvg = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
  child: isSvg
      ? _buildSvgIcon(iconPath, size: 20)
      : ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(iconPath, width: 24, height: 24),
        ),
),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusOn
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusOn
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF999999),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999))),
            ),
          ],
        ),
      ),
    );
  }

  void _showInternalSettingsModal() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _InternalSettingsScreen(
        projectId: widget.projectId,
        internalEnabled: _internalEnabled,
        internalTypes: _internalTypes,
        onInternalToggle: (enabled) {
          setState(() => _internalEnabled = enabled);
          _saveInternal(enabled: enabled);
        },
        onTypeChanged: (types) {
          setState(() => _internalTypes = types);
          _saveInternal(types: types);
        },
      ),
    ),
  );
}


  

  void _showTelegramSettingsModal() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _TelegramSettingsScreen(
        projectId: widget.projectId,
        telegramEnabled: _telegramEnabled,
        telegramTypes: _telegramTypes,
        onTelegramToggle: (enabled) {
          setState(() => _telegramEnabled = enabled);
          _saveTelegram(enabled: enabled);
        },
        onTypeChanged: (types) {
          setState(() => _telegramTypes = types);
          _saveTelegram(types: types);
        },
      ),
    ),
  );
}


  void _showManualSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ManualSettingsScreen(
          projectId: widget.projectId,
          channels: _channels,
          manualEnabled: _manualEnabled,
          onChannelChanged: (channel, enabled) {
            setState(() => _channels[channel] = enabled);
            _saveChannel(channel, enabled);
          },
          onManualToggle: (enabled) {
            setState(() => _manualEnabled = enabled);
          },
        ),
      ),
    );
  }
}

// ==================== ЭКРАН НАСТРОЕК РУЧНОЙ ОТПРАВКИ ====================
class _ManualSettingsScreen extends StatefulWidget {
  final int projectId;
  final Map<String, bool> channels;
  final bool manualEnabled;
  final Function(String channel, bool enabled) onChannelChanged;
  final Function(bool enabled) onManualToggle;

  const _ManualSettingsScreen({
    required this.projectId,
    required this.channels,
    required this.manualEnabled,
    required this.onChannelChanged,
    required this.onManualToggle,
  });

  @override
  State<_ManualSettingsScreen> createState() => _ManualSettingsScreenState();
}

class _ManualSettingsScreenState extends State<_ManualSettingsScreen> {
  late bool _manualEnabled;
  late Map<String, bool> _channels;

  @override
  void initState() {
    super.initState();
    _manualEnabled = widget.manualEnabled;
    _channels = Map<String, bool>.from(widget.channels);
  }

  Widget _buildSvgIcon(String assetName, {double size = 24, Color? color}) {
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    const channelLabels = {
      'sms': 'SMS',
      'telegram': 'Telegram',
      'whatsapp': 'WhatsApp',
      'whatsapp_business': 'WhatsApp Business',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Ручная отправка'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: _buildSvgIcon('assets/check-manual.svg', size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ручная отправка',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      const Text(
                          'SMS, WhatsApp — отправка с вашего устройства',
                          style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                    ],
                  ),
                ),
                Switch(
                  value: _manualEnabled,
                  onChanged: (v) {
                    setState(() => _manualEnabled = v);
                    widget.onManualToggle(v);
                  },
                  activeThumbColor: const Color(0xFFDD1847),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFF8B6914)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Отправка уведомлений будет осуществляться с вашего номера и ваших аккаунтов социальных сетей.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8B6914), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('КАНАЛЫ ОТПРАВКИ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...channelLabels.entries.map((entry) {
            final channel = entry.key;
            final label = entry.value;
            final enabled = _channels[channel] ?? true;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) {
                      setState(() => _channels[channel] = v);
                      widget.onChannelChanged(channel, v);
                    },
                    activeThumbColor: const Color(0xFFDD1847),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==================== ЭКРАН НАСТРОЕК TELEGRAM ====================
class _TelegramSettingsScreen extends StatefulWidget {
  final int projectId;
  final bool telegramEnabled;
  final Map<String, bool> telegramTypes;
  final Function(bool enabled) onTelegramToggle;
  final Function(Map<String, bool> types) onTypeChanged;

  const _TelegramSettingsScreen({
    required this.projectId,
    required this.telegramEnabled,
    required this.telegramTypes,
    required this.onTelegramToggle,
    required this.onTypeChanged,
  });

  @override
  State<_TelegramSettingsScreen> createState() => _TelegramSettingsScreenState();
}

class _TelegramSettingsScreenState extends State<_TelegramSettingsScreen> {
  late bool _telegramEnabled;
  late Map<String, bool> _telegramTypes;

  @override
  void initState() {
    super.initState();
    _telegramEnabled = widget.telegramEnabled;
    _telegramTypes = Map<String, bool>.from(widget.telegramTypes);
  }

  @override
  Widget build(BuildContext context) {
    const types = [
      {'key': 'new_booking', 'label': 'Создание записи'},
      {'key': 'transfer', 'label': 'Перенос записи'},
      {'key': 'cancel', 'label': 'Отмена записи'},
      {'key': 'reminder', 'label': 'Напоминание'},
      {'key': 'return_visit', 'label': 'Повторный визит'},
      {'key': 'after_cancel', 'label': 'После отмены'},
      {'key': 'birthday', 'label': 'День рождения'},
      {'key': 'review_request', 'label': 'Запрос отзыва'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Настройка Telegram'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SvgPicture.asset(
                    'assets/telegram-nf.svg',
                    width: 20,
                    height: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Telegram',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      const Text(
                          'Автоматическая отправка уведомлений клиентам в Telegram',
                          style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                    ],
                  ),
                ),
                Switch(
                  value: _telegramEnabled,
                  onChanged: (v) {
                    setState(() => _telegramEnabled = v);
                    widget.onTelegramToggle(v);
                  },
                  activeThumbColor: const Color(0xFFDD1847),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF1565C0)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Клиент должен активировать бота @bzapis_bot и иметь Telegram в карточке.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1565C0), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('ТИПЫ УВЕДОМЛЕНИЙ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...types.map((t) {
            final key = t['key']!;
            final enabled = _telegramTypes[key] != false;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t['label']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) {
                      setState(() => _telegramTypes[key] = v);
                      widget.onTypeChanged(_telegramTypes);
                    },
                    activeThumbColor: const Color(0xFFDD1847),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==================== ЭКРАН НАСТРОЕК ВНУТРЕННИХ УВЕДОМЛЕНИЙ ====================
class _InternalSettingsScreen extends StatefulWidget {
  final int projectId;
  final bool internalEnabled;
  final Map<String, bool> internalTypes;
  final Function(bool enabled) onInternalToggle;
  final Function(Map<String, bool> types) onTypeChanged;

  const _InternalSettingsScreen({
    required this.projectId,
    required this.internalEnabled,
    required this.internalTypes,
    required this.onInternalToggle,
    required this.onTypeChanged,
  });

  @override
  State<_InternalSettingsScreen> createState() => _InternalSettingsScreenState();
}

class _InternalSettingsScreenState extends State<_InternalSettingsScreen> {
  late bool _internalEnabled;
  late Map<String, bool> _internalTypes;

  @override
  void initState() {
    super.initState();
    _internalEnabled = widget.internalEnabled;
    _internalTypes = Map<String, bool>.from(widget.internalTypes);
  }

  @override
  Widget build(BuildContext context) {
    const types = [
      {'key': 'new_booking', 'label': 'Создание записи'},
      {'key': 'transfer', 'label': 'Перенос записи'},
      {'key': 'cancel', 'label': 'Отмена записи'},
      {'key': 'reminder', 'label': 'Напоминание'},
      {'key': 'return_visit', 'label': 'Повторный визит'},
      {'key': 'after_cancel', 'label': 'После отмены'},
      {'key': 'birthday', 'label': 'День рождения'},
      {'key': 'review_request', 'label': 'Запрос отзыва'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Внутренние уведомления'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Row(
              children: [
                Container(
  width: 40,
  height: 40,
  decoration: BoxDecoration(
    color: const Color(0xFFF8F8F8),
    borderRadius: BorderRadius.circular(10),
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.asset(
      'assets/b-logotip.png',
      width: 24,
      height: 24,
    ),
  ),
),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Внутренние уведомления',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      const Text(
                          'Автоматическая отправка уведомлений клиентам в приложении Б-Запись',
                          style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                    ],
                  ),
                ),
                Switch(
                  value: _internalEnabled,
                  onChanged: (v) {
                    setState(() => _internalEnabled = v);
                    widget.onInternalToggle(v);
                  },
                  activeThumbColor: const Color(0xFFDD1847),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF7B1FA2)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Клиент должен скачать приложение Б-Запись, авторизоваться и включить Push уведомления в настройках телефона.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF7B1FA2), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('ТИПЫ УВЕДОМЛЕНИЙ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...types.map((t) {
            final key = t['key']!;
            final enabled = _internalTypes[key] != false;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t['label']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) {
                      setState(() => _internalTypes[key] = v);
                      widget.onTypeChanged(_internalTypes);
                    },
                    activeThumbColor: const Color(0xFFDD1847),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==================== ДОСТУП СОТРУДНИКОВ ====================
class _ManualAccessScreen extends StatefulWidget {
  final int projectId;
  const _ManualAccessScreen({required this.projectId});
  @override
  State<_ManualAccessScreen> createState() => _ManualAccessScreenState();
}

class _ManualAccessScreenState extends State<_ManualAccessScreen> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String _search = '';
  final Map<int, bool> _notificationRights = {};

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.get(
          '/api/employee/list?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        final emps = List<Map<String, dynamic>>.from(r['data']);
        for (final emp in emps) {
          try {
            final detail = await ApiService.get(
                '/api/employee/get?id=${emp['id']}&project_id=${widget.projectId}');
            if (detail['success'] == true && detail['data'] != null) {
              _notificationRights[emp['id']] =
                  detail['data']['can_send_notifications'] != false;
            }
          } catch (_) {}
        }
        setState(() {
          _employees = emps;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAccess(int empId, bool enabled) async {
    final emp = _employees.firstWhere((e) => e['id'] == empId);
    try {
      await ApiService.post('/api/employee/save', {
        'project_id': widget.projectId,
        'employee_id': empId,
        'first_name': emp['first_name'] ?? '',
        'last_name': emp['last_name'] ?? '',
        'phone': emp['phone'] ?? '',
        'can_send_notifications': enabled ? 1 : 0,
      });
      setState(() => _notificationRights[empId] = enabled);
      if (mounted) {
        showToast(context, enabled ? 'Уведомления включены' : 'Уведомления отключены');
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Ошибка сохранения', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _employees.where((e) {
      if (_search.isEmpty) return true;
      final name =
          '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.toLowerCase();
      return name.contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Доступ сотрудников'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonCircle(size: 48),
                  SizedBox(height: 16),
                  SkeletonBox(height: 14, width: 160),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Поиск сотрудников',
                      prefixIcon: const Icon(Icons.search,
                          size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFF0F0F0)),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(
                              vertical: 10),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final emp = filtered[i];
                      final empName = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
                      final canSend =
                          _notificationRights[emp['id']] ??
                              true;
                      return Container(
                        margin:
                            const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(
                                  0xFFF0F0F0)),
                        ),
                        child: Row(
                          children: [
                            AvatarInitials(
                              name: empName,
                              size: 44,
                              bgColor: const Color(0xFFF3F4F6),
                              textColor: const Color(0xFF999999),
                            ),

                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight
                                                .w600),
                                  ),
                                  Text(
                                    emp['position'] ??
                                        emp['category'] ??
                                        'Сотрудник',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(
                                            0xFF999999)),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: canSend,
                              onChanged: (v) =>
                                  _toggleAccess(
                                      emp['id'], v),
                              activeThumbColor:
                                  const Color(0xFFDD1847),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ==================== ВИДЫ УВЕДОМЛЕНИЙ ====================
class _TypesTab extends StatefulWidget {
  final int projectId;
  const _TypesTab({required this.projectId});
  @override
  State<_TypesTab> createState() => _TypesTabState();
}

class _TypesTabState extends State<_TypesTab> {
  final Map<String, Map<String, dynamic>> _typeData = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    const types = [
      'reminder',
      'return_visit',
      'after_cancel',
      'birthday',
      'review_request'
    ];
    for (final t in types) {
      try {
        final r = await ApiService.get(
            '/api/notification/get-${t == 'review_request' ? 'review-request' : t == 'after_cancel' ? 'after-cancel' : t == 'return_visit' ? 'return' : t}-settings?project_id=${widget.projectId}');
        if (r['success'] == true && mounted) {
          setState(() => _typeData[t] = r['data']);
        }
      } catch (_) {}
    }
  }

  String _getTypeDesc(String type) {
    final d = _typeData[type];
    if (d == null) return 'Загрузка...';
    if (d['enabled'] == false) return 'Выключено';
    switch (type) {
      case 'reminder':
        return ((d['times'] as List?)
                ?.map((t) => {
                      '1h': 'За час',
                      '3h': 'За 3 часа',
                      '6h': 'За 6 часов',
                      '12h': 'За 12 часов',
                      '1d': 'За день',
                      '3d': 'За 3 дня'
                    }[t] ??
                    t)
                .join(', ') ??
            'Настроено');
      case 'return_visit':
        return 'Через ${d['interval_value']} ${_getUnitLabel(d['interval_value'], d['interval_unit'])}, ${d['send_time']}';
      case 'after_cancel':
        return 'Через ${d['interval_value']} ${_getUnitLabel(d['interval_value'], d['interval_unit'])}, ${d['send_time']}';
      case 'birthday':
        return {
              'on_birthday': 'В день рождения',
              '1_day_before': 'За день',
              '3_days_before': 'За 3 дня',
              '1_week_before': 'За неделю',
              '2_weeks_before': 'За 2 недели'
            }[d['send_date']] ??
            d['send_date'] ??
            '';
      case 'review_request':
        return 'Через ${d['delay_value']} ${d['delay_unit'] == 'hours' ? 'час.' : 'дн.'}';
      default:
        return 'Настроено';
    }
  }

  String _getUnitLabel(dynamic value, String? unit) {
    final num = int.tryParse(value?.toString() ?? '1') ?? 1;
    switch (unit) {
      case 'days':
        if (num % 10 == 1 && num % 100 != 11) return 'день';
        if (num % 10 >= 2 &&
            num % 10 <= 4 &&
            (num % 100 < 10 || num % 100 >= 20)) {
          return 'дня';
        }
        return 'дней';
      case 'weeks':
        if (num % 10 == 1 && num % 100 != 11) return 'неделя';
        if (num % 10 >= 2 &&
            num % 10 <= 4 &&
            (num % 100 < 10 || num % 100 >= 20)) {
          return 'недели';
        }
        return 'недель';
      case 'months':
        if (num % 10 == 1 && num % 100 != 11) return 'месяц';
        if (num % 10 >= 2 &&
            num % 10 <= 4 &&
            (num % 100 < 10 || num % 100 >= 20)) {
          return 'месяца';
        }
        return 'месяцев';
      default:
        return unit ?? '';
    }
  }

  bool _isTypeEnabled(String type) {
    final d = _typeData[type];
    if (d == null) return true;
    return d['enabled'] != false;
  }

  void _openTypeSettings(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NotificationTypeSettingsScreen(
          projectId: widget.projectId,
          type: type,
          data: _typeData[type],
          onSaved: () => _loadAll(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFFDD1847),
      onRefresh: () async { await _loadAll(); },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Виды уведомлений',
            style:
                TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Настройте необходимые сообщения',
            style:
                TextStyle(fontSize: 13, color: Color(0xFF888888))),
        const SizedBox(height: 24),
        _sectionTitle('При записи'),
        _typeCard('Создание записи', 'Вкл', true,
            () => _openTypeSettings('new_booking')),
        _typeCard('Перенос записи', 'Вкл', true,
            () => _openTypeSettings('transfer')),
        _typeCard('Отмена записи', 'Вкл', true,
            () => _openTypeSettings('cancel')),
        const SizedBox(height: 16),
        _sectionTitle('Перед визитом'),
        _typeCard('Напоминание о визите',
            _getTypeDesc('reminder'), _isTypeEnabled('reminder'),
            () => _openTypeSettings('reminder')),
        const SizedBox(height: 16),
        _sectionTitle('После визита'),
        _typeCard(
            'Запрос отзыва',
            _getTypeDesc('review_request'),
            _isTypeEnabled('review_request'),
            () => _openTypeSettings('review_request')),
        _typeCard(
            'Повторный визит',
            _getTypeDesc('return_visit'),
            _isTypeEnabled('return_visit'),
            () => _openTypeSettings('return_visit')),
        const SizedBox(height: 16),
        _sectionTitle('Возвращаемость'),
        _typeCard(
            'Приглашение после отмены',
            _getTypeDesc('after_cancel'),
            _isTypeEnabled('after_cancel'),
            () => _openTypeSettings('after_cancel')),
        _typeCard(
            'Поздравление с днём рождения',
            _getTypeDesc('birthday'),
            _isTypeEnabled('birthday'),
            () => _openTypeSettings('birthday')),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF888888),
                letterSpacing: 0.5)),
      );

  Widget _typeCard(
      String name, String desc, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                enabled ? 'Вкл' : 'Выкл',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF999999),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}

// ==================== НАСТРОЙКА ТИПА УВЕДОМЛЕНИЯ ====================
class _NotificationTypeSettingsScreen extends StatefulWidget {
  final int projectId;
  final String type;
  final Map<String, dynamic>? data;
  final VoidCallback onSaved;

  const _NotificationTypeSettingsScreen({
    required this.projectId,
    required this.type,
    this.data,
    required this.onSaved,
  });

  @override
  State<_NotificationTypeSettingsScreen> createState() =>
      _NotificationTypeSettingsScreenState();
}

class _NotificationTypeSettingsScreenState
    extends State<_NotificationTypeSettingsScreen> {
  late Map<String, dynamic> _settings;
  bool _loading = false;
  bool _skipBlocked = true;
  bool _skipNoConsent = true;
  bool _confirmEnabled = true;
  final Map<String, String> _templates = {
    'manual': '',
    'telegram': '',
    'internal': '',
  };
  final Map<String, String> _confirmTemplates = {
    'manual': '',
    'telegram': '',
    'internal': '',
  };
  String _activeChannel = 'manual';
  String _activeReminderTemplate = 'general';
  Timer? _saveTimer;
  bool _showTimesList = false;
  bool _reviewNewClientsOnly = false;
  String _reviewFrequency = 'every_visit';

  static const _typeTitles = {
    'new_booking': 'Создание записи',
    'transfer': 'Перенос записи',
    'cancel': 'Отмена записи',
    'reminder': 'Напоминание о визите',
    'return_visit': 'Повторный визит',
    'after_cancel': 'Приглашение после отмены',
    'birthday': 'Поздравление с днём рождения',
    'review_request': 'Запрос отзыва',
  };

  static const _variables = [
    {'var': ':COMPANY_ADDRESS', 'desc': 'Адрес компании'},
    {'var': ':RECORD_TIME', 'desc': 'Время записи'},
    {'var': ':RECORD_DATE', 'desc': 'Дата записи'},
    {'var': ':MASTER_NAME', 'desc': 'Имя мастера'},
    {'var': ':SERVICES_NAME', 'desc': 'Название услуги'},
    {'var': ':CLIENT_PHONE', 'desc': 'Мобильный телефон клиента'},
    {'var': ':CLIENT_FIRSTNAME', 'desc': 'Имя клиента'},
    {'var': ':COMPANY_NAME', 'desc': 'Название компании'},
    {'var': ':COMPANY_LINK', 'desc': 'Ссылка на компанию'},
    {'var': ':COMPANY_PHONE', 'desc': 'Телефон салона'},
    {'var': ':CLIENT_NAME', 'desc': 'ФИО клиента'},
  ];

  @override
  void initState() {
    super.initState();
    _settings = Map<String, dynamic>.from(widget.data ?? {});
    if (!_settings.containsKey('enabled')) {
      _settings['enabled'] = true;
    }
    _skipBlocked = _settings['skip_blocked'] != false;
    _skipNoConsent = _settings['skip_no_consent'] != false;
    _confirmEnabled = _settings['confirm_enabled'] != false;
    _reviewNewClientsOnly = _settings['new_clients_only'] == true;
    _reviewFrequency = _settings['frequency'] ?? 'every_visit';
        if (_settings['templates'] != null) {
      final t = _settings['templates'];
      if (t is Map) {
        _templates['manual'] = t['manual'] ?? '';
        _templates['telegram'] = t['telegram'] ?? '';
        _templates['internal'] = t['internal'] ?? '';
      }
    }
    if (_templates['manual']!.isEmpty && widget.type == 'after_cancel') {
      _templates['manual'] = ':CLIENT_FIRSTNAME, заметили, что вы отменили запись!\nМы будем рады видеть вас в подходящее вам время.\nЗаписаться на визит можно по ссылке: :COMPANY_LINK';
      _templates['telegram'] = ':CLIENT_FIRSTNAME, заметили что вы отменили запись. Будем рады видеть вас снова! :COMPANY_LINK';
      _templates['internal'] = 'Заметили, что вы отменили запись. Будем рады видеть вас снова!';
    }
    if (_templates['manual']!.isEmpty && widget.type == 'birthday') {
      _templates['manual'] = ':CLIENT_FIRSTNAME, поздравляем вас С Днём рождения!\n\nБудем рады видеть вас снова – загляните к нам, чтобы порадовать себя в этот особенный день \n\n👉 Запишитесь онлайн: :COMPANY_LINK';
      _templates['telegram'] = ':CLIENT_FIRSTNAME, с днём рождения! 🎉 Примите наши поздравления! :COMPANY_LINK';
      _templates['internal'] = 'С днём рождения! 🎉 Примите наши поздравления!';
    }
    if (_templates['manual']!.isEmpty && widget.type == 'cancel') {
      _templates['manual'] = 'Здравствуйте, :CLIENT_NAME! Запись :RECORD_DATE в :RECORD_TIME отменена. С уважением, :COMPANY_NAME.';
      _templates['telegram'] = ':CLIENT_FIRSTNAME, запись :RECORD_DATE в :RECORD_TIME отменена. :COMPANY_NAME';
      _templates['internal'] = 'Запись :RECORD_DATE в :RECORD_TIME отменена.';
    }
    if (_templates['manual']!.isEmpty && widget.type == 'new_booking') {
      _templates['manual'] = 'Здравствуйте, :CLIENT_NAME! Вы записаны на :RECORD_DATE в :RECORD_TIME. :COMPANY_NAME';
      _templates['telegram'] = ':CLIENT_FIRSTNAME, вы записаны на :RECORD_DATE в :RECORD_TIME. :COMPANY_NAME';
      _templates['internal'] = 'Вы записаны на :RECORD_DATE в :RECORD_TIME.';
    }
    if (_templates['manual']!.isEmpty && widget.type == 'transfer') {
      _templates['manual'] = 'Здравствуйте, :CLIENT_NAME! Ваша запись перенесена на :RECORD_DATE в :RECORD_TIME. :COMPANY_NAME';
      _templates['telegram'] = ':CLIENT_FIRSTNAME, запись перенесена на :RECORD_DATE в :RECORD_TIME. :COMPANY_NAME';
      _templates['internal'] = 'Запись перенесена на :RECORD_DATE в :RECORD_TIME.';
    }
    if (_templates['manual']!.isEmpty && widget.type == 'reminder') {
      _templates['manual'] = 'Здравствуйте! Напоминаем о записи на :SERVICES_NAME :RECORD_DATE в :RECORD_TIME. Ваш мастер: :MASTER_NAME.';
      _templates['telegram'] = 'Напоминаем о записи на :SERVICES_NAME :RECORD_DATE в :RECORD_TIME. :MASTER_NAME';
      _templates['internal'] = 'Напоминаем о записи на :SERVICES_NAME :RECORD_DATE в :RECORD_TIME.';
    }
    if (_confirmTemplates['manual']!.isEmpty && widget.type == 'reminder') {
      _confirmTemplates['manual'] = ':CLIENT_FIRSTNAME, здравствуйте!\n❗️Требуется подтверждение визита. Подтвердите запись по ссылке, перенесите или отмените ее 👉🏻 :REMIND_CONFIRM_LINK\n\nЗапись на :SERVICES_NAME :RECORD_DATE в :RECORD_TIME. Ваш мастер: :MASTER_NAME.';
      _confirmTemplates['telegram'] = ':CLIENT_FIRSTNAME, требуется подтверждение визита. Подтвердите: :REMIND_CONFIRM_LINK';
      _confirmTemplates['internal'] = 'Требуется подтверждение визита. Подтвердите запись.';
    }
    if (_templates['manual']!.isEmpty && widget.type == 'return_visit') {
      _templates['manual'] = 'Здравствуйте!\nБудем рады видеть вас в нашей студии повторно на услугу - :SERVICES_NAME.\nУдобное время для записи доступно по ссылке: :LINK';
      _templates['telegram'] = 'Будем рады видеть вас снова! Запишитесь на :SERVICES_NAME по ссылке: :LINK';
      _templates['internal'] = 'Будем рады видеть вас снова! Запишитесь на :SERVICES_NAME.';
    }
    if (_templates['manual']!.isEmpty && widget.type == 'review_request') {
      _templates['manual'] = ':CLIENT_FIRSTNAME, Вам понравилась процедура? Будем рады вашему отзыву :REVIEW_LINK\n\nС уважением, :COMPANY_NAME.';
      _templates['telegram'] = ':CLIENT_FIRSTNAME, как прошла процедура? Оставьте отзыв: :REVIEW_LINK';
      _templates['internal'] = 'Как прошла процедура? Оставьте отзыв.';
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final endpoint = widget.type == 'review_request'
          ? 'review-request'
          : widget.type == 'after_cancel'
              ? 'after-cancel'
              : widget.type == 'return_visit'
                  ? 'return'
                  : widget.type == 'new_booking'
                      ? 'new-booking'
                      : widget.type == 'transfer'
                          ? 'transfer'
                          : widget.type == 'cancel'
                              ? 'cancel'
                              : widget.type == 'reminder'
                                  ? 'reminder'
                                  : widget.type;
      final body = <String, dynamic>{
        'project_id': widget.projectId,
        ..._settings,
      };

      if (widget.type == 'after_cancel' || widget.type == 'birthday' ||
          widget.type == 'cancel' || widget.type == 'new_booking' ||
          widget.type == 'transfer' || widget.type == 'reminder' ||
          widget.type == 'return_visit') {
        if (widget.type == 'reminder') {
          body['confirm_enabled'] = _confirmEnabled ? 1 : 0;
          body['templates'] = _templates;
          body['confirm_templates'] = _confirmTemplates;
        }
        if (widget.type == 'return_visit') {
          body['skip_blocked'] = _skipBlocked ? 1 : 0;
          body['skip_no_consent'] = _skipNoConsent ? 1 : 0;
          body['templates'] = _templates;
          body['template'] = _templates[_activeChannel] ?? '';
        }
        if (widget.type == 'review_request') {
          body['new_clients_only'] = _reviewNewClientsOnly ? 1 : 0;
          body['frequency'] = _reviewFrequency;
          body['templates'] = _templates;
          body['template'] = _templates[_activeChannel] ?? '';
        }
        if (widget.type == 'after_cancel') {
          body['skip_blocked'] = _skipBlocked ? 1 : 0;
          body['skip_no_consent'] = _skipNoConsent ? 1 : 0;
        }
        body['templates'] = _templates;
        body['template'] = _templates[_activeChannel] ?? '';
      }

      final r = await ApiService.post(
          '/api/notification/save-$endpoint-settings', body);
      if (r['success'] == true && mounted) {
        widget.onSaved();
        showToast(context, 'Сохранено');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Ошибка сохранения', isError: true);
      }
    }
    setState(() => _loading = false);
  }

  void _autoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _settings['enabled'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_typeTitles[widget.type] ?? 'Настройки'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Сохранить',
                style: TextStyle(
                    color: Color(0xFFDD1847),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: SwitchListTile(
              title: Text(_typeTitles[widget.type] ?? 'Включено'),
              value: enabled,
              onChanged: (v) {
                setState(() => _settings['enabled'] = v);
                _autoSave();
              },
              activeThumbColor: const Color(0xFFDD1847),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 24),
          Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: IgnorePointer(
              ignoring: !enabled,
              child: Column(
                children: _buildTypeSpecificSettings(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTypeSpecificSettings() {
    switch (widget.type) {
      case 'reminder':
        return _buildReminderSettings();
      case 'return_visit':
        return _buildReturnVisitSettings();
      case 'after_cancel':
        return _buildAfterCancelSettings();
      case 'birthday':
        return _buildBirthdaySettings();
      case 'review_request':
        return _buildReviewSettings();
      case 'new_booking':
      case 'transfer':
      case 'cancel':
        return _buildSimpleTemplateSettings();
      default:
        return [];
    }
  }

  List<Widget> _buildAfterCancelSettings() {
    return [
      ..._buildIntervalSettings(),
      _buildSwitchCard(
        'Не отправлять заблокированным',
        null,
        _skipBlocked,
        (v) {
          setState(() => _skipBlocked = v);
          _autoSave();
        },
      ),
      _buildSwitchCard(
        'Не отправлять клиентам без получения согласия',
        'Приглашение после отмены относятся к рекламным уведомлениям. При включении данной опции они не будут отправляться клиентам, не давшим согласия.',
        _skipNoConsent,
        (v) {
          setState(() => _skipNoConsent = v);
          _autoSave();
        },
      ),
      _buildTemplateCard(),
    ];
  }

  Widget _buildSwitchCard(String title, String? hint, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF999999), height: 1.4)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFDD1847),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard() {

    return GestureDetector(
      onTap: () => _showTemplateModal(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Шаблон ${_typeTitles[widget.type] ?? ''}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              _activeChannel == 'telegram' ? 'Telegram' : (_activeChannel == 'internal' ? 'Внутренние' : 'Ручная'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  void _showTemplateModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final template = _templates[_activeChannel] ?? '';

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _typeTitles[widget.type] ?? 'Шаблон',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close, color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                    ),
                    child: Row(
                      children: [
                        _buildChannelTab('manual', 'Ручная отправка', setModalState),
                        const SizedBox(width: 4),
                        _buildChannelTab('telegram', 'Telegram', setModalState),
                        const SizedBox(width: 4),
                        _buildChannelTab('internal', 'Внутренние', setModalState),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: TextEditingController(text: template),
                              maxLines: 5,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                              style: const TextStyle(fontSize: 13, height: 1.6),
                              onChanged: (v) {
                                _templates[_activeChannel] = v;
                                setModalState(() {});
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ПРЕДПРОСМОТР СООБЩЕНИЯ',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF999999), letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _buildPreview(template),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF333333), height: 1.6),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Список переменных', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text(
                            'Для того, чтобы использовать меняющиеся данные в шаблоне скопируйте переменную и вставьте в нужное место в тексте шаблона',
                            style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                          ),
                          const SizedBox(height: 12),
                          ..._variables.map((v) => _buildVariableRow(v['var']!, v['desc']!)),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _autoSave();
                          Navigator.pop(ctx);
                          showToast(context, 'Шаблон для $_activeChannel сохранён');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDD1847),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Сохранить'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReminderTemplateModal() {
    final title = _activeReminderTemplate == 'confirm' ? 'Шаблон с подтверждением' : 'Шаблон напоминания';

    final vars = _activeReminderTemplate == 'confirm'
        ? <String>[
            ':RECORD_TIME', ':RECORD_DATE', ':CLIENT_FIRSTNAME', ':MASTER_NAME',
            ':COMPANY_NAME', ':SERVICES_NAME', ':REMIND_CONFIRM_LINK',
            ':COMPANY_PHONE', ':CLIENT_NAME',
          ]
        : <String>[
            ':COMPANY_ADDRESS', ':RECORD_TIME', ':RECORD_DATE', ':CLIENT_FIRSTNAME',
            ':MASTER_NAME', ':COMPANY_NAME', ':SERVICES_NAME', ':COMPANY_LINK',
            ':COMPANY_PHONE', ':CLIENT_SURNAME', ':CLIENT_NAME',
          ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final currentTemplate = _activeReminderTemplate == 'confirm'
              ? _confirmTemplates[_activeChannel] ?? ''
              : _templates[_activeChannel] ?? '';

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close, color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
                    ),
                    child: Row(
                      children: [
                        _buildChannelTab('manual', 'Ручная отправка', setModalState),
                        const SizedBox(width: 4),
                        _buildChannelTab('telegram', 'Telegram', setModalState),
                        const SizedBox(width: 4),
                        _buildChannelTab('internal', 'Внутренние', setModalState),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: TextEditingController(text: currentTemplate),
                              maxLines: 5,
                              decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                              style: const TextStyle(fontSize: 13, height: 1.6),
                              onChanged: (v) {
                                if (_activeReminderTemplate == 'confirm') {
                                  _confirmTemplates[_activeChannel] = v;
                                } else {
                                  _templates[_activeChannel] = v;
                                }
                                setModalState(() {});
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ПРЕДПРОСМОТР СООБЩЕНИЯ',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF999999), letterSpacing: 0.5)),
                                const SizedBox(height: 8),
                                Text(
                                  _buildReminderPreview(currentTemplate),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF333333), height: 1.6),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Список переменных', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text(
                            'Для того, чтобы использовать меняющиеся данные в шаблоне скопируйте переменную и вставьте в нужное место в тексте шаблона',
                            style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                          ),
                          const SizedBox(height: 12),
                          ...vars.map((v) {
                            final desc = _getVarDesc(v);
                            return _buildVariableRow(v, desc);
                          }),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _autoSave();
                          Navigator.pop(ctx);
                          showToast(context, 'Шаблон для $_activeChannel сохранён');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDD1847),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Сохранить'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getVarDesc(String variable) {
    const map = {
      ':COMPANY_ADDRESS': 'Адрес компании',
      ':RECORD_TIME': 'Время записи',
      ':RECORD_DATE': 'Дата записи',
      ':CLIENT_FIRSTNAME': 'Имя клиента',
      ':MASTER_NAME': 'Имя мастера',
      ':COMPANY_NAME': 'Название компании',
      ':SERVICES_NAME': 'Название услуги',
      ':COMPANY_LINK': 'Ссылка на компанию',
      ':COMPANY_PHONE': 'Телефон салона',
      ':CLIENT_SURNAME': 'Фамилия клиента',
      ':CLIENT_NAME': 'ФИО клиента',
      ':REMIND_CONFIRM_LINK': 'Ссылка на подтверждение',
    };
    return map[variable] ?? variable;
  }

  String _buildReminderPreview(String template) {
    if (template.isEmpty) return 'Начните вводить шаблон...';
    String text = template;
    text = text.replaceAll(':CLIENT_FIRSTNAME', 'Анна');
    text = text.replaceAll(':CLIENT_NAME', 'Анна Петрова');
    text = text.replaceAll(':CLIENT_SURNAME', 'Петрова');
    text = text.replaceAll(':MASTER_NAME', 'Елена Смирнова');
    text = text.replaceAll(':SERVICES_NAME', 'Стрижка женская');
    text = text.replaceAll(':COMPANY_NAME', 'Beauty Studio');
    text = text.replaceAll(':COMPANY_ADDRESS', 'ул. Примерная, д. 1');
    text = text.replaceAll(':COMPANY_PHONE', '+7 (999) 123-45-67');
    text = text.replaceAll(':COMPANY_LINK', 'https://запись.бьютироща.рф/book/123');
    text = text.replaceAll(':REMIND_CONFIRM_LINK', 'https://запись.бьютироща.рф/confirm/123');
    text = text.replaceAll(':RECORD_DATE', '12 июня');
    text = text.replaceAll(':RECORD_TIME', '14:00');
    text = text.replaceAll(':LINK', 'https://запись.бьютироща.рф/book/123');
    text = text.replaceAll(':REVIEW_LINK', 'https://запись.бьютироща.рф/review/123');
    return text;
  }

  Widget _buildChannelTab(String channel, String label, StateSetter setModalState) {
    final isActive = _activeChannel == channel;
    return GestureDetector(
      onTap: () {
        setModalState(() => _activeChannel = channel);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? const Color(0xFFDD1847) : const Color(0xFF888888),
          ),
        ),
      ),
    );
  }

  String _buildPreview(String template) {
    if (template.isEmpty) return 'Начните вводить шаблон...';
    String text = template;
    text = text.replaceAll(':CLIENT_FIRSTNAME', 'Анна');
    text = text.replaceAll(':CLIENT_NAME', 'Анна Петрова');
    text = text.replaceAll(':CLIENT_PHONE', '+7 (999) 123-45-67');
    text = text.replaceAll(':MASTER_NAME', 'Елена Смирнова');
    text = text.replaceAll(':SERVICES_NAME', 'Стрижка женская');
    text = text.replaceAll(':COMPANY_NAME', 'Beauty Studio');
    text = text.replaceAll(':COMPANY_ADDRESS', 'ул. Примерная, д. 1');
    text = text.replaceAll(':COMPANY_PHONE', '+7 (999) 123-45-67');
    text = text.replaceAll(':COMPANY_LINK', 'https://запись.бьютироща.рф/book/123');
    text = text.replaceAll(':RECORD_DATE', '12 июня');
    text = text.replaceAll(':RECORD_TIME', '14:00');
    return text;
  }

  Widget _buildVariableRow(String variable, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              variable,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(desc, style: const TextStyle(fontSize: 13)),
          ),
          GestureDetector(
            onTap: () {
              showToast(context, '$variable скопировано');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.copy, size: 14, color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReturnVisitSettings() {
    return [
      ..._buildIntervalSettings(),
      _buildSwitchCard(
        'Не отправлять заблокированным',
        null,
        _skipBlocked,
        (v) {
          setState(() => _skipBlocked = v);
          _autoSave();
        },
      ),
      _buildSwitchCard(
        'Не отправлять клиентам без получения согласия',
        'Приглашение на повторный визит относятся к рекламным уведомлениям. При включении данной опции они не будут отправляться клиентам, не давшим согласия.',
        _skipNoConsent,
        (v) {
          setState(() => _skipNoConsent = v);
          _autoSave();
        },
      ),
      _buildTemplateCard(),
    ];
  }

  List<Widget> _buildReminderSettings() {
    final times = List<String>.from(_settings['times'] ?? ['12h', '3d']);
    const options = {
      '1h': 'За час',
      '3h': 'За 3 часа',
      '6h': 'За 6 часов',
      '12h': 'За 12 часов',
      '1d': 'За день',
      '3d': 'За 3 дня',
    };

    final selectedLabels = times.map((t) => options[t] ?? t).join(', ');

    return [
      _buildSwitchCard(
        'Запрашивать подтверждение',
        'В текст напоминания будет добавлена ссылка для подтверждения записи',
        _confirmEnabled,
        (v) {
          setState(() => _confirmEnabled = v);
          _settings['confirm_enabled'] = v;
          _autoSave();
        },
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => setState(() => _showTimesList = !_showTimesList),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Время отправки',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      selectedLabels.isNotEmpty ? selectedLabels : 'Не выбрано',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
            ],
          ),
        ),
      ),
      if (_showTimesList) ...[
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                  border: Border(bottom: BorderSide(color: Color(0xFFFEF3C7))),
                ),
                child: const Text(
                  'Можно выбрать не более двух напоминаний',
                  style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                ),
              ),
              ...options.entries.map((e) {
                final isSelected = times.contains(e.key);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        times.remove(e.key);
                      } else {
                        if (times.length >= 2) {
                          showToast(context, 'Можно выбрать не более двух напоминаний', isError: true);
                          return;
                        }
                        times.add(e.key);
                      }
                      _settings['times'] = times;
                    });
                    _autoSave();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFDF2F5) : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: e.key != options.keys.last ? const Color(0xFFF5F5F5) : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? const Color(0xFFDD1847) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () {
          _activeReminderTemplate = 'general';
          _showReminderTemplateModal();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: const Text('Общий шаблон напоминания',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const Text('Напоминание',
                  style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () {
          _activeReminderTemplate = 'confirm';
          _showReminderTemplateModal();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: const Text('Шаблон напоминания с подтверждением',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const Text('С подтверждением',
                  style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildIntervalSettings() {
    final value =
        int.tryParse(_settings['interval_value']?.toString() ?? '10') ??
            10;
    final unit = _settings['interval_unit'] ?? 'days';
    final sendTime = _settings['send_time'] ?? '12:00';
    const units = {
      'hours': 'Часов',
      'days': 'Дней',
      'weeks': 'Недель',
      'months': 'Месяцев'
    };

    return [
      const Text('Интервал отправки',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(
                  text: value.toString()),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFFF0F0F0)),
                ),
              ),
              onChanged: (v) {
                final num =
                    int.tryParse(v) ?? 10;
                setState(() =>
                    _settings['interval_value'] =
                        num);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                    color:
                        const Color(0xFFF0F0F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: unit,
                  isExpanded: true,
                  items: units.entries
                      .map((e) =>
                          DropdownMenuItem(
                              value: e.key,
                              child:
                                  Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() =>
                          _settings[
                              'interval_unit'] = v);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Text('Время отправки',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () async {
          final time = await showTimePickerSheet(
              context,
              initialTime: TimeOfDay(
                hour: int.parse(sendTime.split(':')[0]),
                minute: int.parse(sendTime.split(':')[1]),
              ),
            );
          if (time != null) {
            setState(() {
              _settings['send_time'] =
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFF0F0F0)),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text('Время'),
              Text(sendTime,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildBirthdaySettings() {
    final sendDate = _settings['send_date'] ?? 'on_birthday';
    final sendTime = _settings['send_time'] ?? '10:00';
    const options = {
      'on_birthday': 'В день рождения',
      '1_day_before': 'За день',
      '3_days_before': 'За 3 дня',
      '1_week_before': 'За неделю',
      '2_weeks_before': 'За 2 недели',
    };

    return [
      const Text('Дата отправки',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      RadioGroup<String>(
        groupValue: sendDate,
        onChanged: (v) {
          if (v != null) {
            setState(() => _settings['send_date'] = v);
            _autoSave();
          }
        },
        child: Column(
          children: options.entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<String>(
              value: e.key,
              title: Text(e.value),
              activeColor: const Color(0xFFDD1847),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white,
            ),
          )).toList(),
        ),
      ),
      const SizedBox(height: 24),
      const Text('Время отправки',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () async {
          final time = await showTimePickerSheet(
              context,
              initialTime: TimeOfDay(
                hour: int.parse(sendTime.split(':')[0]),
                minute: int.parse(sendTime.split(':')[1]),
              ),
            );
          if (time != null) {
            setState(() {
              _settings['send_time'] =
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            });
            _autoSave();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Время'),
              Text(sendTime,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      _buildTemplateCard(),
    ];
  }

  List<Widget> _buildReviewSettings() {
    final value = int.tryParse(_settings['delay_value']?.toString() ?? '1') ?? 1;
    final unit = _settings['delay_unit'] ?? 'hours';
    const units = {
      'hours': 'Часов',
      'days': 'Дней',
    };
    const frequencies = {
      'every_visit': 'После каждого визита',
      'once_3_months': '1 раз в 3 месяца',
      'once_month': '1 раз в месяц',
      'twice_month': '2 раза в месяц',
      'three_times_month': '3 раза в месяц',
    };

    return [
      _buildSwitchCard(
        'Только для новых клиентов',
        'Новым считается клиент, совершивший не более 2 визитов',
        _reviewNewClientsOnly,
        (v) {
          setState(() => _reviewNewClientsOnly = v);
          _settings['new_clients_only'] = v;
          _autoSave();
        },
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text('Периодичность',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: frequencies.containsKey(_reviewFrequency) ? _reviewFrequency : 'every_visit',
                  isDense: true,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
                  items: frequencies.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _reviewFrequency = v);
                      _settings['frequency'] = v;
                      _autoSave();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text('Отправлять через',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: value.toString()),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
                ),
              ),
              onChanged: (v) {
                final num = int.tryParse(v) ?? 1;
                setState(() => _settings['delay_value'] = num);
                _autoSave();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: unit,
                  isExpanded: true,
                  items: units.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _settings['delay_unit'] = v);
                      _autoSave();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _buildTemplateCard(),
    ];
  }

  List<Widget> _buildSimpleTemplateSettings() {
    return [
      _buildTemplateCard(),
    ];
  }
}