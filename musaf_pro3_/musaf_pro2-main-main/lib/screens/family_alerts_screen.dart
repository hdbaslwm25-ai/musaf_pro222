import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/location_provider.dart' hide ConnectionState;

class FamilyAlertsScreen extends StatelessWidget {
  final String patientId;
  const FamilyAlertsScreen({super.key, required this.patientId});

  // --- دالة تنسيق الوقت من Firestore Timestamp ---
 // 🚀 الملاحظة 10: تنسيق ذكي للوقت
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'الآن';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'م' : 'ص';
      final minute = date.minute.toString().padLeft(2, '0');
      final timeString = '$hour:$minute $amPm';

      if (difference.inDays == 0 && now.day == date.day) {
        if (difference.inMinutes < 1) return 'الآن';
        if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
        return 'اليوم، $timeString';
      } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != date.day)) {
        return 'أمس، $timeString';
      } else {
        return '${date.year}/${date.month}/${date.day} $timeString';
      }
    }
    return '';
  }

  void _showDeleteAllConfirmation(BuildContext context, CaregiverPatientProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("حذف السجل؟", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        content: const Text("هل أنت متأكد من مسح جميع التنبيهات؟", textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
           // داخل ElevatedButton الخاص بالحذف
onPressed: () async {
  await provider.clearAllAlerts(patientId);
  if (context.mounted) Navigator.pop(context);
},
            child: const Text("حذف الكل", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locProvider = Provider.of<CaregiverPatientProvider>(context, listen: false);
    final themePrimaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("سجل التنبيهات", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 28),
            onPressed: () => _showDeleteAllConfirmation(context, locProvider),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: locProvider.getAlertsStream(patientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: themePrimaryColor));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final alerts = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Dismissible(
                key: Key(alert['id']),
                direction: DismissDirection.endToStart, // 🚀 الاتجاه الصحيح للعربية (من اليسار لليمين)
                confirmDismiss: (direction) async {
                  // 🚀 إضافة حماية من الحذف بالخطأ
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        title: const Text("حذف التنبيه", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        content: const Text("هل تريد حذف هذا التنبيه من السجل؟", style: TextStyle(fontFamily: 'Cairo')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("حذف", style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      );
                    },
                  );
                },
                // تأكدي أن الدالة في الـ Provider اسمها deleteSingleAlert
                onDismissed: (_) => locProvider.deleteSingleAlert(patientId, alert['id']), 
                background: _buildDismissBackground(),
                child: _buildNotificationItem(alert, locProvider, themePrimaryColor),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> alert, CaregiverPatientProvider provider, Color primaryColor) {
    bool isRead = alert['is_read'] ?? false;
    Color alertColor = _getAlertColor(alert['type'], primaryColor);
    
    // جلب الوقت بعد تحويله
    String displayTime = _formatTimestamp(alert['timestamp']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border(right: BorderSide(color: alertColor, width: 5)),
        boxShadow: [
          BoxShadow(
            color: isRead ? Colors.transparent : Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: alertColor.withOpacity(0.1),
          child: Icon(_getAlertIcon(alert['type'], primaryColor), color: alertColor, size: 24),
        ),
        title: Text(
          alert['message'] ?? 'تنبيه طوارئ جديد',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 14,
            height: 1.4,
            color: isRead ? Colors.black54 : Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                displayTime, 
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
       onTap: () async {
  if (!isRead) {
    try {
      await provider.markAsRead(patientId, alert['id']);
    } catch (e) {
      debugPrint("خطأ في تحديث حالة القراءة: $e");
    }
  }
},
      ),
    );
  }

  Color _getAlertColor(String? type, Color primaryColor) {
    switch (type) {
      case 'exit':
        return AppColors.error; // لون أحمر
      case 'entry':
        return Colors.green;
      case 'battery':
        return Colors.orange;
      case 'signal_loss': 
        return Colors.grey.shade600;
      case 'outside_movement': // 🚀 التنبيه الجديد الذي أضفناه في الـ Service
        return Colors.deepOrange;
      case 'medication_delay':
      case 'medication_reminder': 
        return Colors.teal; 
      case 'accident_fall':
        return Colors.red.shade900;
      default:
        return primaryColor;
    }
  }

  IconData _getAlertIcon(String? type, Color primaryColor) {
    switch (type) {
      case 'exit':
        return Icons.directions_run_rounded; // تغيير أيقونة الخروج لتكون معبرة أكثر
      case 'entry':
        return Icons.home_rounded; 
      case 'battery':
        return Icons.battery_alert_rounded;
      case 'signal_loss':
        return Icons.wifi_off_rounded;
      case 'outside_movement': // 🚀 أيقونة التنبيه الجديد
        return Icons.transfer_within_a_station_rounded;
      case 'medication_delay':
      case 'medication_reminder': 
        return Icons.medication_rounded; 
      case 'accident_fall':
        return Icons.personal_injury_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      alignment: Alignment.centerRight, // 🚀 محاذاة لليمين لتناسب السحب في العربية
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.error, 
        borderRadius: BorderRadius.circular(15)
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_forever_rounded, color: Colors.white, size: 26),
          SizedBox(width: 8),
          Text("حذف التنبيه", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "لا توجد تنبيهات حالياً", 
            style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          Text(
            "سيتم عرض كافة التحديثات وتنبيهات الطوارئ هنا", 
            style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Cairo', fontSize: 13),
          ),
        ],
      ),
    );
  }
}