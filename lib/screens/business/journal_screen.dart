import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import 'journal_sub_screen.dart';
import 'month_view_screen.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import 'list_view_screen.dart';
import 'create_booking_sheet.dart';
import 'booking_view_sheet.dart';
import '../../../services/notification_check_service.dart';
import 'manual_notification_sheet.dart';
import 'chat_screen.dart';



class JournalScreen extends StatefulWidget {
  final int projectId;
  const JournalScreen({super.key, required this.projectId});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  Map<String, dynamic>? _project;
  List<Map<String, dynamic>> _allProjects = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>>? _allEmployees;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _occupiedTime = [];
  List<Map<String, dynamic>> _monthDates = [];
  DateTime _selectedDate = DateTime.now();
  DateTime? _savedDate;
  String _view = 'day';
  bool _loading = true;
  bool _sidebarOpen = false;
  bool _showAllEmployees = true;
  final _dateScrollController = ScrollController();
  bool _datesLoading = false;

  final Set<String> _loadedMonths = {};
  bool _isLoadingMonth = false;
  static const int _datesThreshold = 30;

  bool _dataReady = false;
  bool _datesInitialized = false;

  bool _allOff = false;

  bool _showProjectsList = false;

  int _currentTabIndex = -1;
  bool get _isJournalActive => _currentTabIndex == -1;

  final _notificationService = NotificationCheckService();
  int _unansweredReviews = 0;
  Timer? _reviewsTimer;

  static const List<_NavItem> _navItems = [
    _NavItem(page: 'analytics', title: 'Аналитика', icon: 'assets/analytics.svg'),
    _NavItem(page: 'schedule', title: 'График работы', icon: 'assets/schedule.svg'),
    _NavItem(page: 'clients', title: 'Клиенты', icon: 'assets/people.svg'),
    _NavItem(page: 'reviews', title: 'Отзывы', icon: Icons.star_border, isMaterialIcon: true),
    _NavItem(page: 'profile', title: 'Профиль', icon: 'assets/salon.svg', category: 'НАСТРОЙКИ'),
    _NavItem(page: 'employees', title: 'Сотрудники', icon: 'assets/employees.svg', category: 'НАСТРОЙКИ'),
    _NavItem(page: 'services', title: 'Услуги', icon: 'assets/services.svg', category: 'НАСТРОЙКИ'),
    _NavItem(page: 'resources', title: 'Ресурсы', icon: 'assets/beauty-salon-chair.svg', category: 'НАСТРОЙКИ'),
    _NavItem(page: 'access', title: 'Доступ к проекту', icon: 'assets/access.svg', category: 'НАСТРОЙКИ'),
    _NavItem(page: 'online', title: 'Онлайн-запись', icon: 'assets/online.svg', category: 'НАСТРОЙКИ'),
    _NavItem(page: 'notifications', title: 'Уведомления', icon: 'assets/notifications.svg', category: 'НАСТРОЙКИ'),
    _NavItem(page: 'push_settings', title: 'Оповещения', icon: 'assets/checkmark-double.svg', category: 'СИСТЕМА'),
  ];

  void _toggleSidebar() {
    setState(() {
      _sidebarOpen = !_sidebarOpen;
      if (!_sidebarOpen) {
        _showProjectsList = false;
      }
    });
  }

  void _navigateTo(int index) {
    _savedDate = _selectedDate;
    setState(() {
      _sidebarOpen = false;
      _currentTabIndex = index;
    });
  }

  void _switchToJournal() {
    setState(() {
      _currentTabIndex = -1;
      if (_savedDate != null) {
        _selectedDate = _savedDate!;
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dateScrollController.hasClients && _monthDates.isNotEmpty) {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        final index = _monthDates.indexWhere((d) => d['date'] == dateStr);
        
        if (index >= 0) {
          final viewportWidth = _dateScrollController.position.viewportDimension;
          final targetOffset = (index * 69.0) - (viewportWidth / 2) + 32.5;
          
          _dateScrollController.jumpTo(
            targetOffset.clamp(0.0, _dateScrollController.position.maxScrollExtent)
          );
        }
      }
    });
  }

  void _loadAll() async {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _selectedDate = today;
    _savedDate = today;

    await Future.wait([
      _loadInitialDates(),
      _loadProject(),
    ]);

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }

    await Future.wait([
      _loadSchedule(),
      _loadRecords(),
      _loadOccupiedTime(),
    ]);

