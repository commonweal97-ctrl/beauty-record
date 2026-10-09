import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/cached_image.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _discounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  void _load() async {
    try {
      final result = await ApiService.get('/api/client/discounts');
      if (result['success'] == true && mounted) {
        setState(() {
          _discounts = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Скидки и сертификаты', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.grey), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.all(6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = (constraints.maxWidth) / 2;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        left: _tabController.index == 0 ? 0 : tabWidth,
                        top: 0,
                        bottom: 0,
                        width: tabWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _tabController.animateTo(0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    'Скидки',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _tabController.index == 0 ? Colors.black : const Color(0xFF666666),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _tabController.animateTo(1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    'Сертификаты',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _tabController.index == 1 ? Colors.black : const Color(0xFF666666),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _loading
              ? ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: 4,
                  itemBuilder: (_, _) => _buildSkeletonItem(),
                )
              : _discounts.isEmpty
                  ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.discount_outlined, size: 48, color: Color(0xFFCCCCCC)), SizedBox(height: 12), Text('У вас пока нет скидок', style: TextStyle(color: Color(0xFF999999))), SizedBox(height: 4), Text('Записывайтесь к мастерам и получайте скидки', style: TextStyle(fontSize: 12, color: Color(0xFF999999)))]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _discounts.length,
                      itemBuilder: (_, i) {
                        final d = _discounts[i];
                        final photo = d['profile_photo'] ?? d['project_photo'] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFF0F0F0)), borderRadius: BorderRadius.circular(16)),
                          child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedAvatar(url: photo, size: 52, radius: 14),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d['project_name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(d['address_raw'] ?? d['address'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF999999)))])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('-${d['discount']}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFFDD1847))), const Text('скидка', style: TextStyle(fontSize: 11, color: Color(0xFF999999)))]),
                          ]),
                        );
                      },
                    ),
          const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.card_giftcard, size: 48, color: Color(0xFFDDDDDD)), SizedBox(height: 12), Text('Сертификаты появятся позже', style: TextStyle(color: Color(0xFF999999)))])),
        ],
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SkeletonBox(height: 28, width: 60),
            const SizedBox(height: 4),
            const SkeletonBox(height: 11, width: 40),
          ],
        ),
      ]),
    );
  }
}