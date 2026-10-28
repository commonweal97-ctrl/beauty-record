import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/app_card.dart';
import '../../../widgets/common/time_picker_sheet.dart';
import '../../../widgets/common/avatar_initials.dart';
import '../../../utils/name_utils.dart';

class ServicesScreen extends StatefulWidget {
  final int projectId;
  const ServicesScreen({super.key, required this.projectId});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _services = [];
  int? _highlightServiceId;
  bool _highlightSuccess = false;
  final Map<int, GlobalKey> _serviceKeys = {};
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;

  static const String _baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false, int? highlightId}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/service/list?project_id=${widget.projectId}'),
        ApiService.get('/api/service/categories?project_id=${widget.projectId}'),
      ]);
      if (mounted) {
        setState(() {
          _services = results[0]['success'] == true
              ? List<Map<String, dynamic>>.from(results[0]['data'] ?? [])
              : [];
          _categories = results[1]['success'] == true
              ? List<String>.from(results[1]['data'] ?? [])
              : [];
          _loading = false;
        });
        if (highlightId != null) {
          setState(() {
            _highlightServiceId = highlightId;
            _highlightSuccess = false;
          });
          await Future.delayed(const Duration(milliseconds: 60));
          if (mounted) _scrollToService(highlightId);
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) setState(() => _highlightSuccess = true);
          await Future.delayed(const Duration(milliseconds: 1400));
          if (mounted) {
            setState(() {
              _highlightServiceId = null;
              _highlightSuccess = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToService(int serviceId) {
    final key = _serviceKeys[serviceId];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    }
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_selectedCategory == null) return _services;
    return _services.where((s) => s['category'] == _selectedCategory).toList();
  }

  int _countFor(String? category) {
    if (category == null) return _services.length;
    return _services.where((s) => s['category'] == category).length;
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    if (m > 0) return '$m мин';
    return '0 мин';
  }

  String get _activeFilterLabel {
    if (_selectedCategory == null) return 'Все услуги';
    return _selectedCategory!;
  }

  @override
  Widget build(BuildContext context) {
    final displayServices = _filteredServices;
    final total = _services.length;
    final shown = displayServices.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: shown >= 2
          ? FloatingActionButton(
              heroTag: 'services_magic',
              backgroundColor: const Color(0xFFDD1847),
              elevation: 6,
              shape: const CircleBorder(),
              onPressed: () => _showMagicDemo(context, displayServices),
              child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 26),
            )
          : null,
      body: _loading
          ? _buildSkeleton()
          : RefreshIndicator(
              color: const Color(0xFFDD1847),
              onRefresh: () async { await _load(); },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Шапка «Услуги» + кнопка +
                  SliverToBoxAdapter(
                    child: Padding(
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
                  ),
                  // Фильтры (chips)
                  if (_categories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: SizedBox(
                          height: 46,
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
                    ),
                  // Счётчик под фильтрами
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            _activeFilterLabel,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _selectedCategory == null ? '$total услуг' : '$shown из $total',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                        ),
                      ]),
                    ),
                  ),
                  // Список / Empty
                  if (shown == 0)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmpty(),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      sliver: SliverReorderableList(
                        itemCount: shown,
                        onReorderItem: (oldIndex, newIndex) async {
                          final movedId = displayServices[oldIndex]['id'];
                          final targetId = displayServices[newIndex]['id'];
                          final fullOld = _services.indexWhere((e) => e['id'] == movedId);
                          final fullTarget = _services.indexWhere((e) => e['id'] == targetId);
                          if (fullOld < 0 || fullTarget < 0) return;
                          final item = _services.removeAt(fullOld);
                          final insertAt = _services.indexWhere((e) => e['id'] == targetId);
                          final insertPos = (oldIndex < newIndex) ? insertAt + 1 : insertAt;
                          _services.insert(insertPos, item);
                          for (var i = 0; i < _services.length; i++) {
                            _services[i]['sort_order'] = i;
                          }
                          setState(() {});
                          final orders = _services.asMap().entries.map((e) => {
                            'id': e.value['id'],
                            'sort_order': e.key,
                          }).toList();
                          try {
                            final r = await ApiService.post('/api/service/update-order', {
                              'project_id': widget.projectId,
                              'orders': orders,
                            });
                            if (!mounted) return;
                            if (r['success'] != true) {
                              showToast(this.context, 'Не удалось сохранить порядок', isError: true);
                            }
                          } catch (_) {
                            if (!mounted) return;
                            showToast(this.context, 'Ошибка сохранения порядка', isError: true);
                          }
                        },
                        itemBuilder: (_, i) => _buildServiceCard(
                          displayServices[i],
                          index: i,
                          total: shown,
                          key: ValueKey(displayServices[i]['id']),
                          reorderIndex: i,
                        ),
                      ),
                    ),
                    // Финишер
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                        child: Row(children: [
                          const Expanded(child: Divider(color: Color(0xFFEEEEEE), height: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Показано $shown из $total',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFFEEEEEE), height: 1)),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _categoryChip(String label, String? value) {
    final selected = _selectedCategory == value;
    final count = _countFor(value);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDD1847) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFFDD1847) : const Color(0xFFE5E5E5),
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFDD1847).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF999999),
                  ),
                ),
              ),
            ],
          ),
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

  void _showMagicDemo(BuildContext context, List<Map<String, dynamic>> services) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _MagicDemoOverlay(
        services: services.take(2).toList(),
        buildCard: (s) {
          final eid = s['id'] is int ? s['id'] as int : int.tryParse(s['id'].toString()) ?? 0;
          return _buildServiceCard(
            s,
            index: 0,
            total: 2,
            cardKey: ValueKey('magic_$eid'),  // уникальный ключ — не конфликтует с основным списком
          );
        },
        onClose: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  Widget _buildServiceCard(Map<String, dynamic> s, {int index = 0, int total = 1, Key? key, Key? cardKey, int? reorderIndex}) {
    final photo = s['photo_url']?.toString();
    final isFree = s['is_free'] == true;
    final priceFrom = s['price_from'] == true;
    final price = double.tryParse(s['price']?.toString() ?? '0') ?? 0;
    final duration = s['duration'] as int? ?? 60;
    final sid = s['id'] as int;
    final keyForCard = cardKey ?? _serviceKeys.putIfAbsent(sid, () => GlobalKey());
    final isHighlight = _highlightServiceId == sid;
    final isSuccess = _highlightSuccess && isHighlight;

    final card = Dismissible(
      key: key ?? ValueKey('service_$sid'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Удалить услугу?'),
            content: Text('«${s['name']}» будет удалена.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Удалить', style: TextStyle(color: Color(0xFFDD1847), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteService(sid),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: const Color(0xFFF44336), borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text('Удалить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _openServiceModal(service: s),
        child: AnimatedScale(
          key: keyForCard,
          scale: isHighlight ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: AppCard.margin),
                padding: const EdgeInsets.all(AppCard.padding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppCard.radius),
                  boxShadow: AppCard.shadow,
                ),
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
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (s['online_booking'] ?? true) == true
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (s['online_booking'] ?? true) == true ? Icons.public : Icons.public_off,
                          size: 12,
                          color: (s['online_booking'] ?? true) == true
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF999999),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (s['online_booking'] ?? true) == true ? 'Онлайн' : 'Офлайн',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: (s['online_booking'] ?? true) == true
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
                      if (total > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${index + 1}/$total',
                            style: const TextStyle(fontSize: 10, color: Color(0xFFCCCCCC), fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ]),
              ),
              Positioned(
                top: -10,
                right: 14,
                child: IgnorePointer(
                  child: AnimatedSlide(
                    offset: isSuccess ? Offset.zero : const Offset(0, -0.4),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: isSuccess ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF4CAF50), width: 1.2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 13, color: Color(0xFF4CAF50)),
                            SizedBox(width: 4),
                            Text(
                              'Сохранено',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return reorderIndex == null
        ? card
        : ReorderableDelayedDragStartListener(
            key: ValueKey('reorder_$sid'),
            index: reorderIndex,
            child: card,
          );
  }

  Future<void> _deleteService(int serviceId) async {
    final result = await ApiService.post('/api/service/delete', {
      'service_id': serviceId,
      'project_id': widget.projectId,
    });
    if (result['success'] == true) {
      setState(() {
        _services.removeWhere((s) => s['id'] == serviceId);
        _serviceKeys.remove(serviceId);
      });
      if (mounted) showToast(context, 'Услуга удалена');
    } else {
      if (mounted) {
        showToast(context, result['message'] ?? 'Ошибка удаления', isError: true);
        _load();
      }
    }
  }

  Future<void> _openServiceModal({Map<String, dynamic>? service}) async {
    final savedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionAnimationController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
      builder: (_) => _ServiceFormSheet(
        projectId: widget.projectId,
        service: service,
        categories: _categories,
        onSaved: () {},
      ),
    );
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    _load(silent: true, highlightId: savedId);
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
  bool _editDataLoaded = false;
  List<String> _categoriesFromServer = [];

  Set<int> _employeeIds = {};
  Map<int, Map<String, dynamic>> _employeePrices = {};
  final Map<int, bool> _expandedEmployees = {};

  List<Map<String, dynamic>> _resources = [];
  Map<int, bool> _resourceStates = {};
  final List<File> _workPhotos = [];
  List<Map<String, dynamic>> _existingWorkPhotos = [];
  static const _maxWorkPhotos = 6;

  static const String _baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';

  bool get _isEdit => widget.service != null;
  List<String> get _allCategories => ['Без категории', ..._categoriesFromServer];

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

        debugPrint('SERVICE-EDIT: id=${s['id']}, employee_ids=${s['employee_ids']}, employee_prices=${s['employee_prices']}');
        _employeePrices = {};
        if (s['employee_prices'] != null) {
          final raw = s['employee_prices'];
          if (raw is Map) {
            raw.forEach((k, v) {
              final empId = int.tryParse(k.toString()) ?? 0;
              if (empId > 0 && v is Map) {
                _employeePrices[empId] = Map<String, dynamic>.from(v);
              }
            });
          }
          for (final empId in _employeePrices.keys) {
            if (!_employeeIds.contains(empId)) {
              _employeeIds.add(empId);
            }
          }
        }
        }
    if (_isEdit) {
      _loadEditData();
    } else {
      _editDataLoaded = true;
      _categoriesFromServer = List<String>.from(widget.categories);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ========== ЕДИНЫЙ ЗАПРОС: GET /api/service/edit-data ==========
  Future<void> _loadEditData() async {
    try {
      final r = await ApiService.get(
        '/api/service/edit-data?id=${widget.service!['id']}&project_id=${widget.projectId}',
      );
      if (r['success'] != true || !mounted) {
        if (mounted) setState(() => _editDataLoaded = true);
        return;
      }
      final d = Map<String, dynamic>.from(r['data'] ?? {});
      final svc = Map<String, dynamic>.from(d['service'] ?? {});
      setState(() {
        _photoUrl = svc['photo_url'] ?? _photoUrl;

        _employeePrices = {};
        final rawPrices = svc['employee_prices'];
        if (rawPrices is Map) {
          rawPrices.forEach((k, v) {
            final empId = int.tryParse(k.toString()) ?? 0;
            if (empId > 0 && v is Map) {
              _employeePrices[empId] = Map<String, dynamic>.from(v);
            }
          });
        }
        _employeeIds = Set<int>.from(
          (svc['employee_ids'] as List?)
                  ?.map((e) => int.tryParse(e.toString()) ?? 0)
                  .where((e) => e > 0) ??
              [],
        );

        final photos = d['work_photos'] as List?;
        if (photos != null) {
          _existingWorkPhotos = photos
              .where((p) => (p['photo_url'] ?? '').isNotEmpty)
              .map((p) => {'url': p['photo_url'] ?? '', 'id': p['id']})
              .toList();
        }

        _allEmployees = List<Map<String, dynamic>>.from(d['employees'] ?? []);

        _resources = List<Map<String, dynamic>>.from(d['resources'] ?? []);
        _resourceStates = {};
        for (final res in _resources) {
          final rid = int.tryParse(res['id'].toString()) ?? 0;
          _resourceStates[rid] = false;
        }
        final states = d['resources_for_service'];
        if (states is Map) {
          states.forEach((k, v) {
            final rid = int.tryParse(k.toString()) ?? 0;
            if (rid > 0) _resourceStates[rid] = v == true;
          });
        }

        _categoriesFromServer =
            List<String>.from(d['categories'] ?? _categoriesFromServer);

        _editDataLoaded = true;
      });
    } catch (e) {
      debugPrint('EDIT-DATA ERROR: \$e');
      if (mounted) setState(() => _editDataLoaded = true);
    }
  }

  Widget _employeesSkeletonRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          SkeletonBox(width: 40, height: 40, radius: 10),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 14),
                SizedBox(height: 6),
                SkeletonBox(width: 80, height: 12),
              ],
            ),
          ),
          SkeletonBox(width: 16, height: 16),
        ],
      ),
    );
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

        if (!mounted) return;
        Navigator.pop(context, serviceId);
        widget.onSaved();
        return;  // ← не доходим до setState в конце
      } else if (mounted) {
        showToast(context, result['message'] ?? 'Ошибка сохранения', isError: true);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка: $e', isError: true);
    }
    // Сюда попадаем только при ошибке (модалка ещё открыта).
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
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.55,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(children: [
                const Expanded(
                  child: Text('Категория', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ..._allCategories.map((c) => ListTile(
                        title: Text(c),
                        trailing: _category == c
                            ? const Icon(Icons.check, color: Color(0xFFDD1847))
                            : null,
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
                ],
              ),
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
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Иконка в красном кружке
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDD1847).withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.category_outlined, color: Color(0xFFDD1847), size: 26),
                  ),
                ),
                const SizedBox(height: 16),
                // Заголовок
                const Text(
                  'Новая категория',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Введите название — оно появится в списке фильтров',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF888888)),
                ),
                const SizedBox(height: 20),
                // Поле в стиле AppCard
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => FocusScope.of(ctx).unfocus(),
                  decoration: AppCard.inputDecoration(hint: 'Например: «Брови»'),
                ),
                const SizedBox(height: 20),
                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF666666),
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Отмена', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (ctrl.text.trim().isNotEmpty) {
                            setState(() {
                              widget.categories.add(ctrl.text.trim());
                              _category = ctrl.text.trim();
                            });
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDD1847),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Создать', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          child: SizedBox(
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
                child: (!_editDataLoaded)
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _employeesSkeletonRow(),
                          _employeesSkeletonRow(),
                          _employeesSkeletonRow(),
                        ],
                      )
                    : _allEmployees.isEmpty
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
              filled: true, fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDD1847), width: 1.5)),
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
          decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.access_time, size: 16, color: Color(0xFF999999)),
            const SizedBox(width: 6),
            Expanded(child: Text(prices['duration'] != null ? _formatDuration(prices['duration'] as int) : 'Общая длительность услуги', style: const TextStyle(fontSize: 12, color: Color(0xFF333333)))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]),
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
            activeThumbColor: const Color(0xFFDD1847),
          ),
        ]),
      ),
    ]);
  }

  void _showResourcePicker() async {
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
          child: SizedBox(
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
                                activeThumbColor: const Color(0xFFDD1847),
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
      child: SizedBox(
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
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                const SizedBox(height: 14),
                
                _block('Стоимость', [
                  Row(children: [const Text('Бесплатно'), const Spacer(), Switch(value: _isFree, onChanged: (v) => setState(() => _isFree = v), activeThumbColor: const Color(0xFFDD1847))]),
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
                const SizedBox(height: 14),
                
                _block('Время услуги', [
                  _row('Длительность', _formatDuration(_duration), () => _showTimePicker('Длительность', _duration, (m) => setState(() => _duration = m))),
                  _row('Перерыв после записи', _breakAfter > 0 ? _formatDuration(_breakAfter) : 'Нет', () => _showTimePicker('Перерыв', _breakAfter, (m) => setState(() => _breakAfter = m))),
                ]),
                const SizedBox(height: 14),
                
                _block('Сотрудники', [
                  if (_employeeIds.isEmpty)
                    _row('Сотрудники', 'Все сотрудники', _showEmployeePicker)
                  else if (!_editDataLoaded) ...[
                    _employeesSkeletonRow(),
                    _employeesSkeletonRow(),
                    _employeesSkeletonRow(),
                  ] else ...[
                    ..._employeeIds.map<Widget>((empId) {
                      final emp = _allEmployees.firstWhere(
                        (e) => e['id'] == empId,
                        orElse: () => {'id': empId, 'name': 'Сотрудник #$empId'},
                      );
                      final price = _employeePrices[empId];
                      final name = extractName(emp);
                      final priceVal = price?['price'];
                      final isFree = price?['is_free'] == true;
                      final priceFrom = price?['price_from'] == true;
                      final duration = price?['duration'] as int?;
                      final online = price?['online_booking'] != false;
                      final avatar = emp['avatar']?.toString();
                      return GestureDetector(
                        key: ValueKey('emp_$empId'),
                        onTap: () => _showEmployeePriceEdit(empId),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: (avatar != null && avatar.isNotEmpty)
                                    ? CachedNetworkImage(imageUrl: '$_baseUrl$avatar', width: 40, height: 40, fit: BoxFit.cover)
                                    : AvatarInitials(name: name, size: 40),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (isFree) 'Бесплатно'
                                        else if (priceVal != null) '${priceFrom ? 'от ' : ''}$priceVal ₽'
                                        else 'цена по услуге',
                                        if (duration != null) _formatDuration(duration),
                                        if (!online) 'офлайн',
                                      ].join(' · '),
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFCCCCCC)),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _showEmployeePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 16, color: Color(0xFFDD1847)),
                            SizedBox(width: 6),
                            Text('Добавить сотрудника', style: TextStyle(fontSize: 13, color: Color(0xFFDD1847), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ]),
                
                const SizedBox(height: 14),
                _block('Ресурсы', [
                  _row('Ресурсы', _resourceStates.values.where((v) => v).isEmpty ? 'Не выбрано' : 'Выбрано: ${_resourceStates.values.where((v) => v).length}', _showResourcePicker),
                ]),
                const SizedBox(height: 14),
                _block('Онлайн-запись', [
                  Row(children: [const Text('Онлайн-запись'), const Spacer(), Switch(value: _onlineBooking, onChanged: (v) => setState(() => _onlineBooking = v), activeThumbColor: const Color(0xFFDD1847))]),
                ]),
                const SizedBox(height: 14),
                _block('Примеры работ', [_buildWorkPhotos()]),
                const SizedBox(height: 14),
                _field(_descCtrl, 'Описание услуги...', maxLines: 3),
                const SizedBox(height: 14),
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
                          if (context.mounted) { Navigator.pop(context); widget.onSaved(); }
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

  Future<void> _showEmployeePriceEdit(int empId) async {
    final emp = _allEmployees.firstWhere(
      (e) => e['id'] == empId,
      orElse: () => {'id': empId, 'name': 'Сотрудник'},
    );
    final prices = _employeePrices[empId] ?? {};
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EmployeePriceSheet(
        empId: empId,
        empName: (emp['name'] ?? '').toString(),
        prices: prices,
        defaultDuration: _duration,
        onChanged: (updated) {
          setState(() {
            _employeePrices[empId] = updated;
          });
        },
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
      decoration: AppCard.inputDecoration(hint: hint),
    );
  }
}

// ==================== ОКНО РЕДАКТИРОВАНИЯ ЦЕНЫ СОТРУДНИКА ====================
class _EmployeePriceSheet extends StatefulWidget {
  final int empId;
  final String empName;
  final Map<String, dynamic> prices;
  final int defaultDuration;
  final void Function(Map<String, dynamic>) onChanged;

  const _EmployeePriceSheet({
    required this.empId,
    required this.empName,
    required this.prices,
    required this.defaultDuration,
    required this.onChanged,
  });

  @override
  State<_EmployeePriceSheet> createState() => _EmployeePriceSheetState();
}

class _EmployeePriceSheetState extends State<_EmployeePriceSheet> {
  late TextEditingController _priceCtrl;
  late bool _isFree;
  late bool _priceFrom;
  int? _duration;
  late bool _onlineBooking;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: (widget.prices['price'] ?? '').toString());
    _isFree = widget.prices['is_free'] == true;
    _priceFrom = widget.prices['price_from'] == true;
    _duration = widget.prices['duration'] as int?;
    _onlineBooking = widget.prices['online_booking'] != false;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onChanged({
      'price': _isFree ? null : _priceCtrl.text.trim(),
      'is_free': _isFree,
      'price_from': _priceFrom,
      'duration': _duration,
      'online_booking': _onlineBooking,
    });
    Navigator.pop(context);
  }

  String _fmtDuration(int? m) {
    if (m == null) return 'Общая длительность';
    final h = m ~/ 60;
    final mm = m % 60;
    if (h > 0 && mm > 0) return '$h ч $mm мин';
    if (h > 0) return '$h ч';
    return '$mm мин';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back),
                ),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.empName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Онлайн-запись', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Switch(
                      value: _onlineBooking,
                      onChanged: (v) => setState(() => _onlineBooking = v),
                      activeThumbColor: const Color(0xFFDD1847),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Бесплатно', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Switch(
                      value: _isFree,
                      onChanged: (v) => setState(() => _isFree = v),
                      activeThumbColor: const Color(0xFFDD1847),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!_isFree) ...[
                  Row(
                    children: [
                      const Text('Цена, ₽', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _priceFrom = !_priceFrom),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _priceFrom ? const Color(0xFFDD1847) : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'от',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _priceFrom ? Colors.white : const Color(0xFF888888),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: AppCard.inputDecoration(hint: '0'),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                GestureDetector(
                  onTap: () {
                    final current = _duration ?? widget.defaultDuration;
                    showTimePickerSheet(
                      context,
                      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
                      title: 'Длительность для сотрудника',
                    ).then((t) {
                      if (t != null) {
                        setState(() => _duration = t.hour * 60 + t.minute);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text('Длительность', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(_fmtDuration(_duration), style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
                      ],
                    ),
                  ),
                ),
                if (_duration != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _duration = null),
                    child: const Row(
                      children: [
                        Icon(Icons.close, size: 14, color: Color(0xFF999999)),
                        SizedBox(width: 4),
                        Text('Сбросить (использовать длительность услуги)', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD1847),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Сохранить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
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


// ===== Magic demo overlay: затемнение + 2 карточки + анимация перетаскивания =====
class _MagicDemoOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  final Widget Function(Map<String, dynamic>) buildCard;
  final VoidCallback onClose;

  const _MagicDemoOverlay({
    required this.services,
    required this.buildCard,
    required this.onClose,
  });

  @override
  State<_MagicDemoOverlay> createState() => _MagicDemoOverlayState();
}

class _MagicDemoOverlayState extends State<_MagicDemoOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _cardHeight = 84.0;
  static const double _gap = 12.0;
  static const double _swapDistance = _cardHeight + _gap;

  @override
  void initState() {
    super.initState();
    // Полный цикл 3 сек:
    //  0.0–0.30: swap (первая вниз, вторая вверх)
    //  0.30–0.40: пауза (видно результат)
    //  0.40–0.70: обратный swap
    //  0.70–1.0: пауза
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.services.length < 2) {
      return const SizedBox.shrink();
    }
    final top = widget.services[0];
    final below = widget.services[1];

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: SafeArea(
            child: Stack(
              children: [
                // Подсказка сверху (Flexible — чтобы не переполнялось)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 64, // место под крестик
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_fix_high, color: Color(0xFFDD1847), size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Зажмите и перетащите, чтобы изменить порядок',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Крестик справа сверху
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Color(0xFF1A1A1A), size: 22),
                    ),
                  ),
                ),

                // Карточки по центру — реальный swap
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final t = _controller.value;
                        // 0.0–0.30: свап туда
                        // 0.40–0.70: свап обратно
                        double progress = 0.0;
                        if (t < 0.30) {
                          progress = (t / 0.30).clamp(0.0, 1.0);
                        } else if (t < 0.40) {
                          progress = 1.0; // пауза
                        } else if (t < 0.70) {
                          progress = 1.0 - ((t - 0.40) / 0.30).clamp(0.0, 1.0);
                        } else {
                          progress = 0.0; // пауза
                        }
                        final curve = Curves.easeInOut.transform(progress);
                        final shift = curve * _swapDistance;

                        return SizedBox(
                          height: _cardHeight * 2 + _gap,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Нижняя карточка: опускается наверх (при swap — едет вверх)
                              Positioned(
                                top: _cardHeight + _gap - shift,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(child: widget.buildCard(below)),
                              ),
                              // Верхняя карточка: едет вниз
                              Positioned(
                                top: shift,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(child: widget.buildCard(top)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
