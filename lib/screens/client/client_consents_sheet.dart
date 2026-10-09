import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';

class ClientConsentsSheet extends StatefulWidget {
  final int clientId;
  final int projectId;
  final VoidCallback onSaved;

  const ClientConsentsSheet({
    super.key,
    required this.clientId,
    required this.projectId,
    required this.onSaved,
  });

  @override
  State<ClientConsentsSheet> createState() => _ClientConsentsSheetState();
}

class _ClientConsentsSheetState extends State<ClientConsentsSheet> {
  Map<String, dynamic>? _consentData;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.get(
        '/api/client/consent/get?client_id=${widget.clientId}&project_id=${widget.projectId}',
      );
      if (result['success'] == true && mounted) {
        setState(() {
          _consentData = result['data'];
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки согласий: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revokeConsent(String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отозвать согласие?'),
        content: const Text('Клиент будет уведомлен.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Отозвать'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final field = type == 'data' ? 'data_consent' : 'marketing_consent';

    try {
      final result = await ApiService.post('/api/client/consent/save', {
        'client_id': widget.clientId,
        'project_id': widget.projectId,
        field: 0,
      });
      if (result['success'] == true && mounted) {
    widget.onSaved();
    _load();
    showToast(context, 'Согласие отозвано');
  }
    } catch (e) {
      debugPrint('Ошибка отзыва согласия: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Color(0xFF666666)),
                ),
                const Spacer(),
                const Text(
                  'Согласия',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
          // Тело
          Expanded(
            child: _loading
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSkeletonCard(),
                      const SizedBox(height: 14),
                      _buildSkeletonCard(),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildConsentCard(
                        title: 'Согласие на обработку персональных данных',
                        isGranted: _consentData?['data_consent'] == true,
                        fileUrl: _consentData?['data_consent_file'],
                        fileName: _consentData?['data_consent_file_name'],
                        createdAt: _consentData?['created_at'],
                        onRevoke: () => _revokeConsent('data'),
                      ),
                      const SizedBox(height: 14),
                      _buildConsentCard(
                        title: 'Согласие на получение информационно-рекламной рассылки',
                        isGranted: _consentData?['marketing_consent'] == true,
                        fileUrl: _consentData?['marketing_consent_file'],
                        fileName: _consentData?['marketing_consent_file_name'],
                        createdAt: _consentData?['created_at'],
                        onRevoke: () => _revokeConsent('marketing'),
                      ),
                    ],
                  ),
          ),
          SizedBox(height: bottomInset),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SkeletonBox(height: 14, width: 200)),
              const SkeletonBox(height: 20, width: 80, radius: 10),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonBox(height: 12, width: 150),
          const SizedBox(height: 10),
          const SkeletonBox(height: 44, radius: 12),
        ],
      ),
    );
  }

  Widget _buildConsentCard({
    required String title,
    required bool isGranted,
    String? fileUrl,
    String? fileName,
    String? createdAt,
    required VoidCallback onRevoke,
  }) {
    final statusText = isGranted ? 'Выдано' : 'Не настроено';
    final statusColor = isGranted ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5);
    final statusTextColor = isGranted ? const Color(0xFF2E7D32) : const Color(0xFF999999);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок и статус
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Источник
          if (fileUrl != null && fileUrl.isNotEmpty)
            Text(
              'Способ получения: Офлайн (загружен файл)',
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            )
          else if (isGranted)
            const Text(
              'Способ получения: Онлайн',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          
          // Ссылка на файл
          if (fileUrl != null && fileUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // Открыть файл
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 14, color: Color(0xFFDD1847)),
                  const SizedBox(width: 4),
                  Text(
                    fileName ?? 'Скачать файл',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFDD1847),
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Дата
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Выдано: $createdAt',
              style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
            ),
          ],

          // Зона загрузки
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: const Column(
              children: [
                Icon(Icons.cloud_upload_outlined, color: Color(0xFF999999), size: 24),
                SizedBox(height: 6),
                Text(
                  'Загрузить скан согласия',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666), fontWeight: FontWeight.w500),
                ),
                Text(
                  'PDF, DOC, PNG, JPG',
                  style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
                ),
              ],
            ),
          ),

          // Кнопка отзыва
          if (isGranted) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRevoke,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF44336),
                  side: const BorderSide(color: Color(0xFFF44336)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.close, size: 14),
                label: const Text(
                  'Отозвать согласие',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}