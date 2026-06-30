/// Локализованное форматирование на русском без зависимости от пакета intl.
/// Достаточно для статичных подписей UI (шапка Главной, счётчики вопросов).
library;

import 'package:flutter/material.dart' show TimeOfDay;

/// Время в формате СНГ (24 часа, с ведущим нулём): «19:00», «07:05».
///
/// Замена `TimeOfDay.format(context)`, которая без сконфигурированной локали
/// `ru` рендерит «7:00 PM». Час берём из [TimeOfDay.hour] (0–23) напрямую.
String formatRuTime(TimeOfDay time) {
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

const _weekdaysUpper = <String>[
  'ПОНЕДЕЛЬНИК',
  'ВТОРНИК',
  'СРЕДА',
  'ЧЕТВЕРГ',
  'ПЯТНИЦА',
  'СУББОТА',
  'ВОСКРЕСЕНЬЕ',
];

/// Месяцы в родительном падеже («30 июня») — заглавными для шапки.
const _monthsGenitiveUpper = <String>[
  'ЯНВАРЯ',
  'ФЕВРАЛЯ',
  'МАРТА',
  'АПРЕЛЯ',
  'МАЯ',
  'ИЮНЯ',
  'ИЮЛЯ',
  'АВГУСТА',
  'СЕНТЯБРЯ',
  'ОКТЯБРЯ',
  'НОЯБРЯ',
  'ДЕКАБРЯ',
];

/// Заголовок-дата для шапки Главной: «ПОНЕДЕЛЬНИК, 30 ИЮНЯ».
String formatRuDateHeader(DateTime date) {
  final weekday = _weekdaysUpper[date.weekday - 1];
  final month = _monthsGenitiveUpper[date.month - 1];
  return '$weekday, ${date.day} $month';
}

/// Выбор формы слова по числу [n] (русские правила склонения):
/// [one] — 1, [few] — 2–4, [many] — 0/5+ и 11–14.
String _plural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

/// Правильная форма слова «вопрос» для числа [n]:
/// 1 вопрос, 2 вопроса, 5 вопросов.
String pluralQuestions(int n) => _plural(n, 'вопрос', 'вопроса', 'вопросов');

/// Правильная форма слова «тема» для числа [n]:
/// 1 тема, 2 темы, 5 тем.
String pluralTopics(int n) => _plural(n, 'тема', 'темы', 'тем');
