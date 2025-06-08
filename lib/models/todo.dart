import 'package:uuid/uuid.dart';

class Todo {
  final String id;
  String title;
  bool isCompleted;
  DateTime createdAt;
  DateTime? completedAt;

  Todo({
    String? id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Todo copyWith({
    String? title,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    )..completedAt = completedAt ?? this.completedAt;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    )..completedAt = json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null;
  }
}
