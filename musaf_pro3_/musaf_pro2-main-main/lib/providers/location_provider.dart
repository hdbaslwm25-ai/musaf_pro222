import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/safe_zone.dart';
import '../../domain/repositories/zone_repository.dart';

enum AppConnectionState { loading, connected, error }
class CaregiverPatientProvider with ChangeNotifier {
  final ZoneRepository _zoneRepository;
  
AppConnectionState _connectionState = AppConnectionState.loading;
  AppConnectionState get connectionState => _connectionState;

  // حالة المريض (مستقاة من Firestore)
  Map<String, dynamic>? _patientData;
  Map<String, dynamic>? get patientData => _patientData;

  String _patientName = "التابع";
  String get patientName => _patientName;

  List<SafeZone> _safeZones = [];
  List<SafeZone> get safeZones => _safeZones;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _patientSubscription;

  CaregiverPatientProvider(this._zoneRepository);

  // --- إدارة الاتصال ---
  void startListeningToPatient(String patientId) {
    _connectionState = AppConnectionState.loading;
    _patientSubscription?.cancel();
    
    // الاستماع لمسار المريض الجديد الموحد
    _patientSubscription = FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          _patientData = snapshot.data();
          _connectionState = AppConnectionState.connected;
          notifyListeners();
        }
        // داخل CaregiverPatientProvider -> دالة startListeningToPatient

// تأكدي من وجود هذا الجزء لتغذية الخريطة بإحداثيات السيرفر:
if (_patientData != null && _patientData!['last_latitude'] != null) {
 // يكفي فقط أن تضعي هذا السطر لتحديث الواجهة:
_patientData = snapshot.data();
notifyListeners();

// ❌ وقومي بحذف أي كود يحاول عمل:
// _currentPosition = Position(...)
}
      },
      onError: (error) {
        _connectionState = AppConnectionState.error;
        notifyListeners();
      },
    );
    
    fetchPatientName(patientId);
    loadSafeZones(patientId);
  }

  // --- القراءة وإدارة المناطق ---
  Future<void> fetchPatientName(String patientId) async {
    try {
      _patientName = await _zoneRepository.getPatientName(patientId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching name: $e");
    }
  }

  Future<void> loadSafeZones(String patientId) async {
    try {
      final zones = await _zoneRepository.getSafeZones(patientId);
      // 🚀 التعديل: إزالة الـ map لأنها ترجع List<SafeZone> بالفعل
      _safeZones = zones; 
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading zones: $e");
    }
  }

  // --- التنبيهات (القراءة فقط) ---
  Stream<List<Map<String, dynamic>>> getAlertsStream(String patientId) {
    return _zoneRepository.getPatientAlertsStream(patientId);
  }

  Future<void> markAsRead(String patientId, String alertId) async {
    await _zoneRepository.markAlertAsRead(patientId, alertId);
  }

  Future<void> clearAllAlerts(String patientId) async {
    await _zoneRepository.deleteAllAlerts(patientId);
  }
  Future<void> deleteSafeZoneById(String zoneId, String patientId) async {
    try {
      await _zoneRepository.deleteSafeZone(patientId, zoneId);
      await loadSafeZones(patientId);
    } catch (e) {
      debugPrint("خطأ في حذف المنطقة: $e");
    }
  }

  // --- إدارة المناطق (CRUD) ---
  // (تم الإبقاء على منطق إضافة وحذف المناطق لأنها تظل من صلاحيات المرافق)
  // دالة حذف جميع المناطق (التعديل المطلوب)
  Future<void> deleteAllZones(String patientId) async {
    for (final zone in _safeZones) {
      await _zoneRepository.deleteSafeZone(patientId, zone.id);
    }
    await loadSafeZones(patientId);
  }

  // دالة الإضافة مع شروط التداخل (تم دمجها كما طلبت)
  Future<String> addNewSafeZone({
    required String patientId,
    required String name,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    try {
      if (name.trim().isEmpty) return "يرجى إدخال اسم صالح للمنطقة! ⚠️";
      if (latitude == 0.0 && longitude == 0.0) return "إحداثيات غير صالحة! ⚠️";
      if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0)
        return "إحداثيات خارج النطاق! ⚠️";

      // فحص التداخل
      for (var existingZone in _safeZones) {
        double distance = Geolocator.distanceBetween(
            latitude, longitude, existingZone.latitude, existingZone.longitude);
        
        if (distance < 1.0) return "هذه المنطقة مضافة بالفعل! ⚠️";
        if (distance < (radius + existingZone.radius)) {
          return "خطأ: النطاق يتداخل مع منطقة آمنة أخرى! ⚠️";
        }
      }

      final newZone = SafeZone(
        id: '', name: name.trim(), latitude: latitude,
        longitude: longitude, radius: radius, isActive: true,
      );
      
      await _zoneRepository.addSafeZone(patientId, newZone);
      await loadSafeZones(patientId);
      return "تم إضافة المنطقة بنجاح ✅";
    } catch (e) {
      return "حدث خطأ غير متوقع: $e";
    }
  }
 // 🐛 إصلاح دالة الحذف (استخدام zone.id بدلاً من index)
  Future<void> deleteSafeZone(int index, String patientId) async {
    if (index >= 0 && index < _safeZones.length) {
      final String zoneId = _safeZones[index].id; // 👈 نأخذ الـ ID الصحيح
      await _zoneRepository.deleteSafeZone(patientId, zoneId);
      await loadSafeZones(patientId);
    }
  }
  Future<void> deleteSingleAlert(String patientId, String alertId) async {
    try {
      await _zoneRepository.deleteSingleAlert(patientId, alertId);
      // لا نحتاج لـ notifyListeners() هنا لأن الواجهة تستمع مباشرة لـ Stream
    } catch (e) {
      debugPrint("خطأ في حذف التنبيه: $e");
    }
  }

  // 🚀 إضافة دالة التحديث
  // 🚀 النقطة 3: الحذف الكلي أصبح سريعاً جداً ويستهلك Request واحد فقط
  Future<void> deleteAllSafeZones(String patientId) async {
    await _zoneRepository.deleteAllSafeZones(patientId);
    await loadSafeZones(patientId);
  }

  // 🚀 النقطة 4: إضافة دالة التحديث
  Future<String> updateExistingSafeZone({
    required String patientId,
    required SafeZone oldZone,
    required String newName,
    required double newLatitude,
    required double newLongitude,
    required double newRadius,
  }) async {
    try {
      final updatedZone = SafeZone(
        id: oldZone.id,
        name: newName,
        latitude: newLatitude,
        longitude: newLongitude,
        radius: newRadius,
        isActive: oldZone.isActive,
        createdAt: oldZone.createdAt,
        createdBy: oldZone.createdBy,
      );

      await _zoneRepository.updateSafeZone(patientId, updatedZone);
      await loadSafeZones(patientId);
      return "تم التحديث بنجاح ✅";
    } catch (e) {
      return "حدث خطأ غير متوقع: $e";
    }
  }

  Future<void> toggleZoneStatus(int index, String patientId, bool isActive) async {
    final zone = _safeZones[index];
    await _zoneRepository.updateZoneStatus(patientId, zone.id, isActive);
    await loadSafeZones(patientId);
  }

  @override
  void dispose() {
    _patientSubscription?.cancel();
    super.dispose();
  }
}