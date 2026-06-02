import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Color musafRed = const Color(0xFFB7131A);

  @override
  void initState() {
    super.initState();
    _checkUserSession();
  }

  // 🚀 الدالة الذكية لفحص جلسة تسجيل الدخول وتوجيه المستخدم تلقائياً
  Future<void> _checkUserSession() async {
    // ننتظر 3 ثوانٍ لعرض شعار التطبيق (Splash Effect)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // 1. الفحص: هل يوجد مستخدم مسجل دخول حالياً في الفايربيس؟
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      try {
        // 2. إذا كان مسجل دخول، نروح للفايرستور نشوف هل هو (مريض) أم (مرافق)
        // تفحص مجموعة المستخدمين أولاً (عدلي أسماء الكولكشنز حسب مشروعك لو لزم)
        var patientDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (patientDoc.exists && patientDoc.data()?['role'] == 'patient') {
          if (mounted) Navigator.pushReplacementNamed(context, '/patient_home');
          return;
        }

        var caregiverDoc = await FirebaseFirestore.instance
            .collection('caregivers')
            .doc(currentUser.uid)
            .get();

        if (caregiverDoc.exists ||
            (patientDoc.exists && patientDoc.data()?['role'] == 'caregiver')) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/caregiver_home');
          }
          return;
        }

        // كخيار احتياطي لو الحساب مسجل بس الداتا لسه ما اكتملت في الفايرستور
        if (mounted) Navigator.pushReplacementNamed(context, '/role_selection');
      } catch (e) {
        debugPrint("خطأ في جلب بيانات الدور: $e");
        if (mounted) Navigator.pushReplacementNamed(context, '/role_selection');
      }
    } else {
      // 3. إذا كان المستخدم مو مسجل دخول اصلاً
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎯 شعار تطبيق مُسعف
            Icon(Icons.medical_services, size: 100, color: musafRed),
            const SizedBox(height: 20),
            Text(
              'مُــسْــعِــف',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: musafRed,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            CircularProgressIndicator(color: musafRed),
          ],
        ),
      ),
    );
  }
}
