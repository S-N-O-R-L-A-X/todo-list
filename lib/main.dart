import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/todo_provider.dart';
import 'models/todo.dart';
import 'services/todo_service.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final notificationService = NotificationService();
  await notificationService.initialize();

  // 请求通知权限
  final hasPermission = await notificationService.requestPermission();
  if (!hasPermission) {
    // 可以在这里添加一些提示，告诉用户需要开启通知权限
    debugPrint('通知权限被拒绝，部分功能可能无法正常工作');
  }

  final todoService = TodoService(prefs, notificationService);

  // 初始化小组件服务
  await WidgetService.initializeWidget();
  await WidgetService.updateHomeWidget();

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

  // 打卡相关变量
  List<bool> selectedWeekdays = List.filled(7, true);
  List<bool> selectedMonthDays = List.generate(31, (index) => true);
  TimeOfDay? checkInTime;
  CheckinFrequency selectedFrequency = CheckinFrequency.daily;
  Duration? checkInInterval;

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
            Tab(text: '打卡任务'),
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

  void _handleShowDatePicker(BuildContext context, Todo todo) async {
    if (!context.mounted) return;

    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
      helpText: '选择补打卡日期',
      cancelText: '取消',
      confirmText: '确认',
    );

    if (!context.mounted) return;
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

  void _handleTodayCheckIn(BuildContext context, Todo todo) {
    if (!context.mounted) return;

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
  }

  Widget _buildPopupMenuButton(Todo todo) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.check_circle,
        color: todo.lastCheckIn?.day == DateTime.now().day
            ? Colors.green
            : Colors.grey,
        size: 28,
      ),
      onSelected: (value) async {
        if (value == 'today') {
          _handleTodayCheckIn(context, todo);
        } else if (value == 'select_date') {
          _handleShowDatePicker(context, todo);
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
    );
  }

  Widget _buildTodoList(List<Todo> todos) {
    if (todos.isEmpty) {
      return const Center(child: Text('暂无待办事项'));
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
        } else if (todo.type == TodoType.checkin) {
          String frequencyText;
          switch (todo.frequency) {
            case CheckinFrequency.hourly:
              frequencyText = '每${todo.checkInInterval?.inHours ?? 1}小时一次';
              break;
            case CheckinFrequency.daily:
              frequencyText = '每日一次';
              break;
            case CheckinFrequency.weekly:
              final weekdayLabels = ['日', '一', '二', '三', '四', '五', '六'];
              final activeDays = todo.weekdays
                  .asMap()
                  .entries
                  .where((e) => e.value)
                  .map((e) => weekdayLabels[e.key])
                  .join(' ');
              frequencyText = '每周${activeDays}打卡';
              break;
            case CheckinFrequency.monthly:
              final activeDays = todo.monthDays
                  .asMap()
                  .entries
                  .where((e) => e.value)
                  .map((e) => (e.key + 1).toString())
                  .join(' ');
              frequencyText = '每月${activeDays}号打卡';
              break;
            case CheckinFrequency.weeklyOnce:
              frequencyText = '每周打卡一次';
              break;
            case CheckinFrequency.monthlyOnce:
              frequencyText = '每月打卡一次';
              break;
          }
          subtitle = '打卡时间: ${todo.checkInTime?.format(context) ?? '未设置'}\n'
              '连续打卡: ${todo.streakCount}天\n'
              '频率: $frequencyText';
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
            final currentContext = context;
            if (!mounted) return;
            currentContext.read<TodoProvider>().deleteTodo(todo.id);
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text('已删除：${todo.title}')),
            );
          },
          child: ListTile(
            leading: todo.type == TodoType.checkin
                ? _buildPopupMenuButton(todo)
                : Checkbox(
                    value: todo.isCompleted,
                    onChanged: (_) {
                      final currentContext = context;
                      if (!mounted) return;
                      currentContext.read<TodoProvider>().toggleTodo(todo.id);
                    },
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
                else if (todo.type == TodoType.checkin &&
                    todo.needsCheckInToday())
                  const Icon(
                    Icons.alarm_on,
                    color: Colors.blue,
                    size: 20,
                  ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditTodoDialog(todo),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditTodoDialog(Todo todo) async {
    if (!mounted) return;
    final outerContext = context;
    if (!outerContext.mounted) return;

    _textController.text = todo.title;
    DateTime? selectedDate = todo.scheduledDate;
    TimeOfDay? startTime = todo.startTime;
    TimeOfDay? endTime = todo.endTime;
    bool needsReminder = todo.needsReminder;
    TodoType selectedType = todo.type;
    selectedWeekdays = todo.type == TodoType.checkin &&
            todo.frequency == CheckinFrequency.weekly
        ? List.from(todo.weekdays)
        : List.filled(7, true);
    selectedMonthDays = todo.type == TodoType.checkin &&
            todo.frequency == CheckinFrequency.monthly
        ? List.from(todo.monthDays)
        : List.generate(31, (index) => true);
    checkInTime = todo.type == TodoType.checkin ? todo.checkInTime : null;
    selectedFrequency =
        todo.type == TodoType.checkin ? todo.frequency : CheckinFrequency.daily;
    checkInInterval = todo.type == TodoType.checkin &&
            todo.frequency == CheckinFrequency.hourly
        ? todo.checkInInterval
        : const Duration(hours: 1);

    await showDialog(
      context: outerContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
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
                        case TodoType.checkin:
                          label = '打卡任务';
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
                            if (!mounted) return;
                            final date = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null && mounted) {
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
                            if (!mounted) return;
                            final time = await showTimePicker(
                              context: dialogContext,
                              initialTime: startTime ?? TimeOfDay.now(),
                            );
                            if (time != null && mounted) {
                              setState(() {
                                startTime = time;
                              });
                            }
                          },
                          child: Text(
                            startTime != null
                                ? startTime!.format(dialogContext)
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
                            if (!mounted) return;
                            final date = await showDatePicker(
                              context: dialogContext,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null && mounted) {
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
                            if (!mounted) return;
                            final time = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null && mounted) {
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
                            if (!mounted) return;
                            final time = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null && mounted) {
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
                  ] else if (selectedType == TodoType.checkin) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('打卡日期：'),
                        TextButton(
                          onPressed: () async {
                            if (!mounted) return;
                            final date = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 7)),
                              lastDate: DateTime.now(),
                            );
                            if (date != null && mounted) {
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('打卡时间: '),
                        TextButton(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: dialogContext,
                              initialTime: checkInTime ?? TimeOfDay.now(),
                            );
                            if (time != null && mounted) {
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
                    DropdownButton<CheckinFrequency>(
                      value: selectedFrequency,
                      items: CheckinFrequency.values.map((frequency) {
                        String label;
                        switch (frequency) {
                          case CheckinFrequency.hourly:
                            label = '每小时';
                            break;
                          case CheckinFrequency.daily:
                            label = '每日一次';
                            break;
                          case CheckinFrequency.weekly:
                            label = '每周指定日期';
                            break;
                          case CheckinFrequency.monthly:
                            label = '每月指定日期';
                            break;
                          case CheckinFrequency.weeklyOnce:
                            label = '每周一次';
                            break;
                          case CheckinFrequency.monthlyOnce:
                            label = '每月一次';
                            break;
                        }
                        return DropdownMenuItem(
                          value: frequency,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedFrequency = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    if (selectedFrequency == CheckinFrequency.hourly) ...[
                      const Text('打卡间隔：'),
                      DropdownButton<Duration>(
                        value: checkInInterval ?? const Duration(hours: 1),
                        items: [
                          for (int i = 1; i <= 12; i++)
                            DropdownMenuItem(
                              value: Duration(hours: i),
                              child: Text('$i小时'),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            checkInInterval = value;
                          });
                        },
                      ),
                    ] else if (selectedFrequency ==
                        CheckinFrequency.weekly) ...[
                      const Text('选择打卡日期：'),
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
                    ] else if (selectedFrequency ==
                        CheckinFrequency.monthly) ...[
                      const Text('选择打卡日期：'),
                      SizedBox(
                        height: 150,
                        child: GridView.count(
                          crossAxisCount: 7,
                          children: List.generate(31, (index) {
                            return FilterChip(
                              label: Text('${index + 1}'),
                              selected: selectedMonthDays[index],
                              onSelected: (bool selected) {
                                setState(() {
                                  selectedMonthDays[index] = selected;
                                });
                              },
                            );
                          }),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  if (_textController.text.isNotEmpty) {
                    // 验证必填字段
                    String? errorMessage;

                    switch (selectedType) {
                      case TodoType.scheduled:
                        if (selectedDate == null || startTime == null) {
                          errorMessage = '请设置日期和开始时间';
                        }
                        break;

                      case TodoType.deadline:
                        if (selectedDate == null || startTime == null) {
                          errorMessage = '请设置截止日期和时间';
                        } else if (reminderBefore == null) {
                          errorMessage = '请选择提醒时间';
                        }
                        break;

                      case TodoType.checkin:
                        if (checkInTime == null) {
                          errorMessage = '请设置打卡时间';
                        } else if (selectedFrequency ==
                                CheckinFrequency.hourly &&
                            checkInInterval == null) {
                          errorMessage = '请设置打卡间隔';
                        } else if (selectedFrequency ==
                                CheckinFrequency.weekly &&
                            !selectedWeekdays.contains(true)) {
                          errorMessage = '请至少选择一个打卡日期';
                        } else if (selectedFrequency ==
                                CheckinFrequency.monthly &&
                            !selectedMonthDays.contains(true)) {
                          errorMessage = '请至少选择一个打卡日期';
                        } else if (selectedFrequency ==
                                CheckinFrequency.weeklyOnce ||
                            selectedFrequency == CheckinFrequency.monthlyOnce) {
                          // 不需要额外验证，因为这两种频率不限制具体哪一天打卡
                        }
                        break;
                    }

                    if (errorMessage != null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(errorMessage)),
                      );
                      return;
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
                      frequency: selectedType == TodoType.checkin
                          ? selectedFrequency
                          : CheckinFrequency.daily,
                      weekdays: selectedType == TodoType.checkin &&
                              selectedFrequency == CheckinFrequency.weekly
                          ? selectedWeekdays
                          : null,
                      monthDays: selectedType == TodoType.checkin &&
                              selectedFrequency == CheckinFrequency.monthly
                          ? selectedMonthDays
                          : null,
                      checkInTime:
                          selectedType == TodoType.checkin ? checkInTime : null,
                      deadline: selectedType == TodoType.deadline
                          ? selectedDate
                          : null,
                      reminderBefore: selectedType == TodoType.deadline
                          ? reminderBefore
                          : null,
                      checkInInterval: selectedType == TodoType.checkin &&
                              selectedFrequency == CheckinFrequency.hourly
                          ? checkInInterval
                          : null,
                    );

                    if (!outerContext.mounted) return;
                    outerContext.read<TodoProvider>().updateTodo(updatedTodo);
                    _textController.clear();
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddTodoDialog(BuildContext context) async {
    if (!context.mounted) return;

    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    bool needsReminder = false;
    TodoType selectedType = TodoType.scheduled;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
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
                          case TodoType.checkin:
                            label = '打卡任务';
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
                    ] else if (selectedType == TodoType.checkin) ...[
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('打卡时间: '),
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
                      DropdownButton<CheckinFrequency>(
                        value: selectedFrequency,
                        items: CheckinFrequency.values.map((frequency) {
                          String label;
                          switch (frequency) {
                            case CheckinFrequency.hourly:
                              label = '每小时';
                              break;
                            case CheckinFrequency.daily:
                              label = '每日一次';
                              break;
                            case CheckinFrequency.weekly:
                              label = '每周指定日期';
                              break;
                            case CheckinFrequency.monthly:
                              label = '每月指定日期';
                              break;
                            case CheckinFrequency.weeklyOnce:
                              label = '每周一次';
                              break;
                            case CheckinFrequency.monthlyOnce:
                              label = '每月一次';
                              break;
                          }
                          return DropdownMenuItem(
                            value: frequency,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedFrequency = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      if (selectedFrequency == CheckinFrequency.hourly) ...[
                        const Text('打卡间隔：'),
                        DropdownButton<Duration>(
                          value: checkInInterval ?? const Duration(hours: 1),
                          items: [
                            for (int i = 1; i <= 12; i++)
                              DropdownMenuItem(
                                value: Duration(hours: i),
                                child: Text('$i小时'),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              checkInInterval = value;
                            });
                          },
                        ),
                      ] else if (selectedFrequency ==
                          CheckinFrequency.weekly) ...[
                        const Text('选择打卡日期：'),
                        Wrap(
                          spacing: 4.0,
                          children: [
                            for (var i = 0; i < 7; i++)
                              FilterChip(
                                label: Text(
                                    ['日', '一', '二', '三', '四', '五', '六'][i]),
                                selected: selectedWeekdays[i],
                                onSelected: (bool selected) {
                                  setState(() {
                                    selectedWeekdays[i] = selected;
                                  });
                                },
                              ),
                          ],
                        ),
                      ] else if (selectedFrequency ==
                          CheckinFrequency.monthly) ...[
                        const Text('选择打卡日期：'),
                        SizedBox(
                            height: 150,
                            child: GridView.count(
                              crossAxisCount: 7,
                              children: List.generate(31, (index) {
                                return FilterChip(
                                  label: Text('${index + 1}'),
                                  selected: selectedMonthDays[index],
                                  onSelected: (bool selected) {
                                    setState(() {
                                      selectedMonthDays[index] = selected;
                                    });
                                  },
                                );
                              }),
                            ))
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _textController.clear();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      // 验证必填字段
                      String? errorMessage;

                      switch (selectedType) {
                        case TodoType.scheduled:
                          if (selectedDate == null || startTime == null) {
                            errorMessage = '请设置日期和开始时间';
                          }
                          break;

                        case TodoType.deadline:
                          if (selectedDate == null || startTime == null) {
                            errorMessage = '请设置截止日期和时间';
                          } else if (reminderBefore == null) {
                            errorMessage = '请选择提醒时间';
                          }
                          break;

                        case TodoType.checkin:
                          if (checkInTime == null) {
                            errorMessage = '请设置打卡时间';
                          } else if (selectedFrequency ==
                                  CheckinFrequency.hourly &&
                              checkInInterval == null) {
                            errorMessage = '请设置打卡间隔';
                          } else if (selectedFrequency ==
                                  CheckinFrequency.weekly &&
                              !selectedWeekdays.contains(true)) {
                            errorMessage = '请至少选择一个打卡日期';
                          } else if (selectedFrequency ==
                                  CheckinFrequency.monthly &&
                              !selectedMonthDays.contains(true)) {
                            errorMessage = '请至少选择一个打卡日期';
                          } else if (selectedFrequency ==
                                  CheckinFrequency.weeklyOnce ||
                              selectedFrequency ==
                                  CheckinFrequency.monthlyOnce) {
                            // 不需要额外验证，因为这两种频率不限制具体哪一天打卡
                          }
                          break;
                      }

                      if (errorMessage != null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(errorMessage)),
                        );
                        return;
                      }

                      if (!context.mounted) return;
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
                            frequency: selectedType == TodoType.checkin
                                ? selectedFrequency
                                : CheckinFrequency.daily,
                            weekdays: selectedType == TodoType.checkin &&
                                    selectedFrequency == CheckinFrequency.weekly
                                ? selectedWeekdays
                                : null,
                            monthDays: selectedType == TodoType.checkin &&
                                    selectedFrequency ==
                                        CheckinFrequency.monthly
                                ? selectedMonthDays
                                : null,
                            checkInTime: selectedType == TodoType.checkin
                                ? checkInTime
                                : null,
                            deadline: selectedType == TodoType.deadline
                                ? selectedDate
                                : null,
                            reminderBefore: selectedType == TodoType.deadline
                                ? reminderBefore
                                : null,
                            checkInInterval: selectedType == TodoType.checkin &&
                                    selectedFrequency == CheckinFrequency.hourly
                                ? checkInInterval
                                : null,
                          );
                      _textController.clear();
                      Navigator.pop(dialogContext);
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
