import 'package:flutter/material.dart';
import 'package:musaf_pro/core/theme/app_colors.dart';
import '../../domain/entities/safe_zone.dart';
import '../providers/location_provider.dart';

class ZoneCard extends StatelessWidget {
  final SafeZone zone; 
  final int index;
  final String patientId;
  final CaregiverPatientProvider locProvider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  // 🚀 تم إزالة اللون البنفسجي لتوحيد الهوية البصرية

  const ZoneCard({
    super.key,
    required this.zone,
    required this.index,
    required this.patientId,
    required this.locProvider,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color safeGreen = const Color(0xFF2E7D32); // اللون الأخضر المعتمد
    
    // 🚀 التعديل الذكي: التحقق مما إذا كان المريض داخل هذه المنطقة بالتحديد 
    // عبر قراءة نص الحالة القادم من السيرفر بدلاً من currentZoneId المحذوف
    String statusText = locProvider.patientData?['status']?.toString() ?? "";
    bool isPatientInsideNow = zone.isActive && statusText.contains(zone.name) && statusText.contains("آمن");

    return Dismissible(
      key: Key(zone.id), // استخدام الـ ID يكفي وهو أكثر أماناً من الـ index
      direction: DismissDirection.startToEnd, // السحب من اليمين لليسار
      background: _buildDeleteBackground(),
      confirmDismiss: (direction) async {
        onDelete(); // استدعاء نافذة التأكيد التي برمجناها في الشاشة الأب
        return false; 
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: zone.isActive ? const Color(0xFFFBFBFF) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPatientInsideNow 
                ? safeGreen.withValues(alpha: 0.7) 
                : (zone.isActive ? safeGreen.withValues(alpha: 0.2) : Colors.grey.shade200),
            width: isPatientInsideNow ? 2.5 : 1, 
          ),
          boxShadow: [
            if (isPatientInsideNow)
              BoxShadow(
                color: safeGreen.withValues(alpha: 0.15),
                blurRadius: 15,
                spreadRadius: 3,
              )
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onEdit, 
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Opacity(
              opacity: zone.isActive ? 1.0 : 0.6,
              child: Row(
                children: [
                  _buildIconIndicator(isPatientInsideNow, zone.isActive, safeGreen),
                  const SizedBox(width: 15),
                  _buildZoneDetails(zone.isActive),
                  Switch(
                    value: zone.isActive,
                    activeColor: safeGreen, // تم توحيد اللون للأخضر
                    onChanged: (val) => locProvider.toggleZoneStatus(index, patientId, val),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 👈 تم ضبط المحاذاة لتناسب السحب في الواجهة العربية (يظهر من اليمين)
  Widget _buildDeleteBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight, // 🚀 التعديل هنا
      decoration: BoxDecoration(
        color: AppColors.error, // استخدام الأحمر الخاص بمسعف
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.start, 
        children: [
          Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 26),
          SizedBox(width: 10),
          Text(
            "حذف المنطقة",
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildIconIndicator(bool isInside, bool active, Color activeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInside 
            ? activeColor.withValues(alpha: 0.15) 
            : (active ? activeColor.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(15),
        border: isInside ? Border.all(color: activeColor, width: 1.5) : null,
      ),
      child: Icon(
        _getIconForType(zone.name), 
        color: isInside ? activeColor : (active ? activeColor.withValues(alpha: 0.7) : Colors.grey), 
        size: 28
      ),
    );
  }

  Widget _buildZoneDetails(bool active) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zone.name, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 16, 
              fontFamily: 'Cairo', 
              color: active ? Colors.black87 : Colors.grey
            )
          ),
          const SizedBox(height: 4),
          Text(
            "نطاق الأمان: ${zone.radius.toInt()} متر", 
            style: TextStyle(
              color: Colors.grey.shade600, 
              fontSize: 13, 
              fontFamily: 'Cairo'
            )
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    final name = type.toLowerCase();
    if (name.contains('منزل') || name.contains('بيت')) return Icons.home_rounded;
    if (name.contains('مدرسة') || name.contains('جامعة')) return Icons.school_rounded;
    if (name.contains('حديقة') || name.contains('نادي')) return Icons.park_rounded;
    if (name.contains('مسجد')) return Icons.mosque_rounded;
    if (name.contains('مستشفى') || name.contains('عيادة') || name.contains('مركز')) return Icons.local_hospital_rounded;
    return Icons.location_on_rounded; 
  }
}