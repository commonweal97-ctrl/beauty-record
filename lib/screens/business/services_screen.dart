import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServicesScreen extends StatefulWidget {
  final int projectId;
  const ServicesScreen({super.key, required this.projectId});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<Map<String, dynamic>> _services = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;

  static const String _baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/service/list?project_id=${widget.projectId}'),
        ApiService.get('/api/service/categories?project_id=${widget.projectId}'),
      ]);
      if (mounted) {
        setState(() {
          _services = results[0]['success'] == true ? List<Map<String, dynamic>>.from(results[0]['data'] ?? []) : [];
          _categories = results[1]['success'] == true ? List<String>.from(results[1]['data'] ?? []) : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_selectedCategory == null) return _services;
    return _services.where((s) => s['category'] == _selectedCategory).toList();
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    if (m > 0) return '$m мин';
    return '0 мин';
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _services.removeAt(oldIndex);
    _services.insert(newIndex, item);
    setState(() {});
    
    final orders = _services.asMap().entries.map((e) => {
      'id': e.value['id'],
      'sort_order': e.key,
    }).toList();
    
    await ApiService.post('/api/service/update-order', {
      'project_id': widget.projectId,
      'orders': orders,
    });
  }

    @override
  Widget build(BuildContext context) {
    final displayServices = _filteredServices;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _loading
          ? _buildSkeleton()
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(children: [
                  const Expanded(child: Text('Услуги', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600))),
                  GestureDetector(
                    onTap: () => _openServiceModal(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFDD1847), Color(0xFFC1163D)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ),
              if (_categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _categoryChip('Все', null),
                        ..._categories.map((c) => _categoryChip(c, c)),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: displayServices.isEmpty
                    ? _buildEmpty()
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Row(children: [
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Как изменить порядок?'),
                                    content: const Text('Зажмите услугу пальцем и перетащите в нужное место.'),
                                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно'))],
                                  ),
                                ),
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[300]),
                                  child: const Icon(Icons.question_mark, size: 14, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Зажмите и перетащите для изменения порядка', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                            ]),
                          ),
                          Expanded(
                            child: ReorderableListView.builder(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              itemCount: displayServices.length,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex--;
                                final item = displayServices.removeAt(oldIndex);
                                displayServices.insert(newIndex, item);
                                setState(() {});
                                final orders = displayServices.asMap().entries.map((e) => {
                                  'id': e.value['id'],
                                  'sort_order': e.key,
                                }).toList();
                                ApiService.post('/api/service/update-order', {
                                  'project_id': widget.projectId,
                                  'orders': orders,
                                });
                              },
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, child) {
                                    final elevation = Tween<double>(begin: 0, end: 4).animate(animation).value;
                                    return Material(
                                      elevation: elevation,
                                      shadowColor: Colors.black26,
                                      borderRadius: BorderRadius.circular(16),
                                      child: child,
                                    );
                                  },
                                  child: child,
                                );
                              },
                              itemBuilder: (_, i) => _buildServiceCard(displayServices[i], key: ValueKey(displayServices[i]['id'])),
                            ),
                          ),
                        ],
                      ),
              ),
            ]),
    );
  }
  
  Widget _categoryChip(String label, String? value) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDD1847) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : const Color(0xFF666666))),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.spa, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('Нет услуг', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Добавьте услуги, которые оказывает ваш бизнес', style: TextStyle(color: Color(0xFF888888))),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _openServiceModal(),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Добавить услугу', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 4,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
        child: Row(children: [
          const SkeletonBox(width: 52, height: 52, radius: 12),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(height: 16, width: 150),
            const SizedBox(height: 8),
            Row(children: const [SkeletonBox(height: 12, width: 80), SizedBox(width: 16), SkeletonBox(height: 12, width: 60)]),
          ])),
        ]),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> s, {Key? key}) {
    final photo = s['photo_url']?.toString();
    final isFree = s['is_free'] == true;
    final priceFrom = s['price_from'] == true;
    final price = double.tryParse(s['price']?.toString() ?? '0') ?? 0;
    final duration = s['duration'] as int? ?? 60;
    return GestureDetector(
      key: key,
      onTap: () => _openServiceModal(service: s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: photo != null && photo.isNotEmpty
                ? CachedNetworkImage(imageUrl: '$_baseUrl$photo', fit: BoxFit.cover)
                : const Icon(Icons.spa, size: 22, color: Color(0xFF999999)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                isFree ? 'Бесплатно' : '${priceFrom ? 'от ' : ''}${price.toStringAsFixed(0)} ₽ · ${_formatDuration(duration)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
        ]),
      ),
    );
  }

  void _openServiceModal({Map<String, dynamic>? service}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ServiceFormSheet(
        projectId: widget.projectId,
        service: service,
        categories: _categories,
        onSaved: _load,
      ),
    );
  }
}

