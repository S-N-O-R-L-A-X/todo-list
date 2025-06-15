import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import 'todo_service.dart';
import 'notification_service.dart';

class WidgetService {
  static const String appWidgetProvider = 'TodoWidgetProvider';
  static const String todayTasksKey = 'today_tasks';
  static const String deadlinesKey = 'deadlines';
  static const String dailyTasksKey = 'daily_tasks';

  static Future<void> updateHomeWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationService = NotificationService();
    final todoService = TodoService(prefs, notificationService);

    // 获取今日任务
    final List<Todo> todayTasks = await todoService.getTodayTasks();
    // 获取未完成的DDL任务
    final List<Todo> deadlines = await todoService.getUpcomingDeadlines();
    // 获取打卡任务
    final List<Todo> dailyTasks = await todoService.getDailyTasks();

    // 更新小组件数据
    await HomeWidget.saveWidgetData(
      todayTasksKey,
      todayTasks.map((e) => e.title).join('\n'),
    );
    await HomeWidget.saveWidgetData(
      deadlinesKey,
      deadlines
          .map((e) => '${e.title} (${e.deadline?.toString().split(' ')[0]})')
          .join('\n'),
    );
    await HomeWidget.saveWidgetData(
      dailyTasksKey,
      dailyTasks.map((e) => e.title).join('\n'),
    );

    // 更新小组件
    await HomeWidget.updateWidget(
      name: appWidgetProvider,
      androidName: appWidgetProvider,
      iOSName: appWidgetProvider,
    );
  }

  static Future<void> initializeWidget() async {
    await Workmanager().initialize(
      updateCallback,
      isInDebugMode: false,
    );

    // 设置定期更新任务
    await Workmanager().registerPeriodicTask(
      'todosWidgetUpdate',
      'updateTodosWidget',
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(seconds: 10),
    );
  }

  @pragma('vm:entry-point')
  static void updateCallback() {
    Workmanager().executeTask((task, inputData) async {
      await updateHomeWidget();
      return true;
    });
  }
}
