import 'package:flutter/material.dart';

/// Онбординг: разовый свайп-тур из трёх карточек.
///
/// Это чистый UI-виджет. Он НЕ трогает хранилище, навигацию и роль - всё это
/// делает родитель через [onFinish], который вызывается и кнопкой «Начать
/// первую сессию», и «Пропустить» (оба ведут в одно место). Родителю нужно:
///   1) проставить флаг «онбординг пройден»;
///   2) при единственной роли молча выбрать дефолт (системный аналитик);
///   3) перейти к первой сессии.
///
/// Когда ролей станет ≥2 — здесь добавится третья карточка-развилка с выбором
/// области; сейчас она сознательно не строится (UI под контент, которого нет).
///
/// Финальная карточка — ввод имени (фамилия опциональна). Имя передаётся в
/// [onFinish]; сохраняет его родитель — экран хранилище не трогает.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onFinish, super.key});

  /// Вызывается при завершении тура (кнопка финала) и при пропуске. Передаёт
  /// введённое имя и опциональную фамилию (пустые — если пользователь пропустил).
  final void Function(String firstName, String? lastName) onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // --- Дизайн-токены: одна точка правды для ритма и размеров. ---
  static const _pagePadding = EdgeInsets.symmetric(horizontal: 28);
  static const _gapIconToTitle = 36.0;
  static const _gapTitleToSubtitle = 14.0;
  static const _medallionSize = 132.0;
  static const _iconSize = 56.0;
  static const _ctaMinHeight = 54.0;
  static const _entranceDuration = Duration(milliseconds: 620);

  late final PageController _pageController;
  late final AnimationController _entrance;
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  int _index = 0;

  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: Icons.bolt_outlined,
      title: 'Тренируйся короткими сессиями',
      subtitle: 'Несколько вопросов за заход. Помещается в кофе-брейк.',
    ),
    _OnboardingPageData(
      icon: Icons.lightbulb_outline,
      title: 'Разбор после каждого ответа',
      subtitle: 'Не просто верно или нет — видишь, почему именно так.',
    ),
    _OnboardingPageData(
      icon: Icons.local_fire_department_outlined,
      title: 'Возвращайся — серия растёт',
      subtitle: 'Каждая сессия копит XP и продлевает streak.',
    ),
  ];

  /// Всего страниц: информационные карточки + финальная карточка ввода имени.
  int get _pageCount => _pages.length + 1;

  /// Последняя страница — ввод имени (индекс равен числу инфо-карточек).
  bool get _isLast => _index == _pages.length;

  /// Завершить онбординг с текущим введённым именем.
  void _finish() =>
      widget.onFinish(_firstNameCtrl.text, _lastNameCtrl.text);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _entrance = AnimationController(vsync: this, duration: _entranceDuration)
      ..forward();
    // Обновляем доступность финального CTA по мере ввода имени.
    _firstNameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entrance.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Reduced-motion: если анимации в системе выключены — показываем контент
    // сразу, без entrance-движения.
    if (MediaQuery.of(context).disableAnimations && _entrance.value != 1.0) {
      _entrance.value = 1.0;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя зона: «Пропустить» виден на всех карточках.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: colors.onSurfaceVariant,
                  ),
                  child: const Text('Пропустить'),
                ),
              ),
            ),

            // Лента карточек.
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pageCount,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  if (i >= _pages.length) {
                    return _NamePage(
                      padding: _pagePadding,
                      firstNameController: _firstNameCtrl,
                      lastNameController: _lastNameCtrl,
                    );
                  }
                  return _OnboardingPage(
                    data: _pages[i],
                    entrance: _entrance,
                    padding: _pagePadding,
                    gapIconToTitle: _gapIconToTitle,
                    gapTitleToSubtitle: _gapTitleToSubtitle,
                    medallionSize: _medallionSize,
                    iconSize: _iconSize,
                  );
                },
              ),
            ),

            // Индикатор страниц.
            _PageIndicator(count: _pageCount, index: _index),
            const SizedBox(height: 28),

            // Нижнее действие: «Далее» на 1–2, финальный CTA на 3-й.
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // На карточке имени CTA активен только при непустом имени.
                  onPressed:
                      _isLast && _firstNameCtrl.text.trim().isEmpty ? null : _next,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(_ctaMinHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  child: Text(_isLast ? 'Начать' : 'Далее'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Содержимое одной карточки: медальон с иконкой → заголовок → подпись,
/// со ступенчатым появлением (icon → title → subtitle), завязанным на общий
/// entrance-контроллер первого показа.
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.entrance,
    required this.padding,
    required this.gapIconToTitle,
    required this.gapTitleToSubtitle,
    required this.medallionSize,
    required this.iconSize,
  });

  final _OnboardingPageData data;
  final Animation<double> entrance;
  final EdgeInsets padding;
  final double gapIconToTitle;
  final double gapTitleToSubtitle;
  final double medallionSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Медальон-якорь: мягкая подложка из акцента + контурная иконка.
            _Staggered(
              entrance: entrance,
              begin: 0,
              end: 0.55,
              child: ExcludeSemantics(
                child: Container(
                  width: medallionSize,
                  height: medallionSize,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    data.icon,
                    size: iconSize,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            SizedBox(height: gapIconToTitle),

            // Заголовок: крупный, с собственной типографикой иерархии.
            _Staggered(
              entrance: entrance,
              begin: 0.2,
              end: 0.75,
              child: Text(
                data.title,
                textAlign: TextAlign.center,
                softWrap: true,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            SizedBox(height: gapTitleToSubtitle),

            // Подпись: спокойнее по тону и весу.
            _Staggered(
              entrance: entrance,
              begin: 0.38,
              end: 0.95,
              child: Text(
                data.subtitle,
                textAlign: TextAlign.center,
                softWrap: true,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ступенчатое появление: fade + лёгкий подъём, на интервале [begin, end]
/// общего entrance-контроллера.
class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.entrance,
    required this.begin,
    required this.end,
    required this.child,
  });

  final Animation<double> entrance;
  final double begin;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: entrance,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - curved.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Индикатор страниц: активная точка вытянута в «пилюлю».
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Страница ${index + 1} из $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: active ? 22 : 8,
            decoration: BoxDecoration(
              color: active
                  ? colors.primary
                  : colors.onSurfaceVariant.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

/// Финальная карточка: ввод имени. Имя обязательно (иначе CTA заблокирован),
/// фамилия — нет. Хранилище не трогает: значения уходят в onFinish родителя.
class _NamePage extends StatelessWidget {
  const _NamePage({
    required this.padding,
    required this.firstNameController,
    required this.lastNameController,
  });

  final EdgeInsets padding;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_emotions_outlined,
                size: 56,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'Как тебя зовут?',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Достаточно имени — фамилию можно не указывать.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: firstNameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: lastNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Фамилия (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
