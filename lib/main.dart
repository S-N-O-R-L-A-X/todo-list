import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/todo_provider.dart';
import 'services/todo_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final todoService = TodoService(prefs);
  runApp(MyApp(todoService: todoService));
}

class MyApp extends StatelessWidget {
  final TodoService todoService;

  const MyApp({super.key, required this.todoService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TodoProvider(todoService),
      child: MaterialApp(
        title: 'Todo List',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const TodoListScreen(),
      ),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待办事项'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<TodoProvider>(
        builder: (context, todoProvider, child) {
          final todos = todoProvider.todos;
          return ListView.builder(
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              return ListTile(
                leading: Checkbox(
                  value: todo.isCompleted,
                  onChanged: (_) => todoProvider.toggleTodo(todo.id),
                ),
                title: Text(
                  todo.title,
                  style: TextStyle(
                    decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => todoProvider.deleteTodo(todo.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoDialog(context),
        tooltip: '添加待办事项',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddTodoDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加待办事项'),
          content: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              hintText: '请输入待办事项内容',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (_textController.text.isNotEmpty) {
                  context.read<TodoProvider>().addTodo(_textController.text);
                  _textController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }
}
