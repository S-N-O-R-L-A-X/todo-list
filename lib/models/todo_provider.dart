import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../services/todo_service.dart';
import '../services/notification_service.dart';

class TodoProvider with ChangeNotifier {
  final TodoService _todoService;
  final NotificationService _notificationService;
  List<Todo> _todos = [];

  TodoProvider(this._todoService, this._notificationService) {
    _loadTodos();
  }

  List<Todo> get todos => _todos;
  List<Todo> get completedTodos =>
      _todos.where((todo) => todo.isCompleted).toList();
  List<Todo> get incompleteTodos =>
      _todos.where((todo) => !todo.isCompleted).toList();
  List<Todo> get scheduledTodos =>
      _todos.where((todo) => todo.type == TodoType.scheduled).toList();
  List<Todo> get dailyTodos =>
      _todos.where((todo) => todo.type == TodoType.checkin).toList();
  List<Todo> get deadlineTodos =>
      _todos.where((todo) => todo.type == TodoType.deadline).toList();

  Future<void> _loadTodos() async {
    _todos = await _todoService.getTodos();
    notifyListeners();
  }

  Future<void> addTodo(
    String title, {
    TodoType type = TodoType.scheduled,
    DateTime? scheduledDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool needsReminder = false,
    CheckinFrequency frequency = CheckinFrequency.daily,
    List<bool>? weekdays,
    List<bool>? monthDays,
    TimeOfDay? checkInTime,
    Duration? checkInInterval,
    DateTime? deadline,
    Duration? reminderBefore,
  }) async {
    final todo = Todo(
      title: title,
      type: type,
      scheduledDate: scheduledDate,
      startTime: startTime,
      endTime: endTime,
      needsReminder: needsReminder,
      frequency: frequency,
      weekdays: weekdays,
      monthDays: monthDays,
      checkInTime: checkInTime,
      checkInInterval: checkInInterval,
      deadline: deadline,
      reminderBefore: reminderBefore,
    );

    _todos.add(todo);
    await _todoService.saveTodos(_todos);
    _scheduleNotification(todo);
    notifyListeners();
  }

  Future<void> updateTodo(Todo todo) async {
    final index = _todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      _todos[index] = todo;
      await _todoService.saveTodos(_todos);
      _scheduleNotification(todo);
      notifyListeners();
    }
  }

  void _scheduleNotification(Todo todo) {
    if (!todo.needsReminder) return;

    switch (todo.type) {
      case TodoType.scheduled:
        if (todo.scheduledDate != null && todo.startTime != null) {
          final notificationTime = DateTime(
            todo.scheduledDate!.year,
            todo.scheduledDate!.month,
            todo.scheduledDate!.day,
            todo.startTime!.hour,
            todo.startTime!.minute,
          );
          _notificationService.scheduleNotification(
            id: todo.id.hashCode,
            title: '定时任务提醒',
            body: todo.title,
            scheduledDate: notificationTime,
          );
        }
        break;

      case TodoType.checkin:
        if (todo.checkInTime != null) {
          final now = DateTime.now();
          final notificationTime = DateTime(
            now.year,
            now.month,
            now.day,
            todo.checkInTime!.hour,
            todo.checkInTime!.minute,
          );
          // 如果今天的提醒时间已经过了，设置明天的提醒
          if (notificationTime.isBefore(now)) {
            notificationTime.add(const Duration(days: 1));
          }
          _notificationService.scheduleNotification(
            id: todo.id.hashCode,
            title: '打卡提醒',
            body: '该打卡啦：${todo.title}',
            scheduledDate: notificationTime,
          );
        }
        break;

      case TodoType.deadline:
        if (todo.deadline != null && todo.reminderBefore != null) {
          final notificationTime =
              todo.deadline!.subtract(todo.reminderBefore!);
          _notificationService.scheduleNotification(
            id: todo.id.hashCode,
            title: 'DDL提醒',
            body: '${todo.title} 即将到期！',
            scheduledDate: notificationTime,
          );
        }
        break;
    }
  }

  Future<void> toggleTodo(String id) async {
    await _todoService.toggleTodoCompletion(id);
    final todo = _todos.firstWhere((todo) => todo.id == id);

    // 如果任务完成，取消提醒
    if (todo.isCompleted) {
      await _notificationService.cancelReminder(todo);
    }

    await _loadTodos();
  }

  Future<void> deleteTodo(String id) async {
    final todo = _todos.firstWhere((todo) => todo.id == id);
    await _todoService.deleteTodo(id);
    await _notificationService.cancelReminder(todo);
    await _loadTodos();
  }

  Future<void> updateTodoTitle(String id, String newTitle) async {
    final todo =
        _todos.firstWhere((todo) => todo.id == id).copyWith(title: newTitle);
    await _todoService.updateTodo(todo);
    await _loadTodos();
  }
}
