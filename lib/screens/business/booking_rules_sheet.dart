// booking_rules_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';

// ==================== ПРАВИЛА БРОНИРОВАНИЯ (СПИСОК) ====================
class BookingRulesSheet extends StatefulWidget {
  final int projectId;
  const BookingRulesSheet({super.key, required this.projectId});
  @override
  State<BookingRulesSheet> createState() => _BookingRulesSheetState();
}

class _BookingRulesSheetState extends State<BookingRulesSheet> {
  List<Map<String, dynamic>> _rules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.get('/api/project-profile/get-booking-rules?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        setState(() {
          _rules = List<Map<String, dynamic>>.from(r['data'] ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openRuleEditor({Map<String, dynamic>? rule}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RuleEditorScreen(projectId: widget.projectId, rule: rule),
      ),
    );
    if (result == true) _load();
  }

  void _openOfertaEditor() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OfertaEditorScreen(projectId: widget.projectId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeLabels = {'cancel': 'Отмена или перенос', 'no_show': 'Неявка', 'warning': 'Предупреждение'};
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Правила бронирования', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: 4,
                    itemBuilder: (_, i) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonBox(height: 14, width: 150),
                              const SizedBox(height: 6),
                              const SkeletonBox(height: 12, width: 100),
                            ],
                          ),
                        ),
                        const SkeletonBox(width: 20, height: 20, radius: 4),
                      ]),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Правила бронирования, оферта и пользовательское соглашение, с которыми клиент может ознакомиться во время онлайн-записи.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _openOfertaEditor,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF0F0F0)),
                          ),
                          child: Row(
                            children: [
                              const Text('Оферта', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const Spacer(),
                              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Правила бронирования', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._rules.map(
                        (rule) => GestureDetector(
                          onTap: () => _openRuleEditor(rule: rule),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(rule['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                      Text(
                                        typeLabels[rule['type']] ?? rule['type'] ?? '',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openRuleEditor(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Создать правило'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDD1847),
                          side: const BorderSide(color: Color(0xFFDD1847), style: BorderStyle.solid),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ==================== РЕДАКТОР ПРАВИЛА ====================
class RuleEditorScreen extends StatefulWidget {
  final int projectId;
  final Map<String, dynamic>? rule;
  const RuleEditorScreen({super.key, required this.projectId, this.rule});
  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen> {
  final _nameCtrl = TextEditingController();
  String _type = 'cancel';
  String _limitType = 'ban';
  bool _banAlways = true;
  int _banValue = 1;
  String _banUnit = 'days';
  String? _warningText;
  String? _fineAmount;
  String _fineUnit = 'rub';
  bool _saving = false;
  bool _isEdit = false;

  Map<String, dynamic> _conditions = {
    'services': {'all': true, 'mode': 'specific', 'selectedIds': [], 'selectedCategories': []},
    'employees': {'all': true, 'mode': 'specific', 'selectedIds': [], 'selectedCategories': []},
    'clients': {'all': true, 'mode': 'specific', 'selectedIds': [], 'selectedCategories': []},
    'period': {'noLimit': true, 'dateRange': null, 'months': [], 'weekdays': [], 'monthDays': [], 'hours': []},
  };

  @override
  void initState() {
    super.initState();
    _isEdit = widget.rule != null;
    if (_isEdit) {
      final r = widget.rule!;
      _nameCtrl.text = r['name'] ?? '';
      _type = r['type'] ?? 'cancel';
      final config = r['config'] as Map? ?? {};
      _limitType = config['limit_type'] ?? 'ban';
      _banAlways = config['ban_always'] != false;
      _banValue = config['ban_value'] ?? 1;
      _banUnit = config['ban_unit'] ?? 'days';
      _warningText = config['warning_text'];
      _fineAmount = config['fine_amount']?.toString();
      _fineUnit = config['fine_unit'] ?? 'rub';
      if (r['conditions'] != null) _conditions = Map<String, dynamic>.from(r['conditions']);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showToast(context, 'Введите название', isError: true);
      return;
    }
    setState(() => _saving = true);
    final config = <String, dynamic>{};
    if (_type == 'cancel') {
      config['limit_type'] = _limitType;
      if (_limitType == 'ban') {
        config['ban_always'] = _banAlways;
        if (!_banAlways) {
          config['ban_value'] = _banValue;
          config['ban_unit'] = _banUnit;
        }
      }
    } else if (_type == 'no_show') {
      config['fine_amount'] = _fineAmount;
      config['fine_unit'] = _fineUnit;
    } else if (_type == 'warning') {
      config['warning_text'] = _warningText;
    }
    try {
      await ApiService.post('/api/project-profile/save-booking-rule', {
        'project_id': widget.projectId,
        'id': widget.rule?['id'],
        'name': _nameCtrl.text.trim(),
        'type': _type,
        'conditions': _conditions,
        ...config,
      });
      if (mounted) {
        showToast(context, 'Правило сохранено');
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) showToast(context, 'Ошибка сохранения', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final c = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить правило?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (c == true) {
      try {
        await ApiService.post('/api/project-profile/delete-booking-rule', {
          'id': widget.rule!['id'],
          'project_id': widget.projectId,
        });
        if (mounted) {
          showToast(context, 'Правило удалено');
          Navigator.pop(context, true);
        }
      } catch (_) {
        if (mounted) showToast(context, 'Ошибка удаления', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? 'Редактировать правило' : 'Создать правило',
          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: ['cancel', 'no_show', 'warning'].map((t) {
                    final labels = {'cancel': 'Отмена', 'no_show': 'Неявка', 'warning': 'Предупр.'};
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = t),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _type == t ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _type == t ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Text(
                            labels[t]!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _type == t ? const Color(0xFFDD1847) : const Color(0xFF666666),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Название правила',
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                if (_type == 'cancel') ...[
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _limitType = 'ban'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _limitType == 'ban' ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _limitType == 'ban' ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: const Text('Запрет',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _limitType = 'fine'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _limitType == 'fine' ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _limitType == 'fine' ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: const Text('Штраф',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_limitType == 'ban') ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Всегда'),
                      value: _banAlways,
                      onChanged: (v) => setState(() => _banAlways = v),
                      activeColor: const Color(0xFFDD1847),
                    ),
                    if (!_banAlways)
                      Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: TextEditingController(text: '$_banValue'),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              onChanged: (v) => _banValue = int.tryParse(v) ?? 1,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8F8F8),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _banUnit,
                            items: const [
                              DropdownMenuItem(value: 'days', child: Text('Дней')),
                              DropdownMenuItem(value: 'hours', child: Text('Часов')),
                            ],
                            onChanged: (v) => setState(() => _banUnit = v!),
                          ),
                        ],
                      ),
                  ],
                ] else if (_type == 'no_show') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: _fineAmount),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _fineAmount = v,
                          decoration: InputDecoration(
                            hintText: 'Сумма',
                            filled: true,
                            fillColor: const Color(0xFFF8F8F8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _fineUnit,
                        items: const [
                          DropdownMenuItem(value: 'rub', child: Text('₽')),
                          DropdownMenuItem(value: 'percent', child: Text('%')),
                        ],
                        onChanged: (v) => setState(() => _fineUnit = v!),
                      ),
                    ],
                  ),
                ] else if (_type == 'warning') ...[
                  TextField(
                    controller: TextEditingController(text: _warningText),
                    maxLines: 3,
                    onChanged: (v) => _warningText = v,
                    decoration: InputDecoration(
                      hintText: 'Текст предупреждения',
                      filled: true,
                      fillColor: const Color(0xFFF8F8F8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text('Условия применения', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _ConditionBlock(
                  label: 'Услуги',
                  type: 'services',
                  projectId: widget.projectId,
                  conditions: _conditions,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 8),
                _ConditionBlock(
                  label: 'Сотрудники',
                  type: 'employees',
                  projectId: widget.projectId,
                  conditions: _conditions,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 8),
                _ConditionBlock(
                  label: 'Клиенты',
                  type: 'clients',
                  projectId: widget.projectId,
                  conditions: _conditions,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 8),
                _PeriodBlock(
                  conditions: _conditions,
                  onChanged: () => setState(() {}),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF44336),
                        side: const BorderSide(color: Color(0xFFFCE4E4)),
                      ),
                      child: const Text('Удалить правило'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD1847),
                  disabledBackgroundColor: const Color(0xFFDD1847),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                          SizedBox(width: 12),
                          Text('Сохранение...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      )
                    : const Text('Сохранить правило', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ВИДЖЕТ УСЛОВИЙ ====================
class _ConditionBlock extends StatefulWidget {
  final String label;
  final String type;
  final int projectId;
  final Map<String, dynamic> conditions;
  final VoidCallback onChanged;
  const _ConditionBlock({
    required this.label,
    required this.type,
    required this.projectId,
    required this.conditions,
    required this.onChanged,
  });
  @override
  State<_ConditionBlock> createState() => _ConditionBlockState();
}

class _ConditionBlockState extends State<_ConditionBlock> {
  List<Map<String, dynamic>> _items = [];
  String _searchQuery = '';
  bool _loading = false;

  Map<String, dynamic> get _cond => widget.conditions[widget.type] as Map<String, dynamic>;
  bool get _all => _cond['all'] == true;
  String get _mode => _cond['mode'] ?? 'specific';

  @override
  void initState() {
    super.initState();
    if (!_all) _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      String url;
      switch (widget.type) {
        case 'services':
          url = '/api/service/list?project_id=${widget.projectId}';
          break;
        case 'employees':
          url = '/api/employee/list?project_id=${widget.projectId}';
          break;
        case 'clients':
          url = '/api/client/list?project_id=${widget.projectId}';
          break;
        default:
          url = '';
      }
      final r = await ApiService.get(url);
      if (r['success'] == true && mounted) {
        final data = List<Map<String, dynamic>>.from(r['data'] ?? []);
        if (_mode == 'specific') {
          setState(() {
            _items = data.map((item) {
              String name;
              if (widget.type == 'services') {
                name = item['name'] ?? '';
              } else if (widget.type == 'employees') {
                name = '${item['last_name'] ?? ''} ${item['first_name'] ?? ''}'.trim();
              } else {
                name = item['name'] ?? '';
              }
              return {
                'id': item['id'],
                'name': name,
                'photo_url': item['photo_url'] ?? item['avatar'],
              };
            }).toList();
          });
        } else {
          final categories = <String>{};
          for (final item in data) {
            if (widget.type == 'clients') {
              if (item['group_name'] != null) categories.add(item['group_name']);
            } else {
              if (item['category'] != null) categories.add(item['category']);
            }
          }
          if (widget.type == 'clients' && categories.isEmpty) {
            categories.addAll(['regular', 'sleeping', 'lost', 'never', 'blocked', 'new']);
          }
          setState(() {
            _items = categories.map((c) => {'id': c, 'name': c}).toList();
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleAll(bool v) {
    setState(() {
      _cond['all'] = v;
      if (!v) _loadItems();
    });
    widget.onChanged();
  }

  void _switchMode(String mode) {
    setState(() {
      _cond['mode'] = mode;
      _cond['selectedIds'] = [];
      _cond['selectedCategories'] = [];
      _loadItems();
    });
    widget.onChanged();
  }

  void _toggleItem(dynamic id, String name) {
    setState(() {
      if (_mode == 'specific') {
        final list = _cond['selectedIds'] as List;
        if (list.contains(id)) {
          list.remove(id);
        } else {
          list.add(id);
        }
      } else {
        final list = _cond['selectedCategories'] as List;
        if (list.contains(name)) {
          list.remove(name);
        } else {
          list.add(name);
        }
      }
    });
    widget.onChanged();
  }

  bool _isSelected(dynamic id, String name) {
    if (_mode == 'specific') {
      return (_cond['selectedIds'] as List).contains(id);
    } else {
      return (_cond['selectedCategories'] as List).contains(name);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((item) => item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final labels = {
      'services': {'specific': 'Конкретные услуги', 'category': 'Категории услуг'},
      'employees': {'specific': 'Конкретные сотрудники', 'category': 'Категории сотрудников'},
      'clients': {'specific': 'Конкретные клиенты', 'group': 'Группы клиентов'},
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              Switch(value: _all, onChanged: _toggleAll, activeColor: const Color(0xFFDD1847)),
            ],
          ),
          if (!_all) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchMode('specific'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _mode == 'specific' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        labels[widget.type]!['specific']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _mode == 'specific' ? const Color(0xFFDD1847) : const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchMode(widget.type == 'clients' ? 'group' : 'category'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _mode != 'specific' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.type == 'clients' ? labels[widget.type]!['group']! : labels[widget.type]!['category']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _mode != 'specific' ? const Color(0xFFDD1847) : const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF999999)),
                hintText: _mode == 'specific'
                    ? 'Поиск...'
                    : widget.type == 'clients'
                        ? 'Поиск групп...'
                        : 'Поиск категорий...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkeletonCircle(size: 32),
                      SizedBox(height: 8),
                      SkeletonBox(height: 12, width: 120),
                    ],
                  ),
                ),
              )
            else
              ..._filteredItems.map((item) {
                final selected = _isSelected(item['id'], item['name']);
                return GestureDetector(
                  onTap: () => _toggleItem(item['id'], item['name']),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFDF2F5) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFFDD1847) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: selected ? const Color(0xFFDD1847) : const Color(0xFFDDDDDD)),
                          ),
                          child: selected
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['name'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selected ? const Color(0xFFDD1847) : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}

// ==================== ВИДЖЕТ ПЕРИОДА ====================
class _PeriodBlock extends StatefulWidget {
  final Map<String, dynamic> conditions;
  final VoidCallback onChanged;
  const _PeriodBlock({required this.conditions, required this.onChanged});
  @override
  State<_PeriodBlock> createState() => _PeriodBlockState();
}

class _PeriodBlockState extends State<_PeriodBlock> {
  Map<String, dynamic> get _cond => widget.conditions['period'] as Map<String, dynamic>;
  bool get _noLimit => _cond['noLimit'] == true;

  static const _months = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];
  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  void _toggleChip(String key, dynamic value) {
    setState(() {
      final list = _cond[key] as List;
      if (list.contains(value)) {
        list.remove(value);
      } else {
        list.add(value);
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = _cond['dateRange'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Период', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              Switch(
                value: _noLimit,
                onChanged: (v) {
                  setState(() => _cond['noLimit'] = v);
                  widget.onChanged();
                },
                activeColor: const Color(0xFFDD1847),
              ),
            ],
          ),
          if (!_noLimit) ...[
            const SizedBox(height: 4),
            const Text(
              'Все настройки периода работают в связке «И». Внутри блока вы настраиваете значения, которые будут работать «ИЛИ»',
              style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
            ),
            const SizedBox(height: 12),
            const Text('Период времени', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'С',
                    value: dateRange?['from'],
                    onChanged: (v) {
                      setState(() {
                        _cond['dateRange'] ??= {'from': null, 'to': null};
                        _cond['dateRange']['from'] = v;
                      });
                      widget.onChanged();
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('—', style: TextStyle(color: Color(0xFF999999))),
                ),
                Expanded(
                  child: _DateField(
                    label: 'По',
                    value: dateRange?['to'],
                    onChanged: (v) {
                      setState(() {
                        _cond['dateRange'] ??= {'from': null, 'to': null};
                        _cond['dateRange']['to'] = v;
                      });
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Месяцы', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(12, (i) {
                final sel = (_cond['months'] as List).contains(i);
                return GestureDetector(
                  onTap: () => _toggleChip('months', i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFDD1847) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: sel ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Text(
                      _months[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : const Color(0xFF666666),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text('Дни недели', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(7, (i) {
                final sel = (_cond['weekdays'] as List).contains(i + 1);
                return GestureDetector(
                  onTap: () => _toggleChip('weekdays', i + 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFDD1847) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: sel ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Text(
                      _weekdays[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : const Color(0xFF666666),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text('Дни месяца', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(31, (i) {
                final day = i + 1;
                final sel = (_cond['monthDays'] as List).contains(day);
                return GestureDetector(
                  onTap: () => _toggleChip('monthDays', day),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFDD1847) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: sel ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : const Color(0xFF666666),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text('Часы', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(24, (i) {
                final hour = '${i.toString().padLeft(2, '0')}:00';
                final sel = (_cond['hours'] as List).contains(hour);
                return GestureDetector(
                  onTap: () => _toggleChip('hours', hour),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFDD1847) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: sel ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Text(
                      hour,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : const Color(0xFF666666),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== ПОЛЕ ВЫБОРА ДАТЫ (САМОДЕЛЬНЫЙ КАЛЕНДАРЬ) ====================
class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DateField({
    required this.label,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCalendar(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? label,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null ? const Color(0xFF1A1A1A) : const Color(0xFF999999),
                ),
              ),
            ),
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF999999)),
          ],
        ),
      ),
    );
  }

  void _showCalendar(BuildContext context) {
    DateTime selected = value != null ? DateTime.tryParse(value!) ?? DateTime.now() : DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final year = selected.year;
          final month = selected.month;
          final daysInMonth = DateTime(year, month + 1, 0).day;
          final firstDay = DateTime(year, month, 1).weekday % 7;
          final today = DateTime.now();
          final months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
          final weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setModalState(() => selected = DateTime(year, month - 1, selected.day)),
                    ),
                    Text(
                      '${months[month - 1]} $year',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setModalState(() => selected = DateTime(year, month + 1, selected.day)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: weekdays.map((d) => Expanded(
                    child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: d == 'Сб' || d == 'Вс' ? const Color(0xFFDD1847) : const Color(0xFF999999))),
                  )).toList(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  children: [
                    for (int i = 0; i < firstDay; i++)
                      SizedBox(width: (MediaQuery.of(context).size.width - 40) / 7, height: 40),
                    for (int day = 1; day <= daysInMonth; day++)
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 40) / 7,
                        height: 40,
                        child: GestureDetector(
                          onTap: () {
                            onChanged('$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}');
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: selected.day == day ? const Color(0xFFDD1847) : (today.day == day && today.month == month && today.year == year ? const Color(0xFFFDF2F5) : Colors.transparent),
                              borderRadius: BorderRadius.circular(20),
                              border: today.day == day && today.month == month && today.year == year && selected.day != day
                                  ? Border.all(color: const Color(0xFFDD1847), width: 1.5)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected.day == day ? FontWeight.w600 : FontWeight.w400,
                                  color: selected.day == day ? Colors.white : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================== РЕДАКТОР ОФЕРТЫ ====================
class OfertaEditorScreen extends StatefulWidget {
  final int projectId;
  const OfertaEditorScreen({super.key, required this.projectId});
  @override
  State<OfertaEditorScreen> createState() => _OfertaEditorScreenState();
}

class _OfertaEditorScreenState extends State<OfertaEditorScreen> {
  final _ctrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.get('/api/project-profile/get-online-design?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        _ctrl.text = r['data']?['oferta_text'] ?? '';
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      await ApiService.post('/api/project-profile/save-online-design', {
        'project_id': widget.projectId,
        'oferta_text': _ctrl.text,
      });
      if (mounted) {
        showToast(context, 'Оферта сохранена');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showToast(context, 'Ошибка сохранения', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Оферта', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: 'Введите текст оферты...',
                        filled: true,
                        fillColor: const Color(0xFFF8F8F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDD1847),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Сохранить',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}