import 'dart:convert';
import 'package:shared_preferences.dart';
import '../models/task.dart';

class StorageService {
  static const String TASKS_KEY = 'tasks';
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // 保存任务列表
  Future<void> saveTasks(List<Task> tasks) async {
    final String tasksJson = jsonEncode(
      tasks.map((task) => task.toJson()).toList(),
    );
    await _prefs.setString(TASKS_KEY, tasksJson);
  }

  // 读取任务列表
  List<Task> loadTasks() {
    final String? tasksJson = _prefs.getString(TASKS_KEY);
    if (tasksJson == null) return [];

    final List<dynamic> decodedJson = jsonDecode(tasksJson);
    return decodedJson.map((json) => Task.fromJson(json)).toList();
  }

  // 导出JSON字符串
  String exportTasks(List<Task> tasks) {
    return jsonEncode(tasks.map((task) => task.toJson()).toList());
  }

  // 导入JSON字符串
  List<Task> importTasks(String jsonString) {
    final List<dynamic> decodedJson = jsonDecode(jsonString);
    return decodedJson.map((json) => Task.fromJson(json)).toList();
  }
} 