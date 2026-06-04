import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
  List<TimeOfDay> _notificationTimes = [const TimeOfDay(hour: 8, minute: 0)];
  bool _isSaving = false;

  final List<String> _weekDays = [
    'السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة',
  ];

  Future<void> _requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _saveMedication() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم الدواء')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _requestNotificationPermission();
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      String? fcmToken = await FirebaseMessaging.instance.getToken().catchError((e) => null);

      if (userId != null) {
        await FirebaseFirestore.instance.collection('medications').add({
          'userId': userId,
          'fcmToken': fcmToken ?? "",
          'medName': _nameController.text,
          'timesPerDay': _timesPerDay,
          'selectedDays': _selectedDays,
          'times': _notificationTimes.map((t) => '${t.hour}:${t.minute}').toList(),
          'isTakenToday': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        for (int i = 0; i < _notificationTimes.length; i++) {
          final time = _notificationTimes[i];
          int notificationId = _nameController.text.hashCode + i;
          await NotificationService.scheduleDailyNotification(
            id: notificationId,
            title: '💊 حان موعد جرعة دواء',
            body: 'تذكير طبي: حان الآن وقت أخذ دواء [ ${_nameController.text} ]',
            hour: time.hour,
            minute: time.minute,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الجدول وتفعيل التنبيهات بنجاح ✅', style: TextStyle(color: Colors.white))));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(color: Colors.white))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // تم تصغير حجم الخطوط هنا
    final labelStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800);

    return Theme(
      data: Theme.of(context).copyWith(
        chipTheme: const ChipThemeData(
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(fontSize: 12),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: const Text('إضافة دواء جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('اسم الدواء', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "مثلاً: بنادول",
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Text('كم مرة في اليوم؟', style: labelStyle),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [1, 2, 3].map((num) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text('$num مرات', style: TextStyle(fontSize: 12, color: _timesPerDay == num ? Colors.white : Colors.black)),
                    selected: _timesPerDay == num,
                    selectedColor: musafRed,
                    onSelected: (val) => setState(() {
                      _timesPerDay = num;
                      _notificationTimes = List.generate(num, (i) => const TimeOfDay(hour: 8, minute: 0));
                    }),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              Text('أيام التكرار', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6, alignment: WrapAlignment.end,
                children: ['الكل', ..._weekDays].map((day) {
                  bool isSelected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black)),
                    selected: isSelected,
                    selectedColor: musafRed,
                    onSelected: (val) => setState(() {
                      if (day == 'الكل') _selectedDays = ['الكل'];
                      else {
                        _selectedDays.remove('الكل');
                        val ? _selectedDays.add(day) : _selectedDays.remove(day);
                        if (_selectedDays.isEmpty) _selectedDays = ['الكل'];
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text('أوقات التنبيه', style: labelStyle),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: List.generate(_timesPerDay, (index) => ListTile(
                    dense: true,
                    title: Text("الجرعة ${index + 1}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: musafRed.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(_notificationTimes[index].format(context), style: TextStyle(color: musafRed, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _notificationTimes[index]);
                      if (picked != null) setState(() => _notificationTimes[index] = picked);
                    },
                  )),
                ),
              ),
              const SizedBox(height: 30),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity, height: 45,
                      child: CustomButton(text: 'حفظ الجدول', isPrimary: true, backgroundColor: musafRed, onPressed: _saveMedication),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}