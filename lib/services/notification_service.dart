import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/todo.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<bool> requestPermission() async {
    if (!_isInitialized) return false;

    final platform = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (platform == null) return false;

    final granted = await platform.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    // 为Android创建通知通道
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'todo_reminder',
      '待办提醒',
      description: '待办事项的提醒通知',
      importance: Importance.high,
    );

    // 注册通知通道
    final platform = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (platform != null) {
      await platform.createNotificationChannel(channel);
      // 请求权限
      await platform.requestNotificationsPermission();
    }

    // 初始化设置
    const androidInitialize =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInitialize = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iOSInitialize,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // 处理通知点击
      },
    );

    _isInitialized = true;
  }

  Future<void> scheduleTodoReminder(Todo todo) async {
    if (!_isInitialized || !todo.needsReminder) return;

    DateTime? scheduledDateTime;
    String title = '待办提醒';
    String message = todo.title;
    bool dailyRepeat = false;

    switch (todo.type) {
      case TodoType.scheduled:
        if (todo.scheduledDate != null && todo.startTime != null) {
          scheduledDateTime = DateTime(
            todo.scheduledDate!.year,
            todo.scheduledDate!.month,
            todo.scheduledDate!.day,
            todo.startTime!.hour,
            todo.startTime!.minute,
          );
        }
        break;

      case TodoType.checkin:
        if (todo.checkInTime != null) {
          final now = DateTime.now();
          scheduledDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            todo.checkInTime!.hour,
            todo.checkInTime!.minute,
          );
          // 如果今天的提醒时间已经过了，设置为明天
          if (scheduledDateTime.isBefore(now)) {
            scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
          }
          title = '打卡提醒';
          message = '该打卡啦：${todo.title}';
          dailyRepeat = true;
        }
        break;

      case TodoType.deadline:
        if (todo.deadline != null && todo.reminderBefore != null) {
          scheduledDateTime = todo.deadline!.subtract(todo.reminderBefore!);
          final timeLeft = todo.reminderBefore!.inHours >= 24
              ? '${todo.reminderBefore!.inDays}天'
              : '${todo.reminderBefore!.inHours}小时';
          title = 'DDL提醒';
          message = '${todo.title} 将在$timeLeft后截止';
        }
        break;
    }

    if (scheduledDateTime == null) return;

    await scheduleNotification(
      id: todo.id.hashCode,
      title: title,
      body: message,
      scheduledDate: scheduledDateTime,
      dailyRepeat: dailyRepeat,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool dailyRepeat = false,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'todo_reminder',
        '待办提醒',
        channelDescription: '待办事项的提醒通知',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    if (scheduledDate.isBefore(DateTime.now()) && !dailyRepeat) {
      return;
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: dailyRepeat ? DateTimeComponents.time : null,
    );
  }

  Future<void> cancelReminder(Todo todo) async {
    await _notifications.cancel(todo.id.hashCode);
  }
}
