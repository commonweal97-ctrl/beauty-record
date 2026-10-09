import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';

class ResourcesScreen extends StatefulWidget {
  final int projectId;
  const ResourcesScreen({super.key, required this.projectId});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  List<Map<String, dynamic>> _resources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.get('/api/resource/list?project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        setState(() {
          _resources = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openResourceEditor({Map<String, dynamic>? resource}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ResourceEditSheet(
        projectId: widget.projectId,
        resource: resource,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _loading
          ? ListView.builder(padding: const EdgeInsets.all(24), itemCount: 3, itemBuilder: (_, __) => Container(
              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
              child: Row(children: [
                const SkeletonBox(width: 44, height: 44, radius: 12),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SkeletonBox(height: 16, width: 150), const SizedBox(height: 8),
                  const SkeletonBox(height: 12, width: 100),
                ])),
              ])))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(children: [
                  const Expanded(child: Text('Ресурсы', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600))),
                  GestureDetector(
                    onTap: () => _openResourceEditor(),
                    child: Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFDD1847), Color(0xFFC1163D)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Colors.white, size: 20)),
                  ),
                ]),
              ),
              Expanded(
                child: _resources.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SvgPicture.asset('assets/beauty-salon-chair.svg', width: 48, height: 48, colorFilter: const ColorFilter.mode(Color(0xFFCCCCCC), BlendMode.srcIn)),
                        const SizedBox(height: 16),
                        const Text('Ресурсы не созданы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF888888))),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openResourceEditor(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Создать ресурс'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        ),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _resources.length,
                        itemBuilder: (_, i) {
                          final r = _resources[i];
                          final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString()) ?? 0;
                          final servicesCount = r['services_count'] as int? ?? 0;
                          return GestureDetector(
                            onTap: () => _openResourceEditor(resource: r),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
                              child: Row(children: [
                                Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)), child: SvgPicture.asset('assets/beauty-salon-chair.svg', width: 24, height: 24, colorFilter: const ColorFilter.mode(Color(0xFF999999), BlendMode.srcIn))),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(r['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  Text(servicesCount > 0 ? '$servicesCount ${_getServiceWord(servicesCount)}' : 'Нет услуг', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                                ])),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: r['is_active'] == 1 ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)), child: Text(r['is_active'] == 1 ? 'Активен' : 'Не активен', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: r['is_active'] == 1 ? const Color(0xFF2E7D32) : const Color(0xFF999999)))),
                                const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
                              ]),
                            ),
                          );
                        }),
              ),
            ]),
    );
  }

  String _getServiceWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'услуга';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) return 'услуги';
    return 'услуг';
  }
}

// ==================== РЕДАКТИРОВАНИЕ РЕСУРСА ====================
class _ResourceEditSheet extends StatefulWidget {
  final int projectId;
  final Map<String, dynamic>? resource;
  final VoidCallback onSaved;
  const _ResourceEditSheet({required this.projectId, this.resource, required this.onSaved});
  @override
  State<_ResourceEditSheet> createState() => _ResourceEditSheetState();
}

class _ResourceEditSheetState extends State<_ResourceEditSheet> {
  final _nameCtrl = TextEditingController();
  bool _isActive = true;
  Set<int> _serviceIds = {};
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  bool get _isEdit => widget.resource != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.resource!['name'] ?? '';
      _isActive = widget.resource!['is_active'] == 1;
      final serviceIdsRaw = widget.resource!['service_ids'];
      if (serviceIdsRaw is String && serviceIdsRaw.isNotEmpty) {
        _serviceIds = Set<int>.from(serviceIdsRaw.split(',').map((e) => int.tryParse(e.trim()) ?? 0).where((e) => e > 0));
      }
    }
    _loadServices();
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _loadServices() async {
    try {
      final r = await ApiService.get('/api/service/list?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) setState(() { _services = List<Map<String, dynamic>>.from(r['data'] ?? []); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showToast(context, 'Введите название ресурса', isError: true);
      return;
    }
    try {
      final result = await ApiService.post('/api/resource/save', {
        'project_id': widget.projectId, 'id': widget.resource?['id'] ?? 0,
        'name': _nameCtrl.text.trim(), 'is_active': _isActive ? 1 : 0, 'service_ids': _serviceIds.toList(),
      });
      if (result['success'] == true && mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (_) {}
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Удалить ресурс?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red)))],
    ));
    if (confirm == true) {
      await ApiService.post('/api/resource/delete', {'id': widget.resource!['id'], 'project_id': widget.projectId});
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    }
  }

  void _showServicePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
              child: Row(children: [
                const Expanded(child: Text('Выберите услуги', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _services.map((s) {
                  final id = s['id'] is int ? s['id'] as int : int.tryParse(s['id'].toString()) ?? 0;
                  final sel = _serviceIds.contains(id);
                  return ListTile(
                    title: Text(s['name'] ?? ''),
                    trailing: Icon(
                      sel ? Icons.check_box : Icons.check_box_outline_blank,
                      color: sel ? const Color(0xFFDD1847) : Colors.grey,
                    ),
                    onTap: () => setModalState(() {
                      sel ? _serviceIds.remove(id) : _serviceIds.add(id);
                    }),
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
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD1847),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back)),
            const SizedBox(width: 12),
            Text(_isEdit ? 'Редактирование ресурса' : 'Новый ресурс', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Название ресурса', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.3)),
                      const SizedBox(height: 8),
                      TextField(controller: _nameCtrl, decoration: InputDecoration(hintText: 'Например: Лампа для сушки', filled: true, fillColor: const Color(0xFFF8F8F8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
                    ]),
                    const SizedBox(height: 20),
                    Row(children: [const Text('Активен', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const Spacer(), Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeColor: const Color(0xFFDD1847))]),
                    const SizedBox(height: 20),
                    GestureDetector(onTap: _showServicePicker, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)), child: Row(children: [Expanded(child: Text(_serviceIds.isEmpty ? 'Связанные услуги' : 'Выбрано: ${_serviceIds.length}', style: TextStyle(fontSize: 14, color: _serviceIds.isEmpty ? const Color(0xFF888888) : const Color(0xFF1A1A1A)))), const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC))]))),
                    if (_isEdit) ...[const SizedBox(height: 20), SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _delete, style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF44336), side: const BorderSide(color: Color(0xFFF44336)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Удалить ресурс')))],
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }
}