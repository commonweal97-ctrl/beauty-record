// lib/screens/client/booking/booking_fullscreen_screen.dart
//
// Single-screen wizard для онлайн-записи (как на сайте book/page.php).
//
// Архитектура:
//   - Все шаги — в одном экране.
//   - Переключение через _stepHistory (стек).
//   - Никаких Navigator.push между шагами.
//   - При возврате назад — очистка данных последующих шагов (как bfsGoBack).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import 'steps/booking_start_step.dart';
import 'steps/booking_services_step.dart';
import 'steps/booking_masters_step.dart';
import 'steps/booking_master_services_step.dart';
import 'steps/booking_master_assignment_step.dart';
import 'steps/booking_contact_step.dart';
import 'steps/booking_confirm_step.dart';
import 'steps/booking_success_step.dart';
import 'datetime/datetime_step.dart';
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
  // ========== СТЕК НАВИГАЦИИ (как bfsStepHistory на сайте) ==========
  final List<String> _stepHistory = ['start'];

  String get _currentStep => _stepHistory.last;

  // ========== ДАННЫЕ ==========
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

  // ========== LIFECYCLE ==========
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

  // ========== НАВИГАЦИЯ (как bfsGoNext / bfsGoBack) ==========

  /// Перейти на новый шаг (push в стек).
  void _pushStep(String step) {
    if (_stepHistory.last == step) return; // уже там
    setState(() {
      _stepHistory.add(step);
    });
    AppLogger.debug('Booking step: $_stepHistory');
  }

  /// Вернуться на предыдущий шаг (pop + очистка как bfsGoBack).
  void _goBack() {
    if (_stepHistory.length <= 1) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _stepHistory.removeLast();
      final prev = _stepHistory.last;
      AppLogger.debug('Booking back to: $prev (history=$_stepHistory)');

      // Очистка данных в зависимости от того, на какой шаг вернулись
      // (аналогично bfsGoBack на сайте)
      switch (prev) {
        case 'start':
          _selectedMaster = null;
          _selectedServices.clear();
          _serviceMasters.clear();
          _selectedDate = null;
          _selectedTime = null;
          break;
        case 'services':
          _selectedMaster = null;
          _serviceMasters.clear();
          _selectedDate = null;
          _selectedTime = null;
          break;
        case 'masters':
          _serviceMasters.clear();
          _selectedDate = null;
          _selectedTime = null;
          break;
        case 'master-services':
          _selectedServices.clear();
          _serviceMasters.clear();
          _selectedDate = null;
          _selectedTime = null;
          break;
        case 'master-assignment':
          _serviceMasters.clear();
          _selectedDate = null;
          _selectedTime = null;
          break;
        case 'datetime':
          _selectedDate = null;
          _selectedTime = null;
          break;
        case 'contact':
        case 'confirm':
          // ничего не очищаем
          break;
      }
    });
  }

  // ========== ПЕРЕХОДЫ (как bfsGoTo*) ==========

  void _goToServices() => _pushStep('services');
  void _goToMasters() => _pushStep('masters');
  void _goToMasterServices() => _pushStep('master-services');
  void _goToMasterAssignment() => _pushStep('master-assignment');
  void _goToDateTime() => _pushStep('datetime');
  void _goToContact() => _pushStep('contact');
  void _goToConfirm() => _pushStep('confirm');
  void _goToSuccess() => _pushStep('success');

  /// Главная кнопка «Продолжить» на шаге услуг/мастеров.
  /// Логика как bfsGoNext на сайте:
  /// - Если мастер выбран → автоназначить на все услуги → datetime.
  /// - Если услуг 2+ → master-assignment.
  /// - Иначе → datetime.
  void _goNext() {
    if (_selectedServices.isEmpty) {
      _showSnackBar('Выберите хотя бы одну услугу');
      return;
    }

    if (_selectedMaster != null) {
      for (final s in _selectedServices) {
        _serviceMasters[(s['id'] as num).toInt()] = (_selectedMaster!['id'] as num).toInt();
      }
      _goToDateTime();
      return;
    }

    if (_selectedServices.length >= 2) {
      _goToMasterAssignment();
    } else {
      _goToDateTime();
    }
  }

  // ========== ЗАГРУЗКА ДАННЫХ ==========
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

  // ========== ХЕЛПЕРЫ ==========
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

  // ========== ГЛАВНЫЙ BUILD ==========
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: _stepHistory.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 'start':
        return _buildStartScreen();
      case 'services':
        return _buildServicesScreen();
      case 'masters':
        return _buildMastersScreen();
      case 'master-services':
        return _buildMasterServicesScreen();
      case 'master-assignment':
        return _buildMasterAssignmentScreen();
      case 'datetime':
        return _buildDateTimeScreen();
      case 'contact':
        return _buildContactScreen();
      case 'confirm':
        return _buildConfirmScreen();
      case 'success':
        return _buildSuccessScreen();
      default:
        return _buildStartScreen();
    }
  }

  // ========== ЭКРАНЫ ШАГОВ ==========

  Widget _buildStartScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader('Онлайн-запись'),
          Expanded(
            child: BookingStartStep(
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
            onPressed: _selectedServices.isEmpty ? null : _goNext,
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
              onSelectMaster: (master) {
                setState(() => _selectedMaster = master);
                _goToMasterServices();
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
            onPressed: _selectedServices.isEmpty ? null : _goNext,
          ),
        ],
      ),
    );
  }

  Widget _buildMasterAssignmentScreen() {
    // Все услуги назначены?
    final allAssigned = _selectedServices.every((s) {
      final sid = (s['id'] as num).toInt();
      return _serviceMasters.containsKey(sid);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader('Назначение ${widget.specialistLabelGenitive}'),
          Expanded(
            child: BookingMasterAssignmentStep(
              services: _selectedServices,
              employees: _employees,
              employeeServiceLinks: _employeeServiceLinks,
              serviceMasters: _serviceMasters,
              primaryColor: widget.primaryColor,
              specialistLabel: widget.specialistLabel,
              onAssign: (serviceId, masterId) {
                setState(() {
                  _serviceMasters[serviceId] = masterId;
                  // Также обновляем _selectedMaster для совместимости с datetime
                  final master = _employees
                      .where((e) => (e['id'] as num).toInt() == masterId)
                      .firstOrNull;
                  if (master != null) _selectedMaster = master;
                });
              },
            ),
          ),
          _buildBottomBar(
            onPressed: allAssigned ? _goToDateTime : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeScreen() {
    return DateTimeStep(
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
      onBack: _goBack,
      onSelected: (date, time, masterId) {
        setState(() {
          _selectedDate = date;
          _selectedTime = time;
          if (masterId != null) {
            for (final s in _selectedServices) {
              _serviceMasters[(s['id'] as num).toInt()] = masterId;
            }
            final master = _employees
                .where((e) => (e['id'] as num).toInt() == masterId)
                .firstOrNull;
            if (master != null) _selectedMaster = master;
          }
        });
        // Дальше как bfsConfirmBooking:
        // если залогинен → confirm, иначе → contact
        if (_clientData != null && _clientData!['email'] != null && (_clientData!['email'] as String).isNotEmpty) {
          _contactData = {
            'name': _clientData?['name']?.toString() ?? '',
            'lastName': '',
            'phone': _clientData?['phone']?.toString() ?? '',
            'email': _clientData?['email']?.toString() ?? '',
            'comment': '',
            'promo': '',
          };
          _goToConfirm();
        } else {
          _goToContact();
        }
      },
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
            onPressed: () {
              _contactData = {
                'name': _clientData?['name']?.toString() ?? '',
                'lastName': '',
                'phone': _clientData?['phone']?.toString() ?? '',
                'email': _clientData?['email']?.toString() ?? '',
                'comment': _commentController.text.trim(),
                'promo': _promoController.text.trim(),
              };
              _goToConfirm();
            },
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

  // ========== ОБЩИЕ ЭЛЕМЕНТЫ ==========

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
                onTap: _goBack,
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

  // ========== SUBMIT ==========
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
        _goToSuccess();
      } else {
        _showSnackBar(result['message'] ?? 'Ошибка при создании записи');
      }
    } catch (e) {
      _showSnackBar('Ошибка соединения с сервером');
    }

    setState(() => _submitting = false);
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
