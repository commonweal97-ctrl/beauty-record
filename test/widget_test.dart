// test/widget_test.dart
//
// Smoke-тест для Flutter-приложения Б-Запись.
// Проверяет, что приложение запускается без ошибок.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_record/main.dart';

void main() {
  testWidgets('Приложение запускается', (WidgetTester tester) async {
    await tester.pumpWidget(const BeautyRecordApp());
    // Проверяем, что приложение отрисовалось
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
