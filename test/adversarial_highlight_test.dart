import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/utils/option_highlight.dart';

void main() {
  // ─── Инварианты как математические свойства ─────────────────────────────────
  // Тесты проверяют NOT «функция возвращает X» а «функция никогда не нарушает P».

  group('resolveOptionHighlight — инварианты', () {
    // Перебираем все 8 комбинаций входных флагов
    final allCombinations = [
      for (final c in [true, false])
        for (final p in [true, false])
          for (final m in [true, false])
            (isCorrect: c, isPicked: p, isMultiChoice: m),
    ];

    test('если вариант верный — результат никогда не wrong', () {
      for (final combo in allCombinations.where((c) => c.isCorrect)) {
        final result = resolveOptionHighlight(
          isCorrect: combo.isCorrect,
          isPicked: combo.isPicked,
          isMultiChoice: combo.isMultiChoice,
        );
        expect(result, isNot(OptionHighlight.wrong),
            reason: 'isCorrect=T, isPicked=${combo.isPicked}, isMulti=${combo.isMultiChoice}');
      }
    });

    test('если вариант неверный — результат никогда не correct и не missed', () {
      for (final combo in allCombinations.where((c) => !c.isCorrect)) {
        final result = resolveOptionHighlight(
          isCorrect: combo.isCorrect,
          isPicked: combo.isPicked,
          isMultiChoice: combo.isMultiChoice,
        );
        expect(result, isNot(OptionHighlight.correct),
            reason: 'isCorrect=F, isPicked=${combo.isPicked}, isMulti=${combo.isMultiChoice}');
        expect(result, isNot(OptionHighlight.missed),
            reason: 'isCorrect=F, isPicked=${combo.isPicked}, isMulti=${combo.isMultiChoice}');
      }
    });

    test('missed возникает только при isMultiChoice=true', () {
      for (final combo in allCombinations.where((c) => !c.isMultiChoice)) {
        final result = resolveOptionHighlight(
          isCorrect: combo.isCorrect,
          isPicked: combo.isPicked,
          isMultiChoice: combo.isMultiChoice,
        );
        expect(result, isNot(OptionHighlight.missed),
            reason: 'single-choice не должен давать missed');
      }
    });

    test('если не выбрано и неверно — всегда neutral при любом isMultiChoice', () {
      for (final isMulti in [true, false]) {
        final result = resolveOptionHighlight(
          isCorrect: false,
          isPicked: false,
          isMultiChoice: isMulti,
        );
        expect(result, OptionHighlight.neutral,
            reason: 'isMulti=$isMulti');
      }
    });

    test('если выбрано и неверно — всегда wrong при любом isMultiChoice', () {
      for (final isMulti in [true, false]) {
        final result = resolveOptionHighlight(
          isCorrect: false,
          isPicked: true,
          isMultiChoice: isMulti,
        );
        expect(result, OptionHighlight.wrong,
            reason: 'isMulti=$isMulti');
      }
    });

    test('если верно и выбрано — всегда correct при любом isMultiChoice', () {
      for (final isMulti in [true, false]) {
        final result = resolveOptionHighlight(
          isCorrect: true,
          isPicked: true,
          isMultiChoice: isMulti,
        );
        expect(result, OptionHighlight.correct,
            reason: 'isMulti=$isMulti');
      }
    });

    test('результат детерминирован — одинаковые входы дают одинаковый выход', () {
      for (final combo in allCombinations) {
        final r1 = resolveOptionHighlight(
          isCorrect: combo.isCorrect,
          isPicked: combo.isPicked,
          isMultiChoice: combo.isMultiChoice,
        );
        final r2 = resolveOptionHighlight(
          isCorrect: combo.isCorrect,
          isPicked: combo.isPicked,
          isMultiChoice: combo.isMultiChoice,
        );
        expect(r1, r2);
      }
    });
  });

  // ─── Монотонность (смена одного флага) ─────────────────────────────────────
  group('resolveOptionHighlight — чувствительность к изменению флагов', () {
    test('переключение isMultiChoice меняет результат только для correct+!picked', () {
      // correct+picked: оба варианта → correct, флаг не важен
      expect(
        resolveOptionHighlight(isCorrect: true, isPicked: true, isMultiChoice: false),
        resolveOptionHighlight(isCorrect: true, isPicked: true, isMultiChoice: true),
      );

      // correct+!picked: single → correct, multi → missed
      expect(
        resolveOptionHighlight(isCorrect: true, isPicked: false, isMultiChoice: false),
        isNot(resolveOptionHighlight(isCorrect: true, isPicked: false, isMultiChoice: true)),
      );

      // !correct+picked: оба → wrong
      expect(
        resolveOptionHighlight(isCorrect: false, isPicked: true, isMultiChoice: false),
        resolveOptionHighlight(isCorrect: false, isPicked: true, isMultiChoice: true),
      );

      // !correct+!picked: оба → neutral
      expect(
        resolveOptionHighlight(isCorrect: false, isPicked: false, isMultiChoice: false),
        resolveOptionHighlight(isCorrect: false, isPicked: false, isMultiChoice: true),
      );
    });

    test('переключение isCorrect при picked=true меняет correct↔wrong', () {
      for (final isMulti in [true, false]) {
        final whenCorrect = resolveOptionHighlight(
            isCorrect: true, isPicked: true, isMultiChoice: isMulti);
        final whenWrong = resolveOptionHighlight(
            isCorrect: false, isPicked: true, isMultiChoice: isMulti);
        expect(whenCorrect, OptionHighlight.correct);
        expect(whenWrong, OptionHighlight.wrong);
        expect(whenCorrect, isNot(whenWrong));
      }
    });

    test('переключение isPicked при !correct+multi меняет wrong↔neutral', () {
      expect(
        resolveOptionHighlight(isCorrect: false, isPicked: true, isMultiChoice: true),
        OptionHighlight.wrong,
      );
      expect(
        resolveOptionHighlight(isCorrect: false, isPicked: false, isMultiChoice: true),
        OptionHighlight.neutral,
      );
    });
  });
}
