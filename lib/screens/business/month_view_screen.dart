import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../utils/name_utils.dart';
import '../../../widgets/common/avatar_initials.dart';

class MonthViewScreen extends StatefulWidget {
  final int projectId;
  final Function(DateTime)? onDateSelected;
  const MonthViewScreen({super.key, required this.projectId, this.onDateSelected});

  @override
  State<MonthViewScreen> createState() => _MonthViewScreenState();
}

class _MonthViewScreenState extends State<MonthViewScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _employees = [];
  List<DateTime> _dates = [];
  DateTime _currentMonth = DateTime.now();
  bool _loading = true;
  final _scrollController = ScrollController();
  final _verticalScrollController = ScrollController();

  // Анимация попапа
  late AnimationController _popupAnimationController;
  late Animation<double> _popupScaleAnimation;
  late Animation<double> _popupOpacityAnimation;
  bool _popupVisible = false;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _generateDates();
    _load();

    _popupAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _popupScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _popupAnimationController, curve: Curves.easeOut),
    );
    _popupOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _popupAnimationController, curve: Curves.easeOut),
    );
  }

  void _generateDates() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    _dates = List.generate(daysInMonth, (i) => DateTime(_currentMonth.year, _currentMonth.month, i + 1));
  }

  void _load() async {
    setState(() => _loading = true);
    try {
      final year = _currentMonth.year;
      final month = _currentMonth.month.toString().padLeft(2, '0');
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
      final endDate = '$year-$month-${lastDay.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        ApiService.get('/api/employee/list?project_id=${widget.projectId}'),
        ApiService.get('/api/booking/list?project_id=${widget.projectId}&date=$year-$month-01&end_date=$endDate'),
      ]);

      if (mounted) {
        final empData = results[0];
        final bookData = results[1];

        final List<Map<String, dynamic>> employees = empData['success'] == true
            ? List<Map<String, dynamic>>.from(empData['data'] ?? [])
            : [];
            
        final List<Map<String, dynamic>> allBookings = bookData['success'] == true
            ? List<Map<String, dynamic>>.from(bookData['data'] ?? [])
            : [];

        final List<Map<String, dynamic>> bookings = allBookings
    .where((b) => b['status'] != 'cancelled')
    .toList();

        final Map<int, List<int>> bookingMap = {};
        for (final b in bookings) {
          final empId = b['employee_id'] as int?;
          final dateStr = b['date'] as String?;
          
          if (empId != null && dateStr != null) {
            final date = DateTime.tryParse(dateStr);
            if (date != null) {
              final day = date.day - 1;
              bookingMap.putIfAbsent(empId, () => List.filled(_dates.length, 0));
              if (day >= 0 && day < _dates.length) {
                bookingMap[empId]![day]++;
              }
            }
          }
        }

        setState(() {
          _employees = employees.map((emp) {
            final empId = emp['id'] as int;
            final loads = bookingMap[empId] ?? List.filled(_dates.length, 0);
            return {
              ...emp,
              'loads': loads,
            };
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.day == now.day && d.month == now.month && d.year == now.year;
  }

  bool _isWeekend(DateTime d) => d.weekday == 6 || d.weekday == 7;

  int _weekdayIndex(DateTime d) {
    return d.weekday == 7 ? 0 : d.weekday;
  }

  void _openMonthPicker() {
    setState(() => _popupVisible = true);
    _popupAnimationController.forward();
  }

  void _closeMonthPicker() {
    _popupAnimationController.reverse().then((_) {
      if (mounted) setState(() => _popupVisible = false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _verticalScrollController.dispose();
    _popupAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    final months = [
      'янв.', 'фев.', 'мар.', 'апр.', 'мая', 'июн.',
      'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.'
    ];

    if (_loading) {
      return _buildSkeleton();
    }

    final todayIndex = _dates.indexWhere((d) => _isToday(d));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && todayIndex >= 0) {
        _scrollController.animateTo(
          todayIndex * 85.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Stack(
      children: [
        Column(
          children: [
            // Таблица с фиксированной колонкой
            Expanded(
              child: Stack(
                children: [
                  // СКРОЛЯЩАЯСЯ ЧАСТЬ (даты и индикаторы)
                  GestureDetector(
                    onPanUpdate: (details) {
                      _scrollController.jumpTo(_scrollController.offset - details.delta.dx);
                    },
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        child: Column(
                          children: [
                            // СТРОКА 1: Заголовки дат
                            Row(
                              children: [
                                // Пустая ячейка-заглушка под фиксированную колонку
                                const SizedBox(width: 100, height: 80),
                                // Ячейки с датами
                                ..._dates.map((d) {
                                  final today = _isToday(d);
                                  final weekend = _isWeekend(d);
                                  return Container(
                                    width: 85,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: today ? const Color(0xFFDD1847) : Colors.white,
                                      border: const Border(
                                        right: BorderSide(color: Color(0xFFF5F5F5)),
                                        bottom: BorderSide(color: Color(0xFFF5F5F5)),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          weekdays[_weekdayIndex(d)],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: today
                                                ? Colors.white
                                                : (weekend ? const Color(0xFFDD1847) : const Color(0xFF888888)),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${d.day}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: today ? Colors.white : const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          months[d.month - 1],
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: today ? Colors.white70 : const Color(0xFF888888),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                            // СТРОКИ 2+: Индикаторы загрузки
                            ..._employees.map((e) {
                              final loads = List<int>.from(e['loads'] ?? []);
                              while (loads.length < _dates.length) {
                                loads.add(0);
                              }

                              return Row(
                                children: [
                                  // Пустая ячейка-заглушка
                                  const SizedBox(width: 100, height: 70),
                                  // Индикаторы
                                  ...List.generate(_dates.length, (i) {
                                    final load = i < loads.length ? loads[i] : 0;
                                    final fillPercent = (load / 3.0).clamp(0.0, 1.0);
                                    
                                    return Container(
                                      width: 85,
                                      height: 70,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        border: Border(
                                          right: BorderSide(color: Color(0xFFF5F5F5)),
                                          bottom: BorderSide(color: Color(0xFFF5F5F5)),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Stack(
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF5F5F5),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  left: 0,
                                                  right: 0,
                                                  child: Container(
                                                    height: 48 * fillPercent,
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFFDD1847), Color(0xFFC1163D)],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      ),
                                                      borderRadius: BorderRadius.vertical(
                                                        bottom: const Radius.circular(12),
                                                        top: fillPercent >= 1.0
                                                            ? const Radius.circular(12)
                                                            : Radius.zero,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Center(
                                                  child: Text(
                                                    '$load',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: fillPercent > 0.5
                                                          ? Colors.white
                                                          : const Color(0xFF1A1A1A),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'записей',
                                            style: TextStyle(fontSize: 10, color: Color(0xFF888888)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ФИКСИРОВАННАЯ КОЛОНКА (сотрудники + календарь)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x0A000000),
                            offset: Offset(2, 0),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            // Фиксированная ячейка с календарём (заголовок)
                            Container(
                              width: 100,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  right: BorderSide(color: Color(0xFFF0F0F0)),
                                  bottom: BorderSide(color: Color(0xFFF5F5F5)),
                                ),
                              ),
                              child: Center(
                                child: IconButton(
                                  icon: const Icon(Icons.calendar_today, color: Color(0xFF666666)),
                                  onPressed: _openMonthPicker,
                                ),
                              ),
                            ),
                            // Фиксированные ячейки сотрудников
                            ..._employees.map((e) {
                              return Container(
                                width: 100,
                                height: 70,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    right: BorderSide(color: Color(0xFFF0F0F0)),
                                    bottom: BorderSide(color: Color(0xFFF5F5F5)),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Аватар
                                    (e['avatar'] != null && e['avatar'].toString().isNotEmpty)
                                        ? ClipOval(
                                            child: CachedAvatar(
                                              url: e['avatar'],
                                              size: 36,
                                              radius: 18,
                                            ),
                                          )
                                        : AvatarInitials(name: extractName(e), size: 36, bgColor: const Color(0xFFF0F0F0)),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        extractShortName(e),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Попап выбора месяца
        if (_popupVisible) _buildMonthPickerPopup(),
      ],
    );
  }

  Widget _buildMonthPickerPopup() {
    final monthsList = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
    final now = DateTime.now();
    int selectedYear = _currentMonth.year;
    int selectedMonth = _currentMonth.month - 1;

    return AnimatedBuilder(
      animation: _popupAnimationController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeMonthPicker,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5 * _popupOpacityAnimation.value),
                ),
              ),
            ),
            Center(
              child: Transform.scale(
                scale: _popupScaleAnimation.value,
                child: Opacity(
                  opacity: _popupOpacityAnimation.value,
                  child: Container(
                    width: 340,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 60,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Выберите месяц',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              GestureDetector(
                                onTap: _closeMonthPicker,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.close, size: 20, color: Color(0xFF666666)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Divider(color: Color(0xFFF0F0F0)),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() => selectedYear--),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(shape: BoxShape.circle),
                                      child: const Center(
                                        child: Icon(Icons.chevron_left, size: 22, color: Color(0xFF666666)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Text(
                                    '$selectedYear',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 20),
                                  GestureDetector(
                                    onTap: () => setState(() => selectedYear++),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(shape: BoxShape.circle),
                                      child: const Center(
                                        child: Icon(Icons.chevron_right, size: 22, color: Color(0xFF666666)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 2.2,
                                ),
                                itemCount: 12,
                                itemBuilder: (_, i) {
                                  final isSelected = i == selectedMonth;
                                  final isCurrent = selectedYear == now.year && i == now.month;

                                  Color bgColor;
                                  Color textColor;
                                  Color borderColor;

                                  if (isSelected) {
                                    bgColor = const Color(0xFFDD1847);
                                    textColor = Colors.white;
                                    borderColor = const Color(0xFFDD1847);
                                  } else if (isCurrent) {
                                    bgColor = const Color(0xFFFFF5F7);
                                    textColor = const Color(0xFFDD1847);
                                    borderColor = const Color(0xFFF8A5B9);
                                  } else {
                                    bgColor = Colors.white;
                                    textColor = const Color(0xFF1A1A1A);
                                    borderColor = const Color(0xFFF0F0F0);
                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _currentMonth = DateTime(selectedYear, i + 1);
                                        _generateDates();
                                      });
                                      _load();
                                      _closeMonthPicker();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: borderColor, width: 2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          monthsList[i],
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton() {
    final weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    final months = [
      'янв.', 'фев.', 'мар.', 'апр.', 'мая', 'июн.',
      'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.'
    ];

    final skeletonRows = List.generate(5, (i) => i);

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Скелетон дат и индикаторов
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 100, height: 80),
                          ..._dates.map((d) {
                            final today = _isToday(d);
                            return Container(
                              width: 85,
                              height: 80,
                              decoration: BoxDecoration(
                                color: today ? const Color(0xFFDD1847) : Colors.white,
                                border: const Border(
                                  right: BorderSide(color: Color(0xFFF5F5F5)),
                                  bottom: BorderSide(color: Color(0xFFF5F5F5)),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    weekdays[_weekdayIndex(d)],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: today ? Colors.white : const Color(0xFF888888),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${d.day}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: today ? Colors.white : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    months[d.month - 1],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: today ? Colors.white70 : const Color(0xFF888888),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      ...skeletonRows.map((_) {
                        return Row(
                          children: [
                            const SizedBox(width: 100, height: 70),
                            ...List.generate(_dates.length, (_) {
                              return Container(
                                width: 85,
                                height: 70,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    right: BorderSide(color: Color(0xFFF5F5F5)),
                                    bottom: BorderSide(color: Color(0xFFF5F5F5)),
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SkeletonBox(width: 48, height: 48, radius: 12),
                                    SizedBox(height: 2),
                                    SkeletonBox(width: 40, height: 10, radius: 5),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              // Фиксированная колонка скелетона
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0A000000),
                        offset: Offset(2, 0),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              right: BorderSide(color: Color(0xFFF0F0F0)),
                              bottom: BorderSide(color: Color(0xFFF5F5F5)),
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.calendar_today, color: Color(0xFF666666)),
                          ),
                        ),
                        ...skeletonRows.map((_) {
                          return Container(
                            width: 100,
                            height: 70,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                right: BorderSide(color: Color(0xFFF0F0F0)),
                                bottom: BorderSide(color: Color(0xFFF5F5F5)),
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SkeletonCircle(size: 36),
                                SizedBox(height: 4),
                                SkeletonBox(width: 80, height: 14, radius: 7),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}