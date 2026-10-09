// lib/screens/client/booking/booking_fullscreen_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import 'datetime_selection_screen.dart';
import 'steps/booking_start_step.dart';
import 'steps/booking_services_step.dart';
import 'steps/booking_masters_step.dart';
import 'steps/booking_master_services_step.dart';
import 'steps/booking_contact_step.dart';
import 'steps/booking_confirm_step.dart';
import 'steps/booking_success_step.dart';
import '../../../core/app_logger.dart';

class BookingFullscreenScreen extends StatefulWidget {
  final int projectId;
  final int? masterId;
  final Color primaryColor;
  final Color buttonBg;
  final Color buttonText;
  final String specialistLabel;
  final String serviceLabel;
  final String serviceLabelAccusative;
  final String specialistLabelAccusative;
  final String serviceLabelGenitive;
  final String specialistLabelGenitive;
  
  const BookingFullscreenScreen({
    super.key,
    required this.projectId,
    this.masterId,
    required this.primaryColor,
    required this.buttonBg,
    required this.buttonText,
    this.specialistLabel = 'Специалисты',
    this.serviceLabel = 'Услуги',
    this.serviceLabelAccusative = 'услугу',
    this.specialistLabelAccusative = 'специалиста',
    this.serviceLabelGenitive = 'услуг',
    this.specialistLabelGenitive = 'специалистов',
  });

  @override
  State<BookingFullscreenScreen> createState() => _BookingFullscreenScreenState();
}

class _BookingFullscreenScreenState extends State<BookingFullscreenScreen> {
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _employees = [];
  final List<Map<String, dynamic>> _employeeServiceLinks = [];
  final List<Map<String, dynamic>> _selectedServices = [];
  Map<String, dynamic>? _selectedMaster;
  final Map<int, int> _serviceMasters = {};
  DateTime? _selectedDate;
  String? _selectedTime;
  
  final _commentController = TextEditingController();
  final _promoController = TextEditingController();
  
  bool _agreeData = false;
  bool _agreeMarketing = true;
  
  bool _loading = false;
  bool _submitting = false;
  Map<String, dynamic>? _clientData;
  Map<String, dynamic>? _contactData;
  List<Map<String, dynamic>> _warnings = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
    _loadClientSession();
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  
  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    _commentController.dispose();
    _promoController.dispose();
    super.dispose();
  }
  
  Future<void> _loadClientSession() async {
    try {
      final result = await ApiService.get('/api/auth/check-session');
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _clientData = Map<String, dynamic>.from(result['data']);
        });
      }
    } catch (_) {}
  }
  
  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      final servicesResult = await ApiService.get('/api/service/list?project_id=${widget.projectId}&public=1');
      if (servicesResult['success'] == true) {
        _services = List<Map<String, dynamic>>.from(servicesResult['data'] ?? []);
      }
      
      final employeesResult = await ApiService.get('/api/employee/schedule/list-for-date?project_id=${widget.projectId}&date=${DateTime.now().toIso8601String().substring(0, 10)}');
      if (employeesResult['success'] == true) {
        _employees = List<Map<String, dynamic>>.from(employeesResult['data'] ?? []);
      }
      
      final linksResult = await ApiService.get('/api/employee/list?project_id=${widget.projectId}');
      if (linksResult['success'] == true) {
        final employees = List<Map<String, dynamic>>.from(linksResult['data'] ?? []);
        for (final emp in employees) {
          final empId = (emp['id'] as num).toInt();
          final serviceIds = emp['service_ids'];
          if (serviceIds != null) {
            if (serviceIds is List) {
              for (final sid in serviceIds) {
                _employeeServiceLinks.add({'employee_id': empId, 'service_id': (sid as num).toInt()});
              }
            } else if (serviceIds is String && serviceIds.isNotEmpty) {
              for (final sid in serviceIds.split(',')) {
                final parsed = int.tryParse(sid.trim());
                if (parsed != null) {
                  _employeeServiceLinks.add({'employee_id': empId, 'service_id': parsed});
                }
              }
            }
          }
        }
      }
      
      final rulesResult = await ApiService.get('/api/project-profile/get-booking-rules?project_id=${widget.projectId}');
      if (rulesResult['success'] == true) {
        final rules = List<Map<String, dynamic>>.from(rulesResult['data'] ?? []);
        _warnings = rules.where((r) => r['type'] == 'warning').toList();
      }
      
      if (widget.masterId != null) {
        final master = _employees.where((e) => (e['id'] as num).toInt() == widget.masterId).firstOrNull;
        if (master != null) {
          _selectedMaster = master;
        }
      }
    } catch (e) {
      AppLogger.debug('Error loading booking data: $e');
    }
    
    setState(() => _loading = false);
  }
  
  int _getTotalPrice() {
    return _selectedServices.fold(0, (sum, s) => sum + ((s['price'] as num?)?.toInt() ?? 0));
  }
  
  int _getTotalDuration() {
    return _selectedServices.fold(0, (sum, s) => sum + ((s['duration'] as num?)?.toInt() ?? 0));
  }
  
  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    if (m > 0) return '$m мин';
    return '0 мин';
  }
  
  String _formatPrice(Map<String, dynamic> s) {
    final price = (s['price'] as num?)?.toInt() ?? 0;
    if (price == 0) return 'Бесплатно';
    final from = s['price_from'] == 1 || s['price_from'] == true;
    return '${from ? 'от ' : ''}$price ₽';
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: widget.primaryColor),
    );
  }
  
  // ЕДИНЫЙ МЕТОД НАВИГАЦИИ
  Future<void> _navigateTo(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
  
  Future<void> _goToServices() async {
    await _navigateTo(_buildServicesScreen());
  }
  
  Future<void> _goToMasters() async {
    await _navigateTo(_buildMastersScreen());
  }
  
  Future<void> _goToConfirm() async {
    _contactData = {
      'name': _clientData?['name']?.toString() ?? '',
      'lastName': '',
      'phone': _clientData?['phone']?.toString() ?? '',
      'email': _clientData?['email']?.toString() ?? '',
      'comment': _commentController.text.trim(),
      'promo': _promoController.text.trim(),
    };
    await _navigateTo(_buildConfirmScreen());
  }
  
  Future<void> _goToSuccess() async {
    await _navigateTo(_buildSuccessScreen());
  }
  
  Future<void> _goToDateTime() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DateTimeSelectionScreen(
          projectId: widget.projectId,
          selectedServices: _selectedServices,
          selectedMaster: _selectedMaster,
          serviceMasters: _serviceMasters,
          employees: _employees,
          primaryColor: widget.primaryColor,
          buttonBg: widget.buttonBg,
          buttonText: widget.buttonText,
          specialistLabel: widget.specialistLabel,
          serviceLabel: widget.serviceLabel,
          onDateTimeSelected: (date, time, masterId) async {
            setState(() {
              _selectedDate = date;
              _selectedTime = time;
              if (masterId != null) {
                final masterIdInt = masterId;
                for (final s in _selectedServices) {
                  _serviceMasters[(s['id'] as num).toInt()] = masterIdInt;
                }
                final master = _employees.where((e) => (e['id'] as num).toInt() == masterIdInt).firstOrNull;
                if (master != null) {
                  _selectedMaster = master;
                }
              }
            });
            // Заменяем текущий экран на контакты
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => _buildContactScreen()),
            );
          },
        ),
      ),
    );
  }
  
  Future<void> _submitBooking() async {
    setState(() => _submitting = true);
    
    try {
      final cd = _contactData ?? {};
      final date = _selectedDate != null 
          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
          : '';
      final startTime = _selectedTime != null ? '$_selectedTime:00' : '';
      
      final serviceIds = _selectedServices.map((s) => (s['id'] as num).toInt()).toList();
      
      final serviceMasters = <String, int>{};
      for (final s in _selectedServices) {
        final sid = (s['id'] as num).toInt();
        if (_serviceMasters.containsKey(sid)) {
          serviceMasters[sid.toString()] = _serviceMasters[sid]!;
        } else if (_selectedMaster != null) {
          serviceMasters[sid.toString()] = (_selectedMaster!['id'] as num).toInt();
        }
      }
      
      final result = await ApiService.createBooking(
        projectId: widget.projectId,
        date: date,
        startTime: startTime,
        serviceIds: serviceIds,
        employeeId: _selectedMaster != null ? (_selectedMaster!['id'] as num).toInt() : 0,
        clientName: cd['name'] ?? '',
        clientPhone: cd['phone'] ?? '',
      );
      
      if (result['success'] == true) {
        await _goToSuccess();
      } else {
        _showSnackBar(result['message'] ?? 'Ошибка при создании записи');
      }
    } catch (e) {
      _showSnackBar('Ошибка соединения с сервером');
    }
    
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return _buildStartScreen();
  }
  
  // Экраны (обёртки для шагов)
  Widget _buildStartScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader('Онлайн-запись'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : BookingStartStep(
                    serviceLabelAccusative: widget.serviceLabelAccusative,
                    specialistLabelAccusative: widget.specialistLabelAccusative,
                    serviceLabelGenitive: widget.serviceLabelGenitive,
                    specialistLabelGenitive: widget.specialistLabelGenitive,
                    primaryColor: widget.primaryColor,
                    onSelectServices: _goToServices,
                    onSelectMasters: _goToMasters,
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildServicesScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader('Выбор ${widget.serviceLabelGenitive}'),
          Expanded(
            child: BookingServicesStep(
              services: _services,
              selectedServices: _selectedServices,
              activeCategories: [],
              searchQuery: '',
              primaryColor: widget.primaryColor,
              serviceLabelGenitive: widget.serviceLabelGenitive,
              onToggleService: (s) => setState(() {
                final existing = _selectedServices.any((ss) => ss['id'] == s['id']);
                if (existing) {
                  _selectedServices.removeWhere((ss) => ss['id'] == s['id']);
                } else {
                  _selectedServices.add(s);
                }
              }),
              onSearchChanged: (v) {},
              onCategoryToggle: (c) {},
            ),
          ),
          _buildBottomBar(
            onPressed: _selectedServices.isEmpty ? null : _goToDateTime,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMastersScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader('Выбор ${widget.specialistLabelGenitive}'),
          Expanded(
            child: BookingMastersStep(
              employees: _employees,
              primaryColor: widget.primaryColor,
              specialistLabelGenitive: widget.specialistLabelGenitive,
              onSelectMaster: (master) async {
                setState(() => _selectedMaster = master);
                await _navigateTo(_buildMasterServicesScreen());
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMasterServicesScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader('Выбор ${widget.serviceLabelGenitive}'),
          Expanded(
            child: BookingMasterServicesStep(
              services: _services,
              selectedServices: _selectedServices,
              selectedMaster: _selectedMaster,
              employeeServiceLinks: _employeeServiceLinks,
              primaryColor: widget.primaryColor,
              onToggleService: (s) => setState(() {
                final existing = _selectedServices.any((ss) => ss['id'] == s['id']);
                if (existing) {
                  _selectedServices.removeWhere((ss) => ss['id'] == s['id']);
                } else {
                  _selectedServices.add(s);
                }
              }),
            ),
          ),
          _buildBottomBar(
            onPressed: _selectedServices.isEmpty ? null : _goToDateTime,
          ),
        ],
      ),
    );
  }
  
  Widget _buildContactScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader('Контактные данные'),
          Expanded(
            child: BookingContactStep(
              commentController: _commentController,
              promoController: _promoController,
              primaryColor: widget.primaryColor,
              inputDecoration: _inputDecoration,
            ),
          ),
          _buildBottomBar(
            onPressed: _goToConfirm,
          ),
        ],
      ),
    );
  }
  
  Widget _buildConfirmScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader('Подтверждение'),
          Expanded(
            child: BookingConfirmStep(
              contactData: _contactData,
              selectedServices: _selectedServices,
              selectedMaster: _selectedMaster,
              selectedDate: _selectedDate,
              selectedTime: _selectedTime,
              warnings: _warnings,
              agreeData: _agreeData,
              agreeMarketing: _agreeMarketing,
              submitting: _submitting,
              primaryColor: widget.primaryColor,
              buttonBg: widget.buttonBg,
              buttonText: widget.buttonText,
              onAgreeDataChanged: (v) => setState(() => _agreeData = v),
              onAgreeMarketingChanged: (v) => setState(() => _agreeMarketing = v),
              onSubmit: _submitBooking,
              formatPrice: _formatPrice,
              formatDuration: _formatDuration,
              getTotalPrice: _getTotalPrice,
              getTotalDuration: _getTotalDuration,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader('Запись создана'),
          Expanded(
            child: BookingSuccessStep(
              contactData: _contactData,
              selectedServices: _selectedServices,
              selectedMaster: _selectedMaster,
              selectedDate: _selectedDate,
              selectedTime: _selectedTime,
              primaryColor: widget.primaryColor,
              buttonBg: widget.buttonBg,
              buttonText: widget.buttonText,
              formatPrice: _formatPrice,
              formatDuration: _formatDuration,
              getTotalPrice: _getTotalPrice,
              getTotalDuration: _getTotalDuration,
              onDone: () => Navigator.popUntil(context, (route) => route.isFirst),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader(String title) {
    return Container(
      decoration: BoxDecoration(
        color: widget.primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: widget.primaryColor, width: 1.5),
      ),
    );
  }
  
  Widget _buildBottomBar({VoidCallback? onPressed}) {
    final totalPrice = _getTotalPrice();
    final totalDuration = _getTotalDuration();
    final serviceCount = _selectedServices.length;
    final serviceWord = serviceCount == 1 ? 'услуга' : (serviceCount >= 2 && serviceCount <= 4 ? 'услуги' : 'услуг');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$totalPrice ₽', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text('$serviceCount $serviceWord · ${_formatDuration(totalDuration)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: onPressed != null ? widget.buttonBg : Colors.grey[300],
                foregroundColor: widget.buttonText,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Продолжить', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}