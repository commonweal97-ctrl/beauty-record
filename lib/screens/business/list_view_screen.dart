import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../utils/phone_display.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../widgets/toast.dart';

class ListViewScreen extends StatefulWidget {
  final int projectId;
  final Function(int)? onRecordTap;
  const ListViewScreen({super.key, required this.projectId, this.onRecordTap});

  @override
  State<ListViewScreen> createState() => _ListViewScreenState();
}

class _ListViewScreenState extends State<ListViewScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _allEmployees = [];
  bool _loading = true;
  String _activeFilter = 'all';
  String _sortBy = 'created_at';
  final Set<int> _selectedEmployeeIds = {};
  bool _hasActiveFilters = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadEmployees();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      final lastDay = DateTime(now.year, now.month + 1, 0).day;
      final endDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-$lastDay';

      final result = await ApiService.get(
          '/api/booking/list?project_id=${widget.projectId}&date=$startDate&end_date=$endDate');
      if (result['success'] == true && mounted) {
        List<Map<String, dynamic>> items =
            List<Map<String, dynamic>>.from(result['data'] ?? []);

        // Фильтры
        if (_activeFilter == 'upcoming') {
          final today = DateTime.now().toIso8601String().substring(0, 10);
          items = items
              .where((i) =>
                  i['date'].toString().compareTo(today) >= 0 &&
                  i['status'] != 'cancelled')
              .toList();
        } else if (_activeFilter == 'completed') {
          items = items.where((i) => i['status'] == 'completed').toList();
        } else if (_activeFilter == 'cancelled') {
          items = items.where((i) => i['status'] == 'cancelled').toList();
        }

        if (_selectedEmployeeIds.isNotEmpty) {
          items = items
              .where((i) => _selectedEmployeeIds.contains(i['employee_id']))
              .toList();
        }

        // Сортировка
        if (_sortBy == 'date') {
          items.sort((a, b) {
            final dateCompare = '${a['date']}${a['start_time']}'
                .compareTo('${b['date']}${b['start_time']}');
            if (dateCompare != 0) return dateCompare;
            return (a['start_time'] as String)
                .compareTo(b['start_time'] as String);
          });
        } else {
          items.sort(
              (a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
        }

        setState(() {
          _items = items;
          _loading = false;
          _hasActiveFilters =
              _sortBy != 'created_at' || _selectedEmployeeIds.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadEmployees() async {
    try {
      final result = await ApiService.get(
          '/api/employee/list?project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        setState(() => _allEmployees =
            List<Map<String, dynamic>>.from(result['data'] ?? []));
      }
    } on ApiException catch (e) { if (mounted) showToast(context, e.message, isError: true); }
  }

  String _formatDate(String? d) {
    if (d == null) return '';
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    final parts = d.split('-');
    if (parts.length == 3) {
      return '${int.parse(parts[2])} ${months[int.parse(parts[1]) - 1]}';
    }
    return d;
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        sortBy: _sortBy,
        selectedEmployeeIds: _selectedEmployeeIds,
        employees: _allEmployees,
        projectId: widget.projectId,
        onApply: (sortBy, selectedIds) {
          setState(() {
            _sortBy = sortBy;
            _selectedEmployeeIds.clear();
            _selectedEmployeeIds.addAll(selectedIds);
          });
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Фильтры
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Кнопка расширенных фильтров
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      size: 20,
                      color: _hasActiveFilters
                          ? const Color(0xFFDD1847)
                          : const Color(0xFF666666),
                    ),
                    onPressed: _openFilterModal,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDD1847),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              // Табы фильтров
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _filterChip('Все записи', 'all'),
                    _filterChip('Предстоящие', 'upcoming'),
                    _filterChip('Завершённые', 'completed'),
                    _filterChip('Отменённые', 'cancelled'),
                  ]),
                ),
              ),
            ],
          ),
        ),
        // Список
        Expanded(
          child: _loading
              ? _buildSkeletonList()
              : _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 400,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.note_add_outlined,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                const Text('Нет записей',
                                    style: TextStyle(
                                        fontSize: 16, color: Color(0xFF999999))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      color: const Color(0xFFDD1847),
                      onRefresh: () async {
                        await _load();
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _AnimatedListItem(
                          index: i,
                          child: _buildItem(_items[i]),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String filter) {
    final active = _activeFilter == filter;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () {
          setState(() => _activeFilter = filter);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFDD1847) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: const Color(0xFFDD1847).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final color = _parseColor(item['color'] as String? ?? '#DD1847');
    final statusLabels = {
      'pending': 'Ожидает',
      'confirmed': 'Подтверждена',
      'completed': 'Завершена',
      'cancelled': 'Отменена'
    };
    final services = (item['services'] as List?)
            ?.map((s) => s['name'])
            .join(', ') ??
        item['service_names'] ??
        '—';
    final isNewClient =
        (item['client_visits'] ?? 0) <= 2 && item['status'] == 'confirmed';
    final confirmedByClient =
        item['confirmed_by_client'] == 1 && item['status'] == 'confirmed';
    final createdAt = item['created_at'] != null
        ? _formatDateTime(item['created_at'] as String)
        : '—';

    return GestureDetector(
      onTap: () => widget.onRecordTap?.call(item['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => widget.onRecordTap?.call(item['id']),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Верхняя строка: дата/время и статус
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '${_formatDate(item['date'])} ${(item['start_time'] as String).substring(0, 5)} – ${(item['end_time'] as String).substring(0, 5)}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A)),
                        ),
                      ),
                      if (confirmedByClient)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4EDDA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('✓ Подтверждено',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF155724),
                                  fontWeight: FontWeight.w500)),
                        )
                      else if (item['status'] != 'confirmed')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(
                                item['status'] as String? ?? 'confirmed'),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabels[item['status']] ??
                                item['status'] ??
                                '',
                            style: TextStyle(
                                fontSize: 12,
                                color: _statusTextColor(
                                    item['status'] as String? ?? 'confirmed'),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (isNewClient) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Новый клиент',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Имя клиента
                  Text(item['client_name'] ?? '—',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  // Телефон
                  Text(
                    (item['client_phone'] ?? '').toString().isNotEmpty
                        ? formatPhoneDisplay(item['client_phone'].toString())
                        : '—',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 4),
                  // Сотрудник
                  Text(item['employee_name'] ?? '—',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFDD1847),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  // Услуги
                  Text(services,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 8),
                  // Дата создания
                  Text('создана: $createdAt',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF999999))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFF3CD);
      case 'confirmed':
        return const Color(0xFFD4EDDA);
      case 'completed':
        return const Color(0xFFD1ECF1);
      case 'cancelled':
        return const Color(0xFFF8D7DA);
      default:
        return const Color(0xFFD4EDDA);
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFF856404);
      case 'confirmed':
        return const Color(0xFF155724);
      case 'completed':
        return const Color(0xFF0C5460);
      case 'cancelled':
        return const Color(0xFF721C24);
      default:
        return const Color(0xFF155724);
    }
  }

  String _formatDateTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: 3,
      itemBuilder: (_, i) {
        return AnimatedOpacity(
          opacity: 1.0,
          duration: Duration(milliseconds: 300 + (i * 50)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Дата и статус
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(
                        width: 140 + (i * 20).toDouble(),
                        height: 16,
                        radius: 7),
                    SkeletonBox(
                        width: 90 + (i * 10).toDouble(),
                        height: 22,
                        radius: 11),
                  ],
                ),
                const SizedBox(height: 12),
                // Имя
                SkeletonBox(
                    width: 180 + (i * 15).toDouble(), height: 18, radius: 7),
                const SizedBox(height: 10),
                // Телефон
                SkeletonBox(
                    width: 140 + (i * 10).toDouble(), height: 15, radius: 7),
                const SizedBox(height: 10),
                // Сотрудник
                SkeletonBox(
                    width: 120 + (i * 15).toDouble(), height: 15, radius: 7),
                const SizedBox(height: 10),
                // Услуги
                SkeletonBox(
                    width: 200 + (i * 10).toDouble(), height: 15, radius: 7),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Анимированное появление элемента списка
class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedListItem({required this.index, required this.child});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(-0.05, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: 20 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

// Модальное окно расширенных фильтров
class _FilterSheet extends StatefulWidget {
  final String sortBy;
  final Set<int> selectedEmployeeIds;
  final List<Map<String, dynamic>> employees;
  final int projectId;
  final Function(String sortBy, Set<int> selectedIds) onApply;

  const _FilterSheet({
    required this.sortBy,
    required this.selectedEmployeeIds,
    required this.employees,
    required this.projectId,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _sortBy;
  late Set<int> _selectedIds;
  String _employeeTab = 'all';
  List<Map<String, dynamic>> _loadedEmployees = [];
  bool _employeesLoading = true;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
    _selectedIds = Set<int>.from(widget.selectedEmployeeIds);
    _loadEmployeesForFilter();
  }

  void _loadEmployeesForFilter() async {
    // Если сотрудники уже переданы — используем их
    if (widget.employees.isNotEmpty) {
      setState(() {
        _loadedEmployees = widget.employees;
        _employeesLoading = false;
      });
      return;
    }

    // Иначе загружаем
    try {
      final result = await ApiService.get(
          '/api/employee/list?project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        setState(() {
          _loadedEmployees =
              List<Map<String, dynamic>>.from(result['data'] ?? []);
          _employeesLoading = false;
        });
      } else {
        setState(() => _employeesLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _employeesLoading = false);
    }
  }

  void _resetFilters() {
    setState(() {
      _sortBy = 'created_at';
      _selectedIds.clear();
      _employeeTab = 'all';
    });
  }

  void _applyFilters() {
    widget.onApply(_sortBy, _selectedIds);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Хедер
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back,
                      size: 24, color: Color(0xFF666666)),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text('Фильтры',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close,
                      size: 24, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Тело
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Сортировка
                  const Text('СОРТИРОВКА',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF888888),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  _sortOption('По дате изменения', 'created_at'),
                  _sortOption('По дате записи', 'date'),
                  const SizedBox(height: 24),
                  // Сотрудники
                  const Text('СОТРУДНИКИ',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF888888),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  // Табы внутри фильтра
                  Row(
                    children: [
                      _employeeTabChip('Все', 'all'),
                      const SizedBox(width: 8),
                      _employeeTabChip('По категориям', 'categories'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Список сотрудников
                  if (_employeesLoading)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFFDD1847))))
                  else if (_loadedEmployees.isEmpty)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Сотрудники не найдены',
                                style: TextStyle(color: Color(0xFF999999)))))
                  else
                    ..._filteredEmployees.map((e) => _employeeItem(e)),
                  const SizedBox(height: 12),
                  // Кнопка выбрать всех
                  if (_loadedEmployees.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_selectedIds.length == _loadedEmployees.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds = _loadedEmployees
                                .map((e) => e['id'] as int)
                                .toSet();
                          }
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFFDD1847),
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _selectedIds.length == _loadedEmployees.length
                              ? 'Снять выбор'
                              : 'Выбрать всех',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFDD1847)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Футер
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _resetFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Сбросить',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF666666))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _applyFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDD1847),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Применить',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
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

  Widget _sortOption(String label, String value) {
    final active = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
          border: Border.all(
              color: active ? const Color(0xFFDD1847) : Colors.transparent,
              width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500))),
            if (active)
              const Icon(Icons.check, size: 20, color: Color(0xFFDD1847)),
          ],
        ),
      ),
    );
  }

  Widget _employeeTabChip(String label, String value) {
    final active = _employeeTab == value;
    return GestureDetector(
      onTap: () => setState(() => _employeeTab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFDD1847) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : const Color(0xFF666666))),
      ),
    );
  }

  Widget _employeeItem(Map<String, dynamic> emp) {
    final id = emp['id'] as int;
    final selected = _selectedIds.contains(id);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedIds.remove(id);
          } else {
            _selectedIds.add(id);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
          border: Border.all(
              color: selected ? const Color(0xFFDD1847) : Colors.transparent,
              width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Чекбокс
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected
                        ? const Color(0xFFDD1847)
                        : const Color(0xFFDDDDDD),
                    width: 2),
                color: selected
                    ? const Color(0xFFDD1847)
                    : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            // Аватар
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE8E8E8),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedAvatar(
                url: emp['avatar'],
                size: 40,
                radius: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Инфо
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${emp['first_name']} ${emp['last_name']}'.trim(),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  Text(emp['position'] ?? emp['category'] ?? 'Мастер',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF888888))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    if (_employeeTab == 'categories') {
      return _loadedEmployees;
    }
    return _loadedEmployees;
  }
}