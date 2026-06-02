import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class MyDoctorsScreen extends StatefulWidget {
  const MyDoctorsScreen({super.key});
  @override
  State<MyDoctorsScreen> createState() => _MyDoctorsScreenState();
}

class _MyDoctorsScreenState extends State<MyDoctorsScreen> {
  final Color primaryRed = const Color(0xFFB7131A);
  final Color surfaceColor = const Color(0xFFF7F9FE);
  String searchQuery = "";

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _appointmentController = TextEditingController();
  DateTime? _selectedAppointmentDate;

  Future<void> _scheduleAppointmentNotification(String doctorName) async {
    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();
    final DateTime scheduledTime = DateTime.now().add(
      const Duration(minutes: 1),
    );
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'doctor_appointments_channel',
      'مواعيد الأطباء',
      importance: Importance.max,
      priority: Priority.high,
    );
    await plugin.zonedSchedule(
      doctorName.hashCode,
      'تذكير بموعد طبي 🩺',
      'لديك موعد قادم مع د. $doctorName',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(android: android),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: surfaceColor,
        appBar: AppBar(
          // 🚀 كلمة أطبائي باللون الأبيض
          title: const Text(
            "أطبائي",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          backgroundColor: primaryRed,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showDoctorDialog,
          backgroundColor: primaryRed,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (val) => setState(() => searchQuery = val),
                decoration: InputDecoration(
                  hintText: "ابحث عن طبيب أو تخصص...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('doctors')
                    .where(
                      'userId',
                      isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs.where((doc) {
                    var d = doc.data() as Map<String, dynamic>;
                    return d['name'].toString().contains(searchQuery) ||
                        d['specialty'].toString().contains(searchQuery);
                  }).toList();
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, i) => _buildDoctorCard(docs[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final bool isExpired =
        d['appointmentTimestamp'] != null &&
        (d['appointmentTimestamp'] as Timestamp).toDate().isBefore(
          DateTime.now(),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: primaryRed.withOpacity(0.1),
                child: Icon(
                  isExpired ? Icons.check_circle : Icons.person,
                  color: isExpired ? Colors.green : primaryRed,
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "د. ${d['name']}",
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      d['specialty'] ?? '',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => FirebaseFirestore.instance
                    .collection('doctors')
                    .doc(doc.id)
                    .delete(),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // 🚀 إضافة عرض المستشفى (الموقع)
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: primaryRed),
              const SizedBox(width: 8),
              Text(
                d['hospital'] ?? 'غير محدد',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_month, size: 16, color: primaryRed),
              const SizedBox(width: 8),
              Text(
                isExpired ? "تمت الزيارة" : (d['appointment'] ?? ''),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isExpired)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () =>
                    launchUrl(Uri(scheme: 'tel', path: d['phone'])),
                child: const Text(
                  "اتصال سريع",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDoctorDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("إضافة طبيب"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "اسم الطبيب"),
                ),
                TextField(
                  controller: _specialtyController,
                  decoration: const InputDecoration(labelText: "التخصص"),
                ),
                TextField(
                  controller: _hospitalController,
                  decoration: const InputDecoration(labelText: "المستشفى"),
                ),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "رقم الهاتف"),
                ),
                TextField(
                  controller: _appointmentController,
                  readOnly: true,
                  onTap: () async {
                    DateTime? date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _selectedAppointmentDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          _appointmentController.text =
                              "${date.year}/${date.month}/${date.day} - ${time.format(context)}";
                        });
                      }
                    }
                  },
                  decoration: const InputDecoration(labelText: "موعد الزيارة"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('doctors').add({
                  'name': _nameController.text,
                  'specialty': _specialtyController.text,
                  'hospital': _hospitalController.text,
                  'phone': _phoneController.text,
                  'appointment': _appointmentController.text,
                  'userId': FirebaseAuth.instance.currentUser?.uid,
                  'appointmentTimestamp': _selectedAppointmentDate != null
                      ? Timestamp.fromDate(_selectedAppointmentDate!)
                      : null,
                });
                await _scheduleAppointmentNotification(_nameController.text);
                if (mounted) Navigator.pop(context);
              },
              child: const Text("حفظ", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
