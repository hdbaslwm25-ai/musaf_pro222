import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  Future<void> _requestPermissions(BuildContext context) async {
    // 1. طلب إذن الإشعارات أولاً
    await Permission.notification.request();

    // 2. طلب إذن الموقع
    await Permission.locationWhenInUse.request();

    // 3. التوجيه إلى شاشة تسجيل الدخول بعد الانتهاء
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🚀 تغيير الأيقونة واللون ليتناسب مع الطابع الطبي والطوارئ
              const Icon(
                Icons.health_and_safety_rounded, // أيقونة صحة وأمان مناسبة جداً
                size: 100,
                color: Color(0xFFB71C1C), // اللون الأحمر الموحد في تطبيقك
              ),
              const SizedBox(height: 40),

              const Text(
                "لنبقيك آمناً دائماً",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              const Text(
                "تطبيق مُسعف يحتاج إلى صلاحية الموقع للوصول إليك في حالات الطوارئ، وصلاحية الإشعارات لتذكيرك بمواعيد الأدوية الهامة.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 50),

              // 🚀 الزر باللون الأحمر وزوايا دائرية
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => _requestPermissions(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFB71C1C,
                    ), // اللون الأحمر المتناسق
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "منح الصلاحيات",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),

              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text(
                  "تخطي في الوقت الحالي",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
