// lib/widgets/toast.dart
// Тонкий wrapper над AppToast — обратная совместимость.
// Используй showToast(context, msg, isError: true/false) как раньше.
import 'package:flutter/material.dart';
import 'app_toast.dart';

void showToast(BuildContext context, String message, {bool isError = false}) {
  AppToast.show(
    context,
    message,
    type: isError ? AppToastType.error : AppToastType.success,
  );
}
