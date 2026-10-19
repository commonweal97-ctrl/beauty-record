import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/common/avatar_initials.dart';
import 'fixed_time_settings_sheet.dart';
import 'booking_rules_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/app_logger.dart';

class OnlineBookingScreen extends StatefulWidget {
  final int projectId;
  final void Function(String page)? onNavigate;
  const OnlineBookingScreen({
    super.key,
    required this.projectId,
    this.onNavigate,
  });

  @override
  State<OnlineBookingScreen> createState() => _OnlineBookingScreenState();
}

class _OnlineBookingScreenState extends State<OnlineBookingScreen> {
  String _moderationStatus = 'draft';
  String? _moderationComment;
  bool _loadingStatus = true;

  bool _hasProfile = false;
  bool _hasServices = false;
  bool _hasSchedule = false;
  bool _hasEmployeesWithServices = false;
  bool _onlineEnabled = false;
  String? _bookingUrl;

  String _blockedClients = 'forbidden';
  String _anySpecialist = 'disabled';
  String _ratingSpecialists = 'everywhere';
  bool _marketingConsent = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStatus(), _loadSettings()]);
  }

  Future<void> _loadStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/project-profile/get?project_id=${widget.projectId}'),
        ApiService.get('/api/project-profile/moderation-status?project_id=${widget.projectId}'),
        ApiService.get('/api/service/list?project_id=${widget.projectId}'),
        ApiService.get('/api/employee/list?project_id=${widget.projectId}'),
      ]);

      final project = results[0]['success'] == true ? results[0]['data'] : {};
final modStatus = results[1]['success'] == true ? results[1]['data'] : {};
final services = results[2]['success'] == true ? List<Map<String, dynamic>>.from(results[2]['data'] ?? []) : [];
final employees = results[3]['success'] == true ? List<Map<String, dynamic>>.from(results[3]['data'] ?? []) : [];

AppLogger.debug('=== PROJECT DATA ===');
AppLogger.debug('schedule_json: ${project['schedule_json']}');
AppLogger.debug('schedule_json type: ${project['schedule_json']?.runtimeType}');
AppLogger.debug('schedule_json isEmpty: ${project['schedule_json']?.toString().isEmpty}');
AppLogger.debug('hasSchedule: ${(project['schedule_json']?.toString().isNotEmpty ?? false)}');
AppLogger.debug('employees count: ${employees.length}');
AppLogger.debug('employees with services: ${employees.where((e) => e['provides_services'] == true).length}');
AppLogger.debug('hasEmployeesWithServices: ${employees.any((e) => e['provides_services'] == true)}');
AppLogger.debug('_canActivate: $_canActivate');
            setState(() {
        _hasProfile = (project['profile_photo']?.toString().isNotEmpty ?? false) && (project['address_raw']?.toString().isNotEmpty ?? false);
        _hasServices = services.isNotEmpty;
        _hasSchedule = (project['schedule_json']?.toString().isNotEmpty ?? false);
        _hasEmployeesWithServices = employees.any((e) => e['provides_services'] == true);
        _onlineEnabled = project['online_booking_enabled'] == true;
        _bookingUrl = _onlineEnabled ? 'https://запись.бьютироща.рф/book/${widget.projectId}' : null;

        _moderationStatus = modStatus['moderation_status'] ?? 'draft';
        _moderationComment = modStatus['moderation_comment']?.toString();
        _loadingStatus = false;
      });
