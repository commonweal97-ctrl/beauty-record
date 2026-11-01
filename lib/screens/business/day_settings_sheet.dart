import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/common/avatar_initials.dart';

/// Компактный BottomSheet «Настройки дня» — аналог Web DaySettingsModal.
/// Стиль — как в CreateBookingSheet (Container, Padding all 20, Divider, Footer height 52).
class DaySettingsSheet extends StatefulWidget {
  final int projectId;
  final String date;             // YYYY-MM-DD
  final VoidCallback? onSaved;

  const DaySettingsSheet({
    super.key,
    required this.projectId,
    required this.date,
    this.onSaved,
  });

  @override
  State<DaySettingsSheet> createState() => _DaySettingsSheetState();
}

class _DaySettingsSheetState extends State<DaySettingsSheet> {
  static const Color _accent = Color(0xFFDD1847);
  static const Color _text = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF666666);
  static const Color _lightMuted = Color(0xFF999999);
  static const Color _surface = Color(0xFFF8F8F8);
  static const Color _divider = Color(0xFFF0F0F0);

  int _step = 1;
  bool _loadingEmployees = false;
  bool _saving = false;
  String? _errorEmployees;

  List<Map<String, dynamic>> _employees = [];
  int? _selectedEmployeeId;
  Set<String> _selectedTimes = {};
  String? _expandedHour;
  String _employeeName = '';

  static const int _timeFrom = 9;
  static const int _timeTo = 18;
  static const int _stepMin = 30;

  String _formatDateHuman(String iso) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(iso)) return iso;
    final p = iso.split('-').map(int.parse).toList();
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${p[2]} ${months[p[1] - 1]} ${p[0]}';
  }

  List<String> _buildTimeGrid() {
    final out = <String>[];
    for (int h = _timeFrom; h <= _timeTo; h++) {
      for (int m = 0; m < 60; m += _stepMin) {
        if (h == _timeTo && m > 0) continue;
        out.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      }
    }
    return out;
  }

  Map<String, List<String>> _groupByHour() {
    final g = <String, List<String>>{};
    for (final t in _buildTimeGrid()) {
      g.putIfAbsent(t.substring(0, 2), () => <String>[]).add(t);
    }
    return g;
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _errorEmployees = null;
    });
    try {
      final res = await ApiService.get(
        '/api/employee/get-fixed-time-for-date?project_id=${widget.projectId}&date=${widget.date}',
      );
      final list = (res['data'] as List?) ?? const [];
      final parsed = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _employees = parsed;
        _loadingEmployees = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _loadingEmployees = false;
        _errorEmployees = e.message;
      });
    } catch (_) {
      setState(() {
        _loadingEmployees = false;
        _errorEmployees = 'Не удалось загрузить';
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _selectedEmployeeId == null) return;
    setState(() => _saving = true);
    try {
      final times = _selectedTimes.toList()..sort();
      await ApiService.post('/api/employee/save-fixed-time', {
        'project_id': widget.projectId,
        'employee_id': _selectedEmployeeId,
        'mode': 'specific',
        'specific_date': widget.date,
        'times': times,
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved?.call();
    } on ApiException catch (e) {
      debugPrint('[DSS._save] ApiException: status=${e.statusCode} | message=${e.message} | body=${e.body}');
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, '${e.statusCode}: ${e.message}', type: AppToastType.error);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, 'Не удалось сохранить', type: AppToastType.error);
    }
  }

  void _goBack() {
    setState(() {
      if (_step == 3) {
        _step = 2;
      } else if (_step == 2) {
        _step = 1;
      }
    });
  }

  String get _stepTitle {
    switch (_step) {
      case 1:
        return 'Настройки дня';
      case 2:
        return 'Кто настраивает?';
      case 3:
        return _employeeName;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Шапка
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _step == 1 ? () => Navigator.pop(context) : _goBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                    child: Icon(
                      _step == 1 ? Icons.close : Icons.arrow_back,
                      size: 24,
                      color: _muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _stepTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateHuman(widget.date),
                        style: const TextStyle(fontSize: 13, color: _lightMuted),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close, size: 24, color: _muted),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _divider),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStepBody(),
            ),
          ),

          // Footer
          SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 10 + bottomInset),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _divider)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: _buildFooterButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 1:
        return _buildEntryBody();
      case 2:
        return _buildEmployeesBody();
      case 3:
        return _buildTimesBody();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFooterButton() {
    if (_step == 1) {
      return ElevatedButton(
        onPressed: () {
          setState(() => _step = 2);
          _loadEmployees();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: const Color(0xFFCCCCCC),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Фиксированное время',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      );
    }
    if (_step == 2) {
      return ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: _surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Отмена',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _text),
        ),
      );
    }
    // step 3
    return ElevatedButton(
      onPressed: _saving ? null : _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        disabledBackgroundColor: const Color(0xFFCCCCCC),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _saving
          ? const SizedBox(
              height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text(
              'Сохранить',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
    );
  }

  // ─── Шаг 1 ──────────────────────────────────────────────────

  Widget _buildEntryBody() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.access_time_rounded, size: 48, color: _accent),
          const SizedBox(height: 16),
          const Text(
            'Фиксированное время',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _text),
          ),
          const SizedBox(height: 8),
          Text(
            'Настройте повторяющиеся слоты для мастера на ${_formatDateHuman(widget.date)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ─── Шаг 2 ──────────────────────────────────────────────────

  Widget _buildEmployeesBody() {
    if (_loadingEmployees) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
      );
    }
    if (_errorEmployees != null) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Text(_errorEmployees ?? 'Ошибка', style: const TextStyle(color: _muted, fontSize: 14)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadEmployees,
            child: const Text('Повторить', style: TextStyle(color: _accent, fontSize: 15)),
          ),
        ],
      );
    }
    if (_employees.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('В проекте нет сотрудников', style: TextStyle(fontSize: 14, color: _muted))),
      );
    }
    return Column(
      children: _employees.map((e) {
        final id = (e['id'] as num?)?.toInt() ?? 0;
        final name = (e['name'] as String?) ?? ('#$id');
        return GestureDetector(
          onTap: () {
            final ft = (e['fixed_time'] as Map?) ?? const {};
            final times = ((ft['times'] as List?) ?? const []).map((x) => x.toString()).toSet();
            setState(() {
              _selectedEmployeeId = id;
              _employeeName = name;
              _selectedTimes = times;
              _step = 3;
              _expandedHour = times.isNotEmpty ? (times.toList()..sort()).first.substring(0, 2) : null;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AvatarInitials(name: name, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _text),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 22, color: _lightMuted),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Шаг 3 ──────────────────────────────────────────────────

  Widget _buildTimesBody() {
    final grouped = _groupByHour();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Время (09:00 – 18:00)',
          style: const TextStyle(fontSize: 14, color: _muted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map((entry) => _buildHourRow(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildHourRow(String hour, List<String> slots) {
    final expanded = _expandedHour == hour;
    final selectedInHour = slots.where(_selectedTimes.contains).length;
    final hourSelected = selectedInHour > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expandedHour = expanded ? null : hour),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: hourSelected ? const Color(0xFFFDF2F5) : _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hourSelected ? _accent : Colors.transparent),
            ),
            child: Row(
              children: [
                Text(
                  '$hour:00',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: hourSelected ? _accent : _text,
                  ),
                ),
                if (selectedInHour > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(100)),
                    child: Text(
                      '$selectedInHour',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: _lightMuted,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: slots.map((t) {
                final active = _selectedTimes.contains(t);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (active) _selectedTimes.remove(t);
                      else _selectedTimes.add(t);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? _accent : const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? Colors.transparent : _divider),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: active ? Colors.white : _text,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
