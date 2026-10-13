// lib/screens/profile/settings_screen.dart
//
// Настройки профиля (ЛК клиента и бизнеса):
// - Смена email (через OTP на новый адрес)
// - Смена телефона (через звонок с нового номера)
// - Быстрый вход (PIN + биометрия)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_logger.dart';
import '../../core/app_typography.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common/phone_input.dart';
import '../../widgets/toast.dart';
import '../auth/quick_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _logTag = 'SettingsScreen';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        title: const Text(
          'Настройки',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          _buildSectionTitle('Безопасность и вход'),
          const SizedBox(height: 8),
          _buildCard([
            _buildItem(
              icon: Icons.email_outlined,
              title: 'Email',
              value: user.email.isNotEmpty ? user.email : 'Не указан',
              onTap: _showEmailDialog,
            ),
            _buildDivider(),
            _buildItem(
              icon: Icons.phone_outlined,
              title: 'Телефон',
              value: user.phone.isNotEmpty ? user.phone : 'Не указан',
              onTap: _showPhoneDialog,
            ),
            _buildDivider(),
            _buildItem(
              icon: Icons.dialpad,
              title: 'Быстрый вход',
              value: 'PIN и биометрия',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuickSetupScreen(userId: user.id),
                  ),
                );
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.colors.border.withValues(alpha: 0.5),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.brandLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: context.colors.brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // СМЕНА EMAIL
  // ============================================================

  void _showEmailDialog() {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String? error;
    bool codeSent = false;
    bool loading = false;
    final currentEmail = context.read<UserProvider>().email;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHandle(),
              const SizedBox(height: 20),
              const Text(
                'Изменение email',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Текущий: $currentEmail',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              if (!codeSent)
                const Text(
                  'Введите новый email',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                enabled: !codeSent,
                style: AppTypography.input.copyWith(color: const Color(0xFF1A1A1A)),
                decoration: _inputDecoration('new@email.ru'),
              ),
              if (codeSent) ...[
                const SizedBox(height: 20),
                const Text(
                  'Введите код подтверждения',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  decoration: _inputDecoration('000000').copyWith(counterText: ''),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF856404)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Код отправлен на указанный email',
                          style: TextStyle(fontSize: 13, color: Color(0xFF856404)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final newEmail = emailCtrl.text.trim();
                          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(newEmail)) {
                            setSheetState(() => error = 'Введите корректный email');
                            return;
                          }
                          if (newEmail == currentEmail) {
                            setSheetState(() => error = 'Это ваш текущий email');
                            return;
                          }
                          setSheetState(() {
                            loading = true;
                            error = null;
                          });

                          try {
                            if (!codeSent) {
                              final result = await ApiService.saveEmail(newEmail);
                              if (result['success'] != true) {
                                setSheetState(() {
                                  error = result['message'] ?? 'Ошибка. Попробуйте позже';
                                  loading = false;
                                });
                                return;
                              }
                              setSheetState(() {
                                codeSent = true;
                                loading = false;
                              });
                            } else {
                              final code = codeCtrl.text.trim();
                              if (code.length != 6) {
                                setSheetState(() {
                                  error = 'Введите 6-значный код';
                                  loading = false;
                                });
                                return;
                              }
                              final result = await ApiService.verifyEmail(code);
                              if (result['success'] != true) {
                                setSheetState(() {
                                  error = result['message'] ?? 'Неверный код';
                                  loading = false;
                                });
                                return;
                              }
                              if (mounted) {
                                await context.read<UserProvider>().updateEmail(newEmail);
                                if (mounted) {
                                  showToast(context, 'Email изменён');
                                }
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          } catch (e) {
                            AppLogger.warning('$_logTag: change email failed: $e');
                            setSheetState(() {
                              error = 'Ошибка соединения';
                              loading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    loading ? '...' : (codeSent ? 'Подтвердить' : 'Отправить код'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // СМЕНА ТЕЛЕФОНА
  // ============================================================

  void _showPhoneDialog() {
    final phoneKey = GlobalKey<PhoneInputState>();
    final phoneCtrl = TextEditingController();
    String? error;
    bool codeSent = false; // запрос отправлен → ждём звонка
    bool loading = false;
    String newPhone = '';
    final currentPhone = context.read<UserProvider>().phone;

    // Поллинг статуса звонка
    bool polling = false;

    Future<void> startPolling() async {
      if (polling) return;
      polling = true;
      for (int i = 0; i < 100; i++) {
        // ~5 минут (3 сек × 100)
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) break;
        try {
          final result = await ApiService.changePhoneConfirm(newPhone);
          if (result['success'] == true) {
            if (mounted) {
              await context.read<UserProvider>().updatePhone(newPhone);
              if (mounted) showToast(context, 'Телефон изменён');
            }
            if (mounted) Navigator.pop(context);
            break;
          }
        } catch (_) {}
      }
      polling = false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHandle(),
              const SizedBox(height: 20),
              const Text(
                'Изменение телефона',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Текущий: $currentPhone',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              if (!codeSent) ...[
                const Text(
                  'Введите новый номер телефона',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                PhoneInput(
                  key: phoneKey,
                  controller: phoneCtrl,
                  onPhoneChanged: (_) => setSheetState(() {}),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.phone_in_talk, size: 40, color: context.colors.brand),
                      const SizedBox(height: 12),
                      const Text(
                        'Позвоните с нового номера',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        newPhone,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.colors.brand,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Звонок сбросится — номер подтвердится автоматически',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ожидание звонка...',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (loading || codeSent)
                      ? null
                      : () async {
                          final state = phoneKey.currentState;
                          if (state == null || !state.isValid) {
                            setSheetState(() => error = 'Введите корректный номер');
                            return;
                          }
                          final phone = state.fullPhone;
                          if (phone == currentPhone) {
                            setSheetState(() => error = 'Это ваш текущий номер');
                            return;
                          }
                          setSheetState(() {
                            loading = true;
                            error = null;
                          });

                          try {
                            final result = await ApiService.changePhoneRequest(phone);
                            if (result['success'] != true) {
                              setSheetState(() {
                                error = result['message'] ?? 'Ошибка';
                                loading = false;
                              });
                              return;
                            }
                            newPhone = phone;
                            setSheetState(() {
                              codeSent = true;
                              loading = false;
                            });
                            startPolling();
                          } catch (e) {
                            AppLogger.warning('$_logTag: change phone failed: $e');
                            setSheetState(() {
                              error = 'Ошибка соединения';
                              loading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    loading ? '...' : 'Продолжить',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.colors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.inputHint,
      filled: true,
      fillColor: context.colors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.brand, width: 2),
      ),
    );
  }
}
