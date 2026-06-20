/// Типизированное состояние незавершённой сессии.
class IncompleteSession {
  const IncompleteSession({
    required this.gradeKey,
    required this.questionIds,
    required this.currentIndex,
    required this.answeredData,
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
      );

  final String gradeKey;
  final List<String> questionIds;
  final int currentIndex;
  final List<AnsweredItemData> answeredData;

  Map<String, Object?> toJson() => {
        'gradeKey': gradeKey,
        'questionIds': questionIds,
        'currentIndex': currentIndex,
        'answeredData': answeredData.map((a) => a.toJson()).toList(),
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
