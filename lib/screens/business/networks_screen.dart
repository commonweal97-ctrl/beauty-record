import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/toast.dart';

class NetworksScreen extends StatefulWidget {
  const NetworksScreen({super.key});

  @override
  State<NetworksScreen> createState() => _NetworksScreenState();
}

class _NetworksScreenState extends State<NetworksScreen> {
  List<Map<String, dynamic>> _networks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final result = await ApiService.get('/api/network/list');
      if (result['success'] == true && mounted) {
        setState(() { _networks = List<Map<String, dynamic>>.from(result['data'] ?? []); _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyLink(String slug) {
    Clipboard.setData(ClipboardData(text: 'https://запись.бьютироща.рф/network/$slug'));
    showToast(context, 'Ссылка скопирована!');
  }

  void _editNetwork(Map<String, dynamic> n) async {
    final result = await ApiService.get('/api/network/get?id=${n['id']}');
    if (result['success'] != true || !mounted) return;
    final network = result['data'];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CreateNetworkSheet(network: network),
    ).then((_) => _load());
  }

  void _deleteNetwork(int id) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Удалить сеть?'), content: const Text('Ссылка перестанет работать'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red)))],));
    if (confirm != true) return;
    try {
      await ApiService.deleteNetwork(id);
      _load();
    } catch (_) {}
  }

  Widget _logoPlaceholder({double size = 56}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.25),
        child: SvgPicture.asset('assets/photo-none.svg'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('Сети', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.grey), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? ListView.builder(padding: const EdgeInsets.all(16), itemCount: 3, itemBuilder: (_, _) => _buildSkeleton())
          : _networks.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _networks.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(children: [
                        Expanded(child: Text('Сети', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.grey[900]))),
                        GestureDetector(onTap: () => _showCreateDialog(), child: Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFDD1847), Color(0xFFC1163D)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Colors.white))),
                      ]),
                    );
                    }
                    return _buildCard(_networks[i - 1]);
                  },
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> n) {
    final shortLink = 'network/${n['slug']}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: n['logo_url'] != null && n['logo_url'].toString().isNotEmpty
              ? CachedAvatar(url: n['logo_url'], size: 56, radius: 14)
              : _logoPlaceholder(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _copyLink(n['slug'] ?? ''),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFDF2F5), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(shortLink, style: const TextStyle(fontSize: 12, color: Color(0xFFDD1847))),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy, size: 14, color: Color(0xFFDD1847)),
                ]),
              ),
            ),
            Text('${n['projects_count'] ?? 0} ${_word(n['projects_count'] ?? 0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(onTap: () => _editNetwork(n), child: Container(width: 36, height: 36, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit, size: 16, color: Color(0xFF666666)))),
          const SizedBox(width: 8),
          GestureDetector(onTap: () => _deleteNetwork(n['id'] ?? 0), child: Container(width: 36, height: 36, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFF44336)))),
        ]),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.hub, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('Сетей ещё нет', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Создайте сеть, чтобы клиенты могли записаться в любую из ваших точек', style: TextStyle(color: Color(0xFF888888)), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: () => _showCreateDialog(), icon: const Icon(Icons.add, color: Colors.white), label: const Text('Создать сеть', style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ])),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(children: [
        const SkeletonBox(width: 56, height: 56, radius: 14),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 14, width: 150),
              const SizedBox(height: 10),
              const SkeletonBox(height: 24, width: 200, radius: 6),
            ],
          ),
        ),
      ]),
    );
  }

  String _word(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'проект';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) return 'проекта';
    return 'проектов';
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const CreateNetworkSheet(),
    ).then((_) => _load());
  }
}

class CreateNetworkSheet extends StatefulWidget {
  final Map<String, dynamic>? network;
  const CreateNetworkSheet({super.key, this.network});

  @override
  State<CreateNetworkSheet> createState() => _CreateNetworkSheetState();
}

