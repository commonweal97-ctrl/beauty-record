import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';

class ConsentsScreen extends StatefulWidget {
  const ConsentsScreen({super.key});

  @override
  State<ConsentsScreen> createState() => _ConsentsScreenState();
}

class _ConsentsScreenState extends State<ConsentsScreen> {
  Map<String, dynamic>? _serviceConsent;
  List<Map<String, dynamic>> _projectConsents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final userId = await _getUserId();
      final serviceRes = await ApiService.get('/api/client/consent/get?client_id=$userId&project_id=0');
      final projectRes = await ApiService.get('/api/client/consent/list?client_id=$userId');

      if (mounted) {
        setState(() {
          _serviceConsent = serviceRes['success'] == true ? serviceRes['data'] : null;
          _projectConsents = projectRes['success'] == true ? List<Map<String, dynamic>>.from(projectRes['data'] ?? []).map((p) {
            p['data_consent'] = p['data_consent'] == 1 || p['data_consent'] == true;
            p['marketing_consent'] = p['marketing_consent'] == 1 || p['marketing_consent'] == true;
            return p;
          }).toList() : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<int> _getUserId() async {
    final result = await ApiService.get('/api/profile');
    return result['data']?['id'] ?? 0;
  }

  void _toggleConsent(int projectId, String field, bool current) async {
    final userId = await _getUserId();
    final newValue = current ? 0 : 1;

    setState(() {
      if (projectId == 0 && _serviceConsent != null) {
        _serviceConsent![field] = newValue == 1;
      }
      for (var p in _projectConsents) {
        if (p['project_id'] == projectId) {
          p[field] = newValue == 1;
        }
      }
    });

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/client/consent/save');
      await http.post(uri, headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: 'client_id=$userId&project_id=$projectId&$field=$newValue');
      if (!mounted) return;
      showToast(context, 'Сохранено');
    } catch (e) {
      // Откат
      setState(() {
        if (projectId == 0 && _serviceConsent != null) {
          _serviceConsent![field] = current;
        }
        for (var p in _projectConsents) {
          if (p['project_id'] == projectId) {
            p[field] = current;
          }
        }
      });
      if (!mounted) return;
      showToast(context, 'Ошибка сохранения', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Мои согласия', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.grey), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SkeletonBox(height: 14, width: 140),
                const SizedBox(height: 16),
                _buildSkeletonCard(),
                const SizedBox(height: 24),
                const SkeletonBox(height: 14, width: 100),
                const SizedBox(height: 16),
                _buildSkeletonCard(),
                _buildSkeletonCard(),
              ]),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Сервисное согласие
                const Text('Сервис Б-Запись', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 16),
                _buildCard('Сервис', [
                  _buildToggle('Обработка персональных данных', _serviceConsent?['data_consent'] == true, false, 'data_consent', 0),
                  _buildToggle('Информационно-рекламная рассылка', _serviceConsent?['marketing_consent'] == true, true, 'marketing_consent', 0),
                ], _serviceConsent?['created_at']),

                const SizedBox(height: 24),
                const Text('Проекты', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 16),
                if (_projectConsents.isEmpty)
                  const Padding(padding: EdgeInsets.all(40), child: Text('Нет согласий по проектам', style: TextStyle(color: Color(0xFF94A3B8))))
                else
                  ..._projectConsents.map((p) => _buildCard(
                    p['project_name'] ?? 'Проект',
                    [
                      _buildToggle('Обработка персональных данных', p['data_consent'] == true, true, 'data_consent', p['project_id'] ?? 0),
                      _buildToggle('Информационно-рекламная рассылка', p['marketing_consent'] == true, true, 'marketing_consent', p['project_id'] ?? 0),
                    ],
                    p['created_at'],
                  )),
              ]),
            ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: const SkeletonBox(height: 18, width: 120),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            const Expanded(child: SkeletonBox(height: 14, width: double.infinity)),
            const SizedBox(width: 60),
            const SkeletonBox(height: 14, width: 60),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ]),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: const SkeletonBox(height: 12, width: 160),
        ),
      ]),
    );
  }

  Widget _buildCard(String title, List<Widget> items, String? date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(16))), child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
        ...items,
        if (date != null) Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))), child: Text('Выдано: $date', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
      ]),
    );
  }

  Widget _buildToggle(String label, bool value, bool canToggle, String field, int projectId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
            if (!canToggle) const Text('Обязательное согласие', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ]),
        ),
        Text(value ? 'Дано' : 'Отозвано', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value ? const Color(0xFF16A34A) : const Color(0xFF94A3B8))),
        const SizedBox(width: 10),
        Switch(
          value: value,
          onChanged: canToggle ? (v) => _toggleConsent(projectId, field, value) : null,
          activeThumbColor: const Color(0xFF16A34A),
          inactiveThumbColor: canToggle ? null : const Color(0xFF16A34A),
          inactiveTrackColor: canToggle ? null : const Color(0xFF16A34A).withValues(alpha: 0.3),
        ),
      ]),
    );
  }
}