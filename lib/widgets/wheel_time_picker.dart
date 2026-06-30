import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Прокручиваемый выбор времени «как будильник iPhone»: колёса часов и минут
/// (24-часовой формат) в карточке по центру экрана с кнопками «Отмена» /
/// «Готово». Центрированный диалог — в едином стиле всплывающих окон
/// приложения (см. showAppSelectionDialog).
///
/// Возвращает выбранное [TimeOfDay] или `null`, если окно закрыли без выбора.
Future<TimeOfDay?> showWheelTimePicker({
  required BuildContext context,
  required TimeOfDay initial,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (ctx) => _WheelTimeDialog(initial: initial),
  );
}

class _WheelTimeDialog extends StatefulWidget {
  const _WheelTimeDialog({required this.initial});

  final TimeOfDay initial;

  @override
  State<_WheelTimeDialog> createState() => _WheelTimeDialogState();
}

class _WheelTimeDialogState extends State<_WheelTimeDialog> {
  late TimeOfDay _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Опорная дата нужна только колесу — берём сегодняшнюю с временем initial.
    final now = DateTime.now();
    final initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      widget.initial.hour,
      widget.initial.minute,
    );

    return Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Шапка с действиями.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                  Expanded(
                    child: Text(
                      'Время напоминания',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Готово'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontSize: 21,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: initialDateTime,
                  onDateTimeChanged: (dt) =>
                      _selected = TimeOfDay(hour: dt.hour, minute: dt.minute),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
