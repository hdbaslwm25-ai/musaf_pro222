import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';
import 'fcm_service.dart';

class PatientBackgroundService {
  static const String stopAction = "stopService";

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true, // تغير إلى true لضمان الاستئناف بعد إعادة التشغيل
        isForegroundMode: true,
        foregroundServiceNotificationId: 999,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (!isRunning) await service.startService();
  }
  // داخل PatientBackgroundService في تطبيق المريض

Future<void> handleZoneAlert(String patientId, String title, String message, String type) async {
  final firestore = FirebaseFirestore.instance;
  
  // 1. حفظ التنبيه في قاعدة البيانات
  final alertsRef = firestore.collection('patients').doc(patientId).collection('alerts');
  await alertsRef.add({
    'title': title, 
    'message': message, 
    'type': type, 
    'is_read': false, 
    'timestamp': FieldValue.serverTimestamp()
  });

  // 2. إرسال الإشعار للمرافق مباشرة عبر FCM
  try {
    final patientDoc = await firestore.collection('patients').doc(patientId).get();
    final caregiverId = patientDoc.data()?['caregiverId'];

    if (caregiverId != null) {
      final caregiverDoc = await firestore.collection('users').doc(caregiverId).get();
      final token = caregiverDoc.data()?['fcmToken'];
      
      if (token != null) {
        // استدعاء خدمة FCM الخاصة بك لإرسال الإشعار باستخدام التوكن
        await FcmService.sendPushMessage(
          familyToken: token, 
          title: title, 
          body: message, 
          type: type
        );
      }
    }
  } catch (e) {
    debugPrint("Error sending FCM: $e");
  }
}

  static Future<void> stop() async {
    FlutterBackgroundService().invoke(stopAction);
  }
}
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(title: "مُسعف", content: "يتم تتبع موقع التابع لضمان سلامته");
  }

  // حفظ التوكن فوراً
  String? token = await FirebaseMessaging.instance.getToken();
  final prefs = await SharedPreferences.getInstance();
  String? patientId = prefs.getString('patientId');
  final firestore = FirebaseFirestore.instance;

  if (patientId != null && token != null) {
    await firestore.collection('users').doc(patientId).update({'fcmToken': token});
  }

  service.on("startTracking").listen((event) async {
    patientId = event?["patientId"];
    if (patientId != null) await prefs.setString('patientId', patientId!);
  });

  service.on(PatientBackgroundService.stopAction).listen((event) {
    service.stopSelf();
  });

  if (patientId == null) return;

  // ==========================================
  // 🚀 إصلاحات الأداء (الذاكرة المؤقتة Caching)
  // ==========================================
  List<Map<String, dynamic>> cachedSafeZones = [];
  String? cachedCaregiverToken;
  DateTime lastBatteryCheck = DateTime.now().subtract(const Duration(minutes: 5));
  int currentBatteryLevel = 100;
  final battery = Battery();

  // 1. جلب التوكن الخاص بالمرافق مرة واحدة (إصلاح مسار users/patients)
  final patientDoc = await firestore.collection('users').doc(patientId).get();
  final caregiverId = patientDoc.data()?['caregiverId'];
  
  if (caregiverId != null) {
    final caregiverDoc = await firestore.collection('users').doc(caregiverId).get();
    cachedCaregiverToken = caregiverDoc.data()?['fcmToken'];
  }

  // 2. الاستماع للمناطق الآمنة وتخزينها محلياً (إيقاف استنزاف Firestore)
  firestore
      .collection('patients')
      .doc(patientId)
      .collection('safe_zones')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .listen((snapshot) {
    cachedSafeZones = snapshot.docs.map((doc) => doc.data()).toList();
  });

  // ==========================================
  // 🚀 دوال مساعدة (بدون تكرار)
  // ==========================================
  Future<void> addAlert(String title, String message, String type) async {
    await firestore.collection('patients').doc(patientId!).collection('alerts').add({
      'title': title, 
      'message': message, 
      'type': type, 
      'is_read': false, 
      'timestamp': FieldValue.serverTimestamp()
    });
  }

  Future<void> triggerPushNotification(String title, String message) async {
    if (cachedCaregiverToken != null) {
      await FcmService.sendPushMessage(
        familyToken: cachedCaregiverToken!, 
        title: title, 
        body: message, 
        type: 'alert'
      );
    }
  }

  // ==========================================
  // 🚀 التتبع الجغرافي الذكي
  // ==========================================
  int movementAlertCounter = 0;
  Position? lastOutsideAlertPosition;
  Position? lastSavedRoutePosition;
  bool? previousInsideState;

  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
  ).listen((position) async {
    try {
      // 3. تحديث البطارية كل 5 دقائق كحد أقصى
      if (DateTime.now().difference(lastBatteryCheck).inMinutes >= 5) {
        currentBatteryLevel = await battery.batteryLevel;
        lastBatteryCheck = DateTime.now();
      }

      // 4. حساب المنطقة من الذاكرة (0 Reads)
      bool isInsideZone = false;
      String zoneName = "";
      for (final data in cachedSafeZones) {
        if (Geolocator.distanceBetween(position.latitude, position.longitude, data['latitude'], data['longitude']) <= (data['radius'] as num).toDouble()) {
          isInsideZone = true;
          zoneName = data['name'] ?? '';
          break;
        }
      }
      await firestore.collection('patients').doc(patientId).set({
        'last_latitude': position.latitude, 'last_longitude': position.longitude,
        'battery_level': await battery.batteryLevel,
        'is_safe': isInsideZone,
        'status': isInsideZone ? 'آمن - داخل $zoneName' : 'خارج المنطقة الآمنة',
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // حفظ المسار بفلترة 50م
      if (lastSavedRoutePosition == null || Geolocator.distanceBetween(lastSavedRoutePosition!.latitude, lastSavedRoutePosition!.longitude, position.latitude, position.longitude) >= 50) {
        lastSavedRoutePosition = position;
        await firestore.collection('patients').doc(patientId).collection('route_history').add({
          'latitude': position.latitude, 'longitude': position.longitude, 'speed': position.speed,
          'timestamp': FieldValue.serverTimestamp(),
          'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 10))),
        });
      }

      if (previousInsideState != null) {
        final String mapLink = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
        Future<void> addAlert(String title, String message, String type) async {
          final alertsRef = firestore.collection('patients').doc(patientId).collection('alerts');
          await alertsRef.add({'title': title, 'message': message, 'type': type, 'is_read': false, 'timestamp': FieldValue.serverTimestamp()});
        }

        Future<void> triggerPushNotification(String title, String message) async {
  try {
    // 1. اقرأ من مجموعة 'patients' للحصول على الـ caregiverId
    final patientDoc = await firestore.collection('patients').doc(patientId).get();
    
    if (!patientDoc.exists) {
      debugPrint("Patient document not found!");
      return;
    }

    final caregiverId = patientDoc.data()?['caregiverId'];

    if (caregiverId != null) {
      // 2. الآن استخدم الـ caregiverId لجلب التوكن من مجموعة 'users'
      final caregiverDoc = await firestore.collection('users').doc(caregiverId).get();
      final token = caregiverDoc.data()?['fcmToken'];
      
      if (token != null) {
        await FcmService.sendPushMessage(
          familyToken: token, 
          title: title, 
          body: message, 
          type: 'alert'
        );
      } else {
        debugPrint("Caregiver has no FCM token.");
      }
    } else {
      debugPrint("No caregiverId found for this patient.");
    }
  } catch (e) {
    debugPrint("Error in triggerPushNotification: $e");
  }
}

        if (previousInsideState == true && !isInsideZone) {
          lastOutsideAlertPosition = position;
          movementAlertCounter = 0;
          String msg = 'تحذير: المريض خرج من المنطقة الآمنة! الموقع: $mapLink';
          await addAlert('خروج', msg, 'exit');
          await triggerPushNotification('خروج من المنطقة', msg);
          await firestore.collection('patients').doc(patientId).set({'insideZone': false}, SetOptions(merge: true));
        } else if (!previousInsideState! && isInsideZone) {
          String msg = 'عاد المريض لـ $zoneName بأمان. الموقع: $mapLink';
          await addAlert('عودة', msg, 'entry');
          await triggerPushNotification('عودة للمنطقة', msg);
          await firestore.collection('patients').doc(patientId).set({'insideZone': true}, SetOptions(merge: true));
        } else if (!isInsideZone && lastOutsideAlertPosition != null && Geolocator.distanceBetween(lastOutsideAlertPosition!.latitude, lastOutsideAlertPosition!.longitude, position.latitude, position.longitude) >= 10) {
          lastOutsideAlertPosition = position;
          movementAlertCounter++;
          String msg = 'المريض يتحرك بالخارج! الموقع: $mapLink';
          await addAlert('تنبيه حركة', msg, 'outside_movement');
          if (movementAlertCounter >= 10) {
            movementAlertCounter = 0;
            await triggerPushNotification('تنبيه حركة بالخارج', msg);
          }
        }
      }
      previousInsideState = isInsideZone;
    } catch (e) { debugPrint("Error: $e"); }
  });
}