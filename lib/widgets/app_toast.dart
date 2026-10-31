// lib/widgets/app_toast.dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

enum AppToastType { success, error, info, warning }

class AppToast {
  /// Показывает тост сверху экрана. Внутренняя очередь — новый не перекрывает текущий.
  static void show(BuildContext context, String message, {
    AppToastType type = AppToastType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      _ToastQueue.instance.push(_ToastMessage(message: message, type: type, duration: duration));
    });
  }
}

class _ToastMessage {
  final String message;
  final AppToastType type;
  final Duration duration;
  _ToastMessage({required this.message, required this.type, required this.duration});
}

/// Синглтон-очередь + Notifier, на который подписан Overlay.
class _ToastQueue {
  static final _ToastQueue instance = _ToastQueue._();
  _ToastQueue._();

  final ValueNotifier<_ToastMessage?> current = ValueNotifier<_ToastMessage?>(null);
  final List<_ToastMessage> _pending = [];
  bool _showing = false;

  void push(_ToastMessage msg) {
    _pending.add(msg);
    if (!_showing) _next();
  }

  void _next() {
    if (_pending.isEmpty) {
      _showing = false;
      current.value = null;
      return;
    }
    _showing = true;
    final msg = _pending.removeAt(0);
    current.value = msg;
    Future.delayed(msg.duration + const Duration(milliseconds: 400), () {
      if (current.value == msg) {
        current.value = null;
        Future.delayed(const Duration(milliseconds: 200), _next);
      }
    });
  }

  void dismiss() {
    current.value = null;
    Future.delayed(const Duration(milliseconds: 200), _next);
  }
}

/// Перехватывает Overlay и рисует очередь тостов.
class AppToastHost extends StatefulWidget {
  final Widget child;
  const AppToastHost({super.key, required this.child});

  @override
  State<AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends State<AppToastHost> {
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _ToastQueue.instance.current.addListener(_onCurrentChanged);
  }

  @override
  void dispose() {
    _ToastQueue.instance.current.removeListener(_onCurrentChanged);
    _entry?.remove();
    super.dispose();
  }

  void _onCurrentChanged() {
    final msg = _ToastQueue.instance.current.value;
    if (msg == null) {
      _entry?.remove();
      _entry = null;
      return;
    }
    if (_entry == null) {
      _entry = OverlayEntry(builder: (ctx) => _ToastWidget(
        key: ValueKey(msg.hashCode),
        msg: msg,
        onDismiss: _ToastQueue.instance.dismiss,
      ));
      Overlay.of(context, rootOverlay: true).insert(_entry!);
    } else {
      // Обновляем содержимое без пересоздания
      _entry!.markNeedsBuild();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ToastWidget extends StatefulWidget {
  final _ToastMessage msg;
  final VoidCallback onDismiss;
  const _ToastWidget({super.key, required this.msg, required this.onDismiss});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween<double>(begin: -1.0, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  (Color, Color, IconData, String) _styleFor(AppColors colors) {
    switch (widget.msg.type) {
      case AppToastType.success:
        return (colors.surface, colors.success, Icons.check_circle_rounded, 'Успешно');
      case AppToastType.error:
        return (colors.surface, colors.error, Icons.error_rounded, 'Ошибка');
      case AppToastType.warning:
        return (colors.surface, colors.warning, Icons.warning_rounded, 'Внимание');
      case AppToastType.info:
        return (colors.surface, colors.brand, Icons.info_rounded, 'Информация');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, accent, icon, label) = _styleFor(colors);
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide.drive(Tween(begin: Offset(0, -1), end: Offset.zero)),
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.msg.message,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, color: colors.textMuted, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
