import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../client/client_profile_sheet.dart';
import '../../../widgets/toast.dart';

class BusinessReviewsScreen extends StatefulWidget {
  final int projectId;
  const BusinessReviewsScreen({super.key, required this.projectId});

  static const String baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';

  /// Строит полный URL для изображения
  static String buildImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$cleanPath';
  }

  @override
  State<BusinessReviewsScreen> createState() => _BusinessReviewsScreenState();
}

class _BusinessReviewsScreenState extends State<BusinessReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;

  String _sort = 'newest';
  String _replyFilter = 'all';
  List<int> _clientIds = [];
  List<int> _employeeIds = [];

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadReviews(),
      _loadClients(),
      _loadEmployees(),
    ]);
  }

  Future<void> _loadReviews() async {
    try {
      final params = <String, String>{
        'project_id': widget.projectId.toString(),
        'sort': _sort,
        'reply': _replyFilter,
      };
      if (_clientIds.isNotEmpty) params['client_ids'] = _clientIds.join(',');
      if (_employeeIds.isNotEmpty) params['employee_ids'] = _employeeIds.join(',');

      final uri = '/api/review/list?${Uri(queryParameters: params).query}';
      final result = await ApiService.get(uri);

      if (result['success'] == true && mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _stats = result['stats'];
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки отзывов: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadClients() async {
    try {
      final result = await ApiService.get('/api/client/list?project_id=${widget.projectId}&limit=200');
      if (result['success'] == true) {
        _clients = List<Map<String, dynamic>>.from(result['data'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _loadEmployees() async {
    try {
      final result = await ApiService.get('/api/employee/list?project_id=${widget.projectId}');
      if (result['success'] == true) {
        _employees = List<Map<String, dynamic>>.from(result['data'] ?? []);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_stats != null) _buildRatingCard(),
        const SizedBox(height: 12),
        _buildFilters(),
        const SizedBox(height: 12),
        Expanded(
          child: _loading ? _buildSkeletonList() : _buildReviewsList(),
        ),
      ],
    );
  }

  Widget _buildRatingCard() {
    final avg = double.tryParse(_stats!['avg_rating']?.toString() ?? '0') ?? 0;
    final total = int.tryParse(_stats!['total']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDD1847), Color(0xFFC1163D)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            avg.toStringAsFixed(1),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => Text(
              i < avg.floor() ? '★' : '☆',
              style: const TextStyle(fontSize: 22, color: Colors.white),
            )),
          ),
          const SizedBox(height: 4),
          Text(
            '$total ${_reviewWord(total)}',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Row(
              children: [
                _filterPill('Все', 'all'),
                _filterPill('С ответом', 'with_reply'),
                _filterPill('Без ответа', 'without_reply'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _filterBtn('Клиенты', _clientIds.isNotEmpty, _showClientFilter),
              const SizedBox(width: 8),
              _filterBtn('Сотрудники', _employeeIds.isNotEmpty, _showEmployeeFilter),
              const Spacer(),
              PopupMenuButton<String>(
  onSelected: (v) { _sort = v; _loadReviews(); },
  color: Colors.white,
  surfaceTintColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  itemBuilder: (_) => [
    const PopupMenuItem(value: 'newest', child: Text('Сначала новые')),
    const PopupMenuItem(value: 'oldest', child: Text('Сначала старые')),
    const PopupMenuItem(value: 'positive', child: Text('Сначала положительные')),
    const PopupMenuItem(value: 'negative', child: Text('Сначала отрицательные')),
  ],
  child: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE8E8E8)),
    ),
    child: const Icon(Icons.swap_vert, size: 18, color: Color(0xFF999999)),
  ),
),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterPill(String label, String value) {
    final active = _replyFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () { _replyFilter = value; _loadReviews(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF5F5F5) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? const Color(0xFF1A1A1A) : const Color(0xFF888888),
          )),
        ),
      ),
    );
  }

  Widget _filterBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFFDD1847) : const Color(0xFFE8E8E8),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? const Color(0xFFDD1847) : const Color(0xFF666666))),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: active ? const Color(0xFFDD1847) : const Color(0xFF999999)),
        ]),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 3,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const SkeletonCircle(size: 44),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SkeletonBox(height: 14, width: 140),
              const SizedBox(height: 6),
              const SkeletonBox(height: 12, width: 100),
            ]),
          ]),
          const SizedBox(height: 12),
          const SkeletonBox(height: 16, width: 120),
          const SizedBox(height: 8),
          const SkeletonBox(height: 14),
          const SizedBox(height: 8),
          const SkeletonBox(height: 14, width: 200),
        ]),
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_reviews.isEmpty) {
      return const Center(child: Text('Нет отзывов', style: TextStyle(color: Color(0xFF999999))));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _reviews.length,
      itemBuilder: (_, i) => _buildReviewCard(_reviews[i]),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> r) {
    final clientName = (r['client_name'] ?? '').toString();
    final clientAvatar = r['client_avatar']?.toString();
    final rating = r['rating'] as int? ?? 0;
    final comment = (r['comment'] ?? '').toString();
    final date = (r['created_at'] ?? '').toString();
    final employeeName = r['employee_name']?.toString();
    final employeeAvatar = r['employee_avatar']?.toString();
    final reply = r['reply'] as Map<String, dynamic>?;
    final replyId = r['reply_id'];

    List<String> images = [];
    try {
      final rawImages = r['images'];
      if (rawImages is String && rawImages.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawImages);
          if (decoded is List) {
            images = List<String>.from(decoded.map((s) => s.toString()));
          } else {
            images = [rawImages];
          }
        } catch (_) {
          images = rawImages.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
      } else if (rawImages is List) {
        images = List<String>.from(rawImages.map((s) => s.toString()));
      }
    } catch (_) {}

    final initials = clientName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => _openClientProfile(r['client_id']),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFFDF2F5),
              child: (clientAvatar != null && clientAvatar.isNotEmpty)
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: BusinessReviewsScreen.buildImageUrl(clientAvatar),
                        width: 44, height: 44, fit: BoxFit.cover,
                        placeholder: (_, __) => const SkeletonCircle(size: 44),
                        errorWidget: (_, __, ___) => Text(initials, style: const TextStyle(color: Color(0xFFDD1847), fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    )
                  : Text(initials, style: const TextStyle(color: Color(0xFFDD1847), fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => _openClientProfile(r['client_id']),
              child: Text(clientName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ])),
          if (employeeName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE0E0E0))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (employeeAvatar != null) ...[
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: BusinessReviewsScreen.buildImageUrl(employeeAvatar),
                      width: 24, height: 24, fit: BoxFit.cover,
                      placeholder: (_, __) => const SkeletonCircle(size: 24),
                      errorWidget: (_, __, ___) => const Icon(Icons.person, size: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(employeeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF555555))),
              ]),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: List.generate(5, (i) => Text(i < rating ? '★' : '☆', style: const TextStyle(fontSize: 16, color: Color(0xFFF5A623))))),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(comment, style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.6)),
        ],
        if (images.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: images.map((img) => GestureDetector(
              onTap: () => _openFullPhoto(BusinessReviewsScreen.buildImageUrl(img)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: BusinessReviewsScreen.buildImageUrl(img),
                  width: 80, height: 80, fit: BoxFit.cover,
                  placeholder: (_, __) => const SkeletonBox(width: 80, height: 80, radius: 8),
                  errorWidget: (_, __, ___) => Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            )).toList(),
          ),
        ],
        if (reply != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ответ — ${reply['date'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
              const SizedBox(height: 4),
              Text(reply['content'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
            ]),
          ),
        ],
        if (replyId == null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => _openReplyModal(r['id']),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF666666), side: const BorderSide(color: Color(0xFFE0E0E0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Ответить', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ]),
    );
  }

  void _openClientProfile(int clientId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ClientProfileSheet(clientId: clientId, projectId: widget.projectId, onSaved: _loadReviews),
    );
  }

  void _openFullPhoto(String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.9),
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width,
                  placeholder: (_, __) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonCircle(size: 48),
                        SizedBox(height: 16),
                        SkeletonBox(height: 14, width: 120, radius: 7),
                      ],
                    ),
                  ),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _openReplyModal(int reviewId) {
    final _replyCtrl = TextEditingController();
    final List<File> _replyImages = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ответить на отзыв', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              // Поле текста
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _replyCtrl,
                  maxLines: 4,
                  maxLength: 400,
                  decoration: const InputDecoration(
                    hintText: 'Текст ответа',
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
              ),

              // Фото
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._replyImages.asMap().entries.map((entry) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          entry.value,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() => _replyImages.removeAt(entry.key));
                          },
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF44336),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )),

                  if (_replyImages.length < 3)
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1200,
                          maxHeight: 1200,
                        );
                        if (picked != null) {
                          setModalState(() => _replyImages.add(File(picked.path)));
                        }
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid, width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 20, color: Color(0xFF9CA3AF)),
                            SizedBox(height: 4),
                            Text('Фото', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              if (_replyImages.length < 3)
                const Padding(
                  padding: EdgeInsets.only(top: 4, left: 2),
                  child: Text(
                    'JPG, PNG, WEBP, GIF до 10 МБ • Максимум 3 фото',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
    if (_replyCtrl.text.trim().isEmpty) {
      showToast(ctx, 'Введите текст ответа', isError: true);
      return;
    }

    try {
      final uri = Uri.parse('${BusinessReviewsScreen.baseUrl}/api/review/reply');
      final request = http.MultipartRequest('POST', uri);

      request.fields['review_id'] = reviewId.toString();
      request.fields['content'] = _replyCtrl.text.trim();

      for (final img in _replyImages) {
        request.files.add(
          await http.MultipartFile.fromPath('images[]', img.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 && mounted) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          Navigator.pop(ctx);
          _loadReviews();
          showToast(context, 'Ответ отправлен!');
        } else {
          showToast(ctx, result['message'] ?? 'Ошибка', isError: true);
        }
      }
    } catch (e) {
      debugPrint('Ошибка отправки ответа: $e');
      showToast(ctx, 'Ошибка соединения', isError: true);
    }
  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD1847),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Отправить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClientFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _FilterSheet(
        title: 'Выберите клиентов',
        items: _clients,
        selectedIds: _clientIds.toSet(),
        getTitle: (c) => c['name'] ?? '',
        getSubtitle: (c) => c['phone'] ?? '',
        getAvatar: (c) => c['avatar']?.toString(),
        onApply: (ids) { _clientIds = ids.toList(); _loadReviews(); },
      ),
    );
  }

  void _showEmployeeFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _FilterSheet(
        title: 'Выберите сотрудников',
        items: _employees,
        selectedIds: _employeeIds.toSet(),
        getTitle: (e) => '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim(),
        getSubtitle: (e) => e['position'] ?? 'Сотрудник',
        getAvatar: (e) => e['avatar']?.toString(),
        onApply: (ids) { _employeeIds = ids.toList(); _loadReviews(); },
      ),
    );
  }

  String _reviewWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'отзыв';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) return 'отзыва';
    return 'отзывов';
  }
}

class _FilterSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final Set<int> selectedIds;
  final String Function(Map<String, dynamic>) getTitle;
  final String Function(Map<String, dynamic>) getSubtitle;
  final String? Function(Map<String, dynamic>) getAvatar;
  final Function(Set<int>) onApply;

  const _FilterSheet({
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.getTitle,
    required this.getSubtitle,
    required this.getAvatar,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: ListView(
            children: widget.items.map((item) {
              final id = item['id'] as int? ?? 0;
              final sel = _selected.contains(id);
              final avatarUrl = widget.getAvatar(item);
              
              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFFDF2F5),
                  child: (avatarUrl != null && avatarUrl.isNotEmpty) 
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: BusinessReviewsScreen.buildImageUrl(avatarUrl),
                            width: 36, height: 36, fit: BoxFit.cover,
                            placeholder: (_, __) => const SkeletonCircle(size: 36),
                            errorWidget: (_, __, ___) => Text(
                              widget.getTitle(item).isNotEmpty ? widget.getTitle(item)[0] : '?',
                              style: const TextStyle(color: Color(0xFFDD1847), fontWeight: FontWeight.w700),
                            ),
                          ),
                        )
                      : Text(
                          widget.getTitle(item).isNotEmpty ? widget.getTitle(item)[0] : '?',
                          style: const TextStyle(color: Color(0xFFDD1847), fontWeight: FontWeight.w700),
                        ),
                ),
                title: Text(widget.getTitle(item)),
                subtitle: Text(widget.getSubtitle(item), style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                trailing: sel ? const Icon(Icons.check, color: Color(0xFFDD1847)) : null,
                onTap: () {
                  setState(() { sel ? _selected.remove(id) : _selected.add(id); });
                },
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { widget.onApply(_selected); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Применить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }
}