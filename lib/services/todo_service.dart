import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import 'notification_service.dart';
import 'widget_service.dart';

class TodoService {
  static const String _key = 'todos';
  final SharedPreferences _prefs;

  final NotificationService notificationService;

  TodoService(this._prefs, this.notificationService);

  Future<List<Todo>> getTodos() async {
    final String? todosJson = _prefs.getString(_key);
    if (todosJson == null) return [];

    final List<dynamic> todosList = jsonDecode(todosJson);
    return todosList.map((json) => Todo.fromJson(json)).toList();
  }

  Future<void> saveTodos(List<Todo> todos) async {
    final String todosJson = jsonEncode(
      todos.map((todo) => todo.toJson()).toList(),
    );
    await _prefs.setString(_key, todosJson);
    // 更新小组件
    await WidgetService.updateHomeWidget();
  }

  Future<void> addTodo(Todo todo) async {
    final todos = await getTodos();
    todos.add(todo);
    await saveTodos(todos);
  }

  Future<void> updateTodo(Todo todo) async {
    final todos = await getTodos();
    final index = todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      todos[index] = todo;
      await saveTodos(todos);
    }
  }

  Future<void> deleteTodo(String id) async {
    final todos = await getTodos();
    todos.removeWhere((todo) => todo.id == id);
    await saveTodos(todos);
  }

  Future<void> toggleTodoCompletion(String id) async {
    final todos = await getTodos();
    final index = todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = todos[index];
      todos[index] = todo.copyWith(
        isCompleted: !todo.isCompleted,
        completedAt: !todo.isCompleted ? DateTime.now() : null,
      );
      await saveTodos(todos);
    }
  }

  Future<List<Todo>> getTodayTasks() async {
    final todos = await getTodos();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return todos.where((todo) {
      if (todo.isCompleted) return false;

      if (todo.type == TodoType.scheduled) {
        if (todo.scheduledDate == null) return false;
        final scheduledDay = DateTime(
          todo.scheduledDate!.year,
          todo.scheduledDate!.month,
          todo.scheduledDate!.day,
        );
        return scheduledDay.isAtSameMomentAs(today);
      }
      return false;
    }).toList();
  }

  Future<List<Todo>> getUpcomingDeadlines() async {
    final todos = await getTodos();
    final now = DateTime.now();

    return todos.where((todo) {
      if (todo.isCompleted) return false;
      if (todo.type != TodoType.deadline) return false;
      if (todo.deadline == null) return false;

      return todo.deadline!.isAfter(now);
    }).toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
  }

  Future<List<Todo>> getDailyTasks() async {
    final todos = await getTodos();
    final now = DateTime.now();

    return todos.where((todo) {
      if (todo.isCompleted) return false;
      if (todo.type != TodoType.checkin) return false;

      // 检查是否是每日打卡任务
      if (todo.frequency != CheckinFrequency.daily) return false;

      // 如果今天已经打卡了，就不显示
      if (todo.lastCheckIn != null) {
        final lastCheckInDay = DateTime(
          todo.lastCheckIn!.year,
          todo.lastCheckIn!.month,
          todo.lastCheckIn!.day,
        );
        final today = DateTime(now.year, now.month, now.day);
        if (lastCheckInDay.isAtSameMomentAs(today)) return false;
      }

      return true;
    }).toList();
  }
}
