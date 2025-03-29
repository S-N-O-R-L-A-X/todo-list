class Task {
  String id;
  String title;
  String description;
  bool isCompleted;
  DateTime? deadline;
  bool isHabit; // 用于区分是普通任务还是习惯
  List<DateTime> checkInDates; // 习惯打卡记录

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    this.deadline,
    this.isHabit = false,
    List<DateTime>? checkInDates,
  }) : checkInDates = checkInDates ?? [];

  // 从JSON转换
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      isHabit: json['isHabit'] ?? false,
      checkInDates: (json['checkInDates'] as List?)
          ?.map((date) => DateTime.parse(date))
          .toList() ?? [],
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'deadline': deadline?.toIso8601String(),
      'isHabit': isHabit,
      'checkInDates': checkInDates.map((date) => date.toIso8601String()).toList(),
    };
  }
} 