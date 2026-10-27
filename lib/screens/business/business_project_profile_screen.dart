import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widgets/toast.dart';
import '../../core/app_logger.dart';
import '../../widgets/common/phone_input.dart';
import '../../widgets/common/time_picker_sheet.dart';

class BusinessProjectProfileScreen extends StatefulWidget {
  final int projectId;
  const BusinessProjectProfileScreen({super.key, required this.projectId});

  static const String baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';

  @override
  State<BusinessProjectProfileScreen> createState() => _BusinessProjectProfileScreenState();
}

class _BusinessProjectProfileScreenState extends State<BusinessProjectProfileScreen> {
  bool _loading = true;
  bool _hasChanges = false;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  File? _profilePhoto;
  String? _profilePhotoUrl;
  List<Map<String, dynamic>> _interiorPhotos = [];

  List<Map<String, String>> _phones = [{'dial': '+7', 'number': ''}];
  final List<TextEditingController> _phoneControllers = [];
  final List<GlobalKey<PhoneInputState>> _phoneKeys = [];
  static const int _maxPhones = 5;

  List<String> _selectedSubcategories = [];
  String _sphereDisplay = 'Красота';

  List<Map<String, String>> _socialLinks = [];

  String _selectedCurrency = 'RUB';

  Map<int, String> _schedule = {};

