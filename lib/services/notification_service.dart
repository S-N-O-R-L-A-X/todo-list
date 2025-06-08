import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/todo.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Future<void> initialize() async {
    tz.initializeTimeZones(); // 初始化时区数据    // 为Android创建通知通道
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'todo_reminder', // id
      '待办提醒', // name
      description: '待办事项的提醒通知', // description
      importance: Importance.high,
    );

    // 注册通知通道
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

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
        print('Notification clicked: ${details.payload}');
      },
    );
  }

  Future<void> scheduleTodoReminder(Todo todo) async {
    if (!todo.needsReminder ||
        todo.scheduledDate == null ||
        todo.startTime == null) {
      return;
    }

    final scheduledDateTime = DateTime(
      todo.scheduledDate!.year,
      todo.scheduledDate!.month,
      todo.scheduledDate!.day,
      todo.startTime!.hour,
      todo.startTime!.minute,
    );

    // 如果时间已经过去，就不设置提醒
    if (scheduledDateTime.isBefore(DateTime.now())) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'todo_reminder',
      '待办提醒',
      channelDescription: '待办事项的提醒通知',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );
    await _notifications.zonedSchedule(
      todo.id.hashCode,
      '待办提醒',
      todo.title,
      tz.TZDateTime.from(scheduledDateTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelReminder(Todo todo) async {
    await _notifications.cancel(todo.id.hashCode);
  }
}
