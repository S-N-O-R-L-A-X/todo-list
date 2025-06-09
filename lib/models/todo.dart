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

  // DDL任务相关字段
  DateTime? deadline; // 截止日期
  Duration? reminderBefore; // 提前多久提醒（如提前1天、2小时等）

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
    this.deadline,
    this.reminderBefore,
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
    DateTime? deadline,
    Duration? reminderBefore,
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
      weekdays: weekdays ?? this.weekdays,
      checkInTime: checkInTime ?? this.checkInTime,
      streakCount: streakCount ?? this.streakCount,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      deadline: deadline ?? this.deadline,
      reminderBefore: reminderBefore ?? this.reminderBefore,
    );
  }

  bool checkIn() {
    if (type != TodoType.daily) return false;

    final now = DateTime.now();
    if (!weekdays[now.weekday % 7]) return false;

    if (lastCheckIn?.day == now.day) return false;

    if (checkInTime != null) {
      final checkInDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        checkInTime!.hour,
        checkInTime!.minute,
      );
      if (now.isBefore(checkInDateTime)) return false;
    }

    if (lastCheckIn != null) {
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      if (lastCheckIn!.day == yesterday.day) {
        streakCount++;
      } else {
        streakCount = 1;
      }
    } else {
      streakCount = 1;
    }

    lastCheckIn = now;
    return true;
  }

  bool needsCheckInToday() {
    if (type != TodoType.daily) return false;
    final now = DateTime.now();
    return weekdays[now.weekday % 7] && lastCheckIn?.day != now.day;
  }

  String getRemainingTime() {
    if (type != TodoType.deadline || deadline == null) return '';

    final now = DateTime.now();
    final difference = deadline!.difference(now);

    if (difference.isNegative) {
      return '已超期';
    }

    if (difference.inDays > 0) {
      return '剩余 ${difference.inDays} 天';
    } else if (difference.inHours > 0) {
      return '剩余 ${difference.inHours} 小时';
    } else if (difference.inMinutes > 0) {
      return '剩余 ${difference.inMinutes} 分钟';
    } else {
      return '即将到期';
    }
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
      'deadline': deadline?.toIso8601String(),
      'reminderBefore': reminderBefore?.inMinutes,
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
      needsReminder: json['needsReminder'] as bool,
      type: TodoType.values.firstWhere(
        (type) => type.toString() == json['type'],
      ),
      weekdays: (json['weekdays'] as List<dynamic>).cast<bool>(),
      checkInTime: json['checkInTime'] != null
          ? TimeOfDay(
              hour: json['checkInTime']['hour'] as int,
              minute: json['checkInTime']['minute'] as int,
            )
          : null,
      streakCount: json['streakCount'] as int,
      lastCheckIn: json['lastCheckIn'] != null
          ? DateTime.parse(json['lastCheckIn'] as String)
          : null,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      reminderBefore: json['reminderBefore'] != null
          ? Duration(minutes: json['reminderBefore'] as int)
          : null,
    );
  }
}

enum TodoType {
  scheduled, // 定时任务
  daily, // 每日打卡
  deadline // DDL任务
}
