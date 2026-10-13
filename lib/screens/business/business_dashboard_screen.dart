// lib/screens/business/business_dashboard_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/api_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../auth/quick_setup_screen.dart';
import '../profile/settings_screen.dart';
import '../select_role_screen.dart';
import 'business_profile_screen.dart';
import 'networks_screen.dart';
import 'journal_screen.dart';
import '../../../widgets/app_footer.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/toast.dart';
import '../auth/login_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  final int? initialProjectId;
  const BusinessDashboardScreen({super.key, this.initialProjectId});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  String? _userAvatar;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadUserInfo();
    
    // Если передан initialProjectId — открываем журнал сразу
    if (widget.initialProjectId != null && widget.initialProjectId! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openJournal(widget.initialProjectId!);
      });
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final result = await ApiService.get('/api/profile');
      if (result['success'] == true && mounted) {
        setState(() {
          _userName = result['data']?['name'] ?? '';
          _userAvatar = result['data']?['avatar']?.toString();
        });
      }
    } catch (_) {}
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
    // Сохраняем последний выбранный проект
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

  Future<void> _logout() async {
    try {
      await ApiService.logout();
    } catch (_) {}
    
    await ApiService.clearSession();
    if (!mounted) return;
    await context.read<UserProvider>().logout();
    if (!mounted) return;
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _switchToClient() async {
    await context.read<UserProvider>().setRole('client');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SelectRoleScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _userName.isNotEmpty 
        ? _userName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

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
                GestureDetector(
                  onTap: () => _openDrawer(),
                  child: Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.settings, color: Color(0xFF666666))),
                ),
                Expanded(child: Center(child: SvgPicture.asset('assets/LogoZapis.svg', height: 48))),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessProfileScreen())),
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _userAvatar != null && _userAvatar!.isNotEmpty
                          ? CachedAvatar(url: _userAvatar, size: 50, radius: 15)
                          : Center(child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDD1847), fontSize: 16))),
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
          Expanded(
            child: _loading
                ? ListView.builder(padding: const EdgeInsets.all(16), itemCount: 3, itemBuilder: (_, _) => _buildSkeletonCard())
                : _projects.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: () async => _loadProjects(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _projects.length + 1,
                          itemBuilder: (_, i) {
                            if (i == 0) return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(children: [Expanded(child: Text('Мои проекты', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.grey[900]))), GestureDetector(onTap: _showCreateDialog, child: Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFDD1847), Color(0xFFC1163D)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Colors.white)))]));
                            return _buildProjectCard(_projects[i - 1]);
                          },
                        ),
                      ),
          ),
          const AppFooter(),
        ],
      ),
    );
  }

  void _openDrawer() {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => _buildDrawerContent(),
      transitionBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }

  Widget _buildDrawerContent() {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFDD1847),
          secondary: Color(0xFFDD1847),
          surface: Color(0xFFF5F5F5),
        ),
      ),
      child: Material(
        color: const Color(0xFFF5F5F5),
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: const Color(0xFFF5F5F5),
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  const Text('Меню', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.of(context).pop()),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    _drawerSection('Основное', [
                      _drawerItem(
                        icon: Icons.person_outline,
                        label: 'Переключиться на клиента',
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _switchToClient();
                        },
                      ),
                      _drawerItem(
                        icon: null,
                        svgIcon: 'assets/layers.svg',
                        label: 'Сети',
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => NetworksScreen()));
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _drawerSection('Аккаунт', [
                      _drawerItem(
                        icon: Icons.lock_outline,
                        label: 'Настройки',
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        },
                      ),
                      _drawerItem(
                        icon: Icons.lock_outline,
                        label: 'Быстрый вход',
                        onTap: () async {
                          Navigator.of(context).pop();
                          final result = await ApiService.get('/api/profile');
                          if (!mounted) return;
                          final userId = result['data']?['id'] ?? 0;
                          if (userId > 0) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => QuickSetupScreen(userId: userId)));
                          }
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _drawerSection('Система', [
                      _drawerItem(
                        icon: Icons.logout,
                        label: 'Выйти',
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _logout();
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _drawerSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF999999),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _drawerItem({
    IconData? icon,
    String? svgIcon,
    required String label,
    bool active = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFEF2F4) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? const Color(0xFFDD1847).withValues(alpha: 0.2) : const Color(0xFFF0F0F0),
              width: active ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: active ? 0.04 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFDD1847) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: svgIcon != null
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: SvgPicture.asset(
                          svgIcon,
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            active ? Colors.white : const Color(0xFF666666),
                            BlendMode.srcIn,
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        size: 20,
                        color: active ? Colors.white : const Color(0xFF666666),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: active ? const Color(0xFFDD1847) : Colors.black87,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDD1847),
                    shape: BoxShape.circle,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey[300],
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