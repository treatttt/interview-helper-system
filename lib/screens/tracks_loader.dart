import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/question_repository.dart';

/// Общая логика загрузки каталога треков для экранов, которые его показывают
/// (Обзор и Темы). Держит состояние loading/error и сортирует треки по
/// [Track.order]. Экран реализует [repository] и [loadErrorMessage].
mixin TracksLoader<T extends StatefulWidget> on State<T> {
  /// Источник треков. Реализуется экраном (обычно `widget.repository`).
  QuestionRepository get repository;

  /// Сообщение, показываемое при ошибке загрузки. Реализуется экраном.
  String get loadErrorMessage;

  List<Track> tracks = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(loadTracks());
  }

  Future<void> loadTracks() async {
    try {
      final loaded = await repository.loadTracks();
      if (!mounted) return;
      setState(() {
        tracks = loaded.toList()..sort((a, b) => a.order.compareTo(b.order));
        loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        error = loadErrorMessage;
        loading = false;
      });
    }
  }

  /// Сброс ошибки и повторная попытка — для кнопки «Попробовать снова».
  void retryLoad() {
    setState(() {
      error = null;
      loading = true;
    });
    unawaited(loadTracks());
  }
}

/// Единый экран ошибки загрузки с кнопкой повторной попытки.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    required this.title,
    required this.onRetry,
    super.key,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Что-то пошло не так. Попробуй ещё раз.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }
}