import 'package:flutter/material.dart';
import 'package:interview_helper_system/services/reminder_service.dart';
import 'package:interview_helper_system/widgets/wheel_time_picker.dart';

/// Включение напоминаний с обязательным выбором времени.
///
/// Сначала показывает прокручиваемый выбор времени; если пользователь его
/// отменил — напоминания остаются выключенными. Иначе сохраняет время и
/// включает напоминания (с запросом разрешения). При отказе в разрешении
/// показывает подсказку. Используется и на Профиле, и в Настройках, чтобы
/// «включил → выбрал время» работало одинаково в обоих местах.
Future<void> enableRemindersWithPrompt(
  BuildContext context,
  ReminderService service,
) async {
  final picked = await showWheelTimePicker(
    context: context,
    initial: service.time,
  );
  if (picked == null) return; // отмена — остаёмся выключенными

  await service.setTime(picked);
  final ok = await service.setEnabled(true);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Разрешите уведомления, чтобы получать напоминания'),
      ),
    );
  }
}
