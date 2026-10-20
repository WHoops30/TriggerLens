import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const int digestionTimerId = 1001;
  static const int hydrationChaserId = 1002;
  static const int symptomCheckinId = 1003;
  static const int thresholdWarningId = 1004;
  static const int testNotificationId = 9999;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
    );

    // Explicitly request notification and exact alarm permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _isInitialized = true;
  }

  bool _isQuietHours() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 22 || hour < 7;
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    bool respectQuietHours = false,
  }) async {
    if (respectQuietHours && _isQuietHours()) {
      debugPrint("🔇 Suppressed notification due to quiet hours: $title");
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'triggerlens_alerts',
      'TriggerLens Alerts',
      channelDescription: 'Important health and digestion alerts',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  Future<void> scheduleTargetedNotification({
    required int id,
    required String title,
    required String body,
    required Duration delay,
  }) async {
    final scheduledTime = DateTime.now().add(delay);
    if (scheduledTime.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'triggerlens_timers',
      'TriggerLens Timers',
      channelDescription: 'Scheduled biological timers and follow-ups',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint(
        "⏰ Scheduled notification ID $id in ${delay.inMinutes} minutes.");
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
    debugPrint("❌ Cancelled notification ID $id");
  }

  Future<void> sendTestNotification() async {
    await showInstantNotification(
      id: testNotificationId,
      title: 'TriggerLens Live Test 🔔',
      body:
          'Lock-screen push notifications are successfully wired and working!',
    );
  }
}
