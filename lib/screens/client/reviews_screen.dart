import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Map<String, dynamic>> _orgs = [];
  List<Map<String, dynamic>> _reviews = [];
  String? _selectedOrgName;
  bool _loading = true;
  bool _showDetail = false;

  @override
  void initState() {
    super.initState();
    _loadOrgs();
  }

  void _loadOrgs() async {
    setState(() { _loading = true; _showDetail = false; });
    try {
      final result = await ApiService.get('/api/review/my-orgs');
      if (result['success'] == true && mounted) {
        setState(() { _orgs = List<Map<String, dynamic>>.from(result['data'] ?? []); _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadReviews(int projectId, String orgName) async {
    setState(() { _loading = true; _selectedOrgName = orgName; });
    try {
      final result = await ApiService.get('/api/review/my-list?project_id=$projectId');
      if (result['success'] == true && mounted) {
        setState(() { _reviews = List<Map<String, dynamic>>.from(result['data'] ?? []); _loading = false; _showDetail = true; });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _word(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'отзыв';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) return 'отзыва';
    return 'отзывов';
  }

  String _date(String? d) {
    if (d == null) return '';
    final date = DateTime.tryParse(d);
    if (date == null) return '';
    const m = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
    return '${date.day} ${m[date.month - 1]} ${date.year}';
  }

  Widget _photoPlaceholder({double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.2),
        child: SvgPicture.asset('assets/photo-none.svg'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text(_showDetail ? (_selectedOrgName ?? 'Отзывы') : 'Мои отзывы', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.grey), onPressed: () {
          if (_showDetail) { _loadOrgs(); } else { Navigator.pop(context); }
        }),
      ),
      body: _loading
          ? _showDetail
              ? _buildSkeletonReviews()
              : _buildSkeletonOrgs()
          : _showDetail
              ? _buildReviews()
              : _buildOrgs(),
    );
  }

  Widget _buildSkeletonOrgs() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[100]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const SkeletonBox(width: 52, height: 52, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 15, width: 150),
                const SizedBox(height: 6),
                const SkeletonBox(height: 12, width: 200),
                const SizedBox(height: 4),
                const SkeletonBox(height: 20, width: 80, radius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(children: [
            const SkeletonBox(height: 24, width: 30),
            const SizedBox(height: 4),
            const SkeletonBox(height: 11, width: 50),
          ]),
          const SizedBox(width: 4),
          const SkeletonBox(width: 20, height: 20, radius: 4),
        ]),
      ),
    );
  }

  Widget _buildSkeletonReviews() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[100]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: List.generate(5, (_) => const Padding(padding: EdgeInsets.only(right: 4), child: SkeletonBox(width: 16, height: 16, radius: 2)))),
            const SizedBox(height: 8),
            const SkeletonBox(height: 14),
            const SizedBox(height: 4),
            const SkeletonBox(height: 14, width: 200),
            const SizedBox(height: 8),
            const SkeletonBox(height: 12, width: 180),
            const SizedBox(height: 8),
            Row(children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(right: 6), child: SkeletonBox(width: 70, height: 70, radius: 10)))),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgs() {
    if (_orgs.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.star_border, size: 48, color: Color(0xFFCCCCCC)), SizedBox(height: 12), Text('У вас пока нет отзывов', style: TextStyle(color: Color(0xFF999999)))]) );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orgs.length,
      itemBuilder: (_, i) {
        final o = _orgs[i];
        final photo = o['profile_photo'];
        return GestureDetector(
          onTap: () => _loadReviews(o['project_id'] ?? 0, o['name'] ?? ''),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFF0F0F0)), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: photo != null && photo.toString().isNotEmpty
                    ? CachedAvatar(url: photo, size: 52, radius: 14)
                    : _photoPlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(o['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), if (o['address_raw'] != null) Text(o['address_raw'], style: const TextStyle(fontSize: 12, color: Color(0xFF999999))), if (o['sphere'] != null) _sphereChip(o['sphere'].toString())])),
              Column(children: [Text('${o['review_count'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)), Text(_word(o['review_count'] ?? 0), style: const TextStyle(fontSize: 11, color: Color(0xFF999999)))]),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
            ]),
          ),
        );
      },
    );
  }

  Widget _sphereChip(String s) {
    final m = {'beauty':'Красота','health':'Здоровье','sport':'Спорт','auto':'Авто','education':'Образование','animals':'Животные','entertainment':'Развлечения','law':'Право','style':'Стиль','rent':'Аренда','restaurant':'Рестораны','other':'Прочее'};
    return Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFDF2F5), borderRadius: BorderRadius.circular(6)), child: Text(m[s] ?? s, style: const TextStyle(fontSize: 11, color: Color(0xFFDD1847))));
  }

  Widget _buildReviews() {
    if (_reviews.isEmpty) return const Center(child: Text('Нет отзывов', style: TextStyle(color: Color(0xFF999999))));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (_, i) {
        final r = _reviews[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFF0F0F0)), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: List.generate(5, (j) => Icon(j < (r['rating'] ?? 0) ? Icons.star : Icons.star_border, size: 16, color: j < (r['rating'] ?? 0) ? const Color(0xFFF5A623) : const Color(0xFFE5E7EB)))),
              if (r['comment'] != null && r['comment'].toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(r['comment'].toString(), style: const TextStyle(fontSize: 14, height: 1.5))),
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('${_date(r['created_at'])} · ${r['employee_name'] ?? 'Сотрудник'}', style: const TextStyle(fontSize: 12, color: Color(0xFF999999)))),
              if (r['images'] != null && (r['images'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 6, children: (r['images'] as List).map((img) => GestureDetector(
                    onTap: () => _openLightbox(img.toString()),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai${img.toString()}',
                        width: 70, height: 70, fit: BoxFit.cover,
                        placeholder: (_, __) => const SkeletonBox(width: 70, height: 70, radius: 10),
                        errorWidget: (_, __, ___) => _photoPlaceholder(size: 70),
                      ),
                    ),
                  )).toList()),
                ),
              if (r['reply'] != null)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ответ организации', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
                    const SizedBox(height: 6),
                    Text(r['reply']['content']?.toString() ?? '', style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF555555))),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openLightbox(String url) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: CachedNetworkImage(
              imageUrl: 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai$url',
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    ));
  }
}