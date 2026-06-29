import 'package:flutter/material.dart';

/// Один вариант выбора во всплывающем окне [showAppSelectionDialog].
class AppSelectionOption<T> {
  const AppSelectionOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Единый стиль всплывающих окон приложения: карточка по центру экрана
/// со скруглёнными углами. Используется для выбора темы, направления и
/// последующих диалогов выбора.
///
/// Возвращает выбранное значение или `null`, если окно закрыли без выбора.
Future<T?> showAppSelectionDialog<T>({
  required BuildContext context,
  required String title,
  required List<AppSelectionOption<T>> options,
  T? selected,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => AppSelectionDialog<T>(
      title: title,
      options: options,
      selected: selected,
    ),
  );
}

/// Содержимое всплывающего окна выбора. Вынесено отдельно, чтобы его можно
/// было использовать в тестах и переиспользовать с произвольным контентом.
class AppSelectionDialog<T> extends StatelessWidget {
  const AppSelectionDialog({
    required this.title,
    required this.options,
    this.selected,
    super.key,
  });

  final String title;
  final List<AppSelectionOption<T>> options;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: cs.onSurface,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 10),
                children: [
                  for (final option in options)
                    _OptionRow<T>(
                      option: option,
                      selected: option.value == selected,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({required this.option, required this.selected});

  final AppSelectionOption<T> option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Navigator.of(context).pop(option.value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 20,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? cs.primary : cs.onSurface,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
