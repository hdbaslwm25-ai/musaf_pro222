import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:musaf_pro/screens/medications_screen.dart';

class DailyMedicationsListScreen extends StatefulWidget {
  const DailyMedicationsListScreen({Key? key}) : super(key: key);

  @override
  State<DailyMedicationsListScreen> createState() =>
      _DailyMedicationsListScreenState();
}

class _DailyMedicationsListScreenState
    extends State<DailyMedicationsListScreen> {
  final Color musafRed = const Color(0xFFB7131A);
  DateTime _selectedDate = DateTime.now();
  late Stream<QuerySnapshot> _medicationsStream;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ar', null).then((_) {
      if (mounted) setState(() {});
    });
    _medicationsStream = _getMedicationsStream();
  }

  Stream<QuerySnapshot> _getMedicationsStream() {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  String _getArabicDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
        return 'الأحد';
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      default:
        return '';
    }
  }

  void _onDateSelected(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    String formattedDateText = DateFormat(
      'EEEE، d MMMM',
      'ar',
    ).format(_selectedDate);
    String dateKey = DateFormat(
      'yyyy-MM-dd',
    ).format(_selectedDate); // مفتاح خاص بكل يوم

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'الأدوية',
          style: TextStyle(
            color: musafRed,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الأدوية اليومية',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                formattedDateText,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildDynamicDateSelector(),
              const SizedBox(height: 25),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MedicationsScreen(),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'إضافة دواء',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              StreamBuilder<QuerySnapshot>(
                stream: _medicationsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                    return const Center(child: Text('لا توجد أدوية.'));

                  final medications = snapshot.data!.docs;
                  String selectedDayName = _getArabicDayName(_selectedDate);
                  List<Widget> dailyMedCards = [];

                  for (var med in medications) {
                    var data = med.data() as Map<String, dynamic>;
                    List<dynamic> selectedDays = data['selectedDays'] ?? [];
                    if (selectedDays.contains('الكل') ||
                        selectedDays.contains(selectedDayName)) {
                      List<dynamic> times = data['times'] ?? [];
                      // جلب مصفوفة التناول الخاصة بيوم محدد
                      Map<String, dynamic> takenDates =
                          data['takenDates'] ?? {};
                      List<dynamic> takenIndicesForDate =
                          takenDates[dateKey] ?? [];

                      for (int i = 0; i < times.length; i++) {
                        bool isTaken = takenIndicesForDate.contains(i);
                        dailyMedCards.add(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildMedicationAppointmentCard(
                              documentId: med.id,
                              index: i,
                              name: data['medName'] ?? 'دواء',
                              timeText: times[i],
                              isTaken: isTaken,
                              dateKey: dateKey,
                              takenIndices: takenIndicesForDate,
                            ),
                          ),
                        );
                      }
                    }
                  }
                  return Column(
                    children: dailyMedCards.isEmpty
                        ? [const Text('لا مواعيد لهذا اليوم')]
                        : dailyMedCards,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationAppointmentCard({
    required String documentId,
    required int index,
    required String name,
    required String timeText,
    required bool isTaken,
    required String dateKey,
    required List<dynamic> takenIndices,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          List<dynamic> newIndices = List.from(takenIndices);
          if (isTaken)
            newIndices.remove(index);
          else
            newIndices.add(index);
          // تحديث الحالة الخاصة بتاريخ اليوم فقط
          FirebaseFirestore.instance
              .collection('medications')
              .doc(documentId)
              .set({
                'takenDates': {dateKey: newIndices},
              }, SetOptions(merge: true));
        },
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            children: [
              Icon(
                isTaken ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isTaken ? Colors.green : Colors.grey,
                size: 30,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      isTaken ? 'تم التناول' : 'الموعد: $timeText',
                      style: TextStyle(
                        color: isTaken ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicDateSelector() {
    DateTime now = DateTime.now();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(5, (i) {
          DateTime date = now.add(Duration(days: i - 2));
          return GestureDetector(
            onTap: () => _onDateSelected(date),
            child: _buildDatePill(
              DateFormat('EEEE', 'ar').format(date).replaceFirst('يوم ', ''),
              DateFormat('d').format(date),
              date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDatePill(String day, String date, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: isSelected ? musafRed : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontSize: 13,
            ),
          ),
          Text(
            date,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
