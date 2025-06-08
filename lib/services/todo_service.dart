import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';

class TodoService {
  static const String _key = 'todos';
  final SharedPreferences _prefs;

  TodoService(this._prefs);

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
}
