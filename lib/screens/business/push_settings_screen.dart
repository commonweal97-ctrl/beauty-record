import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/skeletons.dart';
import '../../../widgets/toast.dart';

class PushSettingsScreen extends StatefulWidget {
  final int projectId;
  const PushSettingsScreen({super.key, required this.projectId});

  @override
  State<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends State<PushSettingsScreen> {
  bool _loading = true;
  bool _pushEnabled = true;
  bool _newBooking = true;
  bool _bookingChange = true;
  bool _bookingCancel = true;
  bool _newReview = true;
  bool _chatMessage = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.get('/api/push-settings/get?project_id=${widget.projectId}');
      if (r['success'] == true && mounted) {
        final d = r['data'];
        setState(() {
          _pushEnabled = d['push_enabled'] == true || d['push_enabled'] == 1 || d['push_enabled'] == '1';
          _newBooking = d['new_booking'] == true || d['new_booking'] == 1 || d['new_booking'] == '1';
          _bookingChange = d['booking_change'] == true || d['booking_change'] == 1 || d['booking_change'] == '1';
          _bookingCancel = d['booking_cancel'] == true || d['booking_cancel'] == 1 || d['booking_cancel'] == '1';
          _newReview = d['new_review'] == true || d['new_review'] == 1 || d['new_review'] == '1';
          _chatMessage = d['chat_message'] == true || d['chat_message'] == 1 || d['chat_message'] == '1';
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      await ApiService.post('/api/push-settings/save', {
        'project_id': widget.projectId,
        'push_enabled': _pushEnabled ? 1 : 0,
        'new_booking': _newBooking ? 1 : 0,
        'booking_change': _bookingChange ? 1 : 0,
        'booking_cancel': _bookingCancel ? 1 : 0,
        'new_review': _newReview ? 1 : 0,
        'chat_message': _chatMessage ? 1 : 0,
      });
      if (mounted) {
        showToast(context, 'Сохранено');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonCircle(size: 48),
            SizedBox(height: 16),
            SkeletonBox(height: 14, width: 160),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Оповещения',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Настройте получение push-уведомлений',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 20),
              _buildToggle(
                'Push-уведомления',
                'Получать уведомления на устройство',
                _pushEnabled,
                (v) => setState(() => _pushEnabled = v),
              ),
              if (_pushEnabled) ...[
                const SizedBox(height: 20),
                const Text(
                  'ТИПЫ УВЕДОМЛЕНИЙ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF999999),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildToggle(
                  'Новая запись',
                  'При создании новой записи',
                  _newBooking,
                  (v) => setState(() => _newBooking = v),
                ),
                const SizedBox(height: 12),
                _buildToggle(
                  'Изменение записи',
                  'При переносе или изменении',
                  _bookingChange,
                  (v) => setState(() => _bookingChange = v),
                ),
                const SizedBox(height: 12),
                _buildToggle(
                  'Отмена записи',
                  'При отмене записи',
                  _bookingCancel,
                  (v) => setState(() => _bookingCancel = v),
                ),
                const SizedBox(height: 12),
                _buildToggle(
                  'Новый отзыв',
                  'При появлении нового отзыва',
                  _newReview,
                  (v) => setState(() => _newReview = v),
                ),
                const SizedBox(height: 12),
                _buildToggle(
                  'Сообщения в чате',
                  'При получении нового сообщения',
                  _chatMessage,
                  (v) => setState(() => _chatMessage = v),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDD1847),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Сохранить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFFDD1847)),
        ],
      ),
    );
  }
}