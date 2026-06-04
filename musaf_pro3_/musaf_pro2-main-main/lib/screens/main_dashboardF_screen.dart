import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // تم إضافة مكتبة البروفايدر

import 'package:musaf_pro/screens/home_screen.dart'; 
import 'package:musaf_pro/screens/family_alerts_screen.dart';
import 'package:musaf_pro/screens/settingsF_screen.dart'; 
import 'package:musaf_pro/widgets/custom_bottom_nav.dart';
import '../providers/location_provider.dart'; // تأكدي من مسار ملف الـ LocationProvider

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 0;
  String _currentPatientId = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLinkedPatientId();
  }

  Future<void> _fetchLinkedPatientId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _currentPatientId = doc.data()?['linkedPatientId'] ?? "";
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("خطأ في جلب بيانات المريض: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // إظهار شاشة تحميل ريثما يتم جلب الـ ID
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FD),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
        ),
      );
    }

   final List<Widget> pages = [
      const HomeScreen(), 
      
      // 🚀 التعديل هنا: حماية شاشة التنبيهات من الانهيار إذا كان الـ ID فارغاً
      _currentPatientId.isEmpty 
          ? const Scaffold(
              backgroundColor: Color(0xFFF8F9FD),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_rounded, size: 80, color: Colors.black26),
                    SizedBox(height: 16),
                    Text("لا يوجد تابع مرتبط!", style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    SizedBox(height: 8),
                    Text("قم بربط تابع أولاً لعرض التنبيهات هنا.", style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
            )
          : FamilyAlertsScreen(patientId: _currentPatientId), 
          
      const CaregiverSettingsScreen(), 
    ];
    // 👈 التعديل السحري هنا: قراءة حالة المريض وتحديد اللون ديناميكياً
   // 👈 داخل دالة build في أسفل الملف
   // 👈 داخل دالة build في أسفل الملف
    return Consumer<CaregiverPatientProvider>(
      builder: (context, locProvider, child) {
        // 1. الألوان المعتمدة للتطبيق
        final Color musafRed = const Color(0xFFB7131A);
        final Color safeGreen = const Color(0xFF2E7D32);

        // 2. فحص الحالات
        bool connectionLost = locProvider.connectionState == AppConnectionState.error;
        String statusText = locProvider.patientData?['status']?.toString() ?? "";
        bool isDanger = statusText.contains("خارج") || connectionLost || statusText.contains("⚠️");
        
        // هل توجد مناطق أمان مضافة؟
        bool hasSafeZones = locProvider.safeZones.isNotEmpty; 

        // 3. المنطق: إذا لم تكن هناك مناطق أو كان هناك خطر -> أحمر مُسعف، وإلا -> أخضر
        Color dynamicActiveColor = (!hasSafeZones || isDanger) ? musafRed : safeGreen;

        // 🚀 الحل: إضافة PopScope للتحكم بزر الرجوع الخاص بالجوال
        return PopScope(
          // يسمح بالخروج من التطبيق فــــقــــط إذا كنا في التبويب الأول (الرئيسية index = 0)
          canPop: _currentIndex == 0, 
          onPopInvoked: (didPop) {
            if (didPop) return; // إذا خرج من التطبيق فعلاً (لأنه في الرئيسية)، نوقف التنفيذ
            
            // أما إذا كان في تبويب آخر (مثل الإعدادات) وضغط رجوع، نرجعه للرئيسية بدل الخروج
            setState(() {
              _currentIndex = 0; 
            });
          },
          child: Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
            bottomNavigationBar: CustomBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              activeColor: dynamicActiveColor, // 🚀 الشريط السفلي يتغير لونه ديناميكياً
            ),
          ),
        );
      },
    );
  }
}