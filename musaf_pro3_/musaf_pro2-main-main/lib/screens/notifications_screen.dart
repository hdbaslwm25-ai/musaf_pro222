import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/fcm_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  final Color musafRed = const Color(0xFFB7131A);

  Future<void> _markAsTaken(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('medications')
          .doc(docId)
          .update({
            'lastTakenDate': DateTime.now(),
            'isTakenToday': true,
            'isFamilyNotified': false,
          });
    } catch (e) {
      debugPrint("Error updating medication: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'التنبيهات الصحية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medications')
            .where('userId', isEqualTo: userId)
            .where('isTakenToday', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState("لا توجد تنبيهات عاجلة حالياً");
          }

          final now = DateTime.now();
          final incomingNotifications = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            var timesData = data['times'];
            List times = (timesData is List)
                ? timesData
                : [timesData.toString()];

            for (var timeStr in times) {
              try {
                List<String> parts = timeStr.trim().split(':');
                int hour = int.parse(parts[0]);
                int minute = int.parse(parts[1]);
                final medTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  hour,
                  minute,
                );

                int diff = medTime.difference(now).inMinutes;
                if (diff >= -30 && diff <= 60) return true;
              } catch (e) {
                continue;
              }
            }
            return false;
          }).toList();

          if (incomingNotifications.isNotEmpty && userId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                DocumentSnapshot patientDoc = await FirebaseFirestore.instance
                    .collection('patients')
                    .doc(userId)
                    .get();
                String? familyToken =
                    (patientDoc.data()
                        as Map<String, dynamic>?)?['familyFcmToken'];

                for (var med in incomingNotifications) {
                  var data = med.data() as Map<String, dynamic>;
                  bool isFamilyNotified = data['isFamilyNotified'] ?? false;

                  DateTime medTime = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    int.parse(data['times'][0].toString().split(':')[0]),
                    int.parse(data['times'][0].toString().split(':')[1]),
                  );

                  int diff = now.difference(medTime).inMinutes;

                  if (!isFamilyNotified &&
                      diff >= 10 &&
                      diff <= 20 &&
                      familyToken != null) {
                    await FcmService.sendPushMessage(
                      familyToken: familyToken,
                      title: '⚠️ تنبيه: تأخر المريض!',
                      body:
                          'المريض تأخر عن أخذ جرعة ${data['medName']} لمدة 10 دقائق.',
                      type: 'medication_delay',
                    );

                    String alertId = DateTime.now().millisecondsSinceEpoch
                        .toString();
                    await FirebaseFirestore.instance
                        .collection('patients')
                        .doc(userId)
                        .collection('alerts')
                        .doc(alertId)
                        .set({
                          'id': alertId,
                          'type': 'medication_delay',
                          'message':
                              'المريض تأخر عن أخذ جرعة: ${data['medName']}',
                          'time_string':
                              '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
                          'timestamp': FieldValue.serverTimestamp(),
                          'is_read': false,
                        });

                    await FirebaseFirestore.instance
                        .collection('medications')
                        .doc(med.id)
                        .update({'isFamilyNotified': true});
                  }
                }
              } catch (e) {
                debugPrint("Error: $e");
              }
            });
          }

          if (incomingNotifications.isEmpty)
            return _buildEmptyState("لا توجد تنبيهات نشطة الآن");

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: incomingNotifications.length,
            itemBuilder: (context, index) {
              var med = incomingNotifications[index];
              var data = med.data() as Map<String, dynamic>;
              return Card(
                elevation: 2,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: musafRed, width: 8),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 5,
                      ),
                      // الصح أصبح في الجهة اليمنى (leading)
                      leading: IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 30,
                        ),
                        onPressed: () => _markAsTaken(med.id),
                      ),
                      title: Text(
                        'حان وقت: ${data['medName']}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'اضغط علامة الصح عند أخذ الجرعة',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12),
                      ),
                      // الجرس أصبح في الجهة اليسرى (trailing)
                      trailing: Icon(
                        Icons.notifications_active,
                        color: musafRed,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 60,
            color: Colors.green.withOpacity(0.3),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
