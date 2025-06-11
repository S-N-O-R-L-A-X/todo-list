import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

enum TodoType {
  scheduled, // 定时任务
  checkin, // 打卡任务
  deadline // DDL任务
}

enum CheckinFrequency {
  hourly, // 每小时
  daily, // 每日
  weekly, // 每周
  monthly // 每月
}

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

  // 打卡相关字段
  CheckinFrequency frequency; // 打卡频度
  List<bool> weekdays; // 周几需要打卡（用于每周打卡）[周日,周一,周二,周三,周四,周五,六]
  List<bool> monthDays; // 每月哪几天打卡（用于每月打卡）[1-31]
  TimeOfDay? checkInTime; // 打卡提醒时间（可选）
  int streakCount; // 连续打卡次数
  DateTime? lastCheckIn; // 最后打卡时间
  Duration? checkInInterval; // 打卡间隔（用于每小时打卡）

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
    this.frequency = CheckinFrequency.daily,
    List<bool>? weekdays,
    List<bool>? monthDays,
    this.checkInTime,
    this.streakCount = 0,
    this.lastCheckIn,
    this.deadline,
    this.reminderBefore,
    this.checkInInterval,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        weekdays = weekdays ?? List.filled(7, true),
        monthDays = monthDays ?? List.generate(31, (index) => true) {
    // 确保打卡任务有正确的初始化参数
    if (type == TodoType.checkin) {
      // 每小时打卡必须设置间隔时间
      if (frequency == CheckinFrequency.hourly && checkInInterval == null) {
        checkInInterval = const Duration(hours: 1);
      }
    }
  }

  Todo copyWith({
    String? title,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? scheduledDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? needsReminder,
    TodoType? type,
    CheckinFrequency? frequency,
    List<bool>? weekdays,
    List<bool>? monthDays,
    TimeOfDay? checkInTime,
    int? streakCount,
    DateTime? lastCheckIn,
    DateTime? deadline,
    Duration? reminderBefore,
    Duration? checkInInterval,
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
      frequency: frequency ?? this.frequency,
      weekdays: weekdays ?? this.weekdays,
      monthDays: monthDays ?? this.monthDays,
      checkInTime: checkInTime ?? this.checkInTime,
      streakCount: streakCount ?? this.streakCount,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      deadline: deadline ?? this.deadline,
      reminderBefore: reminderBefore ?? this.reminderBefore,
      checkInInterval: checkInInterval ?? this.checkInInterval,
    );
  }

  bool checkIn([DateTime? checkInDate]) {
    if (type != TodoType.checkin) return false;

    final targetDate = checkInDate ?? DateTime.now();
    final now = DateTime.now();

    // 根据不同频度检查是否可以打卡
    switch (frequency) {
      case CheckinFrequency.hourly:
        if (checkInInterval == null) return false;
        if (lastCheckIn != null) {
          final nextValidCheckIn = lastCheckIn!.add(checkInInterval!);
          if (targetDate.isBefore(nextValidCheckIn)) return false;
        }
        break;

      case CheckinFrequency.daily:
        if (lastCheckIn != null &&
            lastCheckIn!.year == targetDate.year &&
            lastCheckIn!.month == targetDate.month &&
            lastCheckIn!.day == targetDate.day) return false;
        break;

      case CheckinFrequency.weekly:
        if (!weekdays[targetDate.weekday % 7]) return false;
        if (lastCheckIn != null &&
            lastCheckIn!.year == targetDate.year &&
            (lastCheckIn!.difference(targetDate).inDays ~/ 7) == 0 &&
            lastCheckIn!.weekday == targetDate.weekday) return false;
        break;

      case CheckinFrequency.monthly:
        if (!monthDays[targetDate.day - 1]) return false;
        if (lastCheckIn != null &&
            lastCheckIn!.year == targetDate.year &&
            lastCheckIn!.month == targetDate.month &&
            lastCheckIn!.day == targetDate.day) return false;
        break;
    }

    // 如果设置了提醒时间，且是当天打卡，则检查时间
    if (checkInTime != null &&
        checkInDate == null && // 只在实时打卡时检查时间
        targetDate.day == now.day &&
        targetDate.month == now.month &&
        targetDate.year == now.year) {
      final checkInDateTime = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        checkInTime!.hour,
        checkInTime!.minute,
      );
      if (targetDate.isBefore(checkInDateTime)) return false;
    }

    // 更新连续打卡计数
    if (lastCheckIn != null) {
      final expectedInterval = frequency == CheckinFrequency.hourly
          ? checkInInterval!
          : frequency == CheckinFrequency.daily
              ? const Duration(days: 1)
              : frequency == CheckinFrequency.weekly
                  ? const Duration(days: 7)
                  : Duration(
                      days: DateTime(targetDate.year, targetDate.month + 1, 0)
                          .day);

      if (targetDate.difference(lastCheckIn!).abs() <= expectedInterval) {
        streakCount++;
      } else {
        streakCount = 1;
      }
    } else {
      streakCount = 1;
    }

    lastCheckIn = targetDate;
    return true;
  }

  bool needsCheckInToday() {
    if (type != TodoType.checkin) return false;
    final now = DateTime.now();

    switch (frequency) {
      case CheckinFrequency.hourly:
        if (checkInInterval == null) return false;
        if (lastCheckIn == null) return true;
        return now.difference(lastCheckIn!).compareTo(checkInInterval!) >= 0;

      case CheckinFrequency.daily:
        return lastCheckIn?.day != now.day;

      case CheckinFrequency.weekly:
        return weekdays[now.weekday % 7] &&
            (lastCheckIn == null ||
                lastCheckIn!.difference(now).inDays >= 7 ||
                lastCheckIn!.weekday != now.weekday);

      case CheckinFrequency.monthly:
        return monthDays[now.day - 1] &&
            (lastCheckIn == null ||
                lastCheckIn!.year != now.year ||
                lastCheckIn!.month != now.month ||
                lastCheckIn!.day != now.day);
    }
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
      'frequency': frequency.toString(),
      'weekdays': weekdays,
      'monthDays': monthDays,
      'checkInTime': checkInTime != null
          ? {'hour': checkInTime!.hour, 'minute': checkInTime!.minute}
          : null,
      'streakCount': streakCount,
      'lastCheckIn': lastCheckIn?.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'reminderBefore': reminderBefore?.inMinutes,
      'checkInInterval': checkInInterval?.inMinutes,
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
      frequency: json['frequency'] != null
          ? CheckinFrequency.values.firstWhere(
              (freq) => freq.toString() == json['frequency'],
            )
          : CheckinFrequency.daily,
      weekdays: (json['weekdays'] as List<dynamic>?)?.cast<bool>() ??
          List.filled(7, true),
      monthDays: (json['monthDays'] as List<dynamic>?)?.cast<bool>() ??
          List.generate(31, (index) => true),
      checkInTime: json['checkInTime'] != null
          ? TimeOfDay(
              hour: json['checkInTime']['hour'] as int,
              minute: json['checkInTime']['minute'] as int,
            )
          : null,
      streakCount: (json['streakCount'] as int?) ?? 0,
      lastCheckIn: json['lastCheckIn'] != null
          ? DateTime.parse(json['lastCheckIn'] as String)
          : null,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      reminderBefore: json['reminderBefore'] != null
          ? Duration(minutes: json['reminderBefore'] as int)
          : null,
      checkInInterval: json['checkInInterval'] != null
          ? Duration(minutes: json['checkInInterval'] as int)
          : null,
    );
  }
}
