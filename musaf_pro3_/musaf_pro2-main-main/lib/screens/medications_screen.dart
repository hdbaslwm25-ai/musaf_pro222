import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 🚀 استدعاء خدمة الإشعارات المحلية والزر المخصص
import 'package:musaf_pro/services/notification_service.dart';
import 'package:musaf_pro/widgets/custom_button.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final Color musafRed = const Color(0xFFB7131A);
  final TextEditingController _nameController = TextEditingController();

  int _timesPerDay = 1;
  List<String> _selectedDays = ['الكل'];
  List<TimeOfDay> _notificationTimes = [TimeOfDay.now()];
  bool _isSaving = false;

  final List<String> _weekDays = [
    'السبت',
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  // دالة طلب إذن التنبيهات من النظام (لم تُمس ✅)
  Future<void> _requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('حالة الإذن: ${settings.authorizationStatus}');
  }

  // ✅ دالة الحفظ المحدثة بالجدولة المحلية الذكية لمنع التعليق وضمان الرنين
  Future<void> _saveMedication() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال اسم الدواء', textAlign: TextAlign.right),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. طلب الإذن أولاً
      await _requestNotificationPermission();

      String? userId = FirebaseAuth.instance.currentUser?.uid;

      // 2. محاولة جلب التوكن (مع تجنب التعليق إذا فشل)
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint("فشل جلب التوكن: $e");
      }

      if (userId != null) {
        // 3. الحفظ في Firestore
        await FirebaseFirestore.instance.collection('medications').add({
          'userId': userId,
          'fcmToken': fcmToken ?? "", // حفظ نص فارغ إذا لم يتوفر التوكن
          'medName': _nameController.text,
          'timesPerDay': _timesPerDay,
          'selectedDays': _selectedDays.contains('الكل')
              ? ['الكل']
              : _selectedDays,
          'times': _notificationTimes
              .map((t) => '${t.hour}:${t.minute}')
              .toList(),
          'isTakenToday': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 🚀 الخطوة السحرية: جدولة المنبهات محلياً داخل النظام فوراً لكل جرعة
        for (int i = 0; i < _notificationTimes.length; i++) {
          final time = _notificationTimes[i];

          // توليد معرف رقمي فريد لكل جرعة لمنع تداخل الإشعارات
          int notificationId = _nameController.text.hashCode + i;

          await NotificationService.scheduleDailyNotification(
            id: notificationId,
            title: '💊 حان موعد جرعة دواء',
            body:
                'تذكير طبي: حان الآن وقت أخذ دواء [ ${_nameController.text} ]',
            hour: time.hour,
            minute: time.minute,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم حفظ الجدول وتفعيل منبهات الجهاز بنجاح ✅',
                textAlign: TextAlign.right,
              ),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Error saving medication: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحفظ: $e', textAlign: TextAlign.right),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'إضافة جدول دواء',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'اسم الدواء',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _nameController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(hintText: "مثلاً: بنادول"),
            ),
            const SizedBox(height: 25),

            const Text(
              'كم مرة في اليوم؟',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [1, 2, 3]
                  .map(
                    (num) => Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: ChoiceChip(
                        label: Text('$num مرات'),
                        selected: _timesPerDay == num,
                        selectedColor: musafRed.withOpacity(0.2),
                        onSelected: (val) {
                          setState(() {
                            _timesPerDay = num;
                            _notificationTimes = List.generate(
                              num,
                              (index) =>
                                  TimeOfDay(hour: 8 + (index * 4), minute: 0),
                            );
                          });
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 25),

            const Text(
              'أيام التكرار',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              direction: Axis.horizontal,
              alignment: WrapAlignment.end,
              children: ['الكل', ..._weekDays]
                  .map(
                    (day) => FilterChip(
                      label: Text(day),
                      selected: _selectedDays.contains(day),
                      onSelected: (val) {
                        setState(() {
                          if (day == 'الكل') {
                            _selectedDays = ['الكل'];
                          } else {
                            _selectedDays.remove('الكل');
                            val
                                ? _selectedDays.add(day)
                                : _selectedDays.remove(day);
                            if (_selectedDays.isEmpty) _selectedDays = ['الكل'];
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 25),

            const Text(
              'أوقات التنبيه',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...List.generate(
              _timesPerDay,
              (index) => ListTile(
                title: Text(
                  "وقت الجرعة ${index + 1}: ${_notificationTimes[index].format(context)}",
                ),
                trailing: Icon(Icons.access_time, color: musafRed),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _notificationTimes[index],
                  );
                  if (picked != null) {
                    setState(() => _notificationTimes[index] = picked);
                  }
                },
              ),
            ),

            const SizedBox(height: 40),

            // 🚀 استخدام الزر المخصص الموحد المتناسق مع بقية المشروع
            _isSaving
                ? Center(child: CircularProgressIndicator(color: musafRed))
                : CustomButton(
                    text: 'حفظ الجدول وتفعيل التنبيهات',
                    isPrimary: true,
                    backgroundColor: musafRed,
                    onPressed: _saveMedication,
                  ),
          ],
        ),
      ),
    );
  }
}
