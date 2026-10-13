import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/toast.dart';
import '../../../widgets/common/phone_input.dart';
import '../client/client_profile_sheet.dart';
import 'edit_client_sheet.dart';
import '../../core/app_logger.dart';

class ClientsScreen extends StatefulWidget {
  final int projectId;
  const ClientsScreen({super.key, required this.projectId});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _groups = [];
  String? _activeGroup;
  String _search = '';
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  Timer? _searchTimer;

  static const _groupLabels = {
    'regular': {'title': 'Постоянные', 'desc': '3 и более записи за 4 месяца'},
    'sleeping': {'title': 'Спящие', 'desc': 'Не записывались более 3 месяцев'},
    'lost': {'title': 'Пропавшие', 'desc': 'Не записывались более 6 месяцев'},
    'never': {'title': 'Не посещали', 'desc': 'Нет записей'},
    'blocked': {'title': 'Заблокированы', 'desc': 'Не могут записаться онлайн'},
    'new': {'title': 'Новые', 'desc': '1–2 завершённые записи'},
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _search = value;
      _activeGroup = null;
      _load();
    });
  }

  void _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{'project_id': widget.projectId.toString()};
      if (_search.isNotEmpty) params['search'] = _search;
      if (_activeGroup != null) params['group'] = _activeGroup!;
      final uri = '/api/client/list?${Uri(queryParameters: params).query}';
      final result = await ApiService.get(uri);
      if (result['success'] == true && mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _groups = List<Map<String, dynamic>>.from(result['groups'] ?? []);
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setGroup(String? key) {
    _activeGroup = _activeGroup == key ? null : key;
    _load();
  }

  void _openAddClient() {
  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => EditClientSheet(projectId: widget.projectId, onSaved: _load),
  );
}

  void _openClientProfile(int clientId) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ClientProfileSheet(clientId: clientId, projectId: widget.projectId, onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Фиксированная шапка
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSearchBar(),
            ],
          ),
        ),
        // Скроллируемый контент (включая группы)
        Expanded(
          child: _loading
              ? _buildLoader()
              : _clients.isEmpty && _groups.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Группы (в скролле, не липкие)
                          if (_groups.isNotEmpty) ...[
                            _buildGroupsWrap(),
                            const SizedBox(height: 20),
                          ],
                          // Список клиентов
                          ..._clients.asMap().entries.map((e) => Padding(
                            padding: EdgeInsets.only(bottom: e.key < _clients.length - 1 ? 12 : 0),
                            child: _buildClientCard(e.value),
                          )),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 768;
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Клиенты', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A))),
        _buildAddButton(isMobile: isMobile),
      ]);
    });
  }

  Widget _buildSearchBar() {
    return SizedBox(height: 42, child: TextField(
      controller: _searchCtrl, onChanged: _onSearchChanged, style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Поиск по имени, телефону, email...', 
        hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14), 
        prefixIcon: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.search, color: Color(0xFF999999), size: 18)), 
        filled: true, fillColor: Colors.white, 
        contentPadding: const EdgeInsets.symmetric(vertical: 10), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))), 
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))), 
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDD1847))),
      ),
    ));
  }

  Widget _buildAddButton({bool isMobile = false}) {
    return GestureDetector(
      onTap: _openAddClient,
      child: Container(
        height: 42, 
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16), 
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFDD1847), Color(0xFFC1163D)]), borderRadius: BorderRadius.circular(12)), 
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add, color: Colors.white, size: 18), 
          if (!isMobile) ...[const SizedBox(width: 6), const Text('Добавить клиента', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))]
        ]),
      ),
    );
  }

  Widget _buildGroupsWrap() {
    return LayoutBuilder(builder: (context, constraints) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _groups.map((g) {
          final key = g['group_key'] ?? g['key'] ?? '';
          final info = _groupLabels[key] ?? {'title': key, 'desc': ''};
          final active = _activeGroup == key;
          return GestureDetector(
            onTap: () => _setGroup(key),
            child: Container(
              width: (constraints.maxWidth - 10) / 2,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFFDF2F5) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? const Color(0xFFDD1847) : const Color(0xFFF0F0F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${g['count']}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: active ? const Color(0xFFDD1847) : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info['title']!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info['desc']!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888888), height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildLoader() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    itemCount: 5, 
    itemBuilder: (_, i) => Padding(
      padding: EdgeInsets.only(bottom: i < 4 ? 12 : 0), 
      child: Container(
        padding: const EdgeInsets.all(16), 
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)), 
        child: Row(children: [
          const SkeletonCircle(size: 56), 
          const SizedBox(width: 14), 
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(height: 16, width: 150), 
            const SizedBox(height: 8), 
            Row(children: [
              const SkeletonBox(height: 13, width: 120), 
              const SizedBox(width: 16), 
              const SkeletonBox(height: 13, width: 80)
            ])
          ]))
        ])
      )
    )
  );

  Widget _buildEmptyState() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20), 
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), 
        child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.people_outline, size: 48, color: Color(0xFFDDDDDD)), 
          const SizedBox(height: 12), 
          const Text('Нет клиентов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))), 
          const SizedBox(height: 8), 
          const Text('Добавьте первого клиента', style: TextStyle(color: Color(0xFF888888))), 
          const SizedBox(height: 24), 
          ElevatedButton.icon(
            onPressed: _openAddClient, 
            icon: const Icon(Icons.add, color: Colors.white, size: 20), 
            label: const Text('Добавить клиента', style: TextStyle(color: Colors.white)), 
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
          )
        ])
      )
    )
  );

  Widget _buildClientCard(Map<String, dynamic> c) {
    final initials = (c['name'] ?? '?').toString().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    return GestureDetector(
      onTap: () => _openClientProfile(c['id']),
      child: Container(
        padding: const EdgeInsets.all(16), 
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]), 
        child: Row(children: [
          Container(
            width: 56, height: 56, 
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF8F8F8)), 
            clipBehavior: Clip.antiAlias, 
            child: c['avatar'] != null && c['avatar'].toString().isNotEmpty 
                ? CachedAvatar(url: c['avatar'], size: 56, radius: 28) 
                : Center(child: Text(initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFDD1847)))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))), 
              const SizedBox(height: 4), 
              Wrap(spacing: 16, runSpacing: 4, children: [
                if (c['phone'] != null && c['phone'].toString().isNotEmpty) _buildMetaItem(Icons.phone, c['phone'].toString()), 
                if (c['email'] != null && c['email'].toString().isNotEmpty) _buildMetaItem(Icons.email, c['email'].toString()), 
                _buildMetaItem(Icons.calendar_today, '${c['bookings_count'] ?? 0} записей')
              ])
            ]),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
        ]),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min, 
    children: [
      Icon(icon, size: 14, color: const Color(0xFF999999)), 
      const SizedBox(width: 4), 
      Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF666666)))
    ],
  );
}

// Форма добавления клиента
class AddClientSheet extends StatefulWidget {
  final int projectId;
  final VoidCallback onSaved;
  const AddClientSheet({super.key, required this.projectId, required this.onSaved});

  @override
  State<AddClientSheet> createState() => _AddClientSheetState();
}

class _AddClientSheetState extends State<AddClientSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final GlobalKey<PhoneInputState> _phoneKey = GlobalKey<PhoneInputState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  void _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showToast(context, 'Введите имя', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final phone = _phoneKey.currentState?.fullPhone ?? '';
      final result = await ApiService.saveClient(widget.projectId, _nameCtrl.text.trim(), phone, _emailCtrl.text.trim());
      AppLogger.debug('📤 Save client result: $result');
      if (result['success'] == true && mounted) { 
        Navigator.pop(context); 
        widget.onSaved();
        showToast(context, 'Клиент добавлен');
      } else if (mounted) {
        showToast(context, result['message'] ?? 'Ошибка сохранения', isError: true);
      }
    } catch (e) {
      AppLogger.debug('❌ Save client error: $e');
      if (mounted) {
        showToast(context, 'Ошибка сохранения клиента', isError: true);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset), 
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Добавить клиента', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))), 
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
        ]),
        const SizedBox(height: 20),
        _field(_nameCtrl, 'Имя *', Icons.person_outline),
        const SizedBox(height: 12),
        PhoneInput(
          key: _phoneKey,
          controller: _phoneCtrl,
          onPhoneChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _field(_emailCtrl, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 52, 
          child: ElevatedButton(
            onPressed: _loading ? null : _save, 
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), disabledBackgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
            child: _loading 
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)), SizedBox(width: 12), Text('Сохранение...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))]) 
                : const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))
          )
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))), 
      child: TextField(
        controller: c, keyboardType: keyboardType, 
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14), 
          prefixIcon: Icon(icon, color: Colors.grey, size: 20), 
          border: InputBorder.none, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
        )
      ),
    );
  }
}