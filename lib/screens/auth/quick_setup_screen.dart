import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/api_service.dart';
import '../../widgets/skeletons.dart';

class QuickSetupScreen extends StatefulWidget {
  final int userId;
  const QuickSetupScreen({super.key, required this.userId});

  @override
  State<QuickSetupScreen> createState() => _QuickSetupScreenState();
}

class _QuickSetupScreenState extends State<QuickSetupScreen> {
  bool _hasPin = false;
  bool _hasBiometric = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  void _loadStatus() async {
    try {
      final result = await ApiService.get('/api/quick-login/status');
      if (result['success'] == true && mounted) {
        setState(() {
          _hasPin = result['data']['has_pin'] ?? false;
          _hasBiometric = result['data']['has_biometric'] ?? false;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _togglePin() async {
    if (_hasPin) {
      // Удалить PIN
      try {
        final result = await ApiService.deletePin();
        if (result['success'] == true) setState(() => _hasPin = false);
      } catch (_) {}
    } else {
      // Установить PIN
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _PinQuickSetup(userId: widget.userId)),
      );
      if (result == true) setState(() => _hasPin = true);
    }
  }

  void _toggleBiometric() async {
    if (_hasBiometric) {
      try {
        final result = await ApiService.deleteBiometric();
        if (result['success'] == true) setState(() => _hasBiometric = false);
      } catch (_) {}
    } else {
      final localAuth = LocalAuthentication();
      try {
        final authenticated = await localAuth.authenticate(
          localizedReason: 'Подтвердите личность для включения быстрого входа',
        );
        if (authenticated) {
          setState(() => _hasBiometric = true);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('Быстрый вход', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.grey), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SkeletonBox(height: 14, width: 280),
                  const SizedBox(height: 24),
                  _buildSkeletonCard(),
                  const SizedBox(height: 12),
                  _buildSkeletonCard(),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Подключите способы быстрого входа, чтобы не вводить пароль', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  _buildCard(
                    icon: Icons.dialpad,
                    title: 'PIN-код',
                    subtitle: '4 цифры для быстрого входа',
                    enabled: _hasPin,
                    onTap: _togglePin,
                    onDelete: _hasPin ? _togglePin : null,
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    icon: Icons.fingerprint,
                    title: 'Биометрия',
                    subtitle: 'Вход по лицу или отпечатку',
                    enabled: _hasBiometric,
                    onTap: _toggleBiometric,
                    onDelete: _hasBiometric ? _toggleBiometric : null,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(children: [
        const SkeletonBox(width: 44, height: 44, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 16, width: 100),
              const SizedBox(height: 4),
              const SkeletonBox(height: 13, width: 160),
              const SizedBox(height: 6),
              const SkeletonBox(height: 12, width: 100),
            ],
          ),
        ),
        const SkeletonBox(width: 90, height: 36, radius: 10),
      ]),
    );
  }

  Widget _buildCard({required IconData icon, required String title, required String subtitle, required bool enabled, required VoidCallback onTap, VoidCallback? onDelete}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 24, color: const Color(0xFFDD1847))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(enabled ? '✓ Подключен' : 'Не подключен', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: enabled ? const Color(0xFF2E7D32) : const Color(0xFFDD1847))),
        ])),
        Column(children: [
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDD1847), side: const BorderSide(color: Color(0xFFDD1847)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            child: Text(enabled ? 'Изменить' : 'Настроить', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (onDelete != null)
            TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFF44336), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6)),
              child: const Text('Удалить', style: TextStyle(fontSize: 12)),
            ),
        ]),
      ]),
    );
  }
}

// Быстрый ввод PIN (без подтверждения)
class _PinQuickSetup extends StatefulWidget {
  final int userId;
  const _PinQuickSetup({required this.userId});

  @override
  State<_PinQuickSetup> createState() => _PinQuickSetupState();
}

class _PinQuickSetupState extends State<_PinQuickSetup> {
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String? _error;
  String? _pressedKey;

  void _onKeyPressed(String key) {
    HapticFeedback.lightImpact();
    if (_pin.length >= 4) return;
    setState(() { _pin += key; _error = null; _pressedKey = key; });
    Future.delayed(const Duration(milliseconds: 150), () { if (mounted) setState(() => _pressedKey = null); });
    if (_pin.length == 4) Future.delayed(const Duration(milliseconds: 200), () => _processPin());
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() { _pin = _pin.substring(0, _pin.length - 1); _error = null; });
  }

  void _processPin() {
    if (!_isConfirming) {
      setState(() { _firstPin = _pin; _pin = ''; _isConfirming = true; });
    } else {
      if (_pin == _firstPin) {
        ApiService.savePin(widget.userId, _pin).then((_) {
          if (!mounted) return;
          Navigator.pop(context, true);
        });
      } else {
        setState(() { _error = 'PIN-коды не совпадают'; _pin = ''; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.grey), onPressed: () => Navigator.pop(context))),
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          Text(_isConfirming ? 'Повторите PIN-код' : 'Придумайте PIN-код', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_isConfirming ? 'Введите PIN-код ещё раз' : '4 цифры для быстрого входа', style: const TextStyle(fontSize: 16, color: Color(0xFF666666))),
          const SizedBox(height: 40),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) => Container(width: 14, height: 14, margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(shape: BoxShape.circle, color: i < _pin.length ? (_error != null ? Colors.red : const Color(0xFFDD1847)) : const Color(0xFFE0E0E0))))),
          const SizedBox(height: 12),
          SizedBox(height: 20, child: _error != null ? Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)) : null),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['1','2','3'].map((k) => _buildKey(k)).toList()),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['4','5','6'].map((k) => _buildKey(k)).toList()),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['7','8','9'].map((k) => _buildKey(k)).toList()),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [const SizedBox(width: 72), _buildKey('0'), _buildBackspaceKey()]),
            ]),
          ),
          const Spacer(),
        ]),
      ),
    );
  }

  Widget _buildKey(String label) {
    final isPressed = _pressedKey == label;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedKey = label),
      onTapUp: (_) => _onKeyPressed(label),
      onTapCancel: () => setState(() => _pressedKey = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), width: 72, height: 72,
        decoration: BoxDecoration(color: isPressed ? const Color(0xFFDD1847) : const Color(0xFFF8F9FA), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: isPressed ? Colors.white : const Color(0xFF1A1A1A))),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return GestureDetector(
      onTap: _onBackspace,
      child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFFF8F9FA), shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(Icons.backspace_outlined, size: 28, color: Color(0xFF1A1A1A))),
    );
  }
}