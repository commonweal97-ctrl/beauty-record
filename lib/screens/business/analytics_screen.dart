import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';

class AnalyticsScreen extends StatefulWidget {
  final int projectId;
  const AnalyticsScreen({super.key, required this.projectId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _period = 'today';
  String _dateFrom = '';
  String _dateTo = '';

  // Анимация спидометра
  late AnimationController _gaugeController;
  late Animation<double> _gaugeAnimation;
  double _displayedLoad = 0;

  // Анимация круговой диаграммы
  late AnimationController _pieController;
  late Animation<double> _pieAnimation;
  double _displayedOnline = 0;
  double _displayedManual = 0;

  // Данные для графика выручки
  List<double> _revenueHistory = [];

  @override
  void initState() {
    super.initState();

    // Контроллеры анимации
    _gaugeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _gaugeAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _gaugeController, curve: Curves.easeOutCubic),
    );
    _gaugeAnimation.addListener(() {
      setState(() {
        _displayedLoad = _gaugeAnimation.value;
      });
    });

    _pieController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pieAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _pieController, curve: Curves.easeOutCubic),
    );

    final now = DateTime.now();
    _dateFrom = _format(now);
    _dateTo = _format(now);
    _load();
  }

  @override
  void dispose() {
    _gaugeController.dispose();
    _pieController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.get(
        '/api/analytics/data?project_id=${widget.projectId}&date_from=$_dateFrom&date_to=$_dateTo',
      );
      if (result['success'] == true && mounted) {
        setState(() {
          _data = result['data'];
          _loading = false;
          _revenueHistory = _generateDemoRevenueHistory(
            result['data']['planned_revenue'] ?? 0,
            result['data']['total_bookings'] ?? 0,
          );
        });

        final load = (result['data']['load_percent'] ?? 0).toDouble();
        _animateGauge(load);

        final online = (result['data']['online_bookings'] ?? 0).toDouble();
        final manual = (result['data']['manual_bookings'] ?? 0).toDouble();
        _animatePie(online, manual);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, 'Ошибка загрузки аналитики', isError: true);  // ДОБАВИТЬ
      }
    }
  }

  void _animateGauge(double target) {
    _gaugeController.reset();
    _gaugeAnimation = Tween<double>(
      begin: _displayedLoad,
      end: target,
    ).animate(CurvedAnimation(
      parent: _gaugeController,
      curve: Curves.easeOutCubic,
    ));
    _gaugeAnimation.addListener(() {
      setState(() {
        _displayedLoad = _gaugeAnimation.value;
      });
    });
    _gaugeController.forward();
  }

  void _animatePie(double online, double manual) {
    _pieController.reset();
    
    _pieAnimation = Tween<double>(
      begin: 0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pieController,
      curve: Curves.easeOutCubic,
    ));
    
    _pieAnimation.addListener(() {
      setState(() {
        _displayedOnline = online * _pieAnimation.value;
        _displayedManual = manual * _pieAnimation.value;
      });
    });
    
    _pieController.forward().then((_) {
      setState(() {
        _displayedOnline = online;
        _displayedManual = manual;
      });
    });
  }

  List<double> _generateDemoRevenueHistory(int revenue, int bookings) {
    if (revenue == 0) return [];
    final segments = math.min(math.max(bookings ~/ 2, 4), 12);
    final baseVal = revenue / segments;
    final rng = math.Random();
    return List.generate(segments, (i) {
      final variation = (rng.nextDouble() - 0.3) * baseVal * 0.6;
      return (baseVal + variation).roundToDouble();
    });
  }

  String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _setPeriod(String period) {
    final now = DateTime.now();
    DateTime from = now, to = now;

    if (period == 'custom') {
      _showCustomPeriodDialog();
      return;
    }

    switch (period) {
      case 'today':
        break;
      case 'yesterday':
        from = now.subtract(const Duration(days: 1));
        to = from;
        break;
      case 'tomorrow':
        from = now.add(const Duration(days: 1));
        to = from;
        break;
      case 'week':
        from = now.subtract(Duration(days: now.weekday - 1));
        to = from.add(const Duration(days: 6));
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0);
        break;
      case 'quarter':
        final q = (now.month - 1) ~/ 3;
        from = DateTime(now.year, q * 3 + 1, 1);
        to = DateTime(now.year, q * 3 + 4, 0);
        break;
      case 'year':
        from = DateTime(now.year, 1, 1);
        to = DateTime(now.year, 12, 31);
        break;
    }

    setState(() {
      _period = period;
      _dateFrom = _format(from);
      _dateTo = _format(to);
    });
    _load();
  }

  void _showCustomPeriodDialog() async {
    DateTime from = DateTime.parse(_dateFrom);
    DateTime to = DateTime.parse(_dateTo);

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) {
        DateTime tempFrom = from;
        DateTime tempTo = to;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Свой период'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('От',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: tempFrom,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setDialogState(() => tempFrom = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_format(tempFrom)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('До',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: tempTo,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setDialogState(() => tempTo = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_format(tempTo)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD1847),
                  ),
                  onPressed: () {
                    Navigator.pop(context, {'from': tempFrom, 'to': tempTo});
                  },
                  child: const Text('Применить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _period = 'custom';
        _dateFrom = _format(result['from']!);
        _dateTo = _format(result['to']!);
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final total = d?['total_bookings'] ?? 0;
    final online = d?['online_bookings'] ?? 0;
    final manual = d?['manual_bookings'] ?? 0;
    final revenue = d?['planned_revenue'] ?? 0;
    final onlinePercent = total > 0 ? (online / total * 100).round() : 0;
    final manualPercent = total > 0 ? (manual / total * 100).round() : 0;

    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    final dateFromParsed = DateTime.tryParse(_dateFrom);
    final periodDate = dateFromParsed != null
        ? '${dateFromParsed.day} ${months[dateFromParsed.month - 1]}'
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _loading
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SkeletonBox(height: 24, width: 140),
                      const SkeletonBox(height: 36, width: 120, radius: 10),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Спидометр
                  _buildSkeletonCard([
                    const SkeletonBox(height: 13, width: 120),
                    const SizedBox(height: 12),
                    const Center(child: SkeletonCircle(size: 160)),
                  ]),
                  const SizedBox(height: 12),
                  // Выручка
                  _buildSkeletonCard([
                    const SkeletonBox(height: 13, width: 160),
                    const SizedBox(height: 12),
                    const SkeletonBox(height: 28, width: 140),
                    const SizedBox(height: 4),
                    const SkeletonBox(height: 12, width: 200),
                    const SizedBox(height: 12),
                    const SkeletonBox(height: 80),
                  ]),
                  const SizedBox(height: 12),
                  // Круговая диаграмма
                  _buildSkeletonCard([
                    const SkeletonBox(height: 13, width: 150),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SkeletonCircle(size: 160),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonBox(height: 30, width: double.infinity),
                              const SizedBox(height: 16),
                              const SkeletonBox(height: 30, width: double.infinity),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Клиенты
                  Row(
                    children: [
                      Expanded(child: _buildSkeletonMiniCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSkeletonMiniCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSkeletonMiniCard()),
                    ],
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFDD1847),
              onRefresh: () async { await _load(); },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок + период
                  _buildHeader(periodDate),
                  const SizedBox(height: 16),

                  // Свой период
                  if (_period == 'custom') _buildCustomPeriodInfo(),

                  // Загруженность (спидометр)
                  _buildCard('Загруженность',
                      child: _buildGaugeWidget(_displayedLoad)),
                  const SizedBox(height: 12),

                  // Выручка с графиком
                  _buildCard(
                    'Планируемая выручка',
                    child: _buildRevenueSection(revenue, _revenueHistory),
                  ),
                  const SizedBox(height: 12),

                  // Источник записей (круговая диаграмма)
                  _buildCard('Источник записей',
                      child: _buildPieChartSection(
                        _displayedOnline.round(),
                        _displayedManual.round(),
                        total,
                        onlinePercent,
                        manualPercent,
                      )),
                  const SizedBox(height: 12),

                  // Клиенты
                  _buildClientsRow(d),
                ],
              ),
              ),
            ),
    );
  }

  Widget _buildHeader(String periodDate) {
    final labels = {
      'today': 'Сегодня',
      'yesterday': 'Вчера',
      'tomorrow': 'Завтра',
      'week': 'Неделя',
      'month': 'Месяц',
      'quarter': 'Квартал',
      'year': 'Год',
      'custom': 'Свой период',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Аналитика',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        PopupMenuButton<String>(
          initialValue: _period,
          offset: const Offset(0, 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: Colors.white,
          onSelected: _setPeriod,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'today', child: Text('Сегодня')),
            const PopupMenuItem(value: 'yesterday', child: Text('Вчера')),
            const PopupMenuItem(value: 'tomorrow', child: Text('Завтра')),
            const PopupMenuItem(value: 'week', child: Text('Неделя')),
            const PopupMenuItem(value: 'month', child: Text('Месяц')),
            const PopupMenuItem(value: 'quarter', child: Text('Квартал')),
            const PopupMenuItem(value: 'year', child: Text('Год')),
            const PopupMenuItem(
                value: 'custom', child: Text('Свой период')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(labels[_period] ?? 'Сегодня',
                    style: const TextStyle(fontSize: 14)),
                if (periodDate.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(periodDate,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomPeriodInfo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('От',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(_dateFrom, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('До',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(_dateTo, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeWidget(double percent) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        size: const Size(double.infinity, 180),
        painter: _GaugePainter(percent: percent),
      ),
    );
  }

  Widget _buildRevenueSection(int revenue, List<double> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_formatMoney(revenue)} ₽',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFFDD1847),
          ),
        ),
        const Text('от стоимости услуг в записях',
            style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: history.isEmpty
              ? const Center(
                  child: Text('Нет данных',
                      style: TextStyle(color: Colors.grey)))
              : _buildRevenueChart(history),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(List<double> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: const Color(0xFFDD1847),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFDD1847).withValues(alpha: 0.15),
                  const Color(0xFFDD1847).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection(int online, int manual, int total,
      int onlinePercent, int manualPercent) {
    final totalForPie = online + manual;
    final displayOnline = totalForPie > 0 ? online : 0;
    final displayManual = totalForPie > 0 ? manual : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Круговая диаграмма с фиксированным контейнером
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 38,
                  sections: [
                    PieChartSectionData(
                      value: displayOnline.toDouble(),
                      color: const Color(0xFF1565C0),
                      showTitle: false,
                      radius: 45,
                    ),
                    PieChartSectionData(
                      value: displayManual.toDouble(),
                      color: const Color(0xFFE65100),
                      showTitle: false,
                      radius: 45,
                    ),
                  ],
                ),
              ),
              // Центральный текст с ограничением по ширине
              Container(
                width: 70,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'всего записей',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Легенда
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _legendItem('Онлайн-записи', online, '$onlinePercent%',
                  const Color(0xFF1565C0)),
              const SizedBox(height: 16),
              _legendItem('Записи через журнал', manual, '$manualPercent%',
                  const Color(0xFFE65100)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendItem(
      String label, int count, String percent, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$count ($percent)',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientsRow(Map<String, dynamic>? d) {
    return Row(
      children: [
        Expanded(
          child: _miniCard('Посетили', '${d?['visited_clients'] ?? 0}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniCard('Новые', '${d?['new_clients'] ?? 0}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniCard('Вернулись', '${d?['return_clients'] ?? 0}'),
        ),
      ],
    );
  }

  Widget _buildCard(String title, {Widget? child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ?child,
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _miniCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
        ],
      ),
    );
  }

  Widget _buildSkeletonMiniCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 22, width: 40),
          const SizedBox(height: 8),
          const SkeletonBox(height: 12, width: 60),
        ],
      ),
    );
  }

  String _formatMoney(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ' ',
        );
  }
}

// Кастомный спидометр как в веб-версии
class _GaugePainter extends CustomPainter {
  final double percent;

  _GaugePainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 20);
    final radius = math.min(size.width / 2 - 20, size.height - 40);
    const startAngle = math.pi;
    const angleRange = math.pi;

    // Серый фон дуги
    final bgPaint = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      angleRange,
      false,
      bgPaint,
    );

    // Градиент для активной дуги
    final clampedPercent = percent.clamp(0, 100);
    final fillAngle = angleRange * clampedPercent / 100;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = LinearGradient(
      colors: const [
        Color(0xFFDD1847),
        Color(0xFFE91E63),
        Color(0xFFFF5722),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(
      Rect.fromLTWH(center.dx - radius, center.dy - radius,
          radius * 2, radius * 2),
    );

    final activePaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, fillAngle, false, activePaint);

    // Деления
    for (int i = 0; i <= 10; i++) {
      final angle = startAngle + (angleRange * i / 10);
      final innerR = radius - 14;
      final outerR = radius + 14;
      final x1 = center.dx + innerR * math.cos(angle);
      final y1 = center.dy + innerR * math.sin(angle);
      final x2 = center.dx + outerR * math.cos(angle);
      final y2 = center.dy + outerR * math.sin(angle);

      final tickPaint = Paint()
        ..color =
            i <= (clampedPercent / 10).round() ? Colors.white : Colors.grey
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);
    }

    // Текст процента
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${percent.round()}%',
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, size.height - 30),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percent != percent;
  }
}