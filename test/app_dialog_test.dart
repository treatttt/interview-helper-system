import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/widgets/app_dialog.dart';

/// Открывает диалог по нажатию кнопки. Возвращенное значение пишется в [sink].
Future<void> _openDialog(
  WidgetTester tester, {
  String? selected,
  List<AppSelectionOption<String>>? options,
  void Function(String?)? sink,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final picked = await showAppSelectionDialog<String>(
                context: context,
                title: 'Выберите вариант',
                selected: selected,
                options: options ??
                    const [
                      AppSelectionOption(value: 'a', label: 'Первый'),
                      AppSelectionOption(value: 'b', label: 'Второй'),
                      AppSelectionOption(value: 'c', label: 'Третий'),
                    ],
              );
              sink?.call(picked);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('showAppSelectionDialog', () {
    testWidgets('показывает заголовок и все варианты', (tester) async {
      await _openDialog(tester);

      expect(find.text('Выберите вариант'), findsOneWidget);
      expect(find.text('Первый'), findsOneWidget);
      expect(find.text('Второй'), findsOneWidget);
      expect(find.text('Третий'), findsOneWidget);
    });

    testWidgets('тап по варианту закрывает диалог и возвращает его значение',
        (tester) async {
      String? returned;
      var called = false;
      await _openDialog(
        tester,
        sink: (v) {
          returned = v;
          called = true;
        },
      );

      await tester.tap(find.text('Второй'));
      await tester.pumpAndSettle();

      expect(find.text('Выберите вариант'), findsNothing); // закрыт
      expect(called, isTrue);
      expect(returned, 'b');
    });

    testWidgets('выбранный вариант отмечен галочкой', (tester) async {
      await _openDialog(tester, selected: 'b');

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('без выбранного значения галочки нет', (tester) async {
      await _openDialog(tester);

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('иконка варианта отображается, когда задана', (tester) async {
      await _openDialog(
        tester,
        options: const [
          AppSelectionOption(
            value: 'light',
            label: 'Светлая',
            icon: Icons.light_mode_outlined,
          ),
          AppSelectionOption(value: 'dark', label: 'Тёмная'),
        ],
      );

      expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    });
  });
}