    if (mounted) {
      setState(() {
        _dataReady = true;
      });
    }
  }

  Future<void> _loadProject() async {
    try {
      final results = await Future.wait([
        ApiService.get(
            '/api/project-profile/get?project_id=${widget.projectId}'),
        ApiService.get('/api/project/list'),
      ]);
      if (mounted) {
        setState(() {
          _project = results[0]['success'] == true ? results[0]['data'] : null;
          _allProjects = results[1]['success'] == true
              ? List<Map<String, dynamic>>.from(results[1]['data'] ?? [])
              : [];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInitialDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDate = today;
    _savedDate = today;

    final monthsToLoad = <DateTime>[];
    monthsToLoad.add(DateTime(today.year, today.month, 1));
    monthsToLoad.add(DateTime(today.year, today.month - 1, 1));
    monthsToLoad.add(DateTime(today.year, today.month + 1, 1));
    monthsToLoad.add(DateTime(today.year, today.month - 2, 1));
    monthsToLoad.add(DateTime(today.year, today.month + 2, 1));

    await Future.wait(monthsToLoad.map((m) => _loadMonthDates(m.year, m.month)));

    _datesInitialized = true;

    // Ждем несколько кадров, чтобы ListView успел привязаться к контроллеру
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _dateScrollController.hasClients) {
            _scrollToToday();
          }
        });
      }
    });
  }

  Future<void> _loadSchedule() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final result = await ApiService.get(
          '/api/employee/schedule/list-for-date?project_id=${widget.projectId}&date=$dateStr');
      if (result['success'] == true && mounted) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _allEmployees = List.from(_employees);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecords() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final result = await ApiService.get(
          '/api/booking/list?project_id=${widget.projectId}&date=$dateStr&page=1&limit=100');
      if (result['success'] == true && mounted) {
        final filteredRecords = List<Map<String, dynamic>>.from(
                result['data'] ?? [])
            .where((r) => r['status'] != 'cancelled')
            .toList();

        final allOff = result['all_off'] == true;
        
        // Проверяем пагинацию
        final pagination = result['pagination'];
        if (pagination != null && pagination['total'] != null) {
          final total = pagination['total'] as int;
          final loaded = filteredRecords.length;
          
          if (total > loaded) {
            // Есть ещё записи — загружаем остальные страницы
            final totalPages = pagination['total_pages'] as int;
            final futures = <Future>[];
            
            for (int page = 2; page <= totalPages; page++) {
              futures.add(ApiService.get(
                  '/api/booking/list?project_id=${widget.projectId}&date=$dateStr&page=$page&limit=100'));
            }
            
            final results = await Future.wait(futures);
            
            for (final res in results) {
              if (res['success'] == true) {
                final moreRecords = List<Map<String, dynamic>>.from(
                        res['data'] ?? [])
                    .where((r) => r['status'] != 'cancelled')
                    .toList();
                filteredRecords.addAll(moreRecords);
              }
            }
          }
        }

        setState(() {
          _records = filteredRecords;
          _allOff = allOff;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadOccupiedTime() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final result = await ApiService.get(
          '/api/occupied-time/list?project_id=${widget.projectId}&date=$dateStr');
      if (result['success'] == true && mounted) {
        setState(() =>
            _occupiedTime = List<Map<String, dynamic>>.from(result['data'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadMonthDates(int year, int month) async {
    final monthKey = '$year-$month';
    
    print('🔍 _loadMonthDates called: $monthKey');
    print('   _loadedMonths: $_loadedMonths');
    print('   _isLoadingMonth: $_isLoadingMonth');
    
    if (_loadedMonths.contains(monthKey) || _isLoadingMonth) return;
    
    _isLoadingMonth = true;
    if (_datesInitialized && mounted) {
      setState(() => _datesLoading = true);
    }
    
    try {
      final result = await ApiService.get(
          '/api/booking/month-dates?project_id=${widget.projectId}&year=$year&month=$month');
      
      print('📡 API response for $monthKey:');
      print('   success: ${result['success']}');
      print('   dates count: ${(result['dates'] as List?)?.length ?? 0}');
      print('   dates: ${result['dates']}');
      
      if (result['success'] == true && mounted) {
        final newDates = List<Map<String, dynamic>>.from(result['dates'] ?? []);
        
        if (newDates.isNotEmpty) {
          final existingDates = <String>{};
          for (final d in _monthDates) {
            existingDates.add(d['date'] as String);
          }
          
          final uniqueNewDates = newDates
              .where((d) => !existingDates.contains(d['date']))
              .toList();
          
          print('   uniqueNewDates: ${uniqueNewDates.length}');
          
          if (uniqueNewDates.isNotEmpty) {
            final allDates = [..._monthDates, ...uniqueNewDates];
            allDates.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
            
            print('   Total _monthDates after add: ${allDates.length}');
            
            setState(() {
              _monthDates = allDates;
              _datesLoading = false;
            });
          }
        }
        
        _loadedMonths.add(monthKey);
      }
    } catch (e) {
      print('❌ Error loading dates for $monthKey: $e');
    } finally {
      _isLoadingMonth = false;
    }
  }

  void _checkAndLoadAdjacentDates() {
    if (!_dateScrollController.hasClients ||
        _isLoadingMonth ||
        !_datesInitialized) return;

    final offset = _dateScrollController.offset;
    final maxScroll = _dateScrollController.position.maxScrollExtent;
    final viewportWidth = _dateScrollController.position.viewportDimension;

    if (_monthDates.isEmpty) return;

    if (offset < _datesThreshold * 69.0) {
      final firstDateStr = _monthDates.first['date'] as String;
      final firstDate = DateTime.tryParse(firstDateStr);
      if (firstDate != null) {
        final prevMonth = DateTime(firstDate.year, firstDate.month - 1, 1);
        final monthKey = '${prevMonth.year}-${prevMonth.month}';
        if (!_loadedMonths.contains(monthKey)) {
          final oldLength = _monthDates.length;
          _loadMonthDates(prevMonth.year, prevMonth.month).then((_) {
            if (mounted && _dateScrollController.hasClients) {
              final newLength = _monthDates.length;
              final addedCount = newLength - oldLength;
              if (addedCount > 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_dateScrollController.hasClients) {
                    _dateScrollController
                        .jumpTo(offset + addedCount * 69.0);
                  }
                });
              }
            }
          });
        }
      }
    }

    if (offset + viewportWidth > maxScroll - _datesThreshold * 69.0) {
      final lastDateStr = _monthDates.last['date'] as String;
      final lastDate = DateTime.tryParse(lastDateStr);
      if (lastDate != null) {
        final nextMonth = DateTime(lastDate.year, lastDate.month + 1, 1);
        final monthKey = '${nextMonth.year}-${nextMonth.month}';
        if (!_loadedMonths.contains(monthKey)) {
          _loadMonthDates(nextMonth.year, nextMonth.month);
        }
      }
    }
  }

  void _scrollToToday() {
    if (!_dateScrollController.hasClients || _monthDates.isEmpty) return;

    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    final index = _monthDates.indexWhere((d) => d['date'] == todayStr);

    if (index >= 0) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!_dateScrollController.hasClients) return;

        final viewportWidth =
            _dateScrollController.position.viewportDimension;
        final targetOffset =
            (index * 69.0) - (viewportWidth / 2) + 32.5;

        _dateScrollController.jumpTo(targetOffset
            .clamp(0.0, _dateScrollController.position.maxScrollExtent));
      });
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToToday();
      });
    }
  }

  int _timeToMin(String time) {
    final parts = time.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 +
        (int.tryParse(parts[1]) ?? 0);
  }

  void _onDateSelected(DateTime date) {
    _savedDate = date;
    setState(() {
      _selectedDate = date;
      _dataReady = false;
    });

    Future.wait([
      _loadSchedule(),
      _loadRecords(),
      _loadOccupiedTime(),
    ]).then((_) {
      if (mounted) {
        setState(() => _dataReady = true);
      }
    });

    final hasDatesForMonth = _monthDates.any((d) {
      final dateObj = DateTime.tryParse(d['date'] ?? '');
      return dateObj != null &&
          dateObj.year == date.year &&
          dateObj.month == date.month;
    });

    if (!hasDatesForMonth) {
      _loadMonthDates(date.year, date.month);
    }
  }

  void _toggleEmployeesVisibility() {
    setState(() => _showAllEmployees = !_showAllEmployees);
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    if (_showAllEmployees) return _employees;
    return _employees
        .where((e) =>
            e['provides_services'] != false && e['is_working'] != false)
        .toList();
  }

  void _openCalendarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CalendarPicker(
        selectedDate: _selectedDate,
        onDateSelected: (date) {
          Navigator.pop(context);
          _onDateSelected(date);
        },
      ),
    );
  }

  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterEmployeeSheet(
        employees: _allEmployees ?? _employees,
        visibleIds: _employees.map((e) => e['id'] as int).toSet(),
        onApply: (visibleIds) {
          setState(() {
            if (_allEmployees == null) _allEmployees = List.from(_employees);
            _employees = _allEmployees!.where((e) => visibleIds.contains(e['id'])).toList();
            _showAllEmployees = visibleIds.length == _allEmployees!.length;
          });
          _dataReady = false;
          Future.wait([_loadRecords(), _loadOccupiedTime()]).then((_) {
            if (mounted) setState(() => _dataReady = true);
          });
        },
      ),
    );
  }

  void _onCellTap(int employeeId, String time) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreateBookingSheet(
        projectId: widget.projectId,
        employeeId: employeeId,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        startTime: time,
      ),
    ).then((result) {
      if (result == true) {
        _loadRecords();
        _loadOccupiedTime();
      }
    });
  }

  void _onRecordTap(int recordId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BookingViewSheet(
        bookingId: recordId,
        onSaved: () {
          _loadRecords();
          _loadOccupiedTime();
        },
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return const Color(0xFFDD1847);
  }

  Widget _buildSvgIcon(String assetName, {double size = 24, Color? color}) {
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
      placeholderBuilder: (context) => Icon(
        Icons.circle,
        size: size,
        color: color ?? const Color(0xFF666666),
      ),
    );
  }

  void _loadUnansweredReviews() async {
    try {
      final result = await ApiService.get(
          '/api/review/unanswered-count?project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        setState(() => _unansweredReviews = result['count'] ?? 0);
      }
    } catch (_) {}
  }

    @override
void initState() {
    super.initState();
    _selectedDate = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _loadAll();
    _dateScrollController.addListener(_checkAndLoadAdjacentDates);
    _loadUnansweredReviews();
    _reviewsTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _loadUnansweredReviews());
    
    _notificationService.updateContext(context, widget.projectId);
    _notificationService.startPeriodicCheck();
    
    // Мгновенная проверка при открытии журнала
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationService.checkForNewNotifications();
    });
  }

    @override
  void dispose() {
    _dateScrollController.removeListener(_checkAndLoadAdjacentDates);
    _dateScrollController.dispose();
    _reviewsTimer?.cancel();
    _notificationService.stopPeriodicCheck();
    super.dispose();
  }

  Widget _buildHeader() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: SafeArea(
        bottom: false,
        child: Container(
          color: Colors.white,
          height: 56,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: _toggleSidebar,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 0),
                    child: Text(
                      _project?['name'] ?? 'Журнал',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: _buildSvgIcon('assets/chat.svg',
                    size: 24, color: const Color(0xFF1A1A1A)),
                onPressed: () {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(projectId: widget.projectId)));
},
              ),
              GestureDetector(
                onTap: _switchToJournal,
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isJournalActive
                        ? const Color(0xFFDD1847)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _buildSvgIcon(
                    'assets/calendar.svg',
                    size: 24,
                    color: _isJournalActive ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Если активна одна из вкладок меню
    if (_currentTabIndex >= 0 && _currentTabIndex < _navItems.length) {
      final item = _navItems[_currentTabIndex];
      return JournalSubScreen(
        projectId: widget.projectId,
        page: item.page,
        title: item.title,
      );
    }

    // Иначе показываем журнал
    if (_loading && _project == null && _monthDates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SkeletonCircle(size: 60),
            const SizedBox(height: 16),
            const SkeletonBox(height: 14, width: 160),
            const SizedBox(height: 8),
            const SkeletonBox(height: 12, width: 120),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: const Color(0xFFF5F5F5),
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      _tabBtn('День', 'day'),
                      _tabBtn('Месяц', 'month'),
                      _tabBtn('Список', 'list'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _openFilterModal,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _buildSvgIcon('assets/slider.svg', size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_view == 'day') _buildDateStrip(),

        if (_view == 'day')
          Container(
            color: const Color(0xFFF5F5F5),
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Center(
              child: Text(
                DateFormat('d MMMM yyyy', 'ru').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),

        Expanded(
          child: Container(
            color: Colors.white,
            child: _view == 'day'
                ? RepaintBoundary(child: _buildDayView())
                : (_view == 'month'
                    ? _buildMonthView()
                    : _buildListView()),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),

          if (_sidebarOpen)
            GestureDetector(
              onTap: _toggleSidebar,
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            left: _sidebarOpen ? 0 : -280,
            child: Container(
              width: 280,
              color: Colors.white,
              child: SafeArea(
                child: _buildSidebar(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    // Группируем пункты по категориям
    final mainItems = _navItems.where((item) => item.category == null).toList();
    final settingsItems = _navItems.where((item) => item.category == 'НАСТРОЙКИ').toList();
    final systemItems = _navItems.where((item) => item.category == 'СИСТЕМА').toList();

    return Column(
      children: [
        // Проект
        GestureDetector(
          onTap: () {
            setState(() {
              _showProjectsList = !_showProjectsList;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF0F0F0)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedAvatar(
                    url: _project?['profile_photo'],
                    size: 28,
                    radius: 6,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _project?['name'] ?? 'Проект',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (_project?['address_raw'] != null)
                        Text(
                          _project!['address_raw'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888888),
                          ),
                        ),
                      Text(
                        'ID: ${widget.projectId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _showProjectsList ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Список проектов
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _showProjectsList
              ? (_allProjects.length * 80.0).clamp(0.0, 300.0)
              : 0.0,
          child: _showProjectsList
              ? ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _allProjects.length,
                  itemBuilder: (_, i) {
                    final p = _allProjects[i];
                    final isActive = p['id'] == widget.projectId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFFDF2F5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JournalScreen(
                                  projectId: p['id'],
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedAvatar(
                                    url: p['profile_photo'],
                                    size: 32,
                                    radius: 6,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (p['address_raw'] != null)
                                        Text(
                                          p['address_raw']!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF888888),
                                          ),
                                        ),
                                      Text(
                                        'ID: ${p['id']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive)
                                  const Icon(
                                    Icons.check,
                                    color: Color(0xFFDD1847),
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : const SizedBox.shrink(),
        ),

        const Divider(height: 1),

        // Динамическое меню с категориями
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Основные пункты
              ...mainItems.asMap().entries.map((entry) {
                final index = _navItems.indexOf(entry.value);
                return _sidebarMenuItem(index);
              }),

              // Разделитель и категория НАСТРОЙКИ
              if (settingsItems.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'НАСТРОЙКИ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF999999),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...settingsItems.asMap().entries.map((entry) {
                  final index = _navItems.indexOf(entry.value);
                  return _sidebarMenuItem(index);
                }),
              ],

              // Разделитель и категория СИСТЕМА
              if (systemItems.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'СИСТЕМА',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF999999),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...systemItems.asMap().entries.map((entry) {
                  final index = _navItems.indexOf(entry.value);
                  return _sidebarMenuItem(index);
                }),
              ],

              // Выход
              _buildLogoutItem(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebarMenuItem(int index) {
    final item = _navItems[index];
    final isActive = _currentTabIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateTo(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFDD1847)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Row(
            children: [
              if (item.isMaterialIcon)
                Icon(
                  item.icon as IconData,
                  size: 20,
                  color: isActive ? Colors.white : const Color(0xFF1A1A1A),
                )
              else
                _buildSvgIcon(
                  item.icon as String,
                  size: 20,
                  color: isActive ? Colors.white : const Color(0xFF1A1A1A),
                ),
              const SizedBox(width: 12),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              if (item.page == 'reviews' && _unansweredReviews > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : const Color(0xFFDD1847),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_unansweredReviews',
                    style: TextStyle(
                      color: isActive ? const Color(0xFFDD1847) : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutItem() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pushReplacementNamed(context, '/business');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildSvgIcon('assets/logout.svg',
                  size: 20, color: const Color(0xFF1A1A1A)),
              const SizedBox(width: 12),
              const Text(
                'Выйти',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String label, String view) {
    final active = _view == view;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _view = view);
          if (view == 'day') {
            _loadSchedule();
            _loadRecords();
            _loadOccupiedTime();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFDD1847) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateStrip() {
    final today = DateTime.now();
    final months = [
      '',
      'янв.',
      'фев.',
      'мар.',
      'апр.',
      'мая',
      'июн.',
      'июл.',
      'авг.',
      'сен.',
      'окт.',
      'ноя.',
      'дек.'
    ];
    final days = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return Container(
      color: Colors.white,
      height: 72,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.calendar_today,
                size: 20, color: Color(0xFF666666)),
            onPressed: () => _openCalendarPicker(),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  key: const PageStorageKey('date_carousel'),
                  controller: _dateScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: _monthDates.length,
                  itemBuilder: (_, i) {
                    final d = _monthDates[i];
                    final date =
                        DateTime.tryParse(d['date'] ?? '') ?? DateTime.now();
                    return _dateItem(date, today, months, days,
                        hasRecords: d['hasRecords'] == true);
                  },
                ),
                if (_datesLoading)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFDD1847),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateItem(DateTime date, DateTime today, List<String> months,
      List<String> days,
      {bool hasRecords = false}) {
    final isSelected = date.day == _selectedDate.day &&
        date.month == _selectedDate.month &&
        date.year == _selectedDate.year;
    final isToday = date.day == today.day &&
        date.month == today.month &&
        date.year == today.year;
    final isWeekend = date.weekday == 6 || date.weekday == 7;

    return GestureDetector(
      onTap: () => _onDateSelected(date),
      child: Container(
        width: 65,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFDD1847)
              : (isToday ? const Color(0xFFFDF2F5) : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: const Color(0xFFDD1847).withOpacity(0.5))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day} ${days[date.weekday]}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isWeekend ? const Color(0xFFDD1847) : Colors.black),
              ),
            ),
            Text(
              months[date.month],
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : Colors.grey,
              ),
            ),
            if (hasRecords)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.white : const Color(0xFFDD1847),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoOneWorks() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Никто не работает',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Выберите другой день или измените график работы.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD1847),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () {
                _navigateTo(1);
              },
              child: const Text(
                'Изменить график работы',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayView() {
    if (!_dataReady) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonCircle(size: 48),
            SizedBox(height: 16),
            SkeletonBox(height: 14, width: 180),
            SizedBox(height: 8),
            SkeletonBox(height: 12, width: 140),
          ],
        ),
      );
    }

    if (_allOff) {
      return _buildNoOneWorks();
    }

    final displayEmployees = _filteredEmployees;

    if (displayEmployees.isEmpty) {
      return _buildNoOneWorks();
    }

    final hasWorkingEmployees = displayEmployees.any((e) {
      if (e['is_working'] == false) return true;
      final empRecords =
          _records.where((r) => r['employee_id'] == e['id']).toList();
      if (empRecords.isNotEmpty) return true;
      final empOccupied =
          _occupiedTime.where((o) => o['employee_id'] == e['id']).toList();
      if (empOccupied.isNotEmpty) return true;
      return e['is_working'] == true;
    });

    if (!hasWorkingEmployees) {
      return _buildNoOneWorks();
    }

    int minStart = 24 * 60;
    int maxEnd = 0;
    for (final e in displayEmployees) {
      if (e['is_working'] == false) continue;
      final s = _timeToMin(e['work_start'] ?? '09:00');
      final en = _timeToMin(e['work_end'] ?? '18:00');
      if (s < minStart) minStart = s;
      if (en > maxEnd) maxEnd = en;
    }
    if (minStart >= maxEnd) {
      minStart = 0;
      maxEnd = 24 * 60;
    }
    minStart = (minStart ~/ 30) * 30;
    maxEnd = ((maxEnd + 29) ~/ 30) * 30;
    final totalSlots = ((maxEnd - minStart) / 30).ceil();

    const double rowHeight = 36.0;
    const int slotInterval = 30;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final empCount = displayEmployees.length;
        final colWidth = empCount <= 2
            ? (screenWidth - 48) / empCount
            : (screenWidth - 48) / 2;

        return Column(
          children: [
            SizedBox(
              height: 80,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    decoration: const BoxDecoration(
                      border: Border(
                          right: BorderSide(color: Color(0xFFE0E0E0))),
                    ),
                    child: Center(
                      child: GestureDetector(
                        onTap: _toggleEmployeesVisibility,
                        child: _buildSvgIcon(
                          _showAllEmployees
                              ? 'assets/eye.svg'
                              : 'assets/eye-slash.svg',
                          size: 20,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: empCount > 2
                          ? const AlwaysScrollableScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: displayEmployees.asMap().entries.map((entry) {
                          final index = entry.key;
                          final e = entry.value;
                          final isWorking = e['is_working'] != false;
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: index > 0
                                    ? const BorderSide(
                                        color: Color(0xFFE0E0E0))
                                    : BorderSide.none,
                              ),
                            ),
                            child: SizedBox(
                              width: colWidth - 1,
                              child: Opacity(
                                opacity: isWorking ? 1.0 : 0.5,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey[200],
                                      ),
                                      child: Center(
                                        child: CachedAvatar(
                                          url: e['avatar'],
                                          size: 36,
                                          radius: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: Text(
                                        e['name'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      decoration: const BoxDecoration(
                        border: Border(
                            right: BorderSide(color: Color(0xFFE0E0E0))),
                      ),
                      child: Column(
                        children: List.generate(totalSlots, (i) {
                          final m = minStart + i * slotInterval;
                          final hour = m ~/ 60;
                          final min = m % 60;
                          final isHour = min == 0;
                          final isHalf = min == 30;
                          return SizedBox(
                            height: rowHeight,
                            child: Stack(
                              children: [
                                if (isHour)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      height: 2,
                                      color: const Color(0xFFD0D0D0),
                                    ),
                                  ),
                                if (isHalf)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 0,
                                    child: CustomPaint(
                                      size: Size(double.infinity, 0.5),
                                      painter: _DashedLinePainter(
                                        color: const Color(0xFFE0E0E0),
                                        strokeWidth: 1.0,
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        right: 6, top: 2),
                                    child: Text(
                                      isHour
                                          ? '${hour.toString().padLeft(2, '0')}:00'
                                          : (isHalf
                                              ? '${hour.toString().padLeft(2, '0')}:30'
                                              : ''),
                                      style: TextStyle(
                                        fontSize:
                                            isHour ? 13 : (isHalf ? 10 : 9),
                                        fontWeight: isHour
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: isHour
                                            ? const Color(0xFF666666)
                                            : (isHalf
                                                ? const Color(0xFFBBBBBB)
                                                : Colors.transparent),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: empCount > 2
                            ? const AlwaysScrollableScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              displayEmployees.asMap().entries.map((entry) {
                            final index = entry.key;
                            final e = entry.value;
                            final empRecords = _records
                                .where((r) => r['employee_id'] == e['id'])
                                .toList();
                            final empOccupied = _occupiedTime
                                .where((o) => o['employee_id'] == e['id'])
                                .toList();
                            final isWorking = e['is_working'] != false;
                            final workStart =
                                _timeToMin(e['work_start'] ?? '09:00');
                            final workEnd =
                                _timeToMin(e['work_end'] ?? '18:00');

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: index > 0
                                      ? const BorderSide(
                                          color: Color(0xFFE0E0E0))
                                      : BorderSide.none,
                                ),
                              ),
                              child: ClipRect(
                                child: SizedBox(
                                  width: colWidth - 1,
                                  height: totalSlots * rowHeight,
                                  child: Stack(
                                    clipBehavior: Clip.hardEdge,
                                    children: [
                                      ...List.generate(totalSlots, (i) {
                                        final totalMin =
                                            minStart + i * slotInterval;
                                        final isInWorkHours = isWorking &&
                                            totalMin >= workStart &&
                                            totalMin < workEnd;
                                        
                                        final hour = totalMin ~/ 60;
                                        final minute = totalMin % 60;
                                        final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                                        
                                        if (isInWorkHours) {
                                          return Positioned(
                                            top: i * rowHeight,
                                            left: 0,
                                            right: 0,
                                            height: rowHeight,
                                            child: GestureDetector(
                                              onTap: () {
                                                _onCellTap(e['id'] as int, timeStr);
                                              },
                                              child: Container(
                                                color: Colors.transparent,
                                              ),
                                            ),
                                          );
                                        }
                                        
                                        return Positioned(
                                          top: i * rowHeight,
                                          left: 0,
                                          right: 0,
                                          height: rowHeight,
                                          child: CustomPaint(
                                            painter: _StripePainter(),
                                          ),
                                        );
                                      }),
                                      ...List.generate(totalSlots, (i) {
                                        final m = minStart + i * slotInterval;
                                        final min = m % 60;
                                        if (min != 0)
                                          return const SizedBox.shrink();
                                        return Positioned(
                                          top: i * rowHeight,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 2,
                                            color: const Color(0xFFD0D0D0),
                                          ),
                                        );
                                      }),
                                      ...List.generate(totalSlots, (i) {
                                        final m = minStart + i * slotInterval;
                                        final min = m % 60;
                                        if (min != 30)
                                          return const SizedBox.shrink();
                                        return Positioned(
                                          top: i * rowHeight,
                                          left: 0,
                                          right: 0,
                                          child: CustomPaint(
                                            size: Size(colWidth, 0.5),
                                            painter: _DashedLinePainter(
                                              color:
                                                  const Color(0xFFE0E0E0),
                                              strokeWidth: 1.0,
                                            ),
                                          ),
                                        );
                                      }),
                                      ...empOccupied.map((o) {
                                        final startTime =
                                            (o['start_time'] as String)
                                                .substring(0, 5);
                                        final endTime =
                                            (o['end_time'] as String)
                                                .substring(0, 5);
                                        var itemStart =
                                            _timeToMin(startTime);
                                        var itemEnd = _timeToMin(endTime);
                                        if (itemEnd <= workStart ||
                                            itemStart >= workEnd)
                                          return const SizedBox.shrink();
                                        if (itemStart < workStart)
                                          itemStart = workStart;
                                        if (itemEnd > workEnd)
                                          itemEnd = workEnd;
                                        if (itemEnd <= minStart ||
                                            itemStart >= maxEnd)
                                          return const SizedBox.shrink();
                                        if (itemStart < minStart)
                                          itemStart = minStart;
                                        if (itemEnd > maxEnd)
                                          itemEnd = maxEnd;
                                        final top =
                                            ((itemStart - minStart) /
                                                    slotInterval) *
                                                rowHeight;
                                        final height =
                                            ((itemEnd - itemStart) /
                                                    slotInterval) *
                                                rowHeight;
                                        final color = _parseColor(
                                            o['color'] as String? ??
                                                '#DD1847');
                                        final comment =
                                            o['comment'] as String? ?? '';
                                        final durationMin =
                                            itemEnd - itemStart;
                                        final hours = durationMin ~/ 60;
                                        final mins = durationMin % 60;
                                        final durationText = hours > 0
                                            ? '$hours ч ${mins > 0 ? '$mins мин' : ''}'
                                            : '$mins мин';
                                        return Positioned(
                                          top: top + 2,
                                          left: 4,
                                          right: 4,
                                          height: height - 4,
                                          child: GestureDetector(
                                            onTap: () {},
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    color.withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      8, 6, 8, 0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$startTime–$endTime · $durationText',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.black
                                                          .withOpacity(0.8),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (comment.isNotEmpty)
                                                    Text(
                                                      comment,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: Colors.black
                                                            .withOpacity(0.6),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      ...empRecords.map((r) {
                                        final startTime =
                                            (r['start_time'] as String)
                                                .substring(0, 5);
                                        final endTime =
                                            (r['end_time'] as String)
                                                .substring(0, 5);
                                        final recordStartMin =
                                            _timeToMin(startTime);
                                        final recordEndMin =
                                            _timeToMin(endTime);
                                        final top =
                                            ((recordStartMin - minStart) /
                                                    slotInterval) *
                                                rowHeight;
                                        final height =
                                            ((recordEndMin - recordStartMin) /
                                                    slotInterval) *
                                                rowHeight;
                                        final services =
                                            r['services'] as List?;
                                        final recordColor =
                                            r['color'] != null
                                                ? _parseColor(
                                                    r['color'] as String)
                                                : const Color(0xFFDD1847);
                                        return Positioned(
                                          top: top,
                                          left: 4,
                                          right: 4,
                                          height: height.clamp(30, 500),
                                          child: GestureDetector(
                                            onTap: () => _onRecordTap(r['id'] as int),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    recordColor,
                                                    recordColor
                                                        .withOpacity(0.8)
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: recordColor
                                                        .withOpacity(0.3),
                                                    blurRadius: 4,
                                                    offset:
                                                        const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              padding: const EdgeInsets.all(6),
                                              child: Stack(
                                                children: [
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        '$startTime – $endTime',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        r['client_name'] ?? '',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      if (r['client_phone'] !=
                                                          null)
                                                        Text(
                                                          r['client_phone']!,
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 9),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      if (services != null &&
                                                          services.isNotEmpty)
                                                        Text(
                                                          services
                                                              .map((s) =>
                                                                  s['name'])
                                                              .join(', '),
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 9),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                  if (r['client_visits'] !=
                                                          null &&
                                                      (r['client_visits']
                                                              as int) <=
                                                          2)
                                                    Positioned(
                                                      top: 0,
                                                      right: 0,
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                              0xFF4CAF50),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: const Text(
                                                          'Новый',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white,
                                                              fontSize: 9,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthView() => MonthViewScreen(projectId: widget.projectId);

  Widget _buildListView() => ListViewScreen(
  projectId: widget.projectId,
  onRecordTap: _onRecordTap,
);
}

class _NavItem {
  final String page;
  final String title;
  final dynamic icon;
  final bool isMaterialIcon;
  final String? category;

  const _NavItem({
    required this.page,
    required this.title,
    required this.icon,
    this.isMaterialIcon = false,
    this.category,
  });
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DashedLinePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    const double dashWidth = 5.0;
    const double dashSpace = 3.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(
            startX + dashWidth > size.width ? size.width : startX + dashWidth,
            0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1A000000)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final step = 6.0;
    for (double x = -size.height; x < size.width; x += step) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + size.height, size.height)
        ..lineTo(x + size.height - 1.5, size.height)
        ..lineTo(x - 1.5, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CalendarPicker extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _CalendarPicker({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<_CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<_CalendarPicker> {
  late DateTime _selected;
  final _scrollController = ScrollController();
  final _months = <DateTime>[];
  String _headerText = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedDate;
    _generateMonths();
    _updateHeader(_selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
      _scrollController.addListener(_onScroll);
    });
  }

  void _generateMonths() {
    _months.clear();
    final now = DateTime(_selected.year, _selected.month);
    for (int i = -6; i <= 6; i++) {
      _months.add(DateTime(now.year, now.month + i));
    }
  }

  void _scrollToSelected() {
    final index = _months.indexWhere(
        (m) => m.year == _selected.year && m.month == _selected.month);
    if (index >= 0 && _scrollController.hasClients) {
      _scrollController.jumpTo(index * 360.0);
    }
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final index = (offset / 360).round();
    if (index >= 0 && index < _months.length) {
      _updateHeader(_months[index]);
    }
    if (offset < 400) {
      _months.insert(0, DateTime(_months.first.year, _months.first.month - 1));
      _scrollController.jumpTo(offset + 360);
    }
    if (offset > (_months.length - 3) * 360) {
      _months.add(DateTime(_months.last.year, _months.last.month + 1));
    }
  }

  void _updateHeader(DateTime month) {
    final m = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь'
    ];
    setState(() => _headerText = '${m[month.month - 1]} ${month.year}');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь'
    ];
    final today = DateTime.now();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(_headerText,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: d == 'Сб' || d == 'Вс'
                              ? const Color(0xFFDD1847)
                              : Colors.grey,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _months.length,
              itemExtent: 360,
              itemBuilder: (_, mi) {
                final mt = _months[mi];
                final dim = DateTime(mt.year, mt.month + 1, 0).day;
                final fd = DateTime(mt.year, mt.month, 1);
                final so = fd.weekday - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${m[mt.month - 1]} ${mt.year}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7),
                        itemCount: so + dim,
                        itemBuilder: (_, i) {
                          if (i < so) return const SizedBox.shrink();
                          final day = i - so + 1;
                          final date = DateTime(mt.year, mt.month, day);
                          final sel = date.day == _selected.day &&
                              date.month == _selected.month &&
                              date.year == _selected.year;
                          final it = date.day == today.day &&
                              date.month == today.month &&
                              date.year == today.year;
                          final we = date.weekday == 6 || date.weekday == 7;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selected = date);
                              widget.onDateSelected(date);
                            },
                            child: Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: sel
                                    ? const Color(0xFFDD1847)
                                    : (it
                                        ? const Color(0xFFFDF2F5)
                                        : Colors.transparent),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: it || sel
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: sel
                                      ? Colors.white
                                      : (we
                                          ? const Color(0xFFDD1847)
                                          : Colors.black),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ФИЛЬТР СОТРУДНИКОВ ====================
class _FilterEmployeeSheet extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final Set<int> visibleIds;
  final Function(Set<int>) onApply;
  const _FilterEmployeeSheet({required this.employees, required this.visibleIds, required this.onApply});

  @override
  State<_FilterEmployeeSheet> createState() => _FilterEmployeeSheetState();
}

class _FilterEmployeeSheetState extends State<_FilterEmployeeSheet> {
  late Set<int> _selected;
  bool _allSelected = true;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.visibleIds);
    _allSelected = _selected.length == widget.employees.length;
  }

  void _toggleAll() {
    setState(() {
      _allSelected = !_allSelected;
      if (_allSelected) {
        _selected = widget.employees.map((e) => e['id'] as int).toSet();
      } else {
        _selected.clear();
      }
    });
  }

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      _allSelected = _selected.length == widget.employees.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Spacer(),
                const Text('Фильтр сотрудников', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selected.clear();
                        _allSelected = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF666666),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Сбросить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_selected);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD1847),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: Icon(
                    _allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: _allSelected ? const Color(0xFFDD1847) : Colors.grey,
                  ),
                  title: const Text('Все сотрудники', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: _toggleAll,
                ),
                ...widget.employees.map((e) {
                  final id = e['id'] as int;
                  final sel = _selected.contains(id);
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: e['avatar'] != null
                          ? NetworkImage('https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai${e['avatar']}')
                          : null,
                      child: e['avatar'] == null ? Text((e['name'] ?? '?')[0]) : null,
                    ),
                    title: Text(e['name'] ?? '', style: const TextStyle(fontSize: 14)),
                    trailing: Icon(
                      sel ? Icons.check_box : Icons.check_box_outline_blank,
                      color: sel ? const Color(0xFFDD1847) : Colors.grey,
                    ),
                    onTap: () => _toggle(id),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}