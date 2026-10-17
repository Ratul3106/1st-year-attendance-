import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:student_attendance_system/models/app_notification.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';

class NotificationService {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initializeFCM() async {
    if (SupabaseConfig.isDemoMode) return;

    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initializationSettings =
            InitializationSettings(android: initializationSettingsAndroid);

        await _localNotifications.initialize(initializationSettings);

        String? token = await _fcm.getToken();
        if (token != null) {
          await registerFCMToken(token);
        }

        _fcm.onTokenRefresh.listen(registerFCMToken);

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null) {
            _showLocalNotification(
              message.notification!.title ?? 'Notification',
              message.notification!.body ?? '',
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> registerFCMToken(String token) async {
    if (SupabaseConfig.isDemoMode) return;
    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase?.from('device_tokens').upsert(
      {
        'user_id': userId,
        'fcm_token': token,
        'platform': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id, fcm_token',
    );
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'attendance_reports_channel',
      'Daily Attendance Reports',
      channelDescription: 'Notifications for daily student attendance reports',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
    );
  }

  // Fetch in-app notifications
  Future<List<AppNotification>> getNotifications() async {
    if (SupabaseConfig.isDemoMode) {
      final userId = DemoDataService.instance.currentDemoUser?.id ?? 'demo-staff-id';
      return DemoDataService.instance.getNotificationsForUser(userId);
    }

    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase!
        .from('app_notifications')
        .select()
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.markNotificationAsRead(notificationId);
      return;
    }

    await _supabase!
        .from('app_notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', notificationId);
  }
}

