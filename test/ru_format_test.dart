import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/utils/ru_format.dart';

void main() {
  group('formatRuTime — 24-часовой формат СНГ', () {
    test('вечернее время с нулевыми минутами', () {
      expect(formatRuTime(const TimeOfDay(hour: 19, minute: 0)), '19:00');
    });
    test('ведущие нули в часах и минутах', () {
      expect(formatRuTime(const TimeOfDay(hour: 7, minute: 5)), '07:05');
    });
    test('полночь и около полудня', () {
      expect(formatRuTime(const TimeOfDay(hour: 0, minute: 0)), '00:00');
      expect(formatRuTime(const TimeOfDay(hour: 13, minute: 30)), '13:30');
    });
  });

  group('formatRuDateHeader — «ДЕНЬ, N МЕСЯЦ» заглавными', () {
    test('понедельник, январь (родительный падеж)', () {
      // 2024-01-01 — понедельник.
      expect(formatRuDateHeader(DateTime(2024)), 'ПОНЕДЕЛЬНИК, 1 ЯНВАРЯ');
    });

    test('воскресенье — 7-й день недели', () {
      // 2024-01-07 — воскресенье.
      expect(formatRuDateHeader(DateTime(2024, 1, 7)), 'ВОСКРЕСЕНЬЕ, 7 ЯНВАРЯ');
    });

    test('декабрь склоняется как «ДЕКАБРЯ»', () {
      // 2024-12-31 — вторник.
      expect(formatRuDateHeader(DateTime(2024, 12, 31)), 'ВТОРНИК, 31 ДЕКАБРЯ');
    });
  });

  group('pluralQuestions — склонение «вопрос»', () {
    test('1 → вопрос (one)', () => expect(pluralQuestions(1), 'вопрос'));
    test('2–4 → вопроса (few)', () {
      expect(pluralQuestions(2), 'вопроса');
      expect(pluralQuestions(4), 'вопроса');
    });
    test('5, 0 → вопросов (many)', () {
      expect(pluralQuestions(5), 'вопросов');
      expect(pluralQuestions(0), 'вопросов');
    });
    test('11–14 → вопросов (исключение из «один/два»)', () {
      expect(pluralQuestions(11), 'вопросов');
      expect(pluralQuestions(12), 'вопросов');
      expect(pluralQuestions(14), 'вопросов');
    });
    test('21 → вопрос, 22 → вопроса (по последней цифре)', () {
      expect(pluralQuestions(21), 'вопрос');
      expect(pluralQuestions(22), 'вопроса');
    });
    test('111 → вопросов, 101 → вопрос (сотни не мешают)', () {
      expect(pluralQuestions(111), 'вопросов');
      expect(pluralQuestions(101), 'вопрос');
    });
  });

  group('pluralTopics — склонение «тема»', () {
    test('1 → тема', () => expect(pluralTopics(1), 'тема'));
    test('3 → темы', () => expect(pluralTopics(3), 'темы'));
    test('5 → тем', () => expect(pluralTopics(5), 'тем'));
    test('12 → тем (исключение)', () => expect(pluralTopics(12), 'тем'));
    test('21 → тема', () => expect(pluralTopics(21), 'тема'));
  });
}