class _CreateNetworkSheetState extends State<CreateNetworkSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _vkCtrl = TextEditingController();
  final _tgCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  List<int> _selectedProjectIds = [];
  List<Map<String, dynamic>> _availableProjects = [];
  String? _logoUrl;
  String _slug = '';
  bool _loading = false;
  bool _loadingProjects = true;
  String _countryDial = '+7';
  String _countryFlag = '🇷🇺';
  String _countryCode = '7';
  bool get _isEdit => widget.network != null;

  final _countries = [
    {'code': '7', 'dial': '+7', 'flag': '🇷🇺', 'name': 'Россия'},
    {'code': '375', 'dial': '+375', 'flag': '🇧🇾', 'name': 'Беларусь'},
    {'code': '7', 'dial': '+7', 'flag': '🇰🇿', 'name': 'Казахстан'},
    {'code': '380', 'dial': '+380', 'flag': '🇺🇦', 'name': 'Украина'},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final n = widget.network!;
      _nameCtrl.text = n['name'] ?? '';
      _slug = n['slug'] ?? '';
      _logoUrl = n['logo_url'];
      _selectedProjectIds = List<int>.from(n['project_ids'] ?? []);
      
      if (n['phone'] != null && n['phone'].toString().isNotEmpty) {
        String phone = n['phone'].toString();
        if (phone.startsWith('+7')) {
          _countryDial = '+7'; _countryFlag = '🇷🇺'; _countryCode = '7';
          phone = phone.substring(2);
        } else if (phone.startsWith('+375')) {
          _countryDial = '+375'; _countryFlag = '🇧🇾'; _countryCode = '375';
          phone = phone.substring(4);
        } else if (phone.startsWith('+380')) {
          _countryDial = '+380'; _countryFlag = '🇺🇦'; _countryCode = '380';
          phone = phone.substring(4);
        }
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        if (_countryCode == '7' && digits.length >= 10) {
          _phoneCtrl.text = '${digits.substring(0,3)} ${digits.substring(3,6)} ${digits.substring(6,8)} ${digits.substring(8,10)}';
        } else {
          _phoneCtrl.text = digits;
        }
      }
      
      final links = n['social_links'];
      if (links is String) { try { _fillSocials(List<Map<String, dynamic>>.from(jsonDecode(links))); } catch (_) {} }
      else if (links is List) { _fillSocials(List<Map<String, dynamic>>.from(links)); }
    }
    _loadProjects();
  }

  void _fillSocials(List<Map<String, dynamic>> links) {
    for (final l in links) {
      if (l['type'] == 'vk') _vkCtrl.text = l['url'] ?? '';
      if (l['type'] == 'telegram') _tgCtrl.text = l['url'] ?? '';
      if (l['type'] == 'site') _siteCtrl.text = l['url'] ?? '';
    }
  }

  void _loadProjects() async {
    try {
      final result = await ApiService.get('/api/network/available-projects');
      if (result['success'] == true) _availableProjects = List<Map<String, dynamic>>.from(result['data'] ?? []);
    } catch (_) {}
    if (mounted) setState(() => _loadingProjects = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _vkCtrl.dispose(); _tgCtrl.dispose(); _siteCtrl.dispose();
    super.dispose();
  }

  String _transliterate(String text) {
    const map = {'а':'a','б':'b','в':'v','г':'g','д':'d','е':'e','ё':'yo','ж':'zh','з':'z','и':'i','й':'y','к':'k','л':'l','м':'m','н':'n','о':'o','п':'p','р':'r','с':'s','т':'t','у':'u','ф':'f','х':'h','ц':'ts','ч':'ch','ш':'sh','щ':'sch','ъ':'','ы':'y','ь':'','э':'e','ю':'yu','я':'ya',' ':'-'};
    return text.toLowerCase().split('').map((c) => map[c] ?? c).join().replaceAll(RegExp(r'[^a-z0-9-]'), '').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  }

  void _onNameChanged(String v) {
    setState(() => _slug = _transliterate(v));
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Выберите страну', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        ..._countries.map((c) => ListTile(
          leading: Text(c['flag']!, style: const TextStyle(fontSize: 28)),
          title: Text(c['name']!),
          trailing: Text(c['dial']!, style: const TextStyle(fontSize: 16, color: Color(0xFF666666))),
          onTap: () { setState(() { _countryDial = c['dial']!; _countryFlag = c['flag']!; _countryCode = c['code']!; }); Navigator.pop(context); },
        )),
      ])),
    );
  }

  void _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final socials = <Map<String, String>>[];
      if (_vkCtrl.text.isNotEmpty) socials.add({'type': 'vk', 'url': _vkCtrl.text});
      if (_tgCtrl.text.isNotEmpty) socials.add({'type': 'telegram', 'url': _tgCtrl.text});
      if (_siteCtrl.text.isNotEmpty) socials.add({'type': 'site', 'url': _siteCtrl.text});
      final body = {
        if (_isEdit) 'id': widget.network!['id'].toString(),
        'name': _nameCtrl.text.trim(), 'slug': _slug,
        'phone': _phoneCtrl.text.isNotEmpty 
            ? '$_countryDial${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '').replaceFirst(_countryCode, '')}' 
            : '',
        'project_ids': _selectedProjectIds, 'social_links': jsonEncode(socials),
      };
      final result = await ApiService.saveNetwork(body);
      if (result['success'] == true && mounted) Navigator.pop(context, true);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _openSocialPopup() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [const Spacer(), const Text('Ссылки на соц. сети', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), const Spacer(), IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))]),
          const SizedBox(height: 16),
          _socialField('assets/vk-nt.svg', 'ВКонтакте', _vkCtrl),
          const SizedBox(height: 12),
          _socialField('assets/telegram-nf.svg', 'Telegram', _tgCtrl),
          const SizedBox(height: 12),
          _socialField('assets/link.svg', 'Сайт', _siteCtrl),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () { Navigator.pop(context); setState(() {}); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)))),
        ]),
      ),
    );
  }

  Widget _socialField(String icon, String hint, TextEditingController ctrl) {
    return Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)), child: Center(child: SvgPicture.asset(icon, width: 28, height: 28))),
      const SizedBox(width: 12),
      Expanded(child: _miniField(ctrl, 'https://$hint')),
    ]);
  }

  Widget _logoPlaceholder({double size = 86}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.25),
        child: SvgPicture.asset('assets/photo-none.svg'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSocials = _vkCtrl.text.isNotEmpty || _tgCtrl.text.isNotEmpty || _siteCtrl.text.isNotEmpty;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.grey), onPressed: () => Navigator.pop(context)),
            const Spacer(),
            Text(_isEdit ? 'Редактирование сети' : 'Новая сеть', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
            const Text('НАЗВАНИЕ И ЛОГОТИП', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E0E0))),
              child: Row(children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 86, height: 86,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDDDDDD), style: BorderStyle.solid)),
                    child: _logoUrl != null && _logoUrl.toString().isNotEmpty
                        ? Stack(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedAvatar(url: _logoUrl, size: 86, radius: 14),
                            ),
                            Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.camera_alt, color: Colors.white, size: 24))),
                          ])
                        : _logoPlaceholder(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _miniField(_nameCtrl, 'Название сети', bold: true, onChanged: _onNameChanged),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE0E0E0))),
                      child: Text(_slug.isEmpty ? 'network/введите-название' : 'network/$_slug', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _slug.isEmpty ? const Color(0xFF999999) : const Color(0xFFDD1847)), overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('ТЕЛЕФОН', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
              child: Row(children: [
                GestureDetector(
                  onTap: () => _showCountryPicker(),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0x1A000000)))), child: Row(children: [Text(_countryFlag, style: const TextStyle(fontSize: 20)), const SizedBox(width: 4), Text(_countryDial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF666666)))])),
                ),
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 15),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s]'))],
                    onChanged: (v) {
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      if (_countryCode == '7' && digits.length >= 7) {
                        final formatted = '${digits.substring(0,3)} ${digits.substring(3,6)} ${digits.substring(6,8)} ${digits.substring(8,10)}';
                        if (formatted != v) {
                          _phoneCtrl.value = TextEditingValue(text: formatted.trim(), selection: TextSelection.collapsed(offset: formatted.trim().length));
                        }
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: '987 654 32 10',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _openSocialPopup,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
                child: Row(children: [
                  const Text('Ссылки на соц. сети', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  if (hasSocials) Row(children: [
                    if (_vkCtrl.text.isNotEmpty) SvgPicture.asset('assets/vk-nt.svg', width: 18, height: 18),
                    if (_tgCtrl.text.isNotEmpty) const SizedBox(width: 6),
                    if (_tgCtrl.text.isNotEmpty) SvgPicture.asset('assets/telegram-nf.svg', width: 18, height: 18),
                    if (_siteCtrl.text.isNotEmpty) const SizedBox(width: 6),
                    if (_siteCtrl.text.isNotEmpty) SvgPicture.asset('assets/link.svg', width: 18, height: 18),
                  ]) else const Text('Не указаны', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            const Text('ПРОЕКТЫ В СЕТИ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            if (_loadingProjects)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDD1847))),
              )
            else
              ..._availableProjects.map((p) {
                final isOnline = p['online_booking_enabled'] == 1 || p['online_booking_enabled'] == true;
                final isSelected = _selectedProjectIds.contains(p['id']);
                final photo = p['profile_photo'];
                return GestureDetector(
                  onTap: (isOnline || isSelected) ? () => setState(() { isSelected ? _selectedProjectIds.remove(p['id']) : _selectedProjectIds.add(p['id']); }) : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFDF2F5) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? const Color(0xFFDD1847) : const Color(0xFFF0F0F0)),
                    ),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: photo != null && photo.toString().isNotEmpty
                            ? CachedAvatar(url: photo, size: 44, radius: 12)
                            : _logoPlaceholder(size: 44),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        if (p['address_raw'] != null) Text(p['address_raw'], style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                        Text(isOnline ? 'Онлайн-запись активна' : 'Онлайн-запись выключена', style: TextStyle(fontSize: 11, color: isOnline ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
                      ])),
                      Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? const Color(0xFFDD1847) : const Color(0xFFCCCCCC), width: 2), color: isSelected ? const Color(0xFFDD1847) : Colors.transparent), child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null),
                    ]),
                  ),
                );
              }),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: _nameCtrl.text.isNotEmpty && !_loading ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD1847),
              disabledBackgroundColor: const Color(0xFFDD1847),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                      SizedBox(width: 12),
                      Text(_isEdit ? 'Сохранение...' : 'Создание...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  )
                : Text(_isEdit ? 'Сохранить' : 'Создать', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          )),
        ),
      ]),
    );
  }


  Widget _miniField(TextEditingController c, String hint, {bool bold = false, ValueChanged<String>? onChanged}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE0E0E0))),
      child: TextField(controller: c, onChanged: onChanged, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w600 : FontWeight.w400), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true)),
    );
  }
}