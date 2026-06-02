import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart'; // مكتبة جلب توقيت الجهاز تلقائياً

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 🛠️ 1. دالة تهيئة الإشعارات عند تشغيل التطبيق (تُستدعى في main.dart)
  static Future<void> init() async {
    // تهيئة حزمة التوقيت الزمني
    tz.initializeTimeZones();

    try {
      // 🚀 التعديل هنا: جلب كائن المنطقة الزمنية وتحويله إلى اسم نصي متوافق ✅
      final dynamic locationData = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = locationData is String
          ? locationData
          : locationData.name.toString();

      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint(
        "⚠️ فشل تعيين التوقيت المحلي، سيتم استخدام التوقيت الافتراضي: $e",
      );
      // في حال حدوث أي خطأ نثبت توقيت مكة المكرمة/الرياض كاحتياط لمنع توقف التطبيق
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    }

    // إعدادات الأندرويد (استخدام أيقونة التطبيق الافتراضية)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // طلب صلاحيات الإشعارات فوراً لأجهزة أندرويد 13 وفوق
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  // ⏰ 2. دالة جدولة إشعار يومي متكرر لمواعيد الأدوية
  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // إذا كان الوقت المختار قد مر اليوم، نجدوله لليوم التالي تلقائياً
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_reminders_channel', // معرف القناة
          'تنبيهات الأدوية', // اسم القناة في إعدادات جوال المستخدم
          channelDescription:
              'قناة مخصصة لتذكير المرضى بمواعيد أدويتهم اليومية',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode
          .exactAllowWhileIdle, // يضمن رن المنبه حتى في وضع حفظ الطاقة
      matchDateTimeComponents:
          DateTimeComponents.time, // التكرار اليومي في نفس الوقت تماماً
    );
  }
}
