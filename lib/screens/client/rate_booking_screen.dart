import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';

class RateBookingScreen extends StatefulWidget {
  final int bookingId;
  const RateBookingScreen({super.key, required this.bookingId});

  @override
  State<RateBookingScreen> createState() => _RateBookingScreenState();
}

class _RateBookingScreenState extends State<RateBookingScreen> {
  Map<String, dynamic>? _booking;
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  final List<XFile> _images = [];
  bool _loading = true;
  bool _submitting = false;

  final _ratingTexts = {
    1: {'text': 'Ужасно', 'bg': const Color(0xFFFEF2F2)},
    2: {'text': 'Плохо', 'bg': const Color(0xFFFFF7ED)},
    3: {'text': 'Нормально', 'bg': const Color(0xFFF9FAFB)},
    4: {'text': 'Хорошо', 'bg': const Color(0xFFF0FDF4)},
    5: {'text': 'Отлично', 'bg': const Color(0xFFF0FDF4)},
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final result = await ApiService.get('/api/booking/get?booking_id=${widget.bookingId}');
      if (result['success'] == true && mounted) {
        setState(() { _booking = result['data']; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickImages() async {
    if (_images.length >= 3) return;
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 80, limit: 3 - _images.length);
    if (files.isNotEmpty) setState(() => _images.addAll(files));
  }

  void _submit() async {
    if (_rating == 0) return;
    setState(() => _submitting = true);

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/review/create');
      final request = http.MultipartRequest('POST', uri);
      request.fields['booking_id'] = widget.bookingId.toString();
      request.fields['rating'] = _rating.toString();
      request.fields['comment'] = _commentCtrl.text;

      for (final img in _images) {
        request.files.add(await http.MultipartFile.fromPath('images[]', img.path));
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final result = jsonDecode(body);

      if (!mounted) return;
      if (result['success'] == true) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, color: Colors.green, size: 48),
              SizedBox(height: 12),
              Text('Спасибо за отзыв!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text('Ваш отзыв будет опубликован после проверки', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            ]),
          ),
        ).then((_) { if (mounted) Navigator.pop(context); });
      }
    } catch (_) {}
    setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Widget _photoPlaceholder({double size = 80}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.25),
        child: SvgPicture.asset('assets/photo-none.svg'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Оставить отзыв', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Center(child: SkeletonCircle(size: 80)),
            const SizedBox(height: 12),
            const SkeletonBox(height: 20, width: 160),
            const SizedBox(height: 4),
            const SkeletonBox(height: 14, width: 120),
            const SizedBox(height: 16),
            const SkeletonBox(height: 140, radius: 16),
            const SizedBox(height: 16),
            const SkeletonBox(height: 52, radius: 16),
          ]),
        ),
      );
    }
    if (_booking == null) return const Scaffold(backgroundColor: Colors.white, body: Center(child: Text('Ошибка загрузки')));

    final b = _booking!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: const Text('Оставить отзыв', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Мастер
          _buildMasterSection(b),
          const SizedBox(height: 16),
          // Оценка
          _buildRatingBlock(),
          const SizedBox(height: 16),
          // Организация
          _buildOrgFooter(b),
          if (_rating > 0) ...[
            const SizedBox(height: 16),
            // Текст
            _buildCommentField(),
            const SizedBox(height: 16),
            // Фото
            _buildPhotosSection(),
            const SizedBox(height: 24),
            // Кнопка
            _buildSubmitBtn(),
            const SizedBox(height: 12),
            const Text('Нажимая «Отправить», вы принимаете правила публикации', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)), textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }

  Widget _buildMasterSection(Map<String, dynamic> b) {
    final masterAvatar = b['master_avatar'];
    return Column(children: [
      masterAvatar != null && masterAvatar.toString().isNotEmpty
          ? CachedAvatar(url: masterAvatar, size: 80, radius: 40)
          : _photoPlaceholder(),
      const SizedBox(height: 12),
      Text(b['master_name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      if (b['master_position'] != null) Text(b['master_position'], style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
      if (b['service_names'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, children: (b['service_names'] as String).split(',').map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFDF2F5), borderRadius: BorderRadius.circular(20)), child: Text(s.trim(), style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C))))).toList()),
        ),
    ]);
  }

  Widget _buildRatingBlock() {
    final info = _ratingTexts[_rating] ?? _ratingTexts[3]!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: info['bg'] as Color, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6))),
      child: Column(children: [
        const Text('Ваша оценка', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(onTap: () => setState(() => _rating = i + 1), child: Icon(i < _rating ? Icons.star : Icons.star_border, size: 44, color: i < _rating ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB))))),
        if (_rating > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text(info['text'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _buildOrgFooter(Map<String, dynamic> b) {
    final projectPhoto = b['project_photo'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: projectPhoto != null && projectPhoto.toString().isNotEmpty
              ? CachedAvatar(url: projectPhoto, size: 36, radius: 10)
              : _photoPlaceholder(size: 36),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b['project_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), Text('${b['start_time']}–${b['end_time']}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))])),
      ]),
    );
  }

  Widget _buildCommentField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: _commentCtrl,
        maxLength: 400,
        maxLines: 4,
        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Поделитесь впечатлениями', hintStyle: TextStyle(color: Color(0xFF9CA3AF))),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, children: [
          ..._images.map((img) => Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(img.path), width: 72, height: 72, fit: BoxFit.cover)),
            Positioned(top: -6, right: -6, child: GestureDetector(onTap: () => setState(() => _images.remove(img)), child: Container(width: 22, height: 22, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.close, size: 12, color: Colors.white)))),
          ])),
          if (_images.length < 3) GestureDetector(onTap: _pickImages, child: Container(width: 72, height: 72, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.add, color: Color(0xFF9CA3AF)))),
        ]),
        const SizedBox(height: 8),
        const Text('До 3 фото в формате JPG, PNG или WebP', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      ]),
    );
  }

  Widget _buildSubmitBtn() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDD1847),
          disabledBackgroundColor: const Color(0xFFDD1847),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _submitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Отправка...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : const Text('Отправить отзыв', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}