import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:intl/date_symbol_data_local.dart';
import 'package:musaf_pro/screens/medications_screen.dart';
import 'dart:math';

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

  final List<IconData> _medIcons = [
    Icons.medication,
    Icons.medical_services,
    Icons.vaccines,
    Icons.local_pharmacy,
  ];

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
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String currentDayName = _getArabicDayName(_selectedDate);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black87,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'الأدوية',
            style: TextStyle(
              color: Color(0xFFB7131A),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 5.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الأدوية اليومية',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  formattedDateText,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned(
                          right: -20,
                          child: Opacity(
                            opacity: 0.2,
                            child: Icon(
                              Icons.medical_services,
                              size: 150,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add, color: Colors.white, size: 40),
                            SizedBox(height: 5),
                            Text(
                              'إضافة دواء',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
                    List<Widget> dailyMedCards = [];

                    for (var med in medications) {
                      var data = med.data() as Map<String, dynamic>;
                      var selectedDays = data['selectedDays'] ?? [];

                      // الفلترة حسب اليوم
                      if (selectedDays.contains('الكل') ||
                          selectedDays.contains(currentDayName)) {
                        var times = data['times'] ?? [];
                        var takenDates = data['takenDates']?[dateKey] ?? [];
                        for (int i = 0; i < times.length; i++) {
                          dailyMedCards.add(
                            _buildMedicationAppointmentCard(
                              med.id,
                              i,
                              data,
                              times[i],
                              takenDates.contains(i),
                              dateKey,
                              takenDates,
                            ),
                          );
                        }
                      }
                    }

                    return Stack(
                      children: [
                        Positioned(
                          right: 7,
                          top: 10,
                          bottom: 0,
                          child: Container(width: 2, color: Colors.grey[300]),
                        ),
                        Column(
                          children: dailyMedCards.isEmpty
                              ? [
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text('لا مواعيد لهذا اليوم'),
                                    ),
                                  ),
                                ]
                              : dailyMedCards,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationAppointmentCard(
    String docId,
    int index,
    Map data,
    String time,
    bool isTaken,
    String dateKey,
    List takenIndices,
  ) {
    IconData randomIcon =
        _medIcons[data['medName'].hashCode % _medIcons.length];

    return Dismissible(
      key: Key(docId + index.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Icon(Icons.delete, color: Colors.white),
          ),
        ),
      ),
      onDismissed: (direction) => FirebaseFirestore.instance
          .collection('medications')
          .doc(docId)
          .delete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isTaken ? Colors.green : musafRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: isTaken ? Colors.transparent : musafRed,
                        width: 6,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(randomIcon, color: musafRed, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['medName'] ?? 'دواء',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              "عدد الجرعات: 1",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              isTaken ? 'تم التناول' : 'الموعد القادم: $time',
                              style: TextStyle(
                                color: isTaken ? Colors.green : musafRed,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isTaken
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isTaken ? Colors.green : Colors.grey,
                          size: 28,
                        ),
                        onPressed: () {
                          List newIndices = List.from(takenIndices);
                          if (isTaken)
                            newIndices.remove(index);
                          else
                            newIndices.add(index);
                          FirebaseFirestore.instance
                              .collection('medications')
                              .doc(docId)
                              .set({
                                'takenDates': {dateKey: newIndices},
                              }, SetOptions(merge: true));
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicDateSelector() {
    DateTime now = DateTime.now();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(7, (i) {
          DateTime date = now.add(Duration(days: i - 3));
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? musafRed : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontSize: 11,
            ),
          ),
          Text(
            date,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
