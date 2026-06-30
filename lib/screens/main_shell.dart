import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/dev/feedback_flag.dart';
import 'package:interview_helper_system/dev/feedback_route_observer.dart';
import 'package:interview_helper_system/screens/home_screen.dart';
import 'package:interview_helper_system/screens/practice_screen.dart';
import 'package:interview_helper_system/screens/profile_screen.dart';
import 'package:interview_helper_system/screens/progress_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/services/reminder_service.dart';
import 'package:interview_helper_system/services/theme_service.dart';

/// Корневой экран после онбординга: NavigationBar (Material 3) + IndexedStack.
///
/// Вкладки: Главная / Практика / Прогресс / Профиль.
/// IndexedStack сохраняет состояние всех вкладок между переключениями.
/// Переходы в сессию/результат/разбор открываются через Navigator.push
/// поверх этого экрана — таб-бар при этом скрывается.
class MainShell extends StatefulWidget {
  const MainShell({
    required this.repository,
    required this.progress,
    required this.themeService,
    required this.reminderService,
    super.key,
  });

  final QuestionRepository repository;
  final ProgressService progress;
  final ThemeService themeService;
  final ReminderService reminderService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// Подписи вкладок — порядок совпадает с детьми IndexedStack и items нав-бара.
  static const _tabLabels = ['Главная', 'Практика', 'Прогресс', 'Профиль'];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (kFeedbackEnabled) feedbackRouteObserver.updateTab(_tabLabels[0]);
  }

  void _selectTab(int i) {
    setState(() => _selectedIndex = i);
    if (kFeedbackEnabled) feedbackRouteObserver.updateTab(_tabLabels[i]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            repository: widget.repository,
            progress: widget.progress,
          ),
          PracticeScreen(
            repository: widget.repository,
            progress: widget.progress,
          ),
          ProgressScreen(
            repository: widget.repository,
            progress: widget.progress,
          ),
          ProfileScreen(
            progress: widget.progress,
            themeService: widget.themeService,
            reminderService: widget.reminderService,
            repository: widget.repository,
          ),
        ],
      ),
      bottomNavigationBar: PillBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: _selectTab,
        items: const [
          PillNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Главная',
          ),
          PillNavItem(
            icon: Icons.track_changes,
            selectedIcon: Icons.track_changes,
            label: 'Практика',
          ),
          PillNavItem(
            icon: Icons.bar_chart_outlined,
            selectedIcon: Icons.bar_chart,
            label: 'Прогресс',
          ),
          PillNavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

/// Один пункт нижней навигации.
class PillNavItem {
  const PillNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Плавающая навигация-«пилюля» (овальный бар) в стиле Telegram: каждый пункт
/// при нажатии даёт упругий «отклик» (scale-bounce), активный подсвечивается
/// брендовым цветом и капсулой-подложкой.
class PillBottomNav extends StatelessWidget {
  const PillBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<PillNavItem> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _PillNavButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillNavButton extends StatefulWidget {
  const _PillNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PillNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PillNavButton> createState() => _PillNavButtonState();
}

class _PillNavButtonState extends State<_PillNavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  // Упругий «отскок»: 0.85 → перелёт чуть выше 1.0 → 1.0.
  late final Animation<double> _scale = Tween<double>(
    begin: 0.85,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
    unawaited(_controller.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.selected ? cs.primary : cs.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Капсула-подложка — только «вспышка» при нажатии: ярче всего
              // в начале анимации и плавно гаснет к её концу. В покое
              // (_controller.value == 1) полностью прозрачна.
              final highlight = cs.primary.withValues(
                alpha: 0.12 * (1 - _controller.value),
              );
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: highlight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.selected ? widget.item.selectedIcon : widget.item.icon,
                  size: 22,
                  color: color,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