AppLogger.debug('_hasProfile: $_hasProfile');
AppLogger.debug('_hasServices: $_hasServices');
AppLogger.debug('_hasSchedule: $_hasSchedule');
AppLogger.debug('_hasEmployeesWithServices: $_hasEmployeesWithServices');
AppLogger.debug('_canActivate: $_canActivate');
AppLogger.debug('_moderationStatus: $_moderationStatus');
    } catch (e) {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final r = await ApiService.get('/api/project-profile/get-online-settings?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        final s = r['data'] as Map? ?? {};
        setState(() {
          _blockedClients = s['blocked_clients'] ?? 'forbidden';
          _anySpecialist = s['any_specialist'] ?? 'disabled';
          _ratingSpecialists = s['rating_specialists'] ?? 'everywhere';
          _marketingConsent = s['marketing_consent'] == 1;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      await ApiService.post('/api/project-profile/save-online-setting', {
        'project_id': widget.projectId,
        key: value,
      });
    } catch (_) {}
  }

  Future<void> _submitToModeration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отправить на модерацию?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отправить')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final r = await ApiService.post('/api/project-profile/submit-moderation', {'project_id': widget.projectId});
      if (r['success'] == true && mounted) {
        setState(() => _moderationStatus = 'pending');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Проект отправлен на модерацию!'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
  }

  bool get _canActivate => _hasProfile && _hasServices && (_hasSchedule || _hasEmployeesWithServices);
  bool get _isActive => _onlineEnabled && _moderationStatus == 'approved';

  @override
  Widget build(BuildContext context) {
    if (_loadingStatus) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonCircle(size: 48),
            SizedBox(height: 16),
            SkeletonBox(height: 14, width: 160),
          ],
        ),
      );
    }

    final statusColor = _moderationStatus == 'approved'
        ? const Color(0xFF2ED573)
        : _moderationStatus == 'pending'
            ? const Color(0xFFFFA502)
            : const Color(0xFFFF4757);
    final statusBg = _moderationStatus == 'approved'
        ? const Color(0xFFF0FFF4)
        : _moderationStatus == 'pending'
            ? const Color(0xFFFFFBF0)
            : const Color(0xFFFFF5F5);
    final statusText = _moderationStatus == 'approved'
        ? 'Активна'
        : _moderationStatus == 'pending'
            ? 'На модерации'
            : _moderationStatus == 'rejected'
                ? 'Отклонена'
                : 'Неактивна';
final statusIcon = _moderationStatus == 'approved' ? '✓' : _moderationStatus == 'pending' ? '' : '!';    final statusSubtext = _moderationStatus == 'approved'
        ? 'Доступна для клиентов'
        : _moderationStatus == 'pending'
            ? 'Проверка занимает от 15 минут до 12 часов'
            : _moderationStatus == 'rejected'
                ? 'Требуется настройка'
                : 'Требуется настройка';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          color: statusBg,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(14)),
                child: Center(
child: _moderationStatus == 'pending'
    ? SvgPicture.asset('assets/schedule.svg', colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn), width: 22, height: 22)
    : Text(statusIcon, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                    const SizedBox(height: 2),
                    Text(statusSubtext, style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_moderationStatus == 'rejected' && _moderationComment != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Причина отклонения',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626), letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                        child: Text(_moderationComment!, style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B))),
                      ),
                    ],
                  ),
                ),
              if (_isActive && _bookingUrl != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ссылка на онлайн-запись', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F8F8),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                              ),
                              child: Text(_bookingUrl!, style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _bookingUrl!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Скопировано!'), duration: Duration(seconds: 1)),
                              );
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.copy, size: 18, color: Color(0xFF666666)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _settingsItem('Настройки', Icons.settings, _showOnlineSettings),
                _settingsItem('Правила бронирования', Icons.rule, () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => BookingRulesSheet(projectId: widget.projectId),
                  );
                }),
                _settingsItem('Дизайн онлайн-записи', Icons.palette, () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => _OnlineDesignSheet(projectId: widget.projectId),
                  );
                }),
              ],
              if (!_canActivate || _moderationStatus != 'approved') ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Для активации онлайн-записи необходимы:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 12),
                      _conditionItem('Профиль проекта', 'Добавьте фото профиля, адрес проекта', _hasProfile,
                          () => _navigateTo('profile')),
                      const SizedBox(height: 6),
                      _conditionItem('Услуги', 'Добавьте услуги, назначьте стоимость и длительность', _hasServices,
                          () => _navigateTo('services')),
                      const SizedBox(height: 6),
                      _conditionItem('График работы', 'Установите рабочее время для приёма клиентов',
    _hasSchedule || _hasEmployeesWithServices, () => _navigateTo('schedule')),
const SizedBox(height: 6),
_conditionItem(
  'Предстоящие записи',
  'Добавьте ранее запланированные записи. Онлайн-запись будет учитывать занятое на них время.',
  null, // null = опционально
  () {},
),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_canActivate && _moderationStatus == 'draft')
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitToModeration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD1847),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Отправить на модерацию',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              if (_moderationStatus == 'rejected')
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitToModeration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Повторно отправить на модерацию',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

    Widget _conditionItem(String title, String subtitle, bool? done, VoidCallback onTap) {
    final isOptional = done == null;
    final isDone = done == true;
    return GestureDetector(
      onTap: (isDone || isOptional) ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFFE8F5E9) : (isOptional ? const Color(0xFFFFF3E0) : const Color(0xFFFFF5F5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDone ? Icons.check : (isOptional ? Icons.info_outline : Icons.close),
                size: 16,
                color: isDone ? const Color(0xFF4CAF50) : (isOptional ? const Color(0xFFFF9800) : const Color(0xFFF44336)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (!isDone) Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle, style: const TextStyle(fontSize: 13, height: 1.3, color: Color(0xFF888888))),
                  ),
                ],
              ),
            ),
            if (!isDone && !isOptional) const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  Widget _settingsItem(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF666666)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  void _navigateTo(String page) {
    // Переключение вкладки в родителе (JournalScreen), а не новый экран.
    // Так сохраняется header/sidebar и навигация «как из меню».
    widget.onNavigate?.call(page);
  }

  void _showOnlineSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Настройки онлайн-записи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          Text('Управление параметрами онлайн-записи',
                              style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _settingsDropdown(
                      'Заблокированные клиенты',
                      'При активации к вам смогут записываться клиенты из черного списка',
                      _blockedClients,
                      {'forbidden': 'Запрещена', 'allowed': 'Разрешена', 'prepayment': 'По предоплате'},
                      (v) {
                        setModalState(() => _blockedClients = v);
                        _saveSetting('blocked_clients', v);
                      },
                    ),
                    const SizedBox(height: 16),
                    _settingsLink('Фиксированное время', 'Настройки по дням недели и на определенные дни', () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (_) => _FixedTimeEmployeesSheet(projectId: widget.projectId),
                      );
                    }),
                    const SizedBox(height: 16),
                    _settingsLink('Время до записи', 'Минимальное время для записи к сотрудникам', () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (_) => _MinBookingTimeSheet(projectId: widget.projectId),
                      );
                    }),
                    const SizedBox(height: 16),
                    _settingsDropdown(
                      'Любой специалист',
                      'Условие подбора специалиста',
                      _anySpecialist,
                      {
                        'disabled': 'Отключить',
                        'random': 'Случайный',
                        'cheaper': 'Услуга дешевле',
                        'expensive': 'Услуга дороже',
                        'less_busy': 'Менее занятый',
                        'more_busy': 'Более занятый',
                      },
                      (v) {
                        setModalState(() => _anySpecialist = v);
                        _saveSetting('any_specialist', v);
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Рейтинг и отзывы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _settingsDropdown(
                      'Специалисты',
                      '',
                      _ratingSpecialists,
                      {'everywhere': 'Показывать везде', 'booking_only': 'Только в Б-запись'},
                      (v) {
                        setModalState(() => _ratingSpecialists = v);
                        _saveSetting('rating_specialists', v);
                      },
                    ),
                    if (_ratingSpecialists == 'booking_only')
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(6)),
                        child: const Text('По прямой ссылке отзывы видны не будут',
                            style: TextStyle(fontSize: 11, color: Color(0xFFDD1847))),
                      ),
                    const SizedBox(height: 16),
                    _settingsLink('Запрос согласия на обработку ПД', 'Клиенту будет предложено подтвердить согласие', () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (_) => _ConsentSettingsSheet(projectId: widget.projectId),
                      );
                    }),
                    const SizedBox(height: 16),
                    _settingsToggle(
                      'Запрос согласия на рассылку',
                      'Учитывается при создании массовых рассылок',
                      _marketingConsent,
                      (v) {
                        setModalState(() => _marketingConsent = v);
                        _saveSetting('marketing_consent', v ? 1 : 0);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsDropdown(String title, String desc, String value, Map<String, String> options, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (desc.isNotEmpty) const SizedBox(height: 2),
                if (desc.isNotEmpty) Text(desc, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)),
            child: DropdownButton<String>(
              value: value,
              underline: const SizedBox(),
              items: options.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsLink(String title, String desc, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (desc.isNotEmpty) const SizedBox(height: 2),
                  if (desc.isNotEmpty) Text(desc, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  Widget _settingsToggle(String title, String desc, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (desc.isNotEmpty) const SizedBox(height: 2),
                if (desc.isNotEmpty) Text(desc, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFFDD1847)),
        ],
      ),
    );
  }
}

// ==================== МОДАЛКА ВРЕМЯ ДО ЗАПИСИ ====================
class _MinBookingTimeSheet extends StatefulWidget {
  final int projectId;
  const _MinBookingTimeSheet({required this.projectId});

  @override
  State<_MinBookingTimeSheet> createState() => _MinBookingTimeSheetState();
}

class _MinBookingTimeSheetState extends State<_MinBookingTimeSheet> {
  List<Map<String, dynamic>> _employees = [];
  Map<String, Map<String, dynamic>> _mbtData = {};
  Map<String, dynamic>? _editingEmployee;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/employee/list?project_id=${widget.projectId}'),
        ApiService.get('/api/project-profile/get-online-settings?project_id=${widget.projectId}'),
      ]);
      if (mounted) {
        setState(() {
          _employees = results[0]['success'] == true ? List<Map<String, dynamic>>.from(results[0]['data'] ?? []) : [];
          if (results[1]['success'] == true && results[1]['data'] != null) {
            _mbtData = Map<String, Map<String, dynamic>>.from(
              (results[1]['data']['min_booking_time'] as Map?)?.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v))) ?? {},
            );
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEmployeeSettings(Map<String, dynamic> emp) {
    final empId = emp['id'].toString();
    if (!_mbtData.containsKey(empId)) {
      _mbtData[empId] = {'enabled': false, 'value': 1, 'unit': 'hours'};
    }
    setState(() => _editingEmployee = emp);
  }

  String _getStatusText(Map<String, dynamic>? setting) {
    if (setting == null || setting['enabled'] != true) return 'Без ограничений';
    final value = setting['value'] ?? 1;
    final unit = setting['unit'] ?? 'hours';
    final unitLabel = unit == 'minutes' ? 'мин' : unit == 'hours' ? 'ч' : 'дн';
    return 'За $value $unitLabel';
  }

  @override
  Widget build(BuildContext context) {
    if (_editingEmployee != null) {
      return _buildEmployeeSettings();
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Время до записи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      Text('Настройка минимального времени для записи', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonCircle(size: 40),
                    SizedBox(height: 12),
                    SkeletonBox(height: 14, width: 140),
                  ],
                ),
              ),
            )
          else if (_employees.isEmpty)
            const Expanded(child: Center(child: Text('Нет сотрудников', style: TextStyle(color: Color(0xFF999999)))))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Сотрудники', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 8),
                  ..._employees.map((emp) {
                    final empId = emp['id'].toString();
                    final setting = _mbtData[empId];
                    final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
                    final avatar = emp['avatar']?.toString();

                    return GestureDetector(
                      onTap: () => _openEmployeeSettings(emp),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            (avatar != null && avatar.isNotEmpty)
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai$avatar',
                                      width: 40, height: 40, fit: BoxFit.cover,
                                      placeholder: (_, _) => const SkeletonCircle(size: 40),
                                      errorWidget: (_, _, _) => AvatarInitials(name: name, size: 40, textColor: const Color(0xFF666666)),
                                    ),
                                  )
                                : AvatarInitials(name: name, size: 40, textColor: const Color(0xFF666666)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: setting != null && setting['enabled'] == true ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getStatusText(setting),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: setting != null && setting['enabled'] == true ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmployeeSettings() {
    final emp = _editingEmployee!;
    final empId = emp['id'].toString();
    final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    final setting = _mbtData[empId] ?? {'enabled': false, 'value': 1, 'unit': 'hours'};
    bool noLimit = setting['enabled'] != true;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Row(
              children: [
                GestureDetector(onTap: () => setState(() => _editingEmployee = null), child: const Icon(Icons.arrow_back)),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Без ограничений', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            const Text(
                              'Отключите, чтобы задать минимальное время до записи',
                              style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Switch(
                        value: noLimit,
                        onChanged: (v) => setState(() {
                          _mbtData[empId] ??= {'enabled': false, 'value': 1, 'unit': 'hours'};
                          _mbtData[empId]!['enabled'] = !v;
                          noLimit = v;
                        }),
                        activeThumbColor: const Color(0xFFDD1847),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: noLimit ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Нельзя записаться на услугу раньше чем за:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: TextEditingController(text: '${setting['value'] ?? 1}'),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              onChanged: (v) => _mbtData[empId]!['value'] = int.tryParse(v) ?? 1,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF5F5F5),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                            child: DropdownButton<String>(
                              value: setting['unit'] ?? 'hours',
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'minutes', child: Text('Минут')),
                                DropdownMenuItem(value: 'hours', child: Text('Часов')),
                                DropdownMenuItem(value: 'days', child: Text('Дней')),
                              ],
                              onChanged: noLimit
                                  ? null
                                  : (v) {
                                      if (v != null) _mbtData[empId]!['unit'] = v;
                                      setState(() {});
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildMbtPreview(setting['value'] ?? 1, setting['unit'] ?? 'hours'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => _saveMbtSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD1847),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMbtPreview(int value, String unit) {
    final now = DateTime.now();
    DateTime future = now;
    if (unit == 'minutes') {
      future = now.add(Duration(minutes: value));
    } else if (unit == 'hours') future = now.add(Duration(hours: value));
    else if (unit == 'days') future = now.add(Duration(days: value));

    final nowStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final futureStr = '${future.hour.toString().padLeft(2, '0')}:${future.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10)),
      child: Text('Пример: если сейчас $nowStr, записаться можно с $futureStr', style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
    );
  }

  Future<void> _saveMbtSettings() async {
    try {
      await ApiService.post('/api/project-profile/save-online-setting', {
        'project_id': widget.projectId,
        'min_booking_time': _mbtData,
      });
      if (mounted) {
        setState(() => _editingEmployee = null);
        _load();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Настройка сохранена'), backgroundColor: Colors.green));
      }
    } catch (_) {}
  }
}

// ==================== ФИКСИРОВАННОЕ ВРЕМЯ — СПИСОК СОТРУДНИКОВ ====================
class _FixedTimeEmployeesSheet extends StatefulWidget {
  final int projectId;
  const _FixedTimeEmployeesSheet({required this.projectId});
  @override
  State<_FixedTimeEmployeesSheet> createState() => _FixedTimeEmployeesSheetState();
}

class _FixedTimeEmployeesSheetState extends State<_FixedTimeEmployeesSheet> {
  List<Map<String, dynamic>> _employees = [];
  Map<int, bool> _ftEnabled = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/api/employee/list?project_id=${widget.projectId}'),
      ]);
      if (results[0]['success'] == true && mounted) {
        final emps = List<Map<String, dynamic>>.from(results[0]['data'] ?? []);
        final ftResults = await Future.wait(emps.map((e) async {
          try {
            final r = await ApiService.get('/api/employee/get-fixed-time?employee_id=${e['id']}&project_id=${widget.projectId}');
            return {'id': e['id'], 'enabled': r['success'] == true && r['data'] != null && r['data']['enabled'] == true};
          } catch (_) {
            return {'id': e['id'], 'enabled': false};
          }
        }));
        final ftMap = <int, bool>{};
        for (final ft in ftResults) {
          ftMap[ft['id'] as int] = ft['enabled'] as bool;
        }
        setState(() {
          _employees = emps;
          _ftEnabled = ftMap;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Фиксированное время', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      Text('Настройки по дням недели и на определенные дни', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonCircle(size: 40),
                        SizedBox(height: 12),
                        SkeletonBox(height: 14, width: 140),
                      ],
                    ),
                  )
                : _employees.isEmpty
                    ? const Center(child: Text('Нет сотрудников', style: TextStyle(color: Color(0xFF999999))))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text('Сотрудники', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ..._employees.map((emp) {
                            final id = emp['id'] as int;
                            final name = '${emp['last_name'] ?? ''} ${emp['first_name'] ?? ''}'.trim();
                            final avatar = emp['avatar']?.toString();
                            final isOn = _ftEnabled[id] == true;
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.white,
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                  builder: (_) => FixedTimeSettingsSheet(
                                    employeeId: id,
                                    projectId: widget.projectId,
                                    onSaved: () {
                                      _load();
                                    },
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    (avatar != null && avatar.isNotEmpty)
                                        ? ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai$avatar',
                                              width: 40, height: 40, fit: BoxFit.cover,
                                              placeholder: (_, _) => const SkeletonCircle(size: 40),
                                              errorWidget: (_, _, _) => AvatarInitials(name: name, size: 40, textColor: const Color(0xFF666666)),
                                            ),
                                          )
                                        : AvatarInitials(name: name, size: 40, textColor: const Color(0xFF666666)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                          if (emp['position'] != null && emp['position'].toString().isNotEmpty)
                                            Text(emp['position'].toString(), style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isOn ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isOn ? 'Вкл' : 'Выкл',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isOn ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
                                  ],
                                ),
                              ),
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

// ==================== МОДАЛКА СОГЛАСИЯ НА ОБРАБОТКУ ПД ====================
class _ConsentSettingsSheet extends StatefulWidget {
  final int projectId;
  const _ConsentSettingsSheet({required this.projectId});
  @override
  State<_ConsentSettingsSheet> createState() => _ConsentSettingsSheetState();
}

class _ConsentSettingsSheetState extends State<_ConsentSettingsSheet> {
  bool _enabled = false;
  final _textCtrl = TextEditingController();
  bool _loading = true;

  String get _defaultText => '''Настоящим в соответствии с Федеральным законом № 152-ФЗ «О персональных данных» от 27.07.2006 года свободно, своей волей и в своём интересе выражаю своё безусловное согласие на обработку моих персональных данных организации {НАЗВАНИЕ_ОРГАНИЗАЦИИ}, зарегистрированной в соответствии с законодательством РФ по адресу: {АДРЕС} (далее — Оператор).

Персональные данные — любая информация, относящаяся к определённому или определяемому на основании такой информации физическому лицу.

Настоящее Согласие выдано мною на обработку следующих персональных данных:
- фамилия, имя Клиента;
- адрес электронной почты (e-mail) Клиента;
- номер телефона Клиента.

Согласие дано Оператору для совершения следующих действий с моими персональными данными с использованием средств автоматизации и/или без использования таких средств: сбор, систематизация, накопление, хранение, уточнение (обновление, изменение), использование для указанных ниже целей, а также осуществление любых иных действий, предусмотренных действующим законодательством РФ.

Данное согласие даётся Оператору для обработки моих персональных данных в целях продажи товаров, а также сбора информации для дальнейшего осуществления услуг (продвижение товаров, работ, услуг на рынке).

Настоящее согласие действует до момента его отзыва путём направления соответствующего обращения. Либо срок хранения составляет 10 лет.

В случае отзыва согласия на обработку персональных данных Оператор вправе продолжить обработку персональных данных без моего согласия при наличии оснований, указанных в пунктах 2 – 11 части 1 статьи 6, части 2 статьи 10 и части 2 статьи 11 Федерального закона №152-ФЗ «О персональных данных» от 26.06.2006 г.

Оператор персональных данных вправе поручить обработку моих персональных данных третьему лицу, а именно оператору сервиса онлайн-записи Б-Запись — ИП Рощину Александру Александровичу (ИНН 322402991860). Настоящее согласие действует до момента его отзыва или в течение 10 лет после получения.''';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.get('/api/project-profile/get-online-settings?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        final data = r['data'] as Map? ?? {};
        setState(() {
          _enabled = data['consent_enabled'] == true;
          _textCtrl.text = data['consent_text'] ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fillDefault() async {
    try {
      final r = await ApiService.get('/api/project-profile/get?project_id=${widget.projectId}');
      String orgName = 'Организация';
      String orgAddress = 'Адрес организации';
      if (r['success'] == true && r['data'] != null) {
        orgName = r['data']['name'] ?? 'Организация';
        orgAddress = r['data']['address_raw'] ?? 'Адрес организации';
      }
      _textCtrl.text = _defaultText
          .replaceAll('{НАЗВАНИЕ_ОРГАНИЗАЦИИ}', orgName)
          .replaceAll('{АДРЕС}', orgAddress);
    } catch (_) {
      _textCtrl.text = _defaultText
          .replaceAll('{НАЗВАНИЕ_ОРГАНИЗАЦИИ}', 'Организация')
          .replaceAll('{АДРЕС}', 'Адрес организации');
    }
  }

  Future<void> _save() async {
    try {
      await ApiService.post('/api/project-profile/save-online-setting', {
        'project_id': widget.projectId,
        'consent_enabled': _enabled,
        'consent_text': _textCtrl.text,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Настройки сохранены'), backgroundColor: Colors.green));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Запрос согласия на обработку ПД', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      Text('При онлайн-записи клиенту будет предложено подтвердить согласие',
                          style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonCircle(size: 40),
                        SizedBox(height: 12),
                        SkeletonBox(height: 14, width: 160),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Запрашивать согласие у клиентов', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  const Text('При онлайн-записи клиенту единоразово будет предложено подтвердить согласие',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
                                ],
                              ),
                            ),
                            Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v), activeThumbColor: const Color(0xFFDD1847)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedOpacity(
                        opacity: _enabled ? 1.0 : 0.4,
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Текст согласия', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                TextButton(
                                  onPressed: _enabled ? _fillDefault : null,
                                  child: const Text('Заполнить', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _textCtrl,
                              maxLines: 12,
                              enabled: _enabled,
                              style: const TextStyle(fontSize: 13, height: 1.6),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8F8F8),
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
                                  borderSide: const BorderSide(color: Color(0xFFDD1847)),
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8)),
                              child: const Text(
                                'Внизу согласия будет автоматически добавлен обязательный абзац — он сообщает клиенту, что данные передаются сервису Б-Записи.',
                                style: TextStyle(fontSize: 11, color: Color(0xFFDD1847)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
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
                child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== МОДАЛКА ДИЗАЙНА ОНЛАЙН-ЗАПИСИ ====================
class _OnlineDesignSheet extends StatefulWidget {
  final int projectId;
  const _OnlineDesignSheet({required this.projectId});
  @override
  State<_OnlineDesignSheet> createState() => _OnlineDesignSheetState();
}

class _OnlineDesignSheetState extends State<_OnlineDesignSheet> {
  final _primaryCtrl = TextEditingController(text: '#DD1847');
  final _buttonBgCtrl = TextEditingController(text: '#DD1847');
  final _buttonTextCtrl = TextEditingController(text: '#FFFFFF');
  String _specialistLabel = 'Специалисты';
  String _serviceLabel = 'Услуги';
  Color _primaryColor = const Color(0xFFDD1847);
  Color _buttonBg = const Color(0xFFDD1847);
  Color _buttonText = const Color(0xFFFFFFFF);
  bool _loading = true;

  static const _specialistOptions = [
    'Специалисты', 'Тренеры', 'Врачи', 'Мастера', 'Стилисты', 'Преподаватели',
    'Инструкторы', 'Нотариусы', 'Солярии', 'Места', 'Залы', 'Боксы/Посты'
  ];
  static const _serviceOptions = ['Услуги', 'Тренировки', 'Занятия', 'Мероприятия', 'Курсы', 'Индивидуальные занятия'];

  @override
  void initState() {
    super.initState();
    _load();
    _primaryCtrl.addListener(_onPrimaryChanged);
    _buttonBgCtrl.addListener(_onButtonBgChanged);
    _buttonTextCtrl.addListener(_onButtonTextChanged);
  }

  @override
  void dispose() {
    _primaryCtrl.dispose();
    _buttonBgCtrl.dispose();
    _buttonTextCtrl.dispose();
    super.dispose();
  }

  void _onPrimaryChanged() {
    final hex = _primaryCtrl.text.trim();
    if (hex.length == 7 && hex.startsWith('#')) {
      setState(() => _primaryColor = Color(int.parse('FF${hex.substring(1)}', radix: 16)));
    }
  }

  void _onButtonBgChanged() {
    final hex = _buttonBgCtrl.text.trim();
    if (hex.length == 7 && hex.startsWith('#')) {
      setState(() => _buttonBg = Color(int.parse('FF${hex.substring(1)}', radix: 16)));
    }
  }

  void _onButtonTextChanged() {
    final hex = _buttonTextCtrl.text.trim();
    if (hex.length == 7 && hex.startsWith('#')) {
      setState(() => _buttonText = Color(int.parse('FF${hex.substring(1)}', radix: 16)));
    }
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.get('/api/project-profile/get-online-design?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        final d = r['data'] as Map? ?? {};
        setState(() {
          _primaryCtrl.text = d['primary_color'] ?? '#DD1847';
          _buttonBgCtrl.text = d['button_bg'] ?? '#DD1847';
          _buttonTextCtrl.text = d['button_text'] ?? '#FFFFFF';
          _specialistLabel = d['specialist_label'] ?? 'Специалисты';
          _serviceLabel = d['service_label'] ?? 'Услуги';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      await ApiService.post('/api/project-profile/save-online-design', {
        'project_id': widget.projectId,
        'primary_color': _primaryCtrl.text.trim(),
        'button_bg': _buttonBgCtrl.text.trim(),
        'button_text': _buttonTextCtrl.text.trim(),
        'specialist_label': _specialistLabel,
        'service_label': _serviceLabel,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Дизайн сохранён'), backgroundColor: Colors.green));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Дизайн онлайн-записи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      Text('Настройка внешнего вида страницы', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonCircle(size: 40),
                        SizedBox(height: 12),
                        SkeletonBox(height: 14, width: 160),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text('Цветовая палитра', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      _colorField('Основной цвет', 'используется для ссылок и иконок', _primaryCtrl, _primaryColor),
                      const SizedBox(height: 16),
                      _colorField('Цвет кнопок', 'используется для кнопок', _buttonBgCtrl, _buttonBg),
                      const SizedBox(height: 16),
                      _colorField('Цвет текста кнопок', 'используется для текста на кнопках', _buttonTextCtrl, _buttonText),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10)),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            decoration: BoxDecoration(color: _buttonBg, borderRadius: BorderRadius.circular(10)),
                            child: Text('Пример кнопки',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _buttonText)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text('Заголовки разделов', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('По умолчанию выводятся «Специалисты» и «Услуги». Вы можете заменить названия.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                      const SizedBox(height: 12),
                      _labelDropdown('Специалисты', _specialistLabel, _specialistOptions, (v) => setState(() => _specialistLabel = v)),
                      const SizedBox(height: 8),
                      _labelDropdown('Услуги', _serviceLabel, _serviceOptions, (v) => setState(() => _serviceLabel = v)),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD1847),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorField(String title, String subtitle, TextEditingController ctrl, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                maxLength: 7,
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        initialColor: color,
                        onColorSelected: (c) {
                          ctrl.text = '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _labelDropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)),
            child: DropdownButton<String>(
              value: value,
              underline: const SizedBox(),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Простой ColorPicker через GridView
class ColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;
  const ColorPicker({super.key, required this.initialColor, required this.onColorSelected});

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  static const _palette = [
    0xFFDD1847, 0xFFE91E63, 0xFF9C27B0, 0xFF673AB7, 0xFF3F51B5, 0xFF2196F3,
    0xFF03A9F4, 0xFF00BCD4, 0xFF009688, 0xFF4CAF50, 0xFF8BC34A, 0xFFCDDC39,
    0xFFFFEB3B, 0xFFFFC107, 0xFFFF9800, 0xFFFF5722, 0xFF795548, 0xFF607D8B,
    0xFF9E9E9E, 0xFF000000, 0xFFFFFFFF, 0xFFF5F5F5,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _palette
            .map((c) => GestureDetector(
                  onTap: () => widget.onColorSelected(Color(c)),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.initialColor.toARGB32() == c ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}