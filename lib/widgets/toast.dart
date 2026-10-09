// lib/widgets/toast.dart
import 'package:flutter/material.dart';

void showToast(BuildContext context, String message, {bool isError = false}) {
  // Откладываем показ toast до следующего кадра,
  // чтобы убедиться, что контекст полностью инициализирован
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _showToastInternal(context, message, isError: isError);
  });
}

void _showToastInternal(BuildContext context, String message, {bool isError = false}) {
  try {
    // Проверяем, что контекст валиден
    if (!context.mounted) return;
    
    final overlay = Overlay.of(context);
    if (overlay == null) return;
    
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (ctx) {
        // Получаем MediaQuery внутри builder, где контекст валиден
        final mediaQuery = MediaQuery.of(ctx);
        
        return Stack(
          children: [
            Positioned(
              bottom: mediaQuery.padding.bottom + 16,
              left: 16,
              right: 16,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (_, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, -20 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isError ? const Color(0xFFC62828) : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isError ? const Color(0xFFC62828) : const Color(0xFF1A1A1A)).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isError ? Icons.error_outline : Icons.check_circle_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (entry.mounted) {
                              entry.remove();
                            }
                          },
                          child: const Icon(Icons.close, color: Colors.white70, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  } catch (e) {
    // Логируем ошибку, но не крашим приложение
    print('Toast error: $e');
  }
}