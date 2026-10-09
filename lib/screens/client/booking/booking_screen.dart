// lib/screens/client/booking/booking_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Добавьте этот импорт
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import 'booking_fullscreen_screen.dart';
import 'service_detail_modal.dart';
import 'master_detail_modal.dart';
import 'widgets/hero_slider.dart';
import 'widgets/schedule_block.dart';
import 'widgets/master_card.dart';
import 'widgets/service_card.dart';
import 'widgets/review_card.dart';
import 'widgets/bottom_booking_bar.dart';
import '../../../core/app_logger.dart';

class BookingScreen extends StatefulWidget {
  final int projectId;
  
  const BookingScreen({super.key, required this.projectId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Map<String, dynamic>? _project;
  Map<String, dynamic>? _onlineDesign;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _services = [];
  final List<Map<String, dynamic>> _employeeServiceLinks = [];
  final List<Map<String, dynamic>> _workPhotos = [];
  List<String> _interiorPhotos = [];
  List<String> _phones = [];
  List<Map<String, dynamic>> _socialLinks = [];
  Map<String, dynamic> _scheduleData = {};
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  String _error = '';
  
  Color _primaryColor = const Color(0xFFDD1847);
  Color _buttonBg = const Color(0xFFDD1847);
  Color _buttonText = Colors.white;
  String _specialistLabel = 'Специалисты';
  String _serviceLabel = 'Услуги';
  String _serviceLabelAccusative = 'услугу';
  String _specialistLabelAccusative = 'специалиста';
  String _serviceLabelGenitive = 'услуг';
  String _specialistLabelGenitive = 'специалистов';
  
  double _projectRating = 0;
  int _projectReviewsCount = 0;
  final Map<int, Map<String, dynamic>> _employeeStats = {};
  
  final ScrollController _scrollController = ScrollController();
  
  double _headerOpacity = 0;
  static const double _headerScrollThreshold = 150.0;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProject();
    
    // Устанавливаем белые системные иконки
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Белые иконки в статус-баре
        statusBarBrightness: Brightness.dark, // Для iOS (тёмный фон - белые иконки)
        systemNavigationBarColor: Colors.white, // Цвет навигационной панели
        systemNavigationBarIconBrightness: Brightness.dark, // Тёмные иконки навигации (на белом фоне)
      ),
    );
  }
  
  @override
  void dispose() {
    // Восстанавливаем стандартные иконки при закрытии
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Тёмные иконки
        statusBarBrightness: Brightness.light, // Для iOS
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    final scrollY = _scrollController.offset;
    setState(() {
      _headerOpacity = (scrollY / _headerScrollThreshold).clamp(0.0, 1.0);
    });
  }

  Future<void> _loadProject() async {
    setState(() { _loading = true; _error = ''; });
    
    try {
      final result = await ApiService.get('/api/public/projects?city=&search=');
      
      if (result['success'] == true) {
        final projects = List<Map<String, dynamic>>.from(result['data'] ?? []);
        Map<String, dynamic>? project;
        
        for (final p in projects) {
          if ((p['id'] as num).toInt() == widget.projectId) {
            project = p;
            break;
          }
        }
        
        if (project == null) {
          setState(() { _error = 'Проект не найден'; _loading = false; });
          return;
        }
        
        _applyProjectData(project);
        await _loadAdditionalData();
        
        setState(() { _loading = false; });
      } else {
        setState(() { _error = result['message'] ?? 'Ошибка загрузки'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Ошибка соединения'; _loading = false; });
    }
  }
  
  void _applyProjectData(Map<String, dynamic> project) {
    _project = project;
    
    debugPrint('🔍 PROJECT DATA:');
    debugPrint('  name: ${project['name']}');
    debugPrint('  description: ${project['description']}');
    debugPrint('  schedule_json: ${project['schedule_json']}');
    debugPrint('  schedule_json type: ${project['schedule_json']?.runtimeType}');
    debugPrint('  interior_photos: ${project['interior_photos']}');
    debugPrint('  phones_json: ${project['phones_json']}');
    
    final design = project['online_design'];
    if (design != null && design.toString().isNotEmpty) {
      if (design is String) {
        try {
          _onlineDesign = Map<String, dynamic>.from(jsonDecode(design));
        } catch (_) {}
      } else if (design is Map) {
        _onlineDesign = Map<String, dynamic>.from(design);
      }
    }
    
    _primaryColor = _hexToColor(_onlineDesign?['primary_color'] ?? '#dd1847');
    _buttonBg = _hexToColor(_onlineDesign?['button_bg'] ?? '#dd1847');
    _buttonText = _hexToColor(_onlineDesign?['button_text'] ?? '#ffffff');
    _specialistLabel = _onlineDesign?['specialist_label'] ?? 'Специалисты';
    _serviceLabel = _onlineDesign?['service_label'] ?? 'Услуги';
    
    // Загружаем склонения из настроек
    _serviceLabelAccusative = _onlineDesign?['service_label_accusative'] ?? 'услугу';
    _specialistLabelAccusative = _onlineDesign?['specialist_label_accusative'] ?? 'специалиста';
    _serviceLabelGenitive = _onlineDesign?['service_label_genitive'] ?? 'услуг';
    _specialistLabelGenitive = _onlineDesign?['specialist_label_genitive'] ?? 'специалистов';
    
    final interiorRaw = project['interior_photos'];
    if (interiorRaw != null && interiorRaw.toString().isNotEmpty) {
      if (interiorRaw is List) {
        _interiorPhotos = interiorRaw.map((e) {
          if (e is String) return e;
          if (e is Map) return e['url']?.toString() ?? '';
          return '';
        }).where((s) => s.isNotEmpty).toList();
      } else if (interiorRaw is String) {
        try {
          final decoded = jsonDecode(interiorRaw);
          if (decoded is List) {
            _interiorPhotos = decoded.map((e) {
              if (e is String) return e;
              if (e is Map) return e['url']?.toString() ?? '';
              return '';
            }).where((s) => s.isNotEmpty).toList();
          }
        } catch (_) {}
      }
    }
    
    debugPrint('  _interiorPhotos: $_interiorPhotos');
    
    final phonesRaw = project['phones_json'] ?? project['phone'];
    if (phonesRaw != null && phonesRaw.toString().isNotEmpty) {
      if (phonesRaw is List) {
        _phones = phonesRaw.map((p) => _formatPhone(p.toString())).toList();
      } else if (phonesRaw is String && phonesRaw != '[]') {
        try {
          final decoded = jsonDecode(phonesRaw);
          if (decoded is List) {
            _phones = decoded.map((p) => _formatPhone(p.toString())).toList();
          }
        } catch (_) {}
      }
    }
    if (_phones.isEmpty && project['phone'] != null && project['phone'].toString().isNotEmpty) {
      _phones = [_formatPhone(project['phone'].toString())];
    }
    
    final socialRaw = project['social_links'];
    if (socialRaw != null && socialRaw.toString().isNotEmpty) {
      if (socialRaw is List) {
        _socialLinks = socialRaw.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (socialRaw is String && socialRaw != '[]') {
        try {
          final decoded = jsonDecode(socialRaw);
          if (decoded is List) {
            _socialLinks = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        } catch (_) {}
      }
    }
    
    // ===== ГРАФИК РАБОТЫ =====
    final scheduleRaw = project['schedule_json'];
    if (scheduleRaw != null && scheduleRaw.toString().isNotEmpty) {
      if (scheduleRaw is Map) {
        _scheduleData = Map<String, dynamic>.from(scheduleRaw);
        debugPrint('  scheduleData (Map): $_scheduleData');
      } else if (scheduleRaw is List) {
        _scheduleData = {};
        for (int i = 0; i < scheduleRaw.length; i++) {
          if (scheduleRaw[i] is Map) {
            _scheduleData[i.toString()] = Map<String, dynamic>.from(scheduleRaw[i]);
          }
        }
        debugPrint('  scheduleData (List): $_scheduleData');
      } else if (scheduleRaw is String) {
        try {
          final decoded = jsonDecode(scheduleRaw);
          if (decoded is Map) {
            _scheduleData = Map<String, dynamic>.from(decoded);
          } else if (decoded is List) {
            _scheduleData = {};
            for (int i = 0; i < decoded.length; i++) {
              if (decoded[i] is Map) {
                _scheduleData[i.toString()] = Map<String, dynamic>.from(decoded[i]);
              }
            }
          }
          debugPrint('  scheduleData (String decoded): $_scheduleData');
        } catch (e) {
          debugPrint('  scheduleData parse error: $e');
        }
      }
    } else {
      debugPrint('  schedule_json пустой или null');
    }
  }
  
  Future<void> _loadAdditionalData() async {
    try {
      final servicesResult = await ApiService.get('/api/service/list?project_id=${widget.projectId}&public=1');
      if (servicesResult['success'] == true) {
        _services = List<Map<String, dynamic>>.from(servicesResult['data'] ?? []);
      }
      
      final employeesResult = await ApiService.get('/api/employee/schedule/list-for-date?project_id=${widget.projectId}&date=${DateTime.now().toIso8601String().substring(0, 10)}');
      if (employeesResult['success'] == true) {
        _employees = List<Map<String, dynamic>>.from(employeesResult['data'] ?? []);
      }
      
      final linksResult = await ApiService.get('/api/employee/list?project_id=${widget.projectId}');
      if (linksResult['success'] == true) {
        final employees = List<Map<String, dynamic>>.from(linksResult['data'] ?? []);
        for (final emp in employees) {
          final empId = (emp['id'] as num).toInt();
          final serviceIds = emp['service_ids'];
          if (serviceIds != null) {
            if (serviceIds is List) {
              for (final sid in serviceIds) {
                _employeeServiceLinks.add({'employee_id': empId, 'service_id': (sid as num).toInt()});
              }
            } else if (serviceIds is String && serviceIds.isNotEmpty) {
              for (final sid in serviceIds.split(',')) {
                final parsed = int.tryParse(sid.trim());
                if (parsed != null) {
                  _employeeServiceLinks.add({'employee_id': empId, 'service_id': parsed});
                }
              }
            }
          }
        }
      }
      
      final reviewsResult = await ApiService.get('/api/review/public-list?project_id=${widget.projectId}&limit=5&offset=0');
      if (reviewsResult['success'] == true) {
        _reviews = List<Map<String, dynamic>>.from(reviewsResult['data'] ?? []);
        
        final stats = reviewsResult['stats'];
        if (stats != null && stats is Map) {
          final ratingRaw = stats['avg_rating'];
          _projectRating = ratingRaw is num ? ratingRaw.toDouble() : (double.tryParse(ratingRaw?.toString() ?? '') ?? 0);
          final totalRaw = stats['total'];
          _projectReviewsCount = totalRaw is num ? totalRaw.toInt() : (int.tryParse(totalRaw?.toString() ?? '') ?? 0);
        }
        
        final empStats = reviewsResult['employee_stats'];
        if (empStats != null && empStats is Map) {
          empStats.forEach((key, value) {
            if (value is Map) {
              _employeeStats[int.tryParse(key.toString()) ?? 0] = Map<String, dynamic>.from(value);
            }
          });
        }
      }
    } catch (e) {
      AppLogger.debug('Error loading additional data: $e');
    }
  }
  
  String _formatPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.length >= 11 && phone.startsWith('8')) {
      phone = '+7${phone.substring(1)}';
    } else if (phone.length >= 11 && phone.startsWith('7') && !phone.startsWith('+')) {
      phone = '+$phone';
    } else if (phone.length == 10) {
      phone = '+7$phone';
    }
    return phone;
  }
  
  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
  
  void _openBooking({int? masterId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingFullscreenScreen(
          projectId: widget.projectId,
          masterId: masterId,
          primaryColor: _primaryColor,
          buttonBg: _buttonBg,
          buttonText: _buttonText,
          specialistLabel: _specialistLabel,
          serviceLabel: _serviceLabel,
          serviceLabelAccusative: _serviceLabelAccusative,
          specialistLabelAccusative: _specialistLabelAccusative,
          serviceLabelGenitive: _serviceLabelGenitive,
          specialistLabelGenitive: _specialistLabelGenitive,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          children: [
            const SkeletonBox(height: 280, width: double.infinity),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const SkeletonBox(height: 120, width: double.infinity),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const SkeletonBox(height: 200, width: double.infinity),
            ),
          ],
        ),
      );
    }
    
    if (_error.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(backgroundColor: Colors.white, title: const Text('Запись')),
        body: Center(child: Text(_error, style: const TextStyle(fontSize: 16, color: Color(0x000ff888)))),
      );
    }
    
    if (_project == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(backgroundColor: Colors.white, title: const Text('Запись')),
        body: const Center(child: Text('Проект не найден', style: TextStyle(fontSize: 16, color: Color(0x000ff888)))),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                HeroSlider(photos: _interiorPhotos, primaryColor: _primaryColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      if ((_project!['description']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle('О проекте'),
                        _buildDescription(),
                      ],
                      _buildMapCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(_specialistLabel),
                      _buildMastersCarousel(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(_serviceLabel),
                      _buildServicesCarousel(),
                      if (_reviews.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle('Отзывы'),
                        ..._reviews.map((r) => ReviewCard(review: r, primaryColor: _primaryColor)),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildFloatingHeader(),
          ),
          
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: BottomBookingBar(
              buttonBg: _buttonBg,
              buttonText: _buttonText,
              onBook: () => _openBooking(),
              onMyBookings: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
  
  // ===== ПЛАВАЮЩИЙ ХЕДЕР =====
  Widget _buildFloatingHeader() {
    final projectName = _project?['name'] ?? '';
    final projectAddress = _project?['address_raw'] ?? '';
    final projectPhoto = _project?['profile_photo'];
    
    return Container(
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: _headerOpacity),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20 * (1 - _headerOpacity)),
        ),
        boxShadow: _headerOpacity > 0
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1 * _headerOpacity), blurRadius: 20, offset: const Offset(0, 4))]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15 + _headerOpacity * 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15 + _headerOpacity * 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25 + _headerOpacity * 0.05),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: projectPhoto != null && projectPhoto.toString().isNotEmpty
                      ? CachedAvatar(url: projectPhoto.toString(), size: 52, radius: 12)
                      : Icon(Icons.photo, color: Colors.white.withValues(alpha: 0.7), size: 24),
                ),
              ),
              
              if (_headerOpacity > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (projectAddress.isNotEmpty)
                        Text(
                          projectAddress,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }
  
  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_project!['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black)),
              ),
              GestureDetector(
                onTap: _scrollToReviews,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFF5A623), size: 14),
                      const SizedBox(width: 4),
                      Text('$_projectRating · $_projectReviewsCount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_project!['address_raw'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0x000ff666))),
          const SizedBox(height: 4),

if (_scheduleData.isNotEmpty) ...[
  ScheduleBlock(scheduleData: _scheduleData, primaryColor: _primaryColor),
  const SizedBox(height: 8),
],
          
          if (_phones.isNotEmpty) ...[
  Wrap(
    spacing: 10, runSpacing: 10,
    children: _phones.map((phone) => GestureDetector(
      onTap: () => ApiService.openUrl('tel:$phone'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phone,
                size: 16,
                color: _primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              phone,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    )).toList(),
  ),
  const SizedBox(height: 12),
],
          
          if (_socialLinks.isNotEmpty) ...[
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _socialLinks.map((link) {
                final type = link['type'] ?? '';
                final url = link['url'] ?? '';
                if (url.isEmpty) return const SizedBox.shrink();
                
                final names = {'vk': 'ВКонтакте', 'telegram': 'Telegram', 'whatsapp': 'WhatsApp', 'instagram': 'Instagram', 'site': 'Сайт'};
                
                return GestureDetector(
                  onTap: () => ApiService.openUrl(url),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(names[type] ?? type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0x000ff666))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDescription() {
  final description = _project!['description']?.toString() ?? '';
  
  if (description.isEmpty) return const SizedBox.shrink();
  
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Text(
      description,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.black,  // ← Изменено с Color(0xFF555) на Colors.black
        height: 1.6,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}
  
  Widget _buildMapCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFDF2F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.location_on, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Показать на карте', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black)),
                Text(_project!['address_raw'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }
  
  Widget _buildMastersCarousel() {
    if (_employees.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Нет доступных специалистов', style: TextStyle(color: Color(0x000ff999))),
      );
    }
    
    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _employees.length,
        itemBuilder: (_, i) {
          final e = _employees[i];
          final empId = (e['id'] as num).toInt();
          final stats = _employeeStats[empId];
          
          return MasterCard(
            master: e,
            stats: stats,
            primaryColor: _primaryColor,
            buttonBg: _buttonBg,
            buttonText: _buttonText,
            onBook: () => _openBooking(masterId: empId),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MasterDetailModal(
                    master: e,
                    employees: _employees,
                    employeeServiceLinks: _employeeServiceLinks,
                    services: _services,
                    workPhotos: _workPhotos,
                    primaryColor: _primaryColor,
                    buttonBg: _buttonBg,
                    buttonText: _buttonText,
                    specialistLabel: _specialistLabel,
                    serviceLabel: _serviceLabel,
                  ),
                ),
              ).then((result) {
                if (result != null && result is Map<String, dynamic>) {
                  _openBooking(masterId: (result['id'] as num).toInt());
                }
              });
            },
          );
        },
      ),
    );
  }
  
  Widget _buildServicesCarousel() {
    if (_services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Нет услуг', style: TextStyle(color: Color(0x000ff999))),
      );
    }
    
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _services.length,
        itemBuilder: (_, i) {
          final s = _services[i];
          return ServiceCard(
            service: s,
            primaryColor: _primaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ServiceDetailModal(
                    service: s,
                    employees: _employees,
                    employeeServiceLinks: _employeeServiceLinks,
                    primaryColor: _primaryColor,
                  ),
                ),
              ).then((master) {
                if (master != null && master is Map<String, dynamic>) {
                  _openBooking(masterId: (master['id'] as num).toInt());
                }
              });
            },
          );
        },
      ),
    );
  }
  
  void _scrollToReviews() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }
}