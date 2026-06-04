import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/location_provider.dart';
import '../widgets/location_status_panel.dart';
import '../widgets/patient_marker.dart';
import '../widgets/add_zone_dialog.dart';

class MapScreen extends StatefulWidget {
  final String patientId;
  const MapScreen({super.key, required this.patientId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  
  // 🚀 الألوان المعتمدة للتطبيق
  final Color musafRed = const Color(0xFFB7131A); 
  final Color safeGreen = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _initMapData();
  }
//      pro.startListeningToPatient(widget.patientId);

  void _initMapData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = context.read<CaregiverPatientProvider>();
      pro.loadSafeZones(widget.patientId);
      pro.startListeningToPatient(widget.patientId);
    });
  }

  Future<void> _navigateToPatient(double lat, double lng) async {
    final String googleMapsUrl = "google.navigation:q=$lat,$lng";
    final Uri uri = Uri.parse(googleMapsUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final String webUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Consumer<CaregiverPatientProvider>(
        builder: (context, locProvider, child) {
         // 🚀 قراءة الإحداثيات مباشرة من بيانات السيرفر بدون كائن Position
          final lat = locProvider.patientData?['last_latitude'];
          final lng = locProvider.patientData?['last_longitude'];
          
          LatLng? patientLatLng = (lat != null && lng != null) 
              ? LatLng((lat as num).toDouble(), (lng as num).toDouble()) 
              : null;

          // 🚀 جلب الحالة بالطريقة الصحيحة
          String statusText = locProvider.patientData?['status']?.toString() ?? "";
          bool connectionLost = locProvider.connectionState == AppConnectionState.error;
          bool hasSafeZones = locProvider.safeZones.isNotEmpty;
          
          // 🚀 حالة الخطر: خارج المنطقة، فقدان اتصال، أو لا توجد مناطق مضافة أصلاً
          bool isDanger = statusText.contains("خارج") || statusText.contains("⚠️") || connectionLost || !hasSafeZones;

          return Stack(
            children: [
              _buildMap(locProvider, patientLatLng, isDanger),
              if (patientLatLng != null) _buildFloatingControls(isDanger, patientLatLng),
              _buildBottomStatusPanel(statusText, isDanger),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(CaregiverPatientProvider locProvider, LatLng? patientLatLng, bool isDanger) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: patientLatLng ?? const LatLng(21.4225, 39.8262),
        initialZoom: 15.0,
        onLongPress: (tapPos, point) => _showAddZoneDialog(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.musaif.app',
        ),
        _buildSafeZonesLayer(locProvider, isDanger),
        _buildMarkersLayer(patientLatLng, isDanger),
      ],
    );
  }

  Widget _buildSafeZonesLayer(CaregiverPatientProvider locProvider, bool isDanger) {
    return CircleLayer(
      circles: locProvider.safeZones.map((zone) => CircleMarker(
        point: LatLng(zone.latitude, zone.longitude),
        // 🚀 تلوين الدائرة: أحمر للخطر، أخضر للأمان، رمادي للمناطق المعطلة
        color: zone.isActive 
            ? (isDanger ? musafRed.withValues(alpha: 0.1) : safeGreen.withValues(alpha: 0.15))
            : Colors.grey.withValues(alpha: 0.1),
        borderStrokeWidth: 2,
        borderColor: zone.isActive 
            ? (isDanger ? musafRed : safeGreen.withValues(alpha: 0.8))
            : Colors.grey,
        useRadiusInMeter: true,
        radius: zone.radius,
      )).toList(),
    );
  }

  Widget _buildMarkersLayer(LatLng? patientLatLng, bool isDanger) {
    return MarkerLayer(
      markers: [
        if (patientLatLng != null)
          Marker(
            point: patientLatLng,
            width: 120, height: 120,
            alignment: Alignment.topCenter,
            child: PatientMarker(isDanger: isDanger),
          ),
      ],
    );
  }
  
  void _showAddZoneDialog(LatLng point) {
    showDialog(
      context: context,
      builder: (ctx) => AddZoneDialog(point: point, patientId: widget.patientId),
    );
  }

  Widget _buildBottomStatusPanel(String status, bool isDanger) {
    return Positioned(
      bottom: 30, left: 15, right: 15,
      child: LocationStatusPanel(status: status, isDanger: isDanger),
    );
  }

  Widget _buildFloatingControls(bool isDanger, LatLng patientLatLng) {
    return Positioned(
      bottom: 130, right: 20, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isDanger) ...[
            FloatingActionButton.extended(
              heroTag: "nav",
              onPressed: () => _navigateToPatient(patientLatLng.latitude, patientLatLng.longitude),
              label: const Text("ملاحة سريعة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
              icon: const Icon(Icons.directions_car, color: Colors.white),
              backgroundColor: musafRed, 
            ),
            const SizedBox(height: 12),
          ],
          
          FloatingActionButton.extended(
            heroTag: "add_zone",
            onPressed: () {
              final centerPoint = _mapController.camera.center; 
              _showAddZoneDialog(centerPoint);
            },
            label: const Text("إضافة منطقة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
            icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
            // 🚀 زر الإضافة يكون أحمراً إذا لم تكن هناك مناطق/خطر، وأخضر إذا كان الوضع آمناً
            backgroundColor: isDanger ? musafRed : safeGreen, 
          ),
          const SizedBox(height: 12),
          
          FloatingActionButton(
            heroTag: "center",
            backgroundColor: Colors.white,
            onPressed: () => _mapController.move(patientLatLng, 17.0),
            // 🚀 لون الأيقونة يتغير ديناميكياً مع حالة المريض
            child: Icon(Icons.my_location_rounded, color: isDanger ? musafRed : safeGreen),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('التتبع اللحظي', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87)),
      centerTitle: true,
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black87),
    );
  }
}