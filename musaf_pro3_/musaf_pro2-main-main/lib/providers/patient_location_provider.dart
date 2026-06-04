import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientLocationProvider extends ChangeNotifier {
  // الحالة الحالية للمريض (تُحدث عبر Stream)
  Map<String, dynamic>? _patientData;
  Map<String, dynamic>? get patientData => _patientData;

  StreamSubscription<DocumentSnapshot>? _subscription;

  // بدء مراقبة بيانات المريض من الفايربيس (قراءة فقط)
  void startListeningToPatientState(String patientId) {
    _subscription?.cancel();
    
    _subscription = FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _patientData = snapshot.data() as Map<String, dynamic>;
        notifyListeners(); // إشعار الواجهة بتحديث البيانات
      }
    });
  }

  // دوال عرض البيانات (Getters سهلة للواجهة)
  bool get isInsideZone => _patientData?['insideZone'] ?? true;
  String get statusText => _patientData?['status'] ?? 'جاري التحديث...';
  double? get latitude => _patientData?['last_latitude'];
  double? get longitude => _patientData?['last_longitude'];
  int get batteryLevel => _patientData?['battery_level'] ?? 100;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}