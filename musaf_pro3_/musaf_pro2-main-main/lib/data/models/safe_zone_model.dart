import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/safe_zone.dart';

class SafeZoneModel extends SafeZone {
  SafeZoneModel({
    required super.id,
    required super.name,
    required super.latitude,
    required super.longitude,
    required super.radius,
    super.isActive,
    super.createdBy,   
    super.createdAt,   
    super.updatedAt,
  });

  factory SafeZoneModel.fromMap(Map<String, dynamic> map, String docId) {
    return SafeZoneModel(
      id: docId,
      name: map['name'] ?? '',
      latitude: (map['latitude'] as num? ?? 0.0).toDouble(),
      longitude: (map['longitude'] as num? ?? 0.0).toDouble(),
      radius: (map['radius'] as num? ?? 0.0).toDouble(),
      isActive: map['isActive'] ?? true,
      createdBy: map['createdBy'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}