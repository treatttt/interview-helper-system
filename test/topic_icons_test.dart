import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/utils/topic_icons.dart';

void main() {
  group('topicIcon — подбор иконки по ключевым словам', () {
    test('базы данных / SQL → storage', () {
      expect(topicIcon('SQL и базы данных'), Icons.storage);
      expect(topicIcon('Хранение данных'), Icons.storage);
    });

    test('API / интеграции → api', () {
      expect(topicIcon('REST API'), Icons.api);
      expect(topicIcon('Веб-интеграции'), Icons.api);
    });

    test('архитектура → apartment', () {
      expect(topicIcon('Архитектура систем'), Icons.apartment);
    });

    test('моделирование / нотации / диаграммы → schema', () {
      expect(topicIcon('UML нотация'), Icons.schema);
      expect(topicIcon('Моделирование процессов'), Icons.schema);
    });

    test('ООП / объекты → data_object', () {
      expect(topicIcon('ООП'), Icons.data_object);
    });

    test('тестирование / QA → fact_check', () {
      expect(topicIcon('Тестирование'), Icons.fact_check);
      expect(topicIcon('QA практики'), Icons.build); // «практик» матчится раньше
    });

    test('баг-репорт → bug_report', () {
      expect(topicIcon('Баг-репорты'), Icons.bug_report);
    });

    test('регистр не важен (toLowerCase)', () {
      expect(topicIcon('sql'), Icons.storage);
      expect(topicIcon('АрХиТеКтУрА'), Icons.apartment);
    });

    test('первое совпадение выигрывает: «SQL API» → storage (SQL раньше API)', () {
      expect(topicIcon('SQL для API'), Icons.storage);
    });

    test('нет совпадений → дефолт description', () {
      expect(topicIcon('Нечто непонятное'), Icons.description);
      expect(topicIcon(''), Icons.description);
    });
  });
}
