import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';

class ContactScreen extends StatefulWidget {
  final int projectId;
  const ContactScreen({super.key, required this.projectId});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  Map<String, dynamic>? _project;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final result = await ApiService.get('/api/project-profile/get?project_id=${widget.projectId}');
      if (result['success'] == true && mounted) {
        setState(() { _project = result['data']; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text(_project?['name'] ?? 'Контакты', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: List.generate(4, (_) => _buildSkeletonItem()),
            )
          : _project == null
              ? const Center(child: Text('Ошибка загрузки'))
              : ListView(padding: const EdgeInsets.all(20), children: [
                  ...(_project!['phones'] as List<dynamic>? ?? []).map((phone) => _buildItem(
                    iconWidget: const Icon(Icons.phone, size: 22, color: Color(0xFF2E7D32)),
                    label: 'Позвонить', value: phone.toString(),
                    bgColor: const Color(0xFFE8F5E9),
                    onTap: () => _open('tel:$phone'),
                  )),
                  ..._buildSocials(),
                  if (_project!['email'] != null && _project!['email'].toString().isNotEmpty)
                    _buildItem(iconWidget: const Icon(Icons.email, size: 22, color: Color(0xFF7B1FA2)), label: 'Email', value: _project!['email'].toString(), bgColor: const Color(0xFFF3E5F5), onTap: () => _open('mailto:${_project!['email']}')),
                  if (_project!['site'] != null && _project!['site'].toString().isNotEmpty)
                    _buildItem(iconWidget: const Icon(Icons.language, size: 22, color: Color(0xFF666666)), label: 'Сайт', value: _project!['site'].toString(), bgColor: const Color(0xFFF5F5F5), onTap: () => _open(_project!['site'].toString())),
                ]),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(children: [
        const SkeletonBox(width: 44, height: 44, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 15, width: 100),
              const SizedBox(height: 6),
              const SkeletonBox(height: 13, width: 160),
            ],
          ),
        ),
        const SkeletonBox(width: 20, height: 20, radius: 4),
      ]),
    );
  }

  List<Widget> _buildSocials() {
    final links = _project!['social_links'];
    if (links == null) return [];
    List<dynamic> list;
    if (links is String) {
      try { list = List<dynamic>.from(jsonDecode(links)); } catch (_) { return []; }
    } else if (links is List) {
      list = links;
    } else {
      return [];
    }

    return list.map((link) {
      if (link is! Map) return const SizedBox.shrink();
      final type = link['type']?.toString() ?? '';
      final url = link['url']?.toString() ?? '';

      switch (type) {
        case 'whatsapp':
        case 'wa':
          final phone = url.replaceAll(RegExp(r'[^\d]'), '');
          return _buildItem(
            iconWidget: SvgPicture.asset('assets/whatsapp.svg', width: 22, height: 22),
            label: 'WhatsApp', value: phone,
            bgColor: const Color(0xFFE8F5E9),
            onTap: () => _open('https://wa.me/$phone'),
          );
        case 'telegram':
        case 'tg':
          return _buildItem(
            iconWidget: SvgPicture.asset('assets/telegram-nf.svg', width: 22, height: 22),
            label: 'Telegram', value: url,
            bgColor: const Color(0xFFE3F0FF),
            onTap: () => _open(url),
          );
        case 'vk':
          return _buildItem(
            iconWidget: SvgPicture.asset('assets/vk-nt.svg', width: 22, height: 22),
            label: 'ВКонтакте', value: url,
            bgColor: const Color(0xFFE3F0FF),
            onTap: () => _open(url),
          );
        case 'site':
          return _buildItem(
            iconWidget: const Icon(Icons.language, size: 22, color: Color(0xFF666666)),
            label: 'Сайт', value: url,
            bgColor: const Color(0xFFF5F5F5),
            onTap: () => _open(url),
          );
        default:
          return const SizedBox.shrink();
      }
    }).toList();
  }

  Widget _buildItem({required Widget iconWidget, required String label, required String value, required Color bgColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Center(child: iconWidget)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF888888)))])),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }
}