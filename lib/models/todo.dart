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

  // 每日打卡相关字段
  List<bool> weekdays; // 周几需要打卡 [周日,周一,周二,周三,周四,周五,周六]
  TimeOfDay? checkInTime; // 打卡提醒时间
  int streakCount; // 连续打卡天数
  DateTime? lastCheckIn; // 最后打卡时间

  Todo({
    String? id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
    this.scheduledDate,
    this.startTime,
    this.endTime,
    this.needsReminder = false,
    this.type = TodoType.scheduled,
    List<bool>? weekdays,
    this.checkInTime,
    this.streakCount = 0,
    this.lastCheckIn,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        weekdays = weekdays ?? List.filled(7, true); // 默认每天都需要打卡

  Todo copyWith({
    String? title,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? scheduledDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? needsReminder,
    TodoType? type,
    List<bool>? weekdays,
    TimeOfDay? checkInTime,
    int? streakCount,
    DateTime? lastCheckIn,
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
      weekdays: weekdays ?? List.from(this.weekdays),
      checkInTime: checkInTime ?? this.checkInTime,
      streakCount: streakCount ?? this.streakCount,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
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
      'weekdays': weekdays,
      'checkInTime': checkInTime != null
          ? {'hour': checkInTime!.hour, 'minute': checkInTime!.minute}
          : null,
      'streakCount': streakCount,
      'lastCheckIn': lastCheckIn?.toIso8601String(),
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
        orElse: () => TodoType.scheduled,
      ),
      weekdays: (json['weekdays'] as List<dynamic>?)?.cast<bool>() ??
          List.filled(7, true),
      checkInTime: json['checkInTime'] != null
          ? TimeOfDay(
              hour: json['checkInTime']['hour'] as int,
              minute: json['checkInTime']['minute'] as int,
            )
          : null,
      streakCount: json['streakCount'] as int? ?? 0,
      lastCheckIn: json['lastCheckIn'] != null
          ? DateTime.parse(json['lastCheckIn'] as String)
          : null,
    )..completedAt = json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null;
  }

  // 检查今天是否需要打卡
  bool needsCheckInToday() {
    if (type != TodoType.daily) return false;
    final today = DateTime.now().weekday % 7; // 转换为0-6，与weekdays数组对应
    return weekdays[today];
  }

  // 检查是否可以打卡（在指定时间前后1小时内都可以打卡）
  bool canCheckIn() {
    if (type != TodoType.daily || !needsCheckInToday() || checkInTime == null) {
      return false;
    }

    final now = DateTime.now();
    final checkInDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      checkInTime!.hour,
      checkInTime!.minute,
    );

    final difference = now.difference(checkInDateTime).inHours.abs();
    return difference <= 1; // 打卡时间前后1小时内都可以打卡
  }

  // 执行打卡
  bool checkIn() {
    if (!canCheckIn()) return false;

    final now = DateTime.now();

    // 检查是否已经打过卡了
    if (lastCheckIn != null &&
        lastCheckIn!.year == now.year &&
        lastCheckIn!.month == now.month &&
        lastCheckIn!.day == now.day) {
      return false;
    }

    // 检查是否保持连续
    if (lastCheckIn != null) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      if (lastCheckIn!.year == yesterday.year &&
          lastCheckIn!.month == yesterday.month &&
          lastCheckIn!.day == yesterday.day) {
        streakCount++; // 连续打卡
      } else {
        streakCount = 1; // 重新开始计数
      }
    } else {
      streakCount = 1; // 第一次打卡
    }

    lastCheckIn = now;
    return true;
  }
}

enum TodoType {
  scheduled, // 定时任务
  daily, // 每日打卡
  deadline // DDL任务
}