  // DaData подсказки адреса
  List<Map<String, String>> _addressSuggestions = [];
  final _addressFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const _weekdaysFull = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];

  static const _spheres = {
    'beauty': 'Красота', 'health': 'Здоровье', 'sport': 'Спорт',
    'rent': 'Аренда', 'animals': 'Животные', 'auto': 'Авто',
    'entertainment': 'Развлечения', 'education': 'Образование',
    'law': 'Юристы', 'style': 'Стиль', 'restaurant': 'Рестораны', 'other': 'Прочее',
  };

  static const _subcategories = {
    'beauty': ['Солярий','Усы, борода','Парикмахерские услуги','СПА','Ресницы','Пирсинг','Брови','Татуаж, тату','Барбершоп','Ногтевой сервис','Косметология, уход','Депиляция, эпиляция','Массаж','Визаж'],
    'health': ['Офтальмология','Медицина','Анализы','Подология','Стоматология'],
    'sport': ['Йога','Единоборства','Танцы','Фитнес'],
    'rent': ['Коворкинг','Аренда'],
    'animals': ['Ветеринария','Груминг'],
    'auto': ['Техосмотр','Шиномонтаж','Автомойка','Детейлинг','Автошкола','Автосервис'],
    'entertainment': ['Киберспорт','Квест','Бани, сауны','Туризм','Боулинг'],
    'education': ['Автошкола','Музыка','Курсы','Вокал','Репетитор','Языковая школа'],
    'law': ['Юридические услуги','Нотариус'],
    'style': ['Фотостудии'],
    'restaurant': ['Ресторан','Кафе'],
    'other': ['Прочее'],
  };

  static const _currencies = [
    {'code': 'RUB', 'symbol': '₽', 'name': 'Российский рубль', 'flag': '🇷🇺'},
    {'code': 'USD', 'symbol': '\$', 'name': 'Доллар США', 'flag': '🇺🇸'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Евро', 'flag': '🇪🇺'},
    {'code': 'BYN', 'symbol': 'Br', 'name': 'Белорусский рубль', 'flag': '🇧🇾'},
    {'code': 'KZT', 'symbol': '₸', 'name': 'Казахстанский тенге', 'flag': '🇰🇿'},
    {'code': 'UAH', 'symbol': '₴', 'name': 'Украинская гривна', 'flag': '🇺🇦'},
    {'code': 'GBP', 'symbol': '£', 'name': 'Фунт стерлингов', 'flag': '🇬🇧'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Китайский юань', 'flag': '🇨🇳'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Японская иена', 'flag': '🇯🇵'},
    {'code': 'TRY', 'symbol': '₺', 'name': 'Турецкая лира', 'flag': '🇹🇷'},
  ];




  @override
  void initState() {
    super.initState();
    _addressCtrl.addListener(_onAddressChanged);
    _addressFocusNode.addListener(_onAddressFocusChanged);
    _load();
  }

  @override
  void dispose() {
    _removeOverlay();
    _addressCtrl.removeListener(_onAddressChanged);
    _addressFocusNode.removeListener(_onAddressFocusChanged);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    final query = _addressCtrl.text.trim();
    if (query.length < 3) {
      setState(() => _addressSuggestions = []);
      _removeOverlay();
      return;
    }
    _fetchAddressSuggestions(query);
  }

  void _onAddressFocusChanged() {
    if (!_addressFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_addressFocusNode.hasFocus && mounted) {
          _removeOverlay();
        }
      });
    } else if (_addressSuggestions.isNotEmpty) {
      _showOverlay();
    }
  }

  void _selectAddress(String value) {
    _addressCtrl.text = value;
    setState(() => _addressSuggestions = []);
    _removeOverlay();
    _addressFocusNode.unfocus();
    _markChanged();
  }

  Future<void> _fetchAddressSuggestions(String query) async {
    try {
      // Унифицировано с ApiService: from_bound=street + count=15.
      // "Брянск, проспект" → улицы Брянска (пр-кт Героев, пр-кт Ленина...),
      // а не "тер ГО По проспекту Ленина".
      final suggestions = await ApiService.dadataAddressFull(query);

      if (mounted && _addressCtrl.text.trim().length >= 3) {
        setState(() => _addressSuggestions = suggestions);
        if (_addressFocusNode.hasFocus && suggestions.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      debugPrint('DaData error: $e');
    }
  }

  void _showOverlay() {
    _removeOverlay();
    if (_addressSuggestions.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: (_addressFocusNode.context?.findRenderObject() as RenderBox?)?.size.width ?? 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _addressSuggestions.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF5F5F5)),
                itemBuilder: (context, index) {
                  final s = _addressSuggestions[index];
                  return InkWell(
                    onTap: () {
                      _selectAddress(s['value']!);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['value']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                          if (s['postal_code']!.isNotEmpty || s['region']!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${s['postal_code']} ${s['region']}'.trim(),
                                style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.get('/api/project-profile/get?project_id=${widget.projectId}');
      debugPrint('PROFILE-LOAD: success=${result['success']}, msg=${result['message']}, has_data=${result['data'] != null}');
      if (result['success'] == true && mounted) {
        final d = result['data'];
        debugPrint('schedule KEY EXISTS: ${d.containsKey('schedule')}');
        debugPrint('schedule VALUE: ${d['schedule']}');
        debugPrint('schedule TYPE: ${d['schedule']?.runtimeType}');
        
        List phoneList = [];
        try {
          final phoneRaw = d['phone'];
          if (phoneRaw is String && phoneRaw.isNotEmpty) {
            phoneList = jsonDecode(phoneRaw) as List;
          } else if (phoneRaw is List) {
            phoneList = phoneRaw;
          }
        } catch (_) {}
        
        final phonesJson = d['phones'] as List? ?? [];
        if (phonesJson.isNotEmpty) phoneList = phonesJson;

        final phones = <Map<String, String>>[];
        if (phoneList.isNotEmpty) {
          for (final p in phoneList) {
            final phoneStr = p.toString();
            String dial = '+7';
            String number = '';
            
            final knownCodes = ['+375', '+380', '+7'];
            bool found = false;
            
            for (final code in knownCodes) {
              if (phoneStr.startsWith(code)) {
                dial = code;
                number = phoneStr.substring(code.length);
                found = true;
                break;
              }
            }
            
            if (!found) {
              if (phoneStr.startsWith('+')) {
                final codeMatch = RegExp(r'^\+(\d{1,3})').firstMatch(phoneStr);
                if (codeMatch != null) {
                  dial = codeMatch.group(0)!;
                  number = phoneStr.substring(dial.length);
                } else {
                  number = phoneStr.replaceAll(RegExp(r'[^\d]'), '');
                }
              } else {
                number = phoneStr.replaceAll(RegExp(r'[^\d]'), '');
              }
            }
            
            number = number.replaceAll(RegExp(r'[^\d]'), '');
            
            phones.add({
              'dial': dial,
              'number': number,
            });
          }
        }
        if (phones.isEmpty) phones.add({'dial': '+7', 'number': ''});

        // Соцсети
        List<Map<String, String>> socialLinks = [];
        try {
          final raw = d['social_links'];
          if (raw is List) {
            for (final item in raw) {
              if (item is Map) {
                socialLinks.add({
                  'type': item['type']?.toString() ?? '',
                  'url': item['url']?.toString() ?? '',
                });
              }
            }
          } else if (raw is String && raw.isNotEmpty) {
            final decoded = jsonDecode(raw);
            if (decoded is List) socialLinks = List<Map<String, String>>.from(decoded);
          }
        } catch (_) {}

        // График
        Map<int, String> schedule = {};
        try {
          final schedRaw = d['schedule'];
          if (schedRaw is List) {
            for (int i = 0; i < schedRaw.length && i < 7; i++) {
              final day = schedRaw[i];
              if (day is Map && day['start'] != null && day['end'] != null) {
                schedule[i] = '${day['start']}–${day['end']}';
              }
            }
          } else if (schedRaw is Map) {
            schedRaw.forEach((k, v) {
              if (v != null && v is Map) {
                schedule[int.parse(k.toString())] = '${v['start']}–${v['end']}';
              }
            });
          }
        } catch (_) {}
AppLogger.debug('📸 Profile photo from server: ${d['profile_photo']}');
AppLogger.debug('📸 Interior photos from server: ${d['interior_photos']} (${d['interior_photos'].runtimeType})');
        setState(() {
          _nameCtrl.text = d['name'] ?? '';
          _descCtrl.text = d['description'] ?? '';
          _addressCtrl.text = d['address_raw'] ?? '';
          _profilePhotoUrl = d['profile_photo'];
          _phones = phones;
          _syncPhoneHelpers();
          _socialLinks = socialLinks;
          _schedule = schedule;
          _selectedSubcategories = (d['subcategories'] is List) ? List<String>.from(d['subcategories']) : [];
          _updateSphereDisplay();
          _selectedCurrency = d['currency'] ?? 'RUB';

          try {
            final raw = d['interior_photos'];
            if (raw is String && raw.isNotEmpty) {
              _interiorPhotos = List<Map<String, dynamic>>.from(jsonDecode(raw));
            } else if (raw is List) {
              _interiorPhotos = List<Map<String, dynamic>>.from(raw);
            }
          } catch (_) {}
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки профиля: $e');
      if (mounted) setState(() => _loading = false);
    }
    // Если _load завершился без success — сбросить _loading (иначе вечный скелетон).
    // Причина: API вернул 401/403 (не авторизован / нет доступа к проекту).
    if (mounted && _loading) {
      setState(() => _loading = false);
    }
  }

  void _updateSphereDisplay() {
    if (_selectedSubcategories.isEmpty) {
      _sphereDisplay = 'Красота';
    } else {
      final count = _selectedSubcategories.length;
      _sphereDisplay = '$count — ${_selectedSubcategories.take(2).join(', ')}${count > 2 ? '...' : ''}';
    }
  }

  void _markChanged() => setState(() => _hasChanges = true);

  void _syncPhoneHelpers() {
    // Синхронизируем количество controllers/keys с _phones
    while (_phoneControllers.length < _phones.length) {
      _phoneControllers.add(TextEditingController());
      _phoneKeys.add(GlobalKey<PhoneInputState>());
    }
    while (_phoneControllers.length > _phones.length) {
      _phoneControllers.removeLast().dispose();
      _phoneKeys.removeLast();
    }
    // Обновляем текст controllers из _phones (только если пуст или нужно)
    for (int i = 0; i < _phones.length; i++) {
      final digits = (_phones[i]['number'] ?? '').replaceAll(RegExp(r'[^\d]'), '');
      if (digits.isNotEmpty && _phoneControllers[i].text.isEmpty) {
        _phoneControllers[i].text = digits;
      }
    }
  }




  Future<void> _save() async {
    try {
      final phones = <String>[];
      for (int i = 0; i < _phoneKeys.length; i++) {
        final full = _phoneKeys[i].currentState?.fullPhone ?? '';
        if (full.isNotEmpty && full.length > 2) phones.add(full);
      }
      final body = {
        'project_id': widget.projectId,
        'name': _nameCtrl.text,
        'description': _descCtrl.text,
        'address_raw': _addressCtrl.text,
        'phones': phones,
        'sphere': _sphereDisplay,
        'subcategories': _selectedSubcategories,
        'social_links': _socialLinks.isNotEmpty ? jsonEncode(_socialLinks) : null,
        'currency': _selectedCurrency,
        'interior_photos': _interiorPhotos.isNotEmpty ? jsonEncode(_interiorPhotos.map((p) => {'url': p['url']}).toList()) : null,
        'delete_profile_photo': _profilePhoto == null && _profilePhotoUrl == null ? true : null,
      };
      final result = await ApiService.post('/api/project-profile/save', body);
      if (result['success'] == true && mounted) {
        setState(() => _hasChanges = false);
        showToast(context, 'Профиль сохранён!');
      }
    } catch (e) {
      debugPrint('Ошибка сохранения: $e');
    }
  }

  Future<void> _deleteProject() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Удалить проект?'),
      content: const Text('Это действие нельзя отменить. Все данные проекта будут безвозвратно удалены.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена', style: TextStyle(color: Color(0xFF666666))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Удалить', style: TextStyle(color: Color(0xFFF44336))),
        ),
      ],
    ),
  );

  if (confirm != true || !mounted) return;

  try {
    final result = await ApiService.post('/api/project/delete', {'project_id': widget.projectId});
    if (result['success'] == true && mounted) {
      showToast(context, 'Проект удалён');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/business', (route) => false);
      }
    } else {
      if (mounted) {
        showToast(context, result['message'] ?? 'Ошибка удаления', isError: true);
      }
    }
  } catch (e) {
    if (mounted) {
      showToast(context, 'Ошибка при удалении проекта', isError: true);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildSkeleton();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildDisclaimer(),
            const SizedBox(height: 16),
            _buildTopBlock(),
            const SizedBox(height: 12),
            _buildInteriorPhotos(),
            const SizedBox(height: 12),
            _buildClickableRow('Сфера', _sphereDisplay, onTap: _showSpherePicker),
            _buildAddressBlock(),
            _buildPhonesBlock(),
            _buildClickableRow('График работы', _getScheduleText(), onTap: _showSchedulePicker),
            _buildSocialRow(),
            _buildClickableRow('Валюта расчётов', _getCurrencyText(), onTap: _showCurrencyPicker),
            const SizedBox(height: 12),
            _buildDeleteBlock(),
            const SizedBox(height: 100),
          ],
        ),
        if (_hasChanges)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
              ),
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, size: 20),
                  label: const Text('Сохранить изменения', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD1847),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFFDF2F5),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 200, radius: 16),
              const SizedBox(height: 16),
              const SkeletonBox(height: 24),
              const SizedBox(height: 12),
              const SkeletonBox(height: 143),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFDD1847), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Вся информация, указанная в данных настройках будет доступна вашим клиентам при онлайн-записи.',
              style: TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoBlock(200, 210),
                const SizedBox(width: 20),
                Expanded(child: _buildNameBlock()),
              ],
            );
          }
          return Column(
            children: [
              _buildPhotoBlock(double.infinity, 200),
              const SizedBox(height: 16),
              _buildNameBlock(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPhotoBlock(double w, double h) {
    final hasImage = _profilePhoto != null || (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty);
    
    return GestureDetector(
      onTap: _pickProfilePhoto,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            width: hasImage ? 1 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_profilePhoto != null)
              Image.file(_profilePhoto!, fit: BoxFit.cover)
            else if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: '${BusinessProjectProfileScreen.baseUrl}$_profilePhotoUrl',
                fit: BoxFit.cover,
              )
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: w > 200 ? 76 : 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Добавить\nизображение',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            if (hasImage)
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _profilePhoto = null;
                      _profilePhotoUrl = null;
                      _markChanged();
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF44336),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameBlock() {
    return Column(
      children: [
        _buildTextField(_nameCtrl, 'Название проекта', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _buildTextField(_descCtrl, 'Описание проекта...', maxLines: 5, minLines: 5),
      ],
    );
  }

  Widget _buildInteriorPhotos() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Фото интерьера', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._interiorPhotos.map((p) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: '${BusinessProjectProfileScreen.baseUrl}${p['url']}',
                      width: 130,
                      height: 130,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        _interiorPhotos.remove(p);
                        _markChanged();
                        setState(() {});
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              )),
              if (_interiorPhotos.length < 6)
                GestureDetector(
                  onTap: _pickInteriorPhoto,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFF8F8F8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 28, color: Colors.grey[400]),
                        const SizedBox(height: 6),
                        Text('Добавить', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'JPG, PNG, WEBP до 10 МБ • Максимум 6 фото',
            style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressBlock() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Адрес', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          CompositedTransformTarget(
            link: _layerLink,
            child: _buildTextField(_addressCtrl, 'Город, улица, дом, помещение/офис',
              focusNode: _addressFocusNode,
              onTap: () {
                _addressSuggestions = [];
                _removeOverlay();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhonesBlock() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Телефоны организации', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (_phones.length < _maxPhones)
                GestureDetector(
                  onTap: () {
                    _phones.add({'dial': '+7', 'number': ''});
                    _syncPhoneHelpers();
                    _markChanged();
                    setState(() {});
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, size: 18, color: Color(0xFF666666)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ..._phones.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildPhoneField(e.key, e.value['dial']!, e.value['number']!),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPhoneField(int index, String dial, String number) {
    return Row(
      children: [
        Expanded(
          child: PhoneInput(
            key: _phoneKeys[index],
            controller: _phoneControllers[index],
            onPhoneChanged: (_) {
              _phones[index]['number'] = _phoneControllers[index].text;
              _markChanged();
            },
          ),
        ),
        if (_phones.length > 1)
          GestureDetector(
            onTap: () {
              _phones.removeAt(index);
              _syncPhoneHelpers();
              _markChanged();
              setState(() {});
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 20, color: Color(0xFF999999)),
            ),
          ),
      ],
    );
  }

  Widget _buildClickableRow(String label, String value, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialRow() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: GestureDetector(
        onTap: _showSocialEditor,
        child: Row(
          children: [
            const Text('Ссылки на соц. сети', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
            if (_socialLinks.isNotEmpty) ...[
              const SizedBox(width: 8),
              ..._socialLinks.map((link) {
                String asset;
                switch (link['type']) {
                  case 'telegram': asset = 'assets/telegram.svg'; break;
                  case 'vk': asset = 'assets/vk-outline.svg'; break;
                  case 'site': asset = 'assets/web-link.svg'; break;
                  default: asset = 'assets/web-link.svg';
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SvgPicture.asset(asset, width: 20, height: 20, colorFilter: const ColorFilter.mode(Color(0xFF999999), BlendMode.srcIn)),
                );
              }),
            ],
            const Spacer(),
            Text(
              '${_socialLinks.length} ссылки',
              style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteBlock() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _deleteProject,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Удалить проект'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF44336),
            side: const BorderSide(color: Color(0xFFF44336)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextStyle? style,
    int? maxLines,
    int? minLines,
    FocusNode? focusNode,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: style ?? const TextStyle(fontSize: 15),
        maxLines: maxLines ?? 1,
        minLines: minLines,
        onTap: onTap,
        onChanged: (_) => _markChanged(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF999999)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  String _getScheduleText() {
    if (_schedule.isEmpty) return 'Настроить';
    final byTime = <String, List<String>>{};
    _schedule.forEach((day, time) => byTime.putIfAbsent(time, () => []).add(_weekdays[day]));
    final parts = byTime.entries.map((e) => '${e.value.join(', ')}: ${e.key}').toList();
    final offDays = List.generate(7, (i) => i).where((d) => !_schedule.containsKey(d)).map((d) => _weekdays[d]).toList();
    if (offDays.isNotEmpty) parts.add('${offDays.join(', ')}: Выходной');
    return parts.join('; ');
  }

  String _getCurrencyText() {
    final cur = _currencies.firstWhere((c) => c['code'] == _selectedCurrency, orElse: () => _currencies[0]);
    return '${cur['code']} (${cur['symbol']})';
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() { _profilePhoto = File(picked.path); _markChanged(); });
      final prefs = await SharedPreferences.getInstance();
      final cookies = prefs.getString('saved_cookies');
      final formData = http.MultipartRequest('POST', Uri.parse('${BusinessProjectProfileScreen.baseUrl}/api/project-profile/upload-photo'));
      if (cookies != null) formData.headers['Cookie'] = cookies;
      formData.fields['project_id'] = widget.projectId.toString();
      formData.files.add(await http.MultipartFile.fromPath('photo', picked.path));
      final res = await formData.send();
      final body = await res.stream.bytesToString();
      final result = jsonDecode(body);
      if (result['success'] == true) {
        setState(() {
          _profilePhotoUrl = result['data']['photo_url'];
          _profilePhoto = null;
        });
      }
    }
  }


  Future<void> _pickInteriorPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      final cookies = prefs.getString('saved_cookies');
      final formData = http.MultipartRequest('POST', Uri.parse('${BusinessProjectProfileScreen.baseUrl}/api/project-profile/upload-interior-photo'));
      if (cookies != null) formData.headers['Cookie'] = cookies;
      formData.fields['project_id'] = widget.projectId.toString();
      formData.files.add(await http.MultipartFile.fromPath('photo', picked.path));
      final res = await formData.send();
      final body = await res.stream.bytesToString();
      final result = jsonDecode(body);
      if (result['success'] == true) {
        _interiorPhotos.add({'url': result['data']['photo_url']});
        _markChanged();
        setState(() {});
      }
    }
  }

  void _showSpherePicker() {
    String activeSphere = 'beauty';
    for (final key in _subcategories.keys) {
      if (_selectedSubcategories.isNotEmpty && _subcategories[key]!.contains(_selectedSubcategories.first)) {
        activeSphere = key;
        break;
      }
    }

    final sphereIcons = {
      'beauty': 'assets/beauty.svg',
      'health': 'assets/health.svg',
      'sport': 'assets/sport.svg',
      'auto': 'assets/auto.svg',
      'education': 'assets/education.svg',
      'animals': 'assets/pets.svg',
      'entertainment': 'assets/holiday.svg',
      'law': 'assets/law.svg',
      'style': 'assets/photo-camera.svg',
      'rent': 'assets/searching-for-an-apartment.svg',
      'restaurant': 'assets/food.svg',
      'other': 'assets/dots.svg',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Сфера деятельности', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                SizedBox(
                  height: 68,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    children: _spheres.entries.map((e) {
                      final sel = e.key == activeSphere;
                      final iconPath = sphereIcons[e.key] ?? 'assets/dots.svg';
                      
                      return GestureDetector(
                        onTap: () => setModalState(() => activeSphere = e.key),
                        child: Container(
                          width: 68,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: sel ? const Color(0xFFDD1847) : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                iconPath,
                                width: 22,
                                height: 22,
                                colorFilter: sel 
                                    ? const ColorFilter.mode(Color(0xFFDD1847), BlendMode.srcIn) 
                                    : const ColorFilter.mode(Color(0xFF666666), BlendMode.srcIn),
                              ),
                              const SizedBox(height: 1),
                              Flexible(
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                    color: sel ? const Color(0xFFDD1847) : const Color(0xFF666666),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _spheres[activeSphere] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6C757D),
                      ),
                    ),
                  ),
                ),
                
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: (_subcategories[activeSphere] ?? []).map((cat) {
                          final sel = _selectedSubcategories.contains(cat);
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                sel ? _selectedSubcategories.remove(cat) : _selectedSubcategories.add(cat);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: sel ? const Color(0xFFDD1847) : const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel ? const Color(0xFFDD1847) : const Color(0xFFE9ECEF),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: sel ? Colors.white : const Color(0xFF495057),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        _updateSphereDisplay();
                        _markChanged();
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDD1847),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Сохранить',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ссылки на соц. сети', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            _socialField(vkCtrl, 'VK', 'assets/vk-outline.svg'),
            const SizedBox(height: 16),
            _socialField(tgCtrl, 'Telegram', 'assets/telegram.svg'),
            const SizedBox(height: 16),
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
                  _markChanged();
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SvgPicture.asset(iconAsset, width: 24, height: 24, colorFilter: const ColorFilter.mode(Color(0xFF666666), BlendMode.srcIn)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextField(ctrl, label),
        ),
      ],
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Валюта расчётов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: _currencies.map((c) {
                  final sel = _selectedCurrency == c['code'];
                  return ListTile(
                    leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      '${c['code']} ${c['symbol']}',
                      style: TextStyle(
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel ? const Color(0xFFDD1847) : null,
                      ),
                    ),
                    subtitle: Text(c['name']!),
                    trailing: sel ? const Icon(Icons.check, color: Color(0xFFDD1847)) : null,
                    onTap: () {
                      _selectedCurrency = c['code']!;
                      _markChanged();
                      setState(() {});
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSchedulePicker() {
    Set<int> selectedDays = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('График работы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Выберите рабочие дни и установите время работы, неотмеченные дни останутся выходными.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF888888), height: 1.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _scheduleActionBtn('Выбрать все', () {
                          setModalState(() {
                            for (int i = 0; i < 7; i++) {
                              selectedDays.add(i);
                            }
                          });
                        }),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _scheduleActionBtn('Изменить', () async {
                          if (selectedDays.isEmpty) return;
                          
                          final range = await showTimeRangePickerSheet(
                            ctx,
                            startTime: const TimeOfDay(hour: 9, minute: 0),
                            endTime: const TimeOfDay(hour: 18, minute: 0),
                            title: 'Рабочее время',
                          );
                          
                          if (range == null || !ctx.mounted) return;
                          final start = range.start;
                          final end = range.end;
                          final ts = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}–${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
                          setModalState(() {
                            for (final d in selectedDays) {
                              _schedule[d] = ts;
                            }
                            selectedDays.clear();
                          });
                        }, enabled: selectedDays.isNotEmpty),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _scheduleActionBtn('Сделать выходным', () {
                          setModalState(() {
                            for (final d in selectedDays) {
                              _schedule.remove(d);
                            }
                            selectedDays.clear();
                          });
                        }, enabled: selectedDays.isNotEmpty, isRed: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 7,
                    itemBuilder: (context, i) {
                      final sel = selectedDays.contains(i);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            sel ? selectedDays.remove(i) : selectedDays.add(i);
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel ? const Color(0xFFDD1847) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _weekdaysFull[i],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: sel ? const Color(0xFFDD1847) : const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              Text(
                                _schedule[i] ?? 'Выходной',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: sel ? const Color(0xFFDD1847) : const Color(0xFF888888),
                                  fontWeight: sel ? FontWeight.w500 : FontWeight.w400,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: sel ? const Color(0xFFDD1847) : const Color(0xFFDDDDDD),
                                    width: 2,
                                  ),
                                  color: sel ? const Color(0xFFDD1847) : Colors.transparent,
                                ),
                                child: sel ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        _markChanged();
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDD1847),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Применить',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _scheduleActionBtn(String label, VoidCallback onTap, {bool enabled = true, bool isRed = false}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: enabled ? (isRed ? const Color(0xFFDD1847) : const Color(0xFF666666)) : const Color(0xFFCCCCCC),
          ),
        ),
      ),
    );
  }
}