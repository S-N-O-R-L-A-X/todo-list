import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../services/todo_service.dart';

class TodoProvider with ChangeNotifier {
  final TodoService _todoService;
  List<Todo> _todos = [];

  TodoProvider(this._todoService) {
    _loadTodos();
  }

  List<Todo> get todos => _todos;
  List<Todo> get completedTodos => _todos.where((todo) => todo.isCompleted).toList();
  List<Todo> get incompleteTodos => _todos.where((todo) => !todo.isCompleted).toList();

  Future<void> _loadTodos() async {
    _todos = await _todoService.getTodos();
    notifyListeners();
  }

  Future<void> addTodo(String title) async {
    final todo = Todo(title: title);
    await _todoService.addTodo(todo);
    await _loadTodos();
  }

  Future<void> toggleTodo(String id) async {
    await _todoService.toggleTodoCompletion(id);
    await _loadTodos();
  }

  Future<void> deleteTodo(String id) async {
    await _todoService.deleteTodo(id);
    await _loadTodos();
  }

  Future<void> updateTodoTitle(String id, String newTitle) async {
    final index = _todos.indexWhere((todo) => todo.id == id);
    if (index != -1) {
      final todo = _todos[index].copyWith(title: newTitle);
      await _todoService.updateTodo(todo);
      await _loadTodos();
    }
  }
}
