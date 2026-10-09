import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import 'booking/booking_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  String _city = 'Брянск';
  String? _activeSphere;
  String _searchQuery = '';

  final List<Map<String, String>> _spheres = [
    {'key': 'beauty', 'name': 'Красота', 'icon': 'assets/beauty.svg'},
    {'key': 'health', 'name': 'Здоровье', 'icon': 'assets/health.svg'},
    {'key': 'sport', 'name': 'Спорт', 'icon': 'assets/sport.svg'},
    {'key': 'auto', 'name': 'Авто', 'icon': 'assets/auto.svg'},
    {'key': 'education', 'name': 'Образование', 'icon': 'assets/education.svg'},
    {'key': 'animals', 'name': 'Животные', 'icon': 'assets/pets.svg'},
    {'key': 'entertainment', 'name': 'Развлечения', 'icon': 'assets/holiday.svg'},
    {'key': 'law', 'name': 'Право', 'icon': 'assets/law.svg'},
    {'key': 'style', 'name': 'Стиль', 'icon': 'assets/photo-camera.svg'},
    {'key': 'rent', 'name': 'Аренда', 'icon': 'assets/searching-for-an-apartment.svg'},
    {'key': 'restaurant', 'name': 'Рестораны', 'icon': 'assets/food.svg'},
    {'key': 'other', 'name': 'Прочее', 'icon': 'assets/dots.svg'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  void _loadProjects({String? sphere}) async {
    setState(() => _loading = true);
    try {
      var path = '/api/public/projects?city=${Uri.encodeComponent(_city)}';
      if (sphere != null && sphere != 'all') path += '&sphere=$sphere';
      if (_searchQuery.isNotEmpty) path += '&search=${Uri.encodeComponent(_searchQuery)}';
      final result = await ApiService.get(path);
      if (result['success'] == true && mounted) {
        setState(() { 
          _projects = List<Map<String, dynamic>>.from(result['data'] ?? []); 
          _loading = false; 
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSphereTap(String key) {
    setState(() {
      _activeSphere = _activeSphere == key ? null : key;
    });
    _loadProjects(sphere: _activeSphere);
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    // Дебаунс
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_searchQuery == query) {
        _loadProjects(sphere: _activeSphere);
      }
    });
  }

  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final controller = TextEditingController();
        List<String> suggestions = [];
        bool searching = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final popular = ['Москва', 'Санкт-Петербург', 'Воронеж', 'Брянск', 'Нижний Новгород', 'Екатеринбург', 'Казань', 'Краснодар'];

            void selectCity(String city) {
              controller.clear();
              suggestions = [];
              Navigator.pop(ctx);
              setState(() => _city = city);
              _loadProjects();
            }

            void searchCity(String query) async {
              if (query.length < 2) {
                setSheetState(() { suggestions = []; searching = false; });
                return;
              }
              setSheetState(() => searching = true);
              final result = await ApiService.dadataSuggest(query);
              setSheetState(() {
                suggestions = result ?? [];
                searching = false;
              });
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text('Выберите город', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey[900])),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  controller: controller,
                  onChanged: (v) => searchCity(v),
                  decoration: InputDecoration(
                    hintText: 'Поиск города',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: searching ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDD1847)))) : null,
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: suggestions.isNotEmpty
                      ? ListView(
                          children: suggestions.take(4).map((c) => ListTile(
                            title: Text(c),
                            onTap: () => selectCity(c.split(',')[0]),
                          )).toList(),
                        )
                      : controller.text.isEmpty || controller.text.length < 2
                          ? Wrap(
                              spacing: 8,
                              children: popular.map((c) => ChoiceChip(
                                label: Text(c, style: TextStyle(color: _city == c ? Colors.white : Colors.black87)),
                                selected: _city == c,
                                selectedColor: const Color(0xFFDD1847),
                                backgroundColor: Colors.grey[200],
                                checkmarkColor: Colors.white,
                                onSelected: (_) => selectCity(c),
                              )).toList(),
                            )
                          : searching
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDD1847)))
                              : const Center(child: Text('Ничего не найдено', style: TextStyle(color: Colors.grey))),
                ),
                const SizedBox(height: 20),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _photoPlaceholder({double size = 44}) {
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
    return Column(
      children: [
        GestureDetector(
          onTap: _openCityPicker,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 18, color: Color(0xFFDD1847)),
                const SizedBox(width: 6),
                Text(_city, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Поиск по названию, адресу...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDD1847))),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _spheres.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = _spheres[i];
              final active = _activeSphere == s['key'];
              return GestureDetector(
                onTap: () => _onSphereTap(s['key']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFFDF2F5) : const Color(0xFFF8F8F8),
                    border: Border.all(color: active ? const Color(0xFFDD1847) : const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    SvgPicture.asset(s['icon']!, width: 22, height: 22, colorFilter: active ? const ColorFilter.mode(Color(0xFFDD1847), BlendMode.srcIn) : null),
                    const SizedBox(width: 8),
                    Text(s['name']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: active ? const Color(0xFFDD1847) : const Color(0xFF666666))),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 4,
                  itemBuilder: (_, _) => const SkeletonProjectCard(),
                )
              : _projects.isEmpty
                  ? const Center(child: Text('Ничего не найдено', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _projects.length,
                      itemBuilder: (_, i) {
                        final p = _projects[i];
                        final photo = p['profile_photo'];
                        final projectId = (p['id'] as num).toInt();
                        
                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: photo != null && photo.toString().isNotEmpty
                                ? CachedAvatar(url: photo, size: 44, radius: 22)
                                : _photoPlaceholder(),
                            title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(p['address_raw'] ?? '', style: const TextStyle(fontSize: 12)),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingScreen(projectId: projectId),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDD1847),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Записаться', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}