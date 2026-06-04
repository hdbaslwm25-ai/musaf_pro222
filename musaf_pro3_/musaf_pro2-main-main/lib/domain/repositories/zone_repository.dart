import '../entities/safe_zone.dart';

/// [ZoneRepository] هو العقد (Contract) الذي يحدد العمليات المطلوبة من طبقة البيانات.
abstract class ZoneRepository {
  
  Future<List<SafeZone>> getSafeZones(String patientId);
  Future<void> addSafeZone(String patientId, SafeZone zone);
  Future<void> deleteSafeZone(String patientId, String zoneId);
  Future<void> updateZoneStatus(String patientId, String zoneId, bool isActive);

Stream<List<Map<String, dynamic>>> getPatientAlertsStream(String patientId);
Future<void> markAlertAsRead(String patientId, String alertId);
Future<void> deleteAllAlerts(String patientId);
Future<void> deleteSingleAlert(String patientId, String alertId);
  Future<String> getPatientName(String patientId);

  Future<void> updatePatientStatus({
    required String patientId,
    required double latitude,
    required double longitude,
    required int batteryLevel,
    required bool isSafe,
    required String statusText,
  });
  Future<void> saveRoutePoint({
    required String patientId,
    required double latitude,
    required double longitude,
    required double speed,
  });

  /// تحديث حالة التتبع الجغرافي للمريض (داخل/خارج المنطقة)
  Future<void> updatePatientTrackingState({
    required String patientId,
    required bool insideZone,
    required String currentZoneName,
    required bool outsideZoneActive,
  });
  // =========================
  // إضافات التتبع وتحديثات المناطق
  // =========================
  
 
  

  Future<void> updateZoneEvent({
    required String patientId,
    required bool insideZone,
  });

// أضيفي هاتين الدالتين
Future<void> updateSafeZone(String patientId, SafeZone zone);
Stream<List<SafeZone>> watchSafeZones(String patientId); // 👈 للطفل
Future<void> deleteAllSafeZones(String patientId); // 🚀 للحذف السريع
  // --- إدارة التنبيهات الذكية ---

  Future<void> sendAlert(String patientId, String message);
  
  
}