// lib/screens/business/business_dashboard_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../client/client_dashboard_screen.dart';
import '../client/client_chat_screen.dart';
import '../client/profile_screen.dart';
import 'networks_screen.dart';
import 'journal_screen.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/toast.dart';

class BusinessDashboardScreen extends StatefulWidget {
  final int? initialProjectId;
  const BusinessDashboardScreen({super.key, this.initialProjectId});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();

    if (widget.initialProjectId != null && widget.initialProjectId! > 0) {
      // Открывается конкретный проект — setProjectId сам сохранит
      // last_screen='business_project'.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openJournal(widget.initialProjectId!);
      });
    } else {
      // Список проектов — запоминаем, чтобы вернуть пользователя сюда.
      AuthService.saveLastScreen('business');
    }
  }

  void _loadProjects() async {
    try {
      final result = await ApiService.get('/api/project/list');
      if (mounted) {
        setState(() {
          _projects = result['success'] == true
              ? List<Map<String, dynamic>>.from(result['data'] ?? [])
              : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _projects = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _openJournal(int projectId) async {
    await context.read<UserProvider>().setProjectId(projectId);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JournalScreen(projectId: projectId)),
    );
  }

  void _onProjectCreated(int projectId) async {
    _loadProjects();
    await _openJournal(projectId);
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    showToast(context, 'Ссылка скопирована!');
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey[200],
      child: SvgPicture.asset('assets/photo-none.svg', width: 28, height: 28, fit: BoxFit.scaleDown),
    );
  }

  Future<void> _switchToClient() async {
    await context.read<UserProvider>().setRole('client');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ClientDashboardScreen()),
      );
    }
  }

  Widget _buildRoleToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _switchToClient,
              child: Container(
                alignment: Alignment.center,
                child: const Text(
                  'Клиент',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Бизнес',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDD1847),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 88,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF0F0F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)]),
              child: Row(children: [
                const SizedBox(width: 20),
                SvgPicture.asset('assets/LogoZapis.svg', height: 48),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ClientChatScreen()));
                    },
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(15)),
                      child: Center(child: SvgPicture.asset('assets/chat.svg', width: 22, height: 22, colorFilter: const ColorFilter.mode(Color(0xFF666666), BlendMode.srcIn))),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ]),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildRoleToggle(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildProjectsTab(),
                const NetworksScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0F0F0)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildNavItem(0, 'assets/layers.svg', 'Проекты'),
                _buildNavItem(1, 'assets/home.svg', 'Сети'),
                _buildNavItem(2, 'assets/user.svg', 'Профиль'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsTab() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, _) => _buildSkeletonCard(),
      );
    }
    if (_projects.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      onRefresh: () async => _loadProjects(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _projects.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Мои проекты',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.grey[900]),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showCreateDialog,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFDD1847), Color(0xFFC1163D)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }
          return _buildProjectCard(_projects[i - 1]);
        },
      ),
    );
  }

  Widget _buildNavItem(int index, String iconPath, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFDF2F5) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                iconPath,
                width: 24, height: 24,
                colorFilter: ColorFilter.mode(
                  isActive ? const Color(0xFFDD1847) : const Color(0xFF666666),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? const Color(0xFFDD1847) : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> p) {
    final enabled = p['online_booking_enabled'] == true || p['online_booking_enabled'] == 1;
    final photo = p['profile_photo'];

    return GestureDetector(
      onTap: () => _openJournal(p['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: photo != null && photo.toString().isNotEmpty
                ? CachedAvatar(url: photo, size: 56, radius: 12)
                : _photoPlaceholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                p['name'] ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (p['address_raw'] != null)
                Text(
                  p['address_raw'],
                  style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              const SizedBox(height: 6),
              if (enabled)
                GestureDetector(
                  onTap: () => _copyLink('https://запись.бьютироща.рф/book/${p['id']}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E5E5))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(child: Text('запись.бьютироща.рф/book/${p['id']}', style: const TextStyle(fontSize: 12, color: Colors.black54), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy, size: 14, color: Colors.grey),
                    ]),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF0F0F0))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.link_off, size: 14, color: Color(0xFFBBBBBB)),
                    SizedBox(width: 6),
                    Text('Онлайн-запись неактивна', style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
                  ]),
                ),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.business, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 20),
        const Text('Проекты ещё не созданы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Создайте свой первый проект, чтобы начать работу', style: TextStyle(color: Color(0xFF888888))),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: _showCreateDialog, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Создать проект', style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ])),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(children: [
        const SkeletonBox(width: 56, height: 56, radius: 12),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 16, width: 200),
              const SizedBox(height: 8),
              const SkeletonBox(height: 12, width: 140),
              const SizedBox(height: 12),
              const SkeletonBox(height: 28, width: 160, radius: 8),
            ],
          ),
        ),
      ]),
    );
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CreateProjectSheet(onProjectCreated: _onProjectCreated),
      ),
    );
  }
}

