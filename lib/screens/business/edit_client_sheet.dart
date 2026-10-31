import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import '../../../widgets/toast.dart';
import '../../../widgets/common/phone_input.dart';

class EditClientSheet extends StatefulWidget {
  final int? clientId;
  final int projectId;
  final VoidCallback onSaved;

  const EditClientSheet({
    super.key,
    this.clientId,
    required this.projectId,
    required this.onSaved,
  });

  @override
  State<EditClientSheet> createState() => _EditClientSheetState();
}

class _EditClientSheetState extends State<EditClientSheet> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final GlobalKey<PhoneInputState> _phoneKey = GlobalKey<PhoneInputState>();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  

  bool _blocked = false;
  String? _gender;
  List<Map<String, String>> _socialLinks = [];
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.clientId != null;


  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadClient();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClient() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.get(
        '/api/client/get?id=${widget.clientId}&project_id=${widget.projectId}',
      );
      if (result['success'] == true && mounted) {
        final c = result['data'];
        final name = (c['name'] ?? '').toString();
        final parts = name.split(' ');
        
        final phone = (c['phone'] ?? '').toString();

        List<Map<String, String>> socialLinks = [];
        try {
          final raw = c['social_links'];
          if (raw is String && raw.isNotEmpty) {
            socialLinks = List<Map<String, String>>.from(jsonDecode(raw));
          } else if (raw is List) {
            socialLinks = List<Map<String, String>>.from(raw);
          }
        } catch (_) { /* silent: jsonDecode(social) */ }

        setState(() {
          _firstNameCtrl.text = parts.isNotEmpty ? parts[0] : '';
          _lastNameCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          _phoneCtrl.text = phone;
          _emailCtrl.text = c['email'] ?? '';
          _notesCtrl.text = c['notes'] ?? '';
          _discountCtrl.text = c['discount']?.toString() ?? '';
          _blocked = c['blocked'] == 1;
          _gender = c['gender'];
          _socialLinks = socialLinks;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getFullPhone() => _phoneKey.currentState?.fullPhone ?? '';

  Future<void> _save() async {
    final firstName = _firstNameCtrl.text.trim();
    if (firstName.isEmpty) {
      showToast(context, 'Введите имя', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final body = {
        'project_id': widget.projectId,
        'id': widget.clientId,
        'name': '$firstName ${_lastNameCtrl.text.trim()}'.trim(),
        'phone': _getFullPhone(),
        'email': _emailCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'discount': int.tryParse(_discountCtrl.text) ?? 0,
        'gender': _gender,
        'blocked': _blocked ? 1 : 0,
        'social_links': _socialLinks.isNotEmpty ? jsonEncode(_socialLinks) : null,
      };

      final result = await ApiService.post('/api/client/save', body);
      if (result['success'] == true && mounted) {
        Navigator.pop(context);
        widget.onSaved();
      } else if (mounted) {
        showToast(context, result['message'] ?? 'Ошибка сохранения', isError: true);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Ошибка сохранения', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _deleteClient() async {
    if (!_isEdit) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить клиента?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Color(0xFFF44336))),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final result = await ApiService.post('/api/client/delete', {
        'id': widget.clientId,
        'project_id': widget.projectId,
      });
      if (result['success'] == true && mounted) {
        Navigator.pop(context);
        widget.onSaved();
        showToast(context, 'Клиент удалён');
      }
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Ошибка удаления', isError: true);
    }
  }
  

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Выберите пол', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              title: const Text('Мужской'),
              trailing: _gender == 'male' ? const Icon(Icons.check, color: Color(0xFFDD1847)) : null,
              onTap: () {
                setState(() => _gender = 'male');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Женский'),
              trailing: _gender == 'female' ? const Icon(Icons.check, color: Color(0xFFDD1847)) : null,
              onTap: () {
                setState(() => _gender = 'female');
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSocialEditor() {
    final vkCtrl = TextEditingController();
    final tgCtrl = TextEditingController();
    final siteCtrl = TextEditingController();
    
    for (final link in _socialLinks) {
      if (link['type'] == 'vk') vkCtrl.text = link['url'] ?? '';
      if (link['type'] == 'telegram') tgCtrl.text = link['url'] ?? '';
      if (link['type'] == 'site') siteCtrl.text = link['url'] ?? '';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ссылки на соц. сети', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            _socialField(vkCtrl, 'VK', 'assets/vk-outline.svg'),
            const SizedBox(height: 12),
            _socialField(tgCtrl, 'Telegram', 'assets/telegram.svg'),
            const SizedBox(height: 12),
            _socialField(siteCtrl, 'Сайт', 'assets/web-link.svg'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  _socialLinks.clear();
                  if (vkCtrl.text.isNotEmpty) _socialLinks.add({'type': 'vk', 'url': vkCtrl.text});
                  if (tgCtrl.text.isNotEmpty) _socialLinks.add({'type': 'telegram', 'url': tgCtrl.text});
                  if (siteCtrl.text.isNotEmpty) _socialLinks.add({'type': 'site', 'url': siteCtrl.text});
                  setState(() {});
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD1847),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialField(TextEditingController ctrl, String label, String iconAsset) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: SvgPicture.asset(iconAsset, width: 24, height: 24, colorFilter: const ColorFilter.mode(Color(0xFF666666), BlendMode.srcIn)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: label,
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  String _getInitials() {
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    if (first.isEmpty && last.isEmpty) return '?';
    return '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : first.isNotEmpty ? first.length > 1 ? first[1] : '' : ''}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back),
                ),
                const Spacer(),
                Text(
                  _isEdit ? 'Редактирование клиента' : 'Новый клиент',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Avatar + Name fields
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF0F0F0),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              _getInitials(),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFFDD1847)),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFF0F0F0),
                              ),
                              child: const Icon(Icons.lock, size: 12, color: Color(0xFF999999)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _field(_firstNameCtrl, 'Имя'),
                          const SizedBox(height: 8),
                          _field(_lastNameCtrl, 'Фамилия'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Phone
                _buildPhoneField(),
                const SizedBox(height: 20),
                // Email
                _field(_emailCtrl, 'Электронная почта', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
                // Social
                _buildRow(
                  'Ссылки на соц. сети',
                  _socialLinks.isEmpty ? '' : '${_socialLinks.length} ссылки',
                  onTap: _showSocialEditor,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _socialLinks.map((l) {
                      String asset;
                      switch (l['type']) {
                        case 'telegram': asset = 'assets/telegram.svg'; break;
                        case 'vk': asset = 'assets/vk-outline.svg'; break;
                        default: asset = 'assets/web-link.svg';
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: SvgPicture.asset(asset, width: 16, height: 16),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                // Discount
                _buildRow(
                  'Скидка',
                  '',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _discountCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8F8F8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('%', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF666666))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Gender
                _buildRow(
                  'Пол',
                  _gender == null ? 'Не указан' : (_gender == 'male' ? 'Мужской' : 'Женский'),
                  onTap: _showGenderPicker,
                ),
                const SizedBox(height: 20),
                // Notes
                _field(_notesCtrl, 'Заметки...', maxLines: 3),
                const SizedBox(height: 20),
                // Blocked toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Заблокирован', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Switch(
                            value: _blocked,
                            onChanged: (v) => setState(() => _blocked = v),
                            activeThumbColor: const Color(0xFFDD1847),
                          ),
                        ],
                      ),
                      const Text(
                        'Заблокированные клиенты не могут записаться онлайн',
                        style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                      ),
                    ],
                  ),
                ),
                // Delete button
                if (_isEdit) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _deleteClient,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Удалить клиента'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF44336),
                          side: const BorderSide(color: Color(0xFFF44336)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Save button
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEdit ? 'Сохранить' : 'Создать клиента', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return PhoneInput(
      key: _phoneKey,
      controller: _phoneCtrl,
      onPhoneChanged: (_) => setState(() {}),
    );
  }

  Widget _buildRow(String label, String value, {VoidCallback? onTap, Widget? trailing}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            ?trailing,
            if (value.isNotEmpty) Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDD1847))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}