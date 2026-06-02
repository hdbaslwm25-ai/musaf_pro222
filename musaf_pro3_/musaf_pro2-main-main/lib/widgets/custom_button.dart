import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;

  // 🚀 إضافات عهد
  final IconData? icon;
  final Color? backgroundColor;
  final double height;

  // 🎯 التحكم الكامل بحجم الخط
  final double fontSize;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.icon, 
    this.backgroundColor, 
    this.height = 48, // 🎯 تم تصغير الارتفاع الافتراضي من 55 إلى 48 ليكون أنيق ورشيق
    this.fontSize = 14, // 🎯 تم تصغير الخط الافتراضي إلى 14 ليناسب الكاردات تماماً
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      // تجهيز ستايل الزر
      final btnStyle = ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? const Color(0xFFB71C1C),
        minimumSize: Size(double.infinity, height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // زوايا أنعم متناسقة مع الحجم الصغير
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16), // مساحة داخلية متزنة
      );

      // إذا مررنا أيقونة للزر
      if (icon != null) {
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: Colors.white), // 🎯 تصغير الأيقونة لتناسب الخط
          label: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize, // حجم صغير وناعم
              fontWeight: FontWeight.w600, // سمك خط معتدل ومريح للمراعي
            ),
          ),
          style: btnStyle,
        );
      }

      // إذا كان زر عادي بدون أيقونة
      return ElevatedButton(
        onPressed: onPressed,
        style: btnStyle,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      // الزر الشفاف (تخطي / تسجيل جديد)
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: Size(double.infinity, height - 10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13, // 🎯 زر التخطي تم تصغيره إلى 13
            fontWeight: FontWeight.normal,
          ),
        ),
      );
    }
  }
}