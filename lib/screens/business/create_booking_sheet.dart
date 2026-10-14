import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';
import '../../../widgets/common/avatar_initials.dart';
import '../../../utils/phone_display.dart';

class CreateBookingSheet extends StatefulWidget {
  final int projectId;
  final int employeeId;
  final String date;
  final String startTime;
  final String? employeeName;
  final String? employeeAvatar;
  final List<Map<String, dynamic>> existingRecords;
  final List<Map<String, dynamic>> occupiedSlots;
  
  const CreateBookingSheet({
    super.key,
    required this.projectId,
    required this.employeeId,
    required this.date,
    required this.startTime,
    this.employeeName,
    this.employeeAvatar,
    this.existingRecords = const [],
    this.occupiedSlots = const [],
  });

  @override
  State<CreateBookingSheet> createState() => _CreateBookingSheetState();
}

class _CreateBookingSheetState extends State<CreateBookingSheet> {
  int _step = 1;
  String _mode = 'booking';
  String _selectedTime = '09:00';
  final Set<int> _selectedServices = {};
  int? _selectedClient;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _clients = [];
  bool _loadingServices = true;
  bool _loadingClients = false;
  final _searchServicesCtrl = TextEditingController();
  final _searchClientsCtrl = TextEditingController();
  String _servicesQuery = '';
  String _clientsQuery = '';

  // Поля для occupy-режима
  int _occupyDuration = 60;
  String _occupyColor = '#9E9E9E';
  final _occupyCommentCtrl = TextEditingController();
  final _occupyColors = ['#9E9E9E', '#F44336', '#FF9800', '#FFEB3B', '#4CAF50', '#2196F3', '#9C27B0'];

  // Персональные цены сотрудника
  Map<int, Map<String, dynamic>> _employeePrices = {};
  // ignore: unused_field
  bool _loadingPrices = false;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.startTime;
    _loadServices();
    _loadEmployeePrices();
  }

  @override
  void dispose() {
    _searchServicesCtrl.dispose();
    _searchClientsCtrl.dispose();
    _occupyCommentCtrl.dispose();
    super.dispose();
  }

  int _timeToMin(String time) {
    final parts = time.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  bool _isTimeSlotAvailable(String time, {int duration = 5}) {
    final timeMin = _timeToMin(time);
    final timeEnd = timeMin + duration;

    for (final record in widget.existingRecords) {
      final recordStart = _timeToMin((record['start_time'] as String).substring(0, 5));
      final recordEnd = _timeToMin((record['end_time'] as String).substring(0, 5));
      if (timeMin < recordEnd && timeEnd > recordStart) return false;
    }

    for (final slot in widget.occupiedSlots) {
      final slotStart = _timeToMin((slot['start_time'] as String).substring(0, 5));
      final slotEnd = _timeToMin((slot['end_time'] as String).substring(0, 5));
      if (timeMin < slotEnd && timeEnd > slotStart) return false;
    }

    return true;
  }

  void _loadServices() async {
    setState(() => _loadingServices = true);
    try {
      final result = await ApiService.get('/api/service/list?project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _loadingServices = false;
        });
      } else {
        if (mounted) setState(() => _loadingServices = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  void _loadEmployeePrices() async {
    setState(() => _loadingPrices = true);
    try {
      final result = await ApiService.get('/api/employee/get?id=${widget.employeeId}&project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        final data = result['data'];
        if (data['employee_service_prices'] != null) {
          setState(() {
            _employeePrices = Map<int, Map<String, dynamic>>.from(
              (data['employee_service_prices'] as Map).map((k, v) => MapEntry(int.parse(k.toString()), Map<String, dynamic>.from(v)))
            );
            _loadingPrices = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrices = false);
    }
  }

  void _loadClients() async {
    setState(() => _loadingClients = true);
    try {
      final result = await ApiService.get('/api/client/list?project_id=${widget.projectId}&limit=100');
      if (result['success'] == true && mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _loadingClients = false;
        });
      } else {
        if (mounted) setState(() => _loadingClients = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  void _goNext() {
    if (_step == 1) {
      if (_mode == 'booking') {
        setState(() => _step = 2);
      } else {
        _createOccupiedTime();
      }
    } else if (_step == 2) {
      if (_selectedServices.isEmpty) {
        showToast(context, 'Выберите хотя бы одну услугу', isError: true);
        return;
      }
      setState(() => _step = 3);
      _loadClients();
    } else if (_step == 3) {
      if (_selectedClient == null) {
        showToast(context, 'Выберите клиента', isError: true);
        return;
      }
      _createBooking();
    }
  }

  void _goBack() {
    if (_step > 1) {
      setState(() => _step = _step - 1);
    } else {
      Navigator.pop(context);
    }
  }

  void _createOccupiedTime() async {
    try {
      final result = await ApiService.createOccupiedTime(
        projectId: widget.projectId,
        employeeId: widget.employeeId,
        date: widget.date,
        startTime: '$_selectedTime:00',
        duration: _occupyDuration,
        color: _occupyColor,
        comment: _occupyCommentCtrl.text,
        allDay: _occupyDuration >= 1440,
      );
      
      if (result['success'] == true && mounted) {
        Navigator.pop(context, true);
        showToast(context, 'Время занято!');
      } else if (mounted) {
        showToast(context, result['message'] ?? 'Ошибка', isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'Ошибка соединения', isError: true);
    }
  }

  void _createBooking() async {
    setState(() => _loadingClients = true);
    try {
      final result = await ApiService.createBooking(
        projectId: widget.projectId,
        date: widget.date,
        startTime: '$_selectedTime:00',
        serviceIds: _selectedServices.toList(),
        employeeId: widget.employeeId,
        clientName: '',
        clientPhone: '',
        clientId: _selectedClient,
      );
      
      if (result['success'] == true && mounted) {
        Navigator.pop(context, true);
        showToast(context, 'Запись создана!');
      } else if (mounted) {
        showToast(context, result['message'] ?? 'Ошибка создания записи', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Ошибка создания записи', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_servicesQuery.isEmpty) return _services;
    return _services.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      return name.contains(_servicesQuery.toLowerCase());
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredClients {
    if (_clientsQuery.isEmpty) return _clients;
    return _clients.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final query = _clientsQuery.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  String get _stepTitle {
    switch (_step) {
      case 1: return _mode == 'booking' ? 'Создать запись' : 'Занять время';
      case 2: return 'Создать запись';
      case 3: return 'Создать запись';
      default: return '';
    }
  }

  String get _buttonText {
    switch (_step) {
      case 1: return _mode == 'booking' ? 'Далее' : 'Занять время';
      case 2: return 'Далее';
      case 3: return 'Создать запись';
      default: return '';
    }
  }

  String _formatDuration(int m) {
    if (m >= 1440) return 'Весь день';
    final h = m ~/ 60;
    final min = m % 60;
    if (h == 0) return '$min мин';
    if (min == 0) return '$h ч';
    return '$h ч $min мин';
  }

  void _showDurationPicker() {
    final options = [15, 30, 45, 60, 90, 120, 180, 240, 480, 1440];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Длительность', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((m) => GestureDetector(
                onTap: () {
                  setState(() => _occupyDuration = m);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _occupyDuration == m ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _occupyDuration == m ? const Color(0xFFDD1847) : Colors.transparent),
                  ),
                  child: Text(_formatDuration(m), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _goBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                    child: Icon(
                      _step == 1 ? Icons.close : Icons.arrow_back,
                      size: 24,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _stepTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close, size: 24, color: Color(0xFF666666)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _step == 1 
                  ? _buildTimeStep() 
                  : (_step == 2 ? _buildServicesStep() : _buildClientsStep()),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_loadingServices && _step == 1) || _loadingClients ? null : _goNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD1847),
                  disabledBackgroundColor: const Color(0xFFCCCCCC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: (_loadingServices && _step == 1) || _loadingClients
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _buttonText,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStep() {
    final selectedHour = int.parse(_selectedTime.split(':')[0]);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Переключатель режима
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mode = 'booking'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _mode == 'booking' ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _mode == 'booking' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1))] : null,
                    ),
                    child: Text(
                      'Создать запись',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _mode == 'booking' ? FontWeight.w600 : FontWeight.w500,
                        color: _mode == 'booking' ? const Color(0xFF1A1A1A) : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mode = 'occupy'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _mode == 'occupy' ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _mode == 'occupy' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1))] : null,
                    ),
                    child: Text(
                      'Занять время',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _mode == 'occupy' ? FontWeight.w600 : FontWeight.w500,
                        color: _mode == 'occupy' ? const Color(0xFF1A1A1A) : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_mode == 'booking') ...[
          // Инфо о выбранном времени
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('Выбранное время', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                const Spacer(),
                Text(_selectedTime, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                const Spacer(),
                const Text('Нажмите, чтобы\nизменить время', style: TextStyle(fontSize: 12, color: Color(0xFF999999)), textAlign: TextAlign.right),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Таймслоты
          _buildTimeSlots(selectedHour),
        ] else ...[
          // Режим "Занять время"
          _buildOccupyForm(),
        ],
      ],
    );
  }

  Widget _buildTimeSlots(int selectedHour) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(12, (i) {
        final min = i * 5;
        final time = '${selectedHour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
        final available = _isTimeSlotAvailable(time);
        final selected = time == _selectedTime;

        return GestureDetector(
          onTap: available ? () => setState(() => _selectedTime = time) : null,
          child: Container(
            width: (MediaQuery.of(context).size.width - 40 - 18) / 4,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFDD1847)
                  : (available ? const Color(0xFFF8F8F8) : const Color(0xFFF5F5F5)),
              borderRadius: BorderRadius.circular(10),
              border: selected ? Border.all(color: const Color(0xFFDD1847)) : null,
            ),
            child: Text(
              time,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : (available ? const Color(0xFF666666) : const Color(0xFFCCCCCC)),
                decoration: !available ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildOccupyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Инфо о выбранном времени
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Text('Выбранное время', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
              const Spacer(),
              Text(_selectedTime, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
              const Spacer(),
              const Text('Нажмите, чтобы\nизменить время', style: TextStyle(fontSize: 12, color: Color(0xFF999999)), textAlign: TextAlign.right),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Таймслоты для выбора времени
        _buildTimeSlots(int.parse(_selectedTime.split(':')[0])),
        const SizedBox(height: 20),
        // Длительность
        const Text('Длительность', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showDurationPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('Длительность', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Text(_formatDuration(_occupyDuration), style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Цвет
        const Text('Цвет', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
        const SizedBox(height: 8),
        _buildOccupyColors(),
        const SizedBox(height: 20),
        // Комментарий
        const Text('Комментарий', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
        const SizedBox(height: 8),
        TextField(
          controller: _occupyCommentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Добавьте комментарий...',
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOccupyColors() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _occupyColors.map((c) => GestureDetector(
        onTap: () => setState(() => _occupyColor = c),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Color(int.parse('FF${c.substring(1)}', radix: 16)),
            shape: BoxShape.circle,
            border: Border.all(
              color: _occupyColor == c ? Colors.black : Colors.transparent,
              width: 3,
            ),
          ),
        ),
      )).toList(),
    );
  }

  // ШАГ 2: Выбор услуг
  Widget _buildServicesStep() {
    if (_loadingServices) {
  return Container(
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
    child: ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          const SkeletonBox(width: 48, height: 48, radius: 10),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(height: 14, width: 150),
            const SizedBox(height: 4),
            const SkeletonBox(height: 12, width: 100),
          ])),
        ]),
      ),
    ),
  );
}

    final filtered = _filteredServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Выберите услуги', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: TextField(
            controller: _searchServicesCtrl,
            onChanged: (v) => setState(() => _servicesQuery = v),
            decoration: const InputDecoration(
              hintText: 'Поиск услуг...',
              hintStyle: TextStyle(color: Color(0xFF999999)),
              prefixIcon: Icon(Icons.search, color: Color(0xFF999999), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Услуги не найдены', style: TextStyle(color: Color(0xFF999999))),
            ),
          )
        else
          ...filtered.map((s) => _buildServiceItem(s)),
        const SizedBox(height: 12),
        _buildCreateButton('Создать услугу', () {
          Navigator.pop(context);
        }),
      ],
    );
  }

  Widget _buildServiceItem(Map<String, dynamic> s) {
    final sel = _selectedServices.contains(s['id']);
    final photoUrl = s['photo_url'] as String?;
    final duration = s['duration'] as int? ?? 0;
    final hours = duration ~/ 60;
    final mins = duration % 60;

    // Используем персональную цену сотрудника
    final empPrice = _employeePrices[s['id']] ?? {};
    final isFree = empPrice['is_free'] == true || s['is_free'] == true || s['is_free'] == 1;
    final showPrice = (empPrice['price'] != null && empPrice['price'] != '' && empPrice['price'] != 0) 
        ? empPrice['price'].toString() 
        : (s['price'] ?? 0).toString();
    final showPriceFrom = empPrice['price_from'] == true || empPrice['price_from'] == 'true' || empPrice['price_from'] == 1 || empPrice['price_from'] == '1';
    final priceText = isFree ? 'Бесплатно' : '${showPriceFrom ? 'от ' : ''}$showPrice ₽';
    final durationText = '${hours > 0 ? '$hoursч ' : ''}${mins > 0 ? '$mins мин' : ''}'.trim();

    return GestureDetector(
      onTap: () {
        setState(() {
          if (sel) {
            _selectedServices.remove(s['id']);
          } else {
            _selectedServices.add(s['id']);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? const Color(0xFFDD1847) : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedAvatar(url: photoUrl, size: 48, radius: 10)
                  : _serviceDefaultPhoto(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text('$priceText · $durationText', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFDDDDDD), width: 2),
                color: sel ? const Color(0xFFDD1847) : Colors.transparent,
              ),
              child: sel ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceDefaultPhoto() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.spa, size: 20, color: Colors.grey[400]),
        const SizedBox(height: 2),
        Text('Фото', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
      ],
    );
  }

  // ШАГ 3: Выбор клиента
  Widget _buildClientsStep() {
    if (_loadingClients) {
  return Container(
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
    child: ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          const SkeletonCircle(size: 44),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(height: 14, width: 150),
            const SizedBox(height: 4),
            const SkeletonBox(height: 12, width: 100),
          ])),
        ]),
      ),
    ),
  );
}

    final filtered = _filteredClients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Выберите клиента', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: TextField(
            controller: _searchClientsCtrl,
            onChanged: (v) => setState(() => _clientsQuery = v),
            decoration: const InputDecoration(
              hintText: 'Поиск клиентов...',
              hintStyle: TextStyle(color: Color(0xFF999999)),
              prefixIcon: Icon(Icons.search, color: Color(0xFF999999), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _clients.isEmpty ? 'Нет клиентов. Создайте первого клиента.' : 'Клиенты не найдены',
                style: const TextStyle(color: Color(0xFF999999)),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...filtered.map((c) => _buildClientItem(c)),
        const SizedBox(height: 12),
        _buildCreateButton('Создать клиента', () {
          Navigator.pop(context);
        }),
      ],
    );
  }

  Widget _buildClientItem(Map<String, dynamic> c) {
    final sel = _selectedClient == c['id'];
    final name = (c['name'] ?? '') as String;
    return GestureDetector(
      onTap: () => setState(() => _selectedClient = c['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? const Color(0xFFDD1847) : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            AvatarInitials(name: name, size: 44, bgColor: const Color(0xFFFDF2F5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                  Text(
  (c['phone'] ?? '').toString().isNotEmpty
      ? formatPhoneDisplay(c['phone'].toString())
      : 'Нет телефона',
  style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
),
                ],
              ),
            ),
            if (sel) const Icon(Icons.check, size: 20, color: Color(0xFFDD1847)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDD1847), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 18, color: Color(0xFFDD1847)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFDD1847))),
          ],
        ),
      ),
    );
  }
}