import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/utils/option_highlight.dart';

void main() {
  group('resolveOptionHighlight — одиночный выбор', () {
    test('верный, выбранный → correct (зелёный)', () {
      expect(
        resolveOptionHighlight(isCorrect: true, isPicked: true, isMultiChoice: false),
        OptionHighlight.correct,
      );
    });

    test('верный, НЕ выбранный → correct (показываем правильный ответ зелёным)', () {
      // Для одиночного выбора мы всегда подсвечиваем правильный вариант зелёным,
      // чтобы пользователь видел ответ даже если выбрал другой.
      expect(
        resolveOptionHighlight(isCorrect: true, isPicked: false, isMultiChoice: false),
        OptionHighlight.correct,
      );
    });

    test('неверный, выбранный → wrong (красный)', () {
      expect(
        resolveOptionHighlight(isCorrect: false, isPicked: true, isMultiChoice: false),
        OptionHighlight.wrong,
      );
    });

    test('неверный, НЕ выбранный → neutral', () {
      expect(
        resolveOptionHighlight(isCorrect: false, isPicked: false, isMultiChoice: false),
        OptionHighlight.neutral,
      );
    });
  });

  group('resolveOptionHighlight — мультивыбор', () {
    test('верный, выбранный → correct (зелёный)', () {
      expect(
        resolveOptionHighlight(isCorrect: true, isPicked: true, isMultiChoice: true),
        OptionHighlight.correct,
      );
    });

    test('верный, НЕ выбранный → missed (жёлтый — пропущен)', () {
      expect(
        resolveOptionHighlight(isCorrect: true, isPicked: false, isMultiChoice: true),
        OptionHighlight.missed,
      );
    });

    test('неверный, выбранный → wrong (красный)', () {
      expect(
        resolveOptionHighlight(isCorrect: false, isPicked: true, isMultiChoice: true),
        OptionHighlight.wrong,
      );
    });

    test('неверный, НЕ выбранный → neutral', () {
      expect(
        resolveOptionHighlight(isCorrect: false, isPicked: false, isMultiChoice: true),
        OptionHighlight.neutral,
      );
    });
  });

  group('resolveOptionHighlight — граничные случаи', () {
    test('correct имеет приоритет над picked при одиночном выборе', () {
      // Верный И выбранный — однозначно correct, не wrong
      final result = resolveOptionHighlight(isCorrect: true, isPicked: true, isMultiChoice: false);
      expect(result, OptionHighlight.correct);
      expect(result, isNot(OptionHighlight.wrong));
    });

    test('correct имеет приоритет над picked при мультивыборе', () {
      final result = resolveOptionHighlight(isCorrect: true, isPicked: true, isMultiChoice: true);
      expect(result, OptionHighlight.correct);
      expect(result, isNot(OptionHighlight.wrong));
    });

    test('одиночный выбор никогда не даёт missed', () {
      // missed зарезервирован только для мультивыбора
      expect(
        resolveOptionHighlight(isCorrect: true, isPicked: false, isMultiChoice: false),
        isNot(OptionHighlight.missed),
      );
    });
  });
}
