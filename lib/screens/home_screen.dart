import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Task> tasks = [];
  late StorageService storageService;

  @override
  void initState() {
    super.initState();
    _initializeStorage();
  }

  Future<void> _initializeStorage() async {
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    setState(() {
      tasks = storageService.loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Todo & Habits'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '任务'),
              Tab(text: '习惯'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.import_export),
              onPressed: _showImportExportDialog,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildTaskList(false), // 普通任务列表
            _buildTaskList(true), // 习惯列表
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewTask,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildTaskList(bool isHabit) {
    final filteredTasks =
        tasks.where((task) => task.isHabit == isHabit).toList();
    return ListView.builder(
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return ListTile(
          title: Text(task.title),
          subtitle: Text(task.description),
          trailing: isHabit
              ? IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () => _checkInHabit(task),
                )
              : Checkbox(
                  value: task.isCompleted,
                  onChanged: (bool? value) => _toggleTaskComplete(task),
                ),
        );
      },
    );
  }

  void _showImportExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import/Export'),
          content: const Text("Import or export tasks here."),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _addNewTask() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Task'),
          content: const Text("Add new task dialog here."),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _checkInHabit(Task task) {
    print("Check-in habit: ${task.title}");
    // TODO: Implement habit check-in logic.
  }

  void _toggleTaskComplete(Task task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
    // TODO: Implement saving task completion state logic.
  }
}
