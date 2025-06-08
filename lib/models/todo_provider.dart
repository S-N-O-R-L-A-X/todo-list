import 'package:flutter/foundation.dart';
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
      _todos.where((todo) => todo.type == TodoType.daily).toList();
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
    List<bool>? weekdays,
    TimeOfDay? checkInTime,
  }) async {    final todo = Todo(
      title: title,
      type: type,
      scheduledDate: scheduledDate,
      startTime: startTime,
      endTime: endTime,
      needsReminder: needsReminder,
      weekdays: weekdays,
      checkInTime: type == TodoType.daily ? checkInTime : null,
    );

    await _todoService.addTodo(todo);

    if (needsReminder) {
      await _notificationService.scheduleTodoReminder(todo);
    }

    await _loadTodos();
  }

  Future<void> updateTodo(Todo todo) async {
    await _todoService.updateTodo(todo);

    if (todo.needsReminder) {
      await _notificationService.scheduleTodoReminder(todo);
    } else {
      await _notificationService.cancelReminder(todo);
    }

    await _loadTodos();
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
