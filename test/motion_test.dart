import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/utils/motion.dart';

void main() {
  const base = Duration(milliseconds: 220);

  Future<Duration> resolve(WidgetTester tester, {required bool reduce}) async {
    late Duration result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Builder(
          builder: (context) {
            result = motionDuration(context, base);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('motionDuration: при disableAnimations переход мгновенный',
      (tester) async {
    expect(await resolve(tester, reduce: true), Duration.zero);
  },);

  testWidgets('motionDuration: без reduce-motion отдаёт базовую длительность',
      (tester) async {
    expect(await resolve(tester, reduce: false), base);
  },);

  testWidgets('motionDuration: нет MediaQuery → база (не падает)',
      (tester) async {
    late Duration result;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          result = motionDuration(context, base);
          return const SizedBox();
        },
      ),
    );
    expect(result, base);
  },);
}
