// lib/screens/client/booking/master_detail_modal.dart
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/cached_image.dart';

class MasterDetailModal extends StatefulWidget {
  final Map<String, dynamic> master;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> employeeServiceLinks;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> workPhotos;
  final Color primaryColor;
  final Color buttonBg;
  final Color buttonText;
  final String specialistLabel;
  final String serviceLabel;
  
  const MasterDetailModal({
    super.key,
    required this.master,
    required this.employees,
    required this.employeeServiceLinks,
    required this.services,
    required this.workPhotos,
    required this.primaryColor,
    required this.buttonBg,
    required this.buttonText,
    this.specialistLabel = 'Специалисты',
    this.serviceLabel = 'Услуги',
  });

  @override
  State<MasterDetailModal> createState() => _MasterDetailModalState();
}

class _MasterDetailModalState extends State<MasterDetailModal> {
  bool _descExpanded = false;
  double _masterRating = 0;
  int _masterReviewsCount = 0;
  List<Map<String, dynamic>> _masterReviews = [];
  bool _loadingReviews = true;
  
  List<Map<String, dynamic>> get _masterServices {
    final serviceIds = widget.employeeServiceLinks
        .where((l) => (l['employee_id'] as num).toInt() == (widget.master['id'] as num).toInt())
        .map((l) => (l['service_id'] as num).toInt())
        .toList();
    
    return widget.services.where((s) => serviceIds.contains((s['id'] as num).toInt())).toList();
  }
  
  List<Map<String, dynamic>> get _masterPhotos {
    return widget.workPhotos.where((p) {
      return (p['employee_id'] as num?)?.toInt() == (widget.master['id'] as num).toInt() ||
             p['name'] == widget.master['name'];
    }).toList();
  }
  
  @override
  void initState() {
    super.initState();
    _loadReviews();
  }
  
  Future<void> _loadReviews() async {
    try {
      final result = await ApiService.get(
        '/api/review/public-list?project_id=0&employee_id=${widget.master['id']}&limit=50&offset=0'
      );
      
      if (result['success'] == true) {
        _masterReviews = List<Map<String, dynamic>>.from(result['data'] ?? []);
        
        final empStats = result['employee_stats'];
        if (empStats != null && empStats is Map) {
          final stats = empStats[widget.master['id'].toString()];
          if (stats != null && stats is Map) {
            _masterRating = (stats['avg_rating'] as num?)?.toDouble() ?? 0;
            _masterReviewsCount = (stats['total'] as num?)?.toInt() ?? 0;
          }
        }
      }
    } catch (_) {}
    
    setState(() => _loadingReviews = false);
  }
  
  String _formatPrice(Map<String, dynamic> s) {
    final price = (s['price'] as num?)?.toInt() ?? 0;
    if (price == 0) return 'Бесплатно';
    final from = s['price_from'] == 1 || s['price_from'] == true;
    return '${from ? 'от ' : ''}$price ₽';
  }
  
  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    if (m > 0) return '$m мин';
    return '';
  }
  
  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr.replaceFirst(' ', 'T'));
      const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final master = widget.master;
    final services = _masterServices;
    final photos = _masterPhotos;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Хедер
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: widget.primaryColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      master['name'] ?? widget.specialistLabel,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Контент
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Фото мастера
                  if (master['avatar'] != null && master['avatar'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 4/3,
                        child: CachedAvatar(url: master['avatar'], size: double.infinity, radius: 0),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Белый блок: ФИО, должность, описание, рейтинг
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(master['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        if (master['position'] != null && master['position'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(master['position'], style: const TextStyle(fontSize: 14, color: Color(0x000ff888))),
                          ),
                        
                        // Описание
                        if (master['description'] != null && master['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            master['description'],
                            maxLines: _descExpanded ? null : 4,
                            overflow: _descExpanded ? null : TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: Color(0x000ff555), height: 1.5),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _descExpanded = !_descExpanded),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _descExpanded ? 'Скрыть' : 'Подробнее',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: widget.primaryColor),
                              ),
                            ),
                          ),
                        ],
                        
                        // Рейтинг
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ...List.generate(5, (i) => Icon(
                              i < _masterRating.round() ? Icons.star : Icons.star_border,
                              size: 18,
                              color: i < _masterRating.round() ? const Color(0xFFF5A623) : const Color(0xFFE5E7EB),
                            )),
                            const SizedBox(width: 8),
                            Text(_masterRating.toStringAsFixed(1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            Text('· $_masterReviewsCount ${_getReviewWord(_masterReviewsCount)}', style: const TextStyle(fontSize: 13, color: Color(0x000ff888))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Примеры работ
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Примеры работ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        itemBuilder: (_, i) {
                          final photo = photos[i]['photo_url'] ?? '';
                          return GestureDetector(
                            onTap: () => _showLightbox(photo),
                            child: Container(
                              width: 150,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: CachedAvatar(url: photo, size: 150, radius: 14),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  
                  // Услуги мастера
                  const SizedBox(height: 20),
                  Text(widget.serviceLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  
                  if (services.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Нет доступных услуг', style: TextStyle(color: Color(0x000ff999))),
                    )
                  else
                    ...services.map((s) => GestureDetector(
                      onTap: () {
                        // Закрываем мастер-модалку и передаём мастера для записи
                        Navigator.pop(context, widget.master);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: s['photo_url'] != null && s['photo_url'].toString().isNotEmpty
                                  ? ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedAvatar(url: s['photo_url'], size: 56, radius: 14))
                                  : Icon(Icons.photo, color: Colors.grey[400]),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  if (s['category'] != null && s['category'].toString().isNotEmpty)
                                    Text(s['category'], style: const TextStyle(fontSize: 12, color: Color(0x000ff888))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_formatPrice(s), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                if ((s['duration'] ?? 0) > 0)
                                  Text(_formatDuration((s['duration'] as num).toInt()), style: const TextStyle(fontSize: 11, color: Color(0x000ff888))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
                  
                  // Отзывы
                  const SizedBox(height: 20),
                  const Text('Отзывы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  
                  if (_loadingReviews)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_masterReviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Пока нет отзывов', style: TextStyle(color: Color(0x000ff999))),
                    )
                  else
                    ..._masterReviews.map((review) => _buildReviewCard(review)),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      // Нижняя панель с кнопкой "Записаться"
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, widget.master);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.buttonBg,
              foregroundColor: widget.buttonText,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Записаться к ${master['name'] ?? 'специалисту'}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final clientName = review['client_name']?.toString() ?? 'Анонимно';
    final dateStr = _formatDate(review['created_at']?.toString() ?? '');
    final comment = review['comment']?.toString() ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(5, (i) => Icon(
                          i < rating.round() ? Icons.star : Icons.star_border,
                          size: 14,
                          color: i < rating.round() ? const Color(0xFFF5A623) : const Color(0xFFE5E7EB),
                        )),
                        const SizedBox(width: 6),
                        Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0x000ff999))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment, style: const TextStyle(fontSize: 14, color: Color(0x000ff555), height: 1.5)),
          ],
        ],
      ),
    );
  }
  
  void _showLightbox(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: CachedAvatar(url: url, size: double.infinity, radius: 0),
        ),
      ),
    );
  }
  
  String _getReviewWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'отзыв';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'отзыва';
    return 'отзывов';
  }
}