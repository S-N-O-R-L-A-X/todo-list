import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/todo_provider.dart';
import 'models/todo.dart';
import 'services/todo_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final notificationService = NotificationService();
  await notificationService.initialize();
  final todoService = TodoService(prefs, notificationService);
  runApp(MyApp(
      todoService: todoService, notificationService: notificationService));
}

class MyApp extends StatelessWidget {
  final TodoService todoService;
  final NotificationService notificationService;

  const MyApp(
      {super.key,
      required this.todoService,
      required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TodoProvider(todoService, notificationService),
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

class _TodoListScreenState extends State<TodoListScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  late TabController _tabController;

  // 每日打卡相关变量
  List<bool> selectedWeekdays = List.filled(7, true);
  TimeOfDay? checkInTime;

  // DDL任务相关变量
  Duration? reminderBefore;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待办事项'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '定时任务'),
            Tab(text: '每日打卡'),
            Tab(text: 'DDL'),
          ],
        ),
      ),
      body: Consumer<TodoProvider>(
        builder: (context, todoProvider, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildTodoList(todoProvider.todos),
              _buildTodoList(todoProvider.scheduledTodos),
              _buildTodoList(todoProvider.dailyTodos),
              _buildTodoList(todoProvider.deadlineTodos),
            ],
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

  Widget _buildTodoList(List<Todo> todos) {
    if (todos.isEmpty) {
      return const Center(
        child: Text('暂无待办事项'),
      );
    }

    return ListView.builder(
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        final bool isScheduled = todo.type == TodoType.scheduled;
        String? subtitle;
        // 构建不同类型任务的副标题
        if (isScheduled && todo.scheduledDate != null) {
          subtitle =
              '${todo.scheduledDate!.year}-${todo.scheduledDate!.month}-${todo.scheduledDate!.day}';
          if (todo.startTime != null && todo.endTime != null) {
            subtitle +=
                ' ${todo.startTime!.hour}:${todo.startTime!.minute.toString().padLeft(2, '0')} - '
                '${todo.endTime!.hour}:${todo.endTime!.minute.toString().padLeft(2, '0')}';
          }
          if (todo.needsReminder) {
            subtitle += ' (提醒)';
          }
        } else if (todo.type == TodoType.deadline && todo.deadline != null) {
          subtitle =
              '${todo.deadline!.year}-${todo.deadline!.month}-${todo.deadline!.day} '
              '${todo.startTime?.format(context) ?? '23:59'}\n${todo.getRemainingTime()}';
          if (todo.reminderBefore != null) {
            subtitle +=
                '\n提前${todo.reminderBefore!.inHours >= 24 ? '${todo.reminderBefore!.inDays}天' : '${todo.reminderBefore!.inHours}小时'}提醒';
          }
        } else if (todo.type == TodoType.daily) {
          final weekdayLabels = ['日', '一', '二', '三', '四', '五', '六'];
          final activeDays = todo.weekdays
              .asMap()
              .entries
              .where((e) => e.value)
              .map((e) => weekdayLabels[e.key])
              .join(' ');
          subtitle = '打卡时间: ${todo.checkInTime?.format(context) ?? '未设置'}\n'
              '连续打卡: ${todo.streakCount}天 (每周${activeDays})';
        }

        return Dismissible(
          key: Key(todo.id),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            context.read<TodoProvider>().deleteTodo(todo.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已删除：${todo.title}')),
            );
          },
          child: ListTile(
            leading: todo.type == TodoType.daily
                ? PopupMenuButton<String>(
                    icon: Icon(
                      Icons.check_circle,
                      color: todo.lastCheckIn?.day == DateTime.now().day
                          ? Colors.green
                          : Colors.grey,
                      size: 28,
                    ),
                    onSelected: (value) async {
                      if (value == 'today') {
                        if (todo.checkIn()) {
                          context.read<TodoProvider>().updateTodo(todo);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('打卡成功！连续打卡${todo.streakCount}天'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('今天不是打卡日期'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      } else if (value == 'select_date') {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 7)),
                          lastDate: DateTime.now(),
                          helpText: '选择补打卡日期',
                          cancelText: '取消',
                          confirmText: '确认',
                        );
                        if (date != null) {
                          if (todo.checkIn(date)) {
                            context.read<TodoProvider>().updateTodo(todo);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('补打卡成功！连续打卡${todo.streakCount}天'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('所选日期不是打卡日期'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'today',
                        child: Row(
                          children: [
                            Icon(Icons.today),
                            SizedBox(width: 8),
                            Text('今日打卡'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'select_date',
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today),
                            SizedBox(width: 8),
                            Text('补打卡'),
                          ],
                        ),
                      ),
                    ],
                  )
                : Checkbox(
                    value: todo.isCompleted,
                    onChanged: (_) =>
                        context.read<TodoProvider>().toggleTodo(todo.id),
                  ),
            title: Text(
              todo.title,
              style: TextStyle(
                decoration:
                    todo.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: subtitle != null ? Text(subtitle) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isScheduled)
                  Icon(
                    Icons.schedule,
                    color: todo.needsReminder ? Colors.blue : Colors.grey,
                    size: 20,
                  )
                else if (todo.type == TodoType.deadline)
                  Icon(
                    Icons.timer,
                    color: todo.isCompleted
                        ? Colors.grey
                        : todo.deadline!.isBefore(DateTime.now())
                            ? Colors.red
                            : todo.deadline!.difference(DateTime.now()).inDays <
                                    1
                                ? Colors.orange
                                : Colors.blue,
                    size: 20,
                  )
                else if (todo.type == TodoType.daily &&
                    todo.needsCheckInToday())
                  const Icon(
                    Icons.alarm_on,
                    color: Colors.blue,
                    size: 20,
                  ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditTodoDialog(context, todo),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditTodoDialog(BuildContext context, Todo todo) async {
    _textController.text = todo.title;
    DateTime? selectedDate = todo.scheduledDate;
    TimeOfDay? startTime = todo.startTime;
    TimeOfDay? endTime = todo.endTime;
    bool needsReminder = todo.needsReminder;
    TodoType selectedType = todo.type; // 初始化每日打卡相关变量
    selectedWeekdays = todo.type == TodoType.daily
        ? List.from(todo.weekdays)
        : List.filled(7, true);
    checkInTime = todo.type == TodoType.daily ? todo.checkInTime : null;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑待办事项'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: '请输入待办事项内容',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButton<TodoType>(
                      value: selectedType,
                      items: TodoType.values.map((type) {
                        String label;
                        switch (type) {
                          case TodoType.scheduled:
                            label = '定时任务';
                            break;
                          case TodoType.daily:
                            label = '每日打卡';
                            break;
                          case TodoType.deadline:
                            label = 'DDL任务';
                            break;
                        }
                        return DropdownMenuItem(
                          value: type,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                    if (selectedType == TodoType.deadline) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('截止日期: '),
                          TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedDate = date;
                                });
                              }
                            },
                            child: Text(
                              selectedDate != null
                                  ? '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'
                                  : '选择日期',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('截止时间: '),
                          TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: startTime ?? TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  startTime = time;
                                });
                              }
                            },
                            child: Text(
                              startTime != null
                                  ? startTime!.format(context)
                                  : '选择时间',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('提醒设置:'),
                      ListTile(
                        title: const Text('提前1天'),
                        leading: Radio<Duration>(
                          value: const Duration(days: 1),
                          groupValue: reminderBefore,
                          onChanged: (Duration? value) {
                            setState(() {
                              reminderBefore = value;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('提前12小时'),
                        leading: Radio<Duration>(
                          value: const Duration(hours: 12),
                          groupValue: reminderBefore,
                          onChanged: (Duration? value) {
                            setState(() {
                              reminderBefore = value;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('提前2小时'),
                        leading: Radio<Duration>(
                          value: const Duration(hours: 2),
                          groupValue: reminderBefore,
                          onChanged: (Duration? value) {
                            setState(() {
                              reminderBefore = value;
                            });
                          },
                        ),
                      ),
                    ] else if (selectedType == TodoType.scheduled) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('日期: '),
                          TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedDate = date;
                                });
                              }
                            },
                            child: Text(
                              selectedDate != null
                                  ? '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'
                                  : '选择日期',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('开始时间: '),
                          TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: startTime ?? TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  startTime = time;
                                });
                              }
                            },
                            child: Text(
                              startTime != null
                                  ? '${startTime!.hour}:${startTime!.minute.toString().padLeft(2, '0')}'
                                  : '选择时间',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('结束时间: '),
                          TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: endTime ?? TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  endTime = time;
                                });
                              }
                            },
                            child: Text(
                              endTime != null
                                  ? '${endTime!.hour}:${endTime!.minute.toString().padLeft(2, '0')}'
                                  : '选择时间',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: needsReminder,
                            onChanged: (value) {
                              setState(() {
                                needsReminder = value!;
                              });
                            },
                          ),
                          const Text('需要提醒'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _textController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      if (selectedType == TodoType.scheduled) {
                        if (selectedDate == null ||
                            startTime == null ||
                            endTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请填写完整的定时任务信息')),
                          );
                          return;
                        }
                      }
                      final updatedTodo = todo.copyWith(
                        title: _textController.text,
                        type: selectedType,
                        scheduledDate: selectedType == TodoType.scheduled
                            ? selectedDate
                            : null,
                        startTime: selectedType == TodoType.deadline
                            ? startTime
                            : selectedType == TodoType.scheduled
                                ? startTime
                                : null,
                        endTime:
                            selectedType == TodoType.scheduled ? endTime : null,
                        needsReminder: selectedType == TodoType.scheduled
                            ? needsReminder
                            : true,
                        weekdays: selectedType == TodoType.daily
                            ? selectedWeekdays
                            : null,
                        checkInTime:
                            selectedType == TodoType.daily ? checkInTime : null,
                        deadline: selectedType == TodoType.deadline
                            ? selectedDate
                            : null,
                        reminderBefore: selectedType == TodoType.deadline
                            ? reminderBefore
                            : null,
                      );

                      context.read<TodoProvider>().updateTodo(updatedTodo);
                      _textController.clear();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddTodoDialog(BuildContext context) async {
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    bool needsReminder = false;
    TodoType selectedType = TodoType.scheduled;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('添加待办事项'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: '请输入待办事项内容',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButton<TodoType>(
                      value: selectedType,
                      items: TodoType.values.map((type) {
                        String label;
                        switch (type) {
                          case TodoType.scheduled:
                            label = '定时任务';
                            break;
                          case TodoType.daily:
                            label = '每日打卡';
                            break;
                          case TodoType.deadline:
                            label = 'DDL任务';
                            break;
                        }
                        return DropdownMenuItem(
                          value: type,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                    if (selectedType == TodoType.deadline) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('截止日期: '),
                          TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedDate = date;
                                });
                              }
                            },
                            child: Text(
                              selectedDate != null
                                  ? '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'
                                  : '选择日期',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('截止时间: '),
                          TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: startTime ?? TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  startTime = time;
                                });
                              }
                            },
                            child: Text(
                              startTime != null
                                  ? '${startTime!.format(context)}'
                                  : '选择时间',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('提醒设置:'),
                      ListTile(
                        title: const Text('提前1天'),
                        leading: Radio<Duration>(
                          value: const Duration(days: 1),
                          groupValue: reminderBefore,
                          onChanged: (Duration? value) {
                            setState(() {
                              reminderBefore = value;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('提前12小时'),
                        leading: Radio<Duration>(
                          value: const Duration(hours: 12),
                          groupValue: reminderBefore,
                          onChanged: (Duration? value) {
                            setState(() {
                              reminderBefore = value;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('提前2小时'),
                        leading: Radio<Duration>(
                          value: const Duration(hours: 2),
                          groupValue: reminderBefore,
                          onChanged: (Duration? value) {
                            setState(() {
                              reminderBefore = value;
                            });
                          },
                        ),
                      ),
                    ],
                    if (selectedType == TodoType.daily) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('打卡日期：'),
                          TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 7)),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedDate = date;
                                });
                              }
                            },
                            child: Text(
                              selectedDate != null
                                  ? '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'
                                  : '打卡日期（可选）',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('打卡时间设置：'),
                      Row(
                        children: [
                          const Text('提醒时间: '),
                          TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: checkInTime ?? TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  checkInTime = time;
                                });
                              }
                            },
                            child: Text(
                              checkInTime != null
                                  ? '${checkInTime!.hour}:${checkInTime!.minute.toString().padLeft(2, '0')}'
                                  : '选择时间',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('打卡频率：'),
                      Wrap(
                        spacing: 4.0,
                        children: [
                          for (var i = 0; i < 7; i++)
                            FilterChip(
                              label:
                                  Text(['日', '一', '二', '三', '四', '五', '六'][i]),
                              selected: selectedWeekdays[i],
                              onSelected: (bool selected) {
                                setState(() {
                                  selectedWeekdays[i] = selected;
                                });
                              },
                            ),
                        ],
                      ),
                    ] else if (selectedType == TodoType.scheduled) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('日期: '),
                          TextButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedDate = date;
                                });
                              }
                            },
                            child: Text(
                              selectedDate != null
                                  ? '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'
                                  : '选择日期',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('开始时间: '),
                          TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  startTime = time;
                                });
                              }
                            },
                            child: Text(
                              startTime != null
                                  ? '${startTime!.hour}:${startTime!.minute}'
                                  : '选择时间',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('结束时间: '),
                          TextButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  endTime = time;
                                });
                              }
                            },
                            child: Text(
                              endTime != null
                                  ? '${endTime!.hour}:${endTime!.minute}'
                                  : '选择时间',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: needsReminder,
                            onChanged: (value) {
                              setState(() {
                                needsReminder = value!;
                              });
                            },
                          ),
                          const Text('需要提醒'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      if (selectedType == TodoType.scheduled) {
                        if (selectedDate == null ||
                            startTime == null ||
                            endTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请填写完整的定时任务信息')),
                          );
                          return;
                        }
                      } else if (selectedType == TodoType.deadline) {
                        if (selectedDate == null || startTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请设置截止日期和时间')),
                          );
                          return;
                        }
                        if (reminderBefore == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请选择提醒时间')),
                          );
                          return;
                        }
                      } else if (selectedType == TodoType.daily &&
                          checkInTime == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请设置打卡时间')),
                        );
                        return;
                      }
                      context.read<TodoProvider>().addTodo(
                            _textController.text,
                            type: selectedType,
                            scheduledDate: selectedType == TodoType.scheduled
                                ? selectedDate
                                : null,
                            startTime: selectedType == TodoType.deadline
                                ? startTime
                                : selectedType == TodoType.scheduled
                                    ? startTime
                                    : null,
                            endTime: selectedType == TodoType.scheduled
                                ? endTime
                                : null,
                            needsReminder: selectedType == TodoType.scheduled
                                ? needsReminder
                                : true,
                            weekdays: selectedType == TodoType.daily
                                ? selectedWeekdays
                                : null,
                            deadline: selectedType == TodoType.deadline
                                ? selectedDate
                                : null,
                            reminderBefore: selectedType == TodoType.deadline
                                ? reminderBefore
                                : null,
                            checkInTime: selectedType == TodoType.daily
                                ? checkInTime
                                : null,
                          );
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
      },
    );
  }
}
