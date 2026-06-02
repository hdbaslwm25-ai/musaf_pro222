import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// تأكدي من مسار الاستيراد هذا حسب مشروعك
import 'package:musaf_pro/presentation/delete_account_dialog.dart';
import '../../data/repositories/firebase_auth_repository_impl.dart';

class PatientSettingsScreen extends StatefulWidget {
  const PatientSettingsScreen({super.key});

  @override
  State<PatientSettingsScreen> createState() => _PatientSettingsScreenState();
}

class _PatientSettingsScreenState extends State<PatientSettingsScreen> {
  final _authRepository = FirebaseAuthRepositoryImpl();
  final Color themeColor = const Color(0xFFB7131A);

  bool medAlerts = true;
  bool zoneAlerts = true;

  String patientName = "جاري التحميل...";
  String patientEmail = "";
  String patientPhone = "";
  String profileImageUrl = "";

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _loadUserProfile();
  }

  // 🚀 دالة جلب بيانات المستخدم بدقة (من Auth و Firestore)
  Future<void> _loadUserProfile() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (doc.exists && mounted) {
          var data = doc.data() as Map<String, dynamic>?;
          setState(() {
            // الأولوية لاسم Firestore، ثم اسم Auth، وإذا كانا فارغين نعرض نصاً بديلاً
            patientName =
                data?['displayName'] ??
                currentUser.displayName ??
                "لم يتم تحديد الاسم";
            patientEmail = data?['email'] ?? currentUser.email ?? "";
            patientPhone = data?['phoneNumber'] ?? "";
            profileImageUrl =
                data?['profileImageUrl'] ?? currentUser.photoURL ?? "";
          });
        }
      } catch (e) {
        debugPrint("خطأ في جلب بيانات المستخدم: $e");
        if (mounted)
          setState(
            () => patientName = currentUser.displayName ?? "مستخدم مُسعف",
          );
      }
    }
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        medAlerts = prefs.getBool('medAlerts') ?? true;
        zoneAlerts = prefs.getBool('zoneAlerts') ?? true;
      });
    }
  }

  Future<void> _saveNotificationSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // 🚀 دالة لاختيار ورفع الصورة الشخصية
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "جاري تحديث الصورة...",
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );

        File imageFile = File(pickedFile.path);
        String uniqueFileName =
            '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(uniqueFileName);

        UploadTask uploadTask = storageRef.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'profileImageUrl': downloadUrl});

        setState(() => profileImageUrl = downloadUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "تم تحديث الصورة بنجاح ✅",
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("خطأ أثناء اختيار الصورة: $e");
    }
  }

  // 🚀 دالة لفتح نافذة تعديل الاسم ورقم الهاتف
  void _showEditProfileDialog() {
    TextEditingController nameController = TextEditingController(
      text: patientName == "لم يتم تحديد الاسم" ? "" : patientName,
    );
    TextEditingController phoneController = TextEditingController(
      text: patientPhone,
    );

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "تعديل البيانات",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "الاسم",
                labelStyle: const TextStyle(fontFamily: 'Cairo'),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: themeColor),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "رقم الهاتف",
                labelStyle: const TextStyle(fontFamily: 'Cairo'),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: themeColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text(
              "إلغاء",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(d); // إغلاق النافذة

                setState(() {
                  patientName = nameController.text.trim();
                  patientPhone = phoneController.text.trim();
                });

                User? currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .update({
                          'displayName': patientName,
                          'phoneNumber': patientPhone,
                        });
                    // تحديث الاسم في Auth أيضاً
                    await currentUser.updateDisplayName(patientName);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "تم تحديث البيانات بنجاح ✅",
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint("خطأ في تحديث البيانات: $e");
                  }
                }
              }
            },
            child: const Text(
              "حفظ",
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          "الإعدادات",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: themeColor,
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        children: [
          // ==================== رأس الصفحة (بيانات المستخدم) ====================
          _buildProfileHeader(),

          // ==================== 1. الملف الشخصي والقياسات ====================
          _buildSectionTitle("الحساب والبيانات"),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.edit_document,
              title: "تعديل الملف الشخصي",
              onTap: _showEditProfileDialog, // 🚀 ربطنا الزر بالنافذة المنبثقة
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.monitor_heart_outlined,
              title: "القياسات الحيوية",
              onTap: () => Navigator.pushNamed(context, '/health_vitals'),
            ),
          ]),

          const SizedBox(height: 20),

          // ==================== 2. الإشعارات والتنبيهات ====================
          _buildSectionTitle("الإشعارات"),
          _buildSettingsCard([
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              secondary: Icon(Icons.medication_outlined, color: themeColor),
              title: const Text(
                "تنبيهات الأدوية",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              value: medAlerts,
              activeColor: themeColor,
              onChanged: (value) {
                setState(() => medAlerts = value);
                _saveNotificationSetting('medAlerts', value);
              },
            ),
            _buildDivider(),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              secondary: Icon(Icons.share_location_outlined, color: themeColor),
              title: const Text(
                "تنبيهات الموقع (الدخول والخروج)",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              value: zoneAlerts,
              activeColor: themeColor,
              onChanged: (value) {
                setState(() => zoneAlerts = value);
                _saveNotificationSetting('zoneAlerts', value);
              },
            ),
          ]),

          const SizedBox(height: 20),

          // ==================== 3. النظام والأمان ====================
          _buildSectionTitle("النظام والأمان"),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.info_outline_rounded,
              title: "حول التطبيق",
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: "تطبيق مُسعف",
                  applicationVersion: "1.0.0",
                  applicationLegalese: "© 2026 جميع الحقوق محفوظة",
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.logout_rounded,
              title: "تسجيل الخروج",
              textColor: Colors.orange[800],
              iconColor: Colors.orange[800],
              onTap: _showLogoutDialog,
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.delete_forever_rounded,
              title: "حذف الحساب نهائياً",
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) =>
                      DeleteAccountDialog(authRepository: _authRepository),
                );
              },
            ),
          ]),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- دوال بناء الواجهة (Widgets) ---

  Widget _buildProfileHeader() {
    return Column(
      children: [
        const SizedBox(height: 10),
        GestureDetector(
          onTap:
              _pickAndUploadImage, // 🚀 يفتح الاستديو لتغيير الصورة عند الضغط
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: themeColor.withOpacity(0.1),
                backgroundImage: profileImageUrl.isNotEmpty
                    ? (profileImageUrl.startsWith('http')
                              ? NetworkImage(profileImageUrl)
                              : FileImage(File(profileImageUrl)))
                          as ImageProvider
                    : null,
                child: profileImageUrl.isEmpty
                    ? Icon(Icons.person, size: 45, color: themeColor)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          patientName,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (patientEmail.isNotEmpty || patientPhone.isNotEmpty)
          Text(
            patientEmail.isNotEmpty ? patientEmail : patientPhone,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          fontFamily: 'Cairo',
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? themeColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? themeColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: textColor ?? Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: Colors.black38,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 60,
      endIndent: 20,
      color: Color(0xFFEEEEEE),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "تسجيل خروج",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟",
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "إلغاء",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted)
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/role_selection',
                  (r) => false,
                );
            },
            child: const Text(
              "خروج",
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
