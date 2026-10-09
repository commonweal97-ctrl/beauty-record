import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';

class ClientNotificationSettingsSheet extends StatefulWidget {
  final int clientId;
  final int projectId;

  const ClientNotificationSettingsSheet({
    super.key,
    required this.clientId,
    required this.projectId,
  });

  @override
  State<ClientNotificationSettingsSheet> createState() =>
      _ClientNotificationSettingsSheetState();
}

class _ClientNotificationSettingsSheetState
    extends State<ClientNotificationSettingsSheet> {
  Map<String, bool> _settings = {};
  bool _loading = true;

  static const _types = [
    {'key': 'new_booking', 'label': 'Создание записи'},
    {'key': 'transfer', 'label': 'Перенос записи'},
    {'key': 'cancel', 'label': 'Отмена записи'},
    {'key': 'reminder', 'label': 'Напоминание'},
    {'key': 'return_visit', 'label': 'Повторный визит'},
    {'key': 'after_cancel', 'label': 'После отмены'},
    {'key': 'birthday', 'label': 'День рождения'},
    {'key': 'review_request', 'label': 'Запрос отзыва'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.get(
        '/api/client/notification-settings?client_id=${widget.clientId}&project_id=${widget.projectId}',
      );
      if (result['success'] == true && mounted) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final settings = <String, bool>{};
        for (final type in _types) {
          final key = type['key']!;
          settings[key] = data[key] != false;
        }
        setState(() {
          _settings = settings;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки настроек уведомлений: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String type, bool enabled) async {
    // Оптимистичное обновление UI
    setState(() => _settings[type] = enabled);

    try {
      // Сохраняем все настройки
      await ApiService.saveNotificationSettings(
        clientId: widget.clientId,
        projectId: widget.projectId,
        settings: _settings,
      );
    } catch (e) {
      debugPrint('Ошибка сохранения настройки: $e');
      // Откатываем
      if (mounted) {
        setState(() => _settings[type] = !enabled);
        showToast(context, 'Ошибка сохранения', isError: true);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
              border:
                  Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_back,
                        color: Color(0xFF666666),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Уведомления клиента',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.close,
                        color: Color(0xFF666666),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Список
          Expanded(
            child: _loading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (_, i) => Padding(
                      padding:
                          EdgeInsets.only(bottom: i < 4 ? 8 : 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const SkeletonBox(
                                height: 14, width: 150),
                            const SkeletonBox(
                                height: 24, width: 44, radius: 12),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: _types.map((type) {
                      final key = type['key']!;
                      final label = type['label']!;
                      final enabled = _settings[key] ?? true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Switch(
                              value: enabled,
                              onChanged: (v) => _toggle(key, v),
                              activeThumbColor: const Color(0xFFDD1847),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}