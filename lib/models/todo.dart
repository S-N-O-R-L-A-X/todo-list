import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

class Todo {
  final String id;
  String title;
  bool isCompleted;
  DateTime createdAt;
  DateTime? completedAt;

  // 定时任务相关字段
  DateTime? scheduledDate; // 计划日期
  TimeOfDay? startTime; // 开始时间
  TimeOfDay? endTime; // 结束时间
  bool needsReminder; // 是否需要提醒
  TodoType type; // 任务类型

  Todo({
    String? id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
    this.scheduledDate,
    this.startTime,
    this.endTime,
    this.needsReminder = false,
    this.type = TodoType.regular,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Todo copyWith({
    String? title,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? scheduledDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? needsReminder,
    TodoType? type,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      needsReminder: needsReminder ?? this.needsReminder,
      type: type ?? this.type,
    )..completedAt = completedAt ?? this.completedAt;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'scheduledDate': scheduledDate?.toIso8601String(),
      'startTime': startTime != null
          ? {'hour': startTime!.hour, 'minute': startTime!.minute}
          : null,
      'endTime': endTime != null
          ? {'hour': endTime!.hour, 'minute': endTime!.minute}
          : null,
      'needsReminder': needsReminder,
      'type': type.toString(),
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'] as String)
          : null,
      startTime: json['startTime'] != null
          ? TimeOfDay(
              hour: json['startTime']['hour'] as int,
              minute: json['startTime']['minute'] as int,
            )
          : null,
      endTime: json['endTime'] != null
          ? TimeOfDay(
              hour: json['endTime']['hour'] as int,
              minute: json['endTime']['minute'] as int,
            )
          : null,
      needsReminder: json['needsReminder'] as bool? ?? false,
      type: TodoType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => TodoType.regular,
      ),
    )..completedAt = json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null;
  }
}

enum TodoType {
  regular, // 普通任务
  scheduled, // 定时任务
  daily, // 每日打卡
  deadline // DDL任务
}