// ==================== ФОРМА УСЛУГИ ====================
class _ServiceFormSheet extends StatefulWidget {
  final int projectId;
  final Map<String, dynamic>? service;
  final List<String> categories;
  final VoidCallback onSaved;
  const _ServiceFormSheet({required this.projectId, this.service, required this.categories, required this.onSaved});
  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Без категории';
  bool _isFree = false;
  bool _priceFrom = false;
  bool _onlineBooking = true;
  int _duration = 60;
  int _breakAfter = 0;
  String _photoUrl = '';
  File? _photoFile;
  bool _saving = false;

  List<Map<String, dynamic>> _allEmployees = [];
  
  Set<int> _employeeIds = {};
  Map<int, Map<String, dynamic>> _employeePrices = {};
  Map<int, bool> _expandedEmployees = {};

  List<Map<String, dynamic>> _resources = [];
  Map<int, bool> _resourceStates = {};
  List<File> _workPhotos = [];
  List<Map<String, dynamic>> _existingWorkPhotos = [];
  static const _maxWorkPhotos = 6;

  static const String _baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';

  bool get _isEdit => widget.service != null;
  List<String> get _allCategories => ['Без категории', ...widget.categories];

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    if (m > 0) return '$m мин';
    return '0 мин';
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.service!;
      _nameCtrl.text = s['name'] ?? '';
      _priceCtrl.text = s['price']?.toString() ?? '';
      _descCtrl.text = s['description'] ?? '';
      _category = s['category'] ?? 'Без категории';
      _isFree = s['is_free'] == true;
      _priceFrom = s['price_from'] == true;
      _duration = s['duration'] as int? ?? 60;
      _breakAfter = s['break_after'] as int? ?? 0;
      _onlineBooking = s['online_booking'] != false;
      _photoUrl = s['photo_url'] ?? '';

      _employeeIds = Set<int>.from(
  (s['employee_ids'] as List?)?.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0) ?? []
);

print('=== DEBUG employee_prices ===');
print('Service keys: ${s.keys}');
print('Has employee_prices key: ${s.containsKey('employee_prices')}');
print('RAW employee_prices: ${s['employee_prices']}');
print('Type: ${s['employee_prices']?.runtimeType}');

_employeePrices = {};
if (s['employee_prices'] != null) {
  final raw = s['employee_prices'];
  if (raw is Map) {
    raw.forEach((k, v) {
      print('  Key: $k (${k.runtimeType}), Value: $v (${v.runtimeType})');
      final empId = int.tryParse(k.toString()) ?? 0;
      if (empId > 0 && v is Map) {
        _employeePrices[empId] = Map<String, dynamic>.from(v);
        print('  -> Added empId=$empId: ${_employeePrices[empId]}');
      } else {
        print('  -> SKIPPED: empId=$empId, v is Map=${v is Map}');
      }
    });
  } else {
    print('raw is NOT a Map, it is ${raw.runtimeType}');
  }
  for (final empId in _employeePrices.keys) {
    if (!_employeeIds.contains(empId)) {
      _employeeIds.add(empId);
    }
  }
} else {
  print('employee_prices is NULL');
}
print('PARSED _employeePrices: $_employeePrices');
print('_employeeIds: $_employeeIds');
print('=== END DEBUG ===');
        }
    _loadResources();
    _loadEmployees();
    if (_isEdit) {
      _loadServiceData();
      _loadEmployeePrices();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final r = await ApiService.get('/api/employee/list?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        setState(() => _allEmployees = List<Map<String, dynamic>>.from(r['data'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadResources() async {
    try {
      final r = await ApiService.get('/api/resource/list?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        final list = List<Map<String, dynamic>>.from(r['data'] ?? []);
        _resourceStates = {};
        for (final res in list) {
          final rid = res['id'] is int ? res['id'] as int : int.tryParse(res['id'].toString()) ?? 0;
          _resourceStates[rid] = false;
        }
        if (_isEdit) {
          final serviceId = widget.service?['id'];
          final resStates = await ApiService.get('/api/resource/get-for-service?service_id=$serviceId&project_id=${widget.projectId}');
          if (resStates['success'] == true) {
            final states = resStates['data'] as List? ?? [];
            for (final s in states) {
              _resourceStates[s['resource_id']] = s['is_active'] == 1;
            }
          }
        }
        setState(() => _resources = list);
      }
    } catch (_) {}
  }

  Future<void> _loadServiceData() async {
    final result = await ApiService.get('/api/service/get?id=${widget.service?['id']}&project_id=${widget.projectId}');
    if (result['success'] == true && mounted) {
      final data = result['data'];
      setState(() {
        _photoUrl = data['photo_url'] ?? '';
        final photos = data['work_photos'] as List?;
        if (photos != null && photos.isNotEmpty) {
          _existingWorkPhotos = photos.where((p) => (p['photo_url'] ?? '').isNotEmpty).map((p) {
            return {'url': p['photo_url'] ?? p['url'] ?? '', 'id': p['id']};
          }).toList();
        }
      });
    }
  }

  Future<void> _loadEmployeePrices() async {
  try {
    final result = await ApiService.get('/api/service/get?id=${widget.service!['id']}&project_id=${widget.projectId}');
    print('=== _loadEmployeePrices ===');
    print('Result success: ${result['success']}');
    if (result['success'] == true) {
      final data = result['data'];
      print('Has employee_prices: ${data['employee_prices'] != null}');
      print('RAW: ${data['employee_prices']}');
      if (data['employee_prices'] != null && mounted) {
        setState(() {
          _employeePrices = {};
          (data['employee_prices'] as Map).forEach((k, v) {
            final empId = int.tryParse(k.toString()) ?? 0;
            if (empId > 0 && v is Map) {
              _employeePrices[empId] = Map<String, dynamic>.from(v);
            }
          });
          for (final empId in _employeePrices.keys) {
            if (!_employeeIds.contains(empId)) {
              _employeeIds.add(empId);
            }
          }
          print('PARSED: $_employeePrices');
        });
      }
    }
    print('=== END _loadEmployeePrices ===');
  } catch (e) {
    print('_loadEmployeePrices ERROR: $e');
  }
}

  // ========== МЕТОДЫ ДЛЯ ПЕРСОНАЛЬНЫХ НАСТРОЕК ==========
  
  void _toggleEmployee(int empId) {
    setState(() {
      if (_employeeIds.contains(empId)) {
        _employeeIds.remove(empId);
        _employeePrices.remove(empId);
        _expandedEmployees.remove(empId);
      } else {
        _employeeIds.add(empId);
        _employeePrices[empId] = {};
      }
    });
  }

  void _expandEmployee(int empId) {
    setState(() => _expandedEmployees[empId] = true);
  }

  void _updateEmployeePrice(int empId, String value) {
    _employeePrices[empId] ??= {};
    _employeePrices[empId]!['price'] = value;
  }

  void _updateEmployeeFree(int empId, bool value) {
    _employeePrices[empId] ??= {};
    _employeePrices[empId]!['is_free'] = value;
    if (value) {
      _employeePrices[empId]!['price'] = '';
      _employeePrices[empId]!['price_from'] = false;
    }
    setState(() {});
  }

  void _updateEmployeePriceFrom(int empId, bool value) {
    _employeePrices[empId] ??= {};
    _employeePrices[empId]!['price_from'] = value;
    setState(() {});
  }

  void _updateEmployeeDuration(int empId, int value) {
    _employeePrices[empId] ??= {};
    _employeePrices[empId]!['duration'] = value;
    setState(() {});
  }

  void _updateEmployeeOnlineBooking(int empId, bool value) {
    _employeePrices[empId] ??= {};
    _employeePrices[empId]!['online_booking'] = value;
    setState(() {});
  }

  void _pickEmployeeDuration(int empId) {
    final currentDuration = (_employeePrices[empId]?['duration'] as int?) ?? _duration;
    _showTimePicker('Длительность для сотрудника', currentDuration, (m) {
      _updateEmployeeDuration(empId, m);
    });
  }

  // ========== СОХРАНЕНИЕ ==========
  
  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showToast(context, 'Введите название', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final employeePricesToSend = <String, Map<String, dynamic>>{};
for (final entry in _employeePrices.entries) {
  final p = entry.value;
  // Отправляем только если есть персональные настройки (не пустые)
  final hasCustom = p['price'] != null || p['is_free'] == true || p['duration'] != null || (p['online_booking'] != null && p['online_booking'] != true);
  if (hasCustom) {
    employeePricesToSend[entry.key.toString()] = {
      'price': p['price'] ?? 0,
      'is_free': p['is_free'] ?? false,
      'price_from': p['price_from'] ?? false,
      'duration': p['duration'],
      'online_booking': p['online_booking'] ?? true,
    };
  }
}

      final body = {
        'project_id': widget.projectId,
        'service_id': widget.service?['id'],
        'name': _nameCtrl.text.trim(),
        'category': _category == 'Без категории' ? '' : _category,
        'is_free': _isFree,
        'price': _isFree ? 0 : double.tryParse(_priceCtrl.text) ?? 0,
        'price_from': _priceFrom,
        'duration': _duration,
        'break_after': _breakAfter,
        'online_booking': _onlineBooking,
        'description': _descCtrl.text.trim(),
        'employee_ids': _employeeIds.toList(),
        'employee_prices': employeePricesToSend,
        'delete_photo': _photoFile == null && _photoUrl.isEmpty && widget.service?['photo_url'] != null ? true : null,
      };

      final url = _isEdit ? '/api/service/update' : '/api/service/create';
      final result = await ApiService.post(url, body);
      
      if (result['success'] == true && mounted) {
        final serviceId = result['data']?['id'] ?? widget.service?['id'];

        if (serviceId != null && _resourceStates.isNotEmpty) {
          final states = _resourceStates.entries.map((e) => {'resource_id': e.key, 'is_active': e.value ? 1 : 0}).toList();
          await ApiService.post('/api/service/save-resources', {'service_id': serviceId, 'project_id': widget.projectId, 'resources': states});
        }

        if (_photoFile != null && serviceId != null) {
          final prefs = await SharedPreferences.getInstance();
          final cookies = prefs.getString('saved_cookies');
          final formData = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/service/upload-photo'));
          if (cookies != null) formData.headers['Cookie'] = cookies;
          formData.fields['service_id'] = serviceId.toString();
          formData.fields['project_id'] = widget.projectId.toString();
          formData.files.add(await http.MultipartFile.fromPath('photo', _photoFile!.path));
          await formData.send();
        }

        if (_workPhotos.isNotEmpty && serviceId != null) {
          final prefs = await SharedPreferences.getInstance();
          final cookies = prefs.getString('saved_cookies');
          for (final file in _workPhotos) {
            final formData = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/service/upload-work-photo'));
            if (cookies != null) formData.headers['Cookie'] = cookies;
            formData.fields['service_id'] = serviceId.toString();
            formData.fields['project_id'] = widget.projectId.toString();
            formData.files.add(await http.MultipartFile.fromPath('photo', file.path));
            await formData.send();
          }
        }

        Navigator.pop(context);
        widget.onSaved();
      } else if (mounted) {
        showToast(context, result['message'] ?? 'Ошибка сохранения', isError: true);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка: $e', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  // ========== ПИКЕРЫ И ДИАЛОГИ ==========

  void _showTimePicker(String title, int current, ValueChanged<int> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TimeWheelPicker(initialMinutes: current, title: title, onSelected: (m) { onSelected(m); Navigator.pop(ctx); }),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Категория', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ..._allCategories.map((c) => ListTile(
                  title: Text(c),
                  trailing: _category == c ? const Icon(Icons.check, color: Color(0xFFDD1847)) : null,
                  onTap: () {
                    setState(() => _category = c);
                    Navigator.pop(ctx);
                  },
                )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add, color: Color(0xFFDD1847)),
              title: const Text('Создать категорию', style: TextStyle(color: Color(0xFFDD1847))),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateCategory();
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _showCreateCategory() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: AlertDialog(
          title: const Text('Новая категория'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(ctx).unfocus(),
            decoration: const InputDecoration(hintText: 'Название категории'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            TextButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  setState(() {
                    widget.categories.add(ctrl.text.trim());
                    _category = ctrl.text.trim();
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmployeePicker() async {
    if (_allEmployees.isEmpty) {
      try {
        final r = await ApiService.get('/api/employee/list?project_id=${widget.projectId}');
        if (r['success'] == true) {
          _allEmployees = List<Map<String, dynamic>>.from(r['data'] ?? []);
        }
      } catch (_) {}
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => GestureDetector(
          onTap: () => FocusScope.of(ctx).unfocus(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
                child: Row(children: [
                  const Expanded(child: Text('Сотрудники', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Expanded(
                child: _allEmployees.isEmpty
                    ? const Center(child: Text('Нет сотрудников', style: TextStyle(color: Color(0xFF999999))))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: _allEmployees.map((emp) {
                          final empId = emp['id'] as int;
                          final isSelected = _employeeIds.contains(empId);
                          final prices = _employeePrices[empId] ?? {};
                          final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
                          final position = emp['position']?.toString() ?? '';
                          final hasCustom = prices['price'] != null || prices['is_free'] == true || prices['duration'] != null || prices['online_booking'] != null;
                          final isExpanded = _expandedEmployees[empId] == true;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isSelected ? const Color(0xFFDD1847) : const Color(0xFFE8E8E8), width: isSelected ? 2 : 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => setModalState(() => _toggleEmployee(empId)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.grey[200],
                                        child: emp['avatar'] != null && emp['avatar'].toString().isNotEmpty
                                            ? ClipOval(child: CachedNetworkImage(imageUrl: '$_baseUrl${emp['avatar']}', width: 44, height: 44, fit: BoxFit.cover))
                                            : Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF999999))),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                          if (position.isNotEmpty) Text(position, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                        ]),
                                      ),
                                      Container(
                                        width: 24, height: 24,
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFDD1847) : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: isSelected ? const Color(0xFFDD1847) : const Color(0xFFCCCCCC), width: 2),
                                        ),
                                        child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                      ),
                                    ]),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                    child: () {
                                      if (!hasCustom && !isExpanded) {
                                        return GestureDetector(
                                          onTap: () => setModalState(() => _expandedEmployees[empId] = true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8E8E8))),
                                            child: Row(children: [
                                              const Expanded(child: Text('Используются общие настройки услуги', style: TextStyle(fontSize: 11, color: Color(0xFF999999)))),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDD1847)), borderRadius: BorderRadius.circular(6)),
                                                child: const Text('Править', style: TextStyle(fontSize: 10, color: Color(0xFFDD1847), fontWeight: FontWeight.w600)),
                                              ),
                                            ]),
                                          ),
                                        );
                                      } else {
                                        return _buildEmployeeSettings(empId, prices, setModalState);
                                      }
                                    }(),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
                child: SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Готово', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeSettings(int empId, Map<String, dynamic> prices, StateSetter setModalState) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ЦЕНА', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF999999), letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Row(children: [
        GestureDetector(
          onTap: () {
            _updateEmployeePriceFrom(empId, !(prices['price_from'] ?? false));
            setModalState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (prices['price_from'] ?? false) ? const Color(0xFFDD1847) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: (prices['price_from'] ?? false) ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0)),
            ),
            child: Text('от', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (prices['price_from'] ?? false) ? Colors.white : const Color(0xFF999999))),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 70, height: 32,
          child: TextField(
            controller: TextEditingController(text: (prices['price'] ?? '').toString()),
            keyboardType: TextInputType.number,
            enabled: !(prices['is_free'] ?? false),
            onChanged: (v) => _updateEmployeePrice(empId, v),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE8E8E8))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Text('руб', style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            _updateEmployeeFree(empId, !(prices['is_free'] ?? false));
            setModalState(() {});
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon((prices['is_free'] ?? false) ? Icons.check_box : Icons.check_box_outline_blank, size: 16, color: const Color(0xFFDD1847)),
            const SizedBox(width: 3),
            const Text('Бесплатно', style: TextStyle(fontSize: 11, color: Color(0xFF666666))),
          ]),
        ),
      ]),
      
      const SizedBox(height: 10),
      const Text('ДЛИТЕЛЬНОСТЬ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF999999), letterSpacing: 0.5)),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () {
          final currentDuration = (prices['duration'] as int?) ?? _duration;
          _showTimePicker('Длительность для сотрудника', currentDuration, (m) {
            _updateEmployeeDuration(empId, m);
            setModalState(() {});
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8E8E8))),
          child: Row(children: [
            const Icon(Icons.access_time, size: 16, color: Color(0xFF999999)),
            const SizedBox(width: 6),
            Expanded(child: Text(prices['duration'] != null ? _formatDuration(prices['duration'] as int) : 'Общая длительность услуги', style: const TextStyle(fontSize: 12, color: Color(0xFF333333)))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(6)),
              child: Text(prices['duration'] != null ? 'Изменить' : 'Установить', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
            ),
          ]),
        ),
      ),
      
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8E8E8))),
        child: Row(children: [
          const Text('Онлайн-запись', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
          const Spacer(),
          Switch(
            value: prices['online_booking'] ?? true,
            onChanged: (v) {
              _updateEmployeeOnlineBooking(empId, v);
              setModalState(() {});
            },
            activeColor: const Color(0xFFDD1847),
          ),
        ]),
      ),
    ]);
  }

  void _showResourcePicker() async {
    await _loadResources();
    if (!mounted) return;
    
    final localStates = Map<int, bool>.from(_resourceStates);
    
    final result = await showModalBottomSheet<Map<int, bool>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => GestureDetector(
          onTap: () => FocusScope.of(ctx).unfocus(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
                child: Row(children: [
                  const Expanded(child: Text('Ресурсы для услуги', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Expanded(
                child: _resources.isEmpty
                    ? Center(child: Text('Ресурсы не созданы', style: TextStyle(color: Colors.grey[500])))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: _resources.map((r) {
                          final rid = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString()) ?? 0;
                          final isActive = localStates[rid] ?? false;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                Text(isActive ? 'Активно на ресурсе' : 'Неактивно', style: TextStyle(fontSize: 12, color: isActive ? const Color(0xFF2E7D32) : const Color(0xFF999999))),
                              ])),
                              Switch(
                                value: isActive,
                                activeColor: const Color(0xFFDD1847),
                                onChanged: (v) => setModalState(() => localStates[rid] = v),
                              ),
                            ]),
                          );
                        }).toList(),
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, localStates),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    
    if (result != null && mounted) {
      setState(() => _resourceStates = result);
    }
  }

  Widget _buildWorkPhotos() {
    final total = _existingWorkPhotos.length + _workPhotos.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        ..._existingWorkPhotos.asMap().entries.where((e) => (e.value['url'] ?? '').isNotEmpty).map((e) => _workPhotoItem(
      e.value['url'] ?? '',
      () => _deleteExistingPhoto(e.key),
    )),
        ..._workPhotos.asMap().entries.map((e) => _workPhotoItem(e.value.path, () {
              _workPhotos.removeAt(e.key);
              setState(() {});
            }, isFile: true)),
        if (total < _maxWorkPhotos)
          GestureDetector(
            onTap: _pickWorkPhoto,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF8F8F8),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add, size: 22, color: Colors.grey[400]),
                const SizedBox(height: 4),
                Text('Фото', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ),
          ),
      ]),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('JPG, PNG, WEBP до 5 МБ • Максимум 6 фото', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
      ),
    ]);
  }

  Widget _workPhotoItem(String urlOrPath, VoidCallback onDelete, {bool isFile = false}) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isFile
            ? Image.file(File(urlOrPath), width: 90, height: 90, fit: BoxFit.cover)
            : CachedNetworkImage(imageUrl: '$_baseUrl$urlOrPath', width: 90, height: 90, fit: BoxFit.cover),
      ),
      Positioned(
        top: 4, right: 4,
        child: GestureDetector(
          onTap: onDelete,
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 14, color: Colors.white),
          ),
        ),
      ),
    ]);
  }

  Future<void> _deleteExistingPhoto(int index) async {
    final photo = _existingWorkPhotos[index];
    final photoUrl = photo['url'] ?? '';
    final result = await ApiService.post('/api/service/delete-photo', {
      'service_id': widget.service?['id'],
      'project_id': widget.projectId,
      'photo_url': photoUrl,
    });
    if (result['success'] == true && mounted) {
      setState(() => _existingWorkPhotos.removeAt(index));
    }
  }

  Future<void> _pickWorkPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked != null) setState(() => _workPhotos.add(File(picked.path)));
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back)),
              const Spacer(),
              Text(_isEdit ? 'Услуга' : 'Новая услуга', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () async {
                      final p = ImagePicker();
                      final f = await p.pickImage(source: ImageSource.gallery, maxWidth: 800);
                      if (f != null) setState(() { _photoFile = File(f.path); _photoUrl = ''; });
                    },
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E0E0))),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: _photoFile != null
                              ? Image.file(_photoFile!, width: 70, height: 70, fit: BoxFit.cover)
                              : _photoUrl.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: '$_baseUrl$_photoUrl', width: 70, height: 70, fit: BoxFit.cover)
                                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image, size: 28, color: Color(0xFF999999)), Text('Фото', style: TextStyle(fontSize: 9, color: Color(0xFF999999)))]),
                        ),
                      ),
                      if (_photoFile != null || _photoUrl.isNotEmpty)
                        Positioned(top: -8, right: -8, child: GestureDetector(onTap: () => setState(() { _photoFile = null; _photoUrl = ''; }), child: Container(width: 26, height: 26, decoration: BoxDecoration(color: const Color(0xFFF44336), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.close, size: 14, color: Colors.white)))),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(children: [
                      _field(_nameCtrl, 'Название услуги'),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _showCategoryPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0E0E0))),
                          child: Row(children: [
                            const Text('Категория: ', style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
                            Flexible(child: Text(_category, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFFCCCCCC)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),
                
                _block('Стоимость', [
                  Row(children: [const Text('Бесплатно'), const Spacer(), Switch(value: _isFree, onChanged: (v) => setState(() => _isFree = v), activeColor: const Color(0xFFDD1847))]),
                  if (!_isFree) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Text('Цена'), const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _priceFrom = !_priceFrom),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: _priceFrom ? const Color(0xFFDD1847) : const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(16), border: Border.all(color: _priceFrom ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0))),
                          child: Text('от', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _priceFrom ? Colors.white : const Color(0xFF888888))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(suffixText: '₽', filled: true, fillColor: const Color(0xFFF8F8F8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true),
                        ),
                      ),
                    ]),
                  ],
                ]),
                const SizedBox(height: 20),
                
                _block('Время услуги', [
                  _row('Длительность', _formatDuration(_duration), () => _showTimePicker('Длительность', _duration, (m) => setState(() => _duration = m))),
                  _row('Перерыв после записи', _breakAfter > 0 ? _formatDuration(_breakAfter) : 'Нет', () => _showTimePicker('Перерыв', _breakAfter, (m) => setState(() => _breakAfter = m))),
                ]),
                const SizedBox(height: 20),
                
                _block('Сотрудники', [
                  _row('Сотрудники', _employeeIds.isEmpty ? 'Все сотрудники' : 'Выбрано: ${_employeeIds.length}', _showEmployeePicker),
                ]),
                
                const SizedBox(height: 20),
                _block('Ресурсы', [
                  _row('Ресурсы', _resourceStates.values.where((v) => v).isEmpty ? 'Не выбрано' : 'Выбрано: ${_resourceStates.values.where((v) => v).length}', _showResourcePicker),
                ]),
                const SizedBox(height: 20),
                _block('Онлайн-запись', [
                  Row(children: [const Text('Онлайн-запись'), const Spacer(), Switch(value: _onlineBooking, onChanged: (v) => setState(() => _onlineBooking = v), activeColor: const Color(0xFFDD1847))]),
                ]),
                const SizedBox(height: 20),
                _block('Примеры работ', [_buildWorkPhotos()]),
                const SizedBox(height: 20),
                _field(_descCtrl, 'Описание услуги...', maxLines: 3),
                const SizedBox(height: 20),
                if (_isEdit)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Удалить услугу?'), actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                        ]));
                        if (c == true) {
                          await ApiService.post('/api/service/delete', {'service_id': widget.service!['id'], 'project_id': widget.projectId});
                          if (mounted) { Navigator.pop(context); widget.onSaved(); }
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Удалить услугу'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF44336), side: const BorderSide(color: Color(0xFFF44336)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
            child: SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), disabledBackgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving
                    ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)), SizedBox(width: 12), Text('Сохранение...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))])
                    : Text(_isEdit ? 'Сохранить' : 'Создать услугу', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _block(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _row(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
        child: Row(children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl, maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint, filled: true, fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDD1847))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ==================== ПИКЕР ВРЕМЕНИ ====================
class _TimeWheelPicker extends StatefulWidget {
  final int initialMinutes;
  final String title;
  final ValueChanged<int> onSelected;
  const _TimeWheelPicker({required this.initialMinutes, required this.title, required this.onSelected});
  @override
  State<_TimeWheelPicker> createState() => _TimeWheelPickerState();
}

class _TimeWheelPickerState extends State<_TimeWheelPicker> {
  late FixedExtentScrollController _hourCtrl, _minCtrl;
  int _hours = 0, _minutes = 0;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialMinutes ~/ 60;
    _minutes = (widget.initialMinutes % 60) ~/ 5 * 5;
    _hourCtrl = FixedExtentScrollController(initialItem: _hours);
    _minCtrl = FixedExtentScrollController(initialItem: _minutes ~/ 5);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('часы', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                const SizedBox(height: 8),
                SizedBox(
                  height: 130,
                  width: 80,
                  child: ListWheelScrollView.useDelegate(
                    controller: _hourCtrl,
                    itemExtent: 40,
                    diameterRatio: 1.2,
                    onSelectedItemChanged: (i) {
                      if (i >= 0) {
                        setState(() => _hours = i);
                      } else {
                        _hourCtrl.jumpToItem(0);
                        setState(() => _hours = 0);
                      }
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (ctx, i) {
                        if (i < 0) return const SizedBox.shrink();
                        return Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w500,
                              color: i == _hours ? const Color(0xFF1A1A1A) : const Color(0xFFCCCCCC),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ]),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(':', style: TextStyle(fontSize: 26, color: Color(0xFFCCCCCC))),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('минуты', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                const SizedBox(height: 8),
                SizedBox(
                  height: 130,
                  width: 80,
                  child: ListWheelScrollView.useDelegate(
                    controller: _minCtrl,
                    itemExtent: 40,
                    diameterRatio: 1.2,
                    onSelectedItemChanged: (i) {
                      if (i >= 0 && i <= 11) {
                        setState(() => _minutes = i * 5);
                      } else if (i < 0) {
                        _minCtrl.jumpToItem(0);
                        setState(() => _minutes = 0);
                      } else {
                        _minCtrl.jumpToItem(11);
                        setState(() => _minutes = 55);
                      }
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (ctx, i) {
                        if (i < 0 || i > 11) return const SizedBox.shrink();
                        return Center(
                          child: Text(
                            (i * 5).toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w500,
                              color: i * 5 == _minutes ? const Color(0xFF1A1A1A) : const Color(0xFFCCCCCC),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => widget.onSelected(_hours * 60 + _minutes),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD1847),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Сохранить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}