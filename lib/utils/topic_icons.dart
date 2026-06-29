import 'package:flutter/material.dart';

/// Подбирает иконку для темы по ключевым словам в её названии.
/// Порядок проверки важен — первое совпадение выигрывает. Дефолт — description.
///
/// Иконки — встроенные Material как временные заглушки; при желании их можно
/// заменить на любой свой набор, не трогая остальной код.
IconData topicIcon(String title) {
  final t = title.toLowerCase();
  bool has(List<String> keys) => keys.any(t.contains);

  if (has(['sql', 'баз', 'данны', 'хранен'])) return Icons.storage;
  if (has(['api', 'интеграц', 'http', 'веб'])) return Icons.api;
  if (has(['архитектур'])) return Icons.apartment;
  if (has(['нотаци', 'моделирован', 'диаграмм', 'схем'])) return Icons.schema;
  if (has(['требован'])) return Icons.description;
  if (has(['процесс', 'agile', 'аджайл', 'управлен'])) {
    return Icons.view_kanban;
  }
  if (has(['продукт'])) return Icons.inventory_2;
  if (has(['ооп', 'объект'])) return Icons.data_object;
  if (has(['алгоритм', 'структур'])) return Icons.account_tree;
  if (has(['инструмент', 'практик'])) return Icons.build;
  if (has(['баг', 'репорт'])) return Icons.bug_report;
  if (has(['дизайн'])) return Icons.space_dashboard;
  if (has(['документац'])) return Icons.article;
  if (has(['вид', 'категори'])) return Icons.category;
  if (has(['тестир', 'провер', 'qa'])) return Icons.fact_check;
  return Icons.description;
}
