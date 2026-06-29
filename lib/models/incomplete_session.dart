import 'package:interview_helper_system/services/progress_service.dart' show ProgressService;

/// Типизированное состояние незавершённой сессии.
///
/// Один и тот же тип обслуживает два независимых слота в [ProgressService]:
///   • грейдовый слот — полногрейдовая сессия ([topicTitle] == null), ключ gradeKey;
///   • тема-слот — пауза тема-дрилла ([topicTitle] != null), ключ — название темы.
class IncompleteSession {
  const IncompleteSession({
    required this.gradeKey,
    required this.questionIds,
    required this.currentIndex,
    required this.answeredData,
    this.topicTitle,
  });

  factory IncompleteSession.fromJson(Map<String, Object?> json) =>
      IncompleteSession(
        gradeKey: json['gradeKey']! as String,
        questionIds: (json['questionIds']! as List).cast<String>(),
        currentIndex: json['currentIndex']! as int,
        answeredData: (json['answeredData']! as List)
            .map(
              (e) => AnsweredItemData.fromJson(
            (e as Map).cast<String, Object?>(),
          ),
        )
            .toList(),
        topicTitle: json['topicTitle'] as String?,
      );

  final String gradeKey;
  final List<String> questionIds;
  final int currentIndex;
  final List<AnsweredItemData> answeredData;

  /// Тема, если это пауза тема-дрилла; null — для полногрейдовой сессии.
  /// В JSON ключ пишется только когда задан, чтобы грейдовая запись осталась
  /// байт-в-байт совместимой со старым форматом хранилища.
  final String? topicTitle;

  Map<String, Object?> toJson() => {
    'gradeKey': gradeKey,
    'questionIds': questionIds,
    'currentIndex': currentIndex,
    'answeredData': answeredData.map((a) => a.toJson()).toList(),
    if (topicTitle != null) 'topicTitle': topicTitle,
  };
}

/// Сериализованный одиночный ответ внутри незавершённой сессии.
class AnsweredItemData {
  const AnsweredItemData({
    required this.id,
    required this.selected,
    required this.outcome,
  });

  factory AnsweredItemData.fromJson(Map<String, Object?> json) =>
      AnsweredItemData(
        id: json['id']! as String,
        selected: (json['selected']! as List).cast<int>(),
        outcome: json['outcome']! as String,
      );

  final String id;
  final List<int> selected;
  final String outcome;

  Map<String, Object?> toJson() => {
    'id': id,
    'selected': selected,
    'outcome': outcome,
  };
}