class CreateProjectSheet extends StatefulWidget {
  final Function(int projectId)? onProjectCreated;

  const CreateProjectSheet({super.key, this.onProjectCreated});

  @override
  State<CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<CreateProjectSheet> {
  int _step = 1;
  String? _type;
  String? _sphere;
  final List<String> _selectedSubcategories = [];
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _terms = false;
  bool _newsletter = true;
  bool _loading = false;

  final _addressFocus = FocusNode();
  List<String> _addressSuggestions = [];
  bool _addressSearching = false;
  Timer? _addressTimer;

  final _spheres = {
    'beauty': 'Красота', 'health': 'Здоровье', 'sport': 'Спорт', 'rent': 'Аренда',
    'animals': 'Животные', 'auto': 'Авто', 'entertainment': 'Развлечения', 'education': 'Образование',
    'law': 'Юристы', 'style': 'Стиль', 'restaurant': 'Рестораны', 'other': 'Прочее',
  };

  final _sphereExamples = {
    'beauty': 'татуаж, тату, барбершоп, ногтевой сервис, косметология',
    'health': 'подология, стоматология, медицина, офтальмология',
    'sport': 'танцы, фитнес, йога, единоборства',
    'rent': 'аренда, коворкинг',
    'animals': 'груминг, ветеринария',
    'auto': 'автомойка, детейлинг, автошкола, автосервис',
    'entertainment': 'туризм, боулинг, киберспорт, квест, бани, сауны',
    'education': 'вокал, репетитор, языковая школа, музыка',
    'law': 'нотариус, юридические услуги',
    'style': 'фотостудия',
    'restaurant': 'ресторан',
    'other': 'прочие услуги',
  };

  final _sphereIcons = {
    'beauty': 'assets/beauty.svg', 'health': 'assets/health.svg', 'sport': 'assets/sport.svg',
    'rent': 'assets/searching-for-an-apartment.svg', 'animals': 'assets/pets.svg', 'auto': 'assets/auto.svg',
    'entertainment': 'assets/holiday.svg', 'education': 'assets/education.svg', 'law': 'assets/law.svg',
    'style': 'assets/photo-camera.svg', 'restaurant': 'assets/food.svg', 'other': 'assets/dots.svg',
  };

  final _subcategories = {
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _addressFocus.dispose();
    _addressTimer?.cancel();
    super.dispose();
  }

  void _submit() async {
    if (!_terms || _nameCtrl.text.trim().isEmpty || _addressCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final result = await ApiService.createProject(
        type: _type ?? 'specialist',
        sphere: _sphere ?? 'beauty',
        name: _nameCtrl.text.trim(),
        addressRaw: _addressCtrl.text.trim(),
      );

      if (result['success'] == true && mounted) {
        final projectIdRaw = result['data']?['id'] ?? result['data']?['project_id'];
        final projectId = projectIdRaw is int ? projectIdRaw : int.tryParse(projectIdRaw?.toString() ?? '');

        Navigator.pop(context);

        if (projectId != null && widget.onProjectCreated != null) {
          widget.onProjectCreated!(projectId);
        }
      } else {
        if (mounted) {
          showToast(context, result['message'] ?? 'Ошибка создания проекта', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(context, 'Ошибка при создании проекта', isError: true);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onAddressChanged(String query) {
    _addressTimer?.cancel();
    if (query.length < 3) {
      setState(() => _addressSuggestions = []);
      return;
    }
    _addressTimer = Timer(const Duration(milliseconds: 400), () => _searchAddress(query));
  }

  void _searchAddress(String query) async {
    setState(() => _addressSearching = true);
    try {
      final suggestions = await ApiService.dadataAddress(query);
      if (mounted) setState(() { _addressSuggestions = suggestions; _addressSearching = false; });
    } catch (_) {
      if (mounted) setState(() { _addressSuggestions = []; _addressSearching = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(width: 48, child: _step > 1 ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _step--), padding: EdgeInsets.zero, constraints: const BoxConstraints()) : null),
            Expanded(child: Center(child: Text(['Тип проекта', 'Сфера деятельности', 'Подкатегории', 'Основная информация'][_step - 1], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))),
            SizedBox(width: 48, child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints())),
          ]),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_step == 1) _buildStep1(),
                  if (_step == 2) _buildStep2(),
                  if (_step == 3) _buildStep2b(),
                  if (_step == 4) _buildStep3(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(children: [
      _buildTypeCard('Компания', '2 и более специалистов для записи', 'assets/layers.svg', () {
        setState(() {
          _type = 'company';
          _step++;
        });
      }),
      const SizedBox(height: 12),
      _buildTypeCard('Специалист', 'Работаю самостоятельно', 'assets/user.svg', () {
        setState(() {
          _type = 'specialist';
          _step++;
        });
      }),
    ]);
  }

  Widget _buildTypeCard(String title, String desc, String svgAsset, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(children: [
          SvgPicture.asset(svgAsset, width: 48, height: 48),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),
        ]),
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _spheres.entries.map((e) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _sphere = e.key;
              _selectedSubcategories.clear();
              _step++;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
            child: Row(children: [
              SvgPicture.asset(_sphereIcons[e.key] ?? 'assets/dots.svg', width: 24, height: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_sphereExamples[e.key] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStep2b() {
    final cats = _subcategories[_sphere] ?? [];
    if (cats.isEmpty) {
      _step++;
      return _buildStep3();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Выберите подкатегории', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: cats.map((cat) {
            final sel = _selectedSubcategories.contains(cat);
            return GestureDetector(
              onTap: () => setState(() { sel ? _selectedSubcategories.remove(cat) : _selectedSubcategories.add(cat); }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFDD1847) : const Color(0xFFF8F9FA),
                  border: Border.all(color: sel ? const Color(0xFFDD1847) : const Color(0xFFF0F0F0)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(cat, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: sel ? Colors.white : const Color(0xFF666666))),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: () => setState(() => _step++),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Далее', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        )),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
          child: TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Наименование компании',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF8F8F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
              child: TextField(
                controller: _addressCtrl,
                focusNode: _addressFocus,
                maxLines: 2,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Город, улица, дом, помещение/офис',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: (v) => _onAddressChanged(v),
              ),
            ),
            if (_addressSuggestions.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _addressSuggestions.length.clamp(0, 5),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(_addressSuggestions[i], style: const TextStyle(fontSize: 14)),
                    onTap: () {
                      _addressCtrl.text = _addressSuggestions[i];
                      setState(() => _addressSuggestions.clear());
                      _addressFocus.unfocus();
                    },
                  ),
                ),
              )
            else if (_addressSearching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDD1847))),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 24, height: 24, child: Checkbox(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false), activeColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)))),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _terms = !_terms),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                    children: [
                      const TextSpan(text: 'Я принимаю условия '),
                      TextSpan(
                        text: 'Пользовательского соглашения',
                        style: const TextStyle(color: Color(0xFFDD1847), decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = () => ApiService.openUrl('https://запись.бьютироща.рф/terms'),
                      ),
                      const TextSpan(text: ' и '),
                      TextSpan(
                        text: 'Политики конфиденциальности',
                        style: const TextStyle(color: Color(0xFFDD1847), decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = () => ApiService.openUrl('https://запись.бьютироща.рф/privacy'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 24, height: 24, child: Checkbox(value: _newsletter, onChanged: (v) => setState(() => _newsletter = v ?? false), activeColor: const Color(0xFFDD1847), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(onTap: () => setState(() => _newsletter = !_newsletter), child: Text('Согласен на получение информационно-рекламной рассылки', style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)))),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: (_terms && _nameCtrl.text.isNotEmpty && _addressCtrl.text.isNotEmpty && !_loading) ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDD1847),
            disabledBackgroundColor: const Color(0xFFDD1847),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _loading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                    SizedBox(width: 12),
                    Text('Создание...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                )
              : const Text('Создать проект', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        )),
      ],
    );
  }
}
