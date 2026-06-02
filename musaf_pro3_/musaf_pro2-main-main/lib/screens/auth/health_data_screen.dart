import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🚀 تم إضافة استدعاء الزر المخصص هنا
import 'package:musaf_pro/widgets/custom_button.dart';

class HealthDataScreen extends StatefulWidget {
  const HealthDataScreen({super.key});

  @override
  State<HealthDataScreen> createState() => _HealthDataScreenState();
}

class _HealthDataScreenState extends State<HealthDataScreen> {
  // القوائم والبيانات
  String? _selectedGender;
  String? _selectedBloodType;
  final TextEditingController _ageController = TextEditingController();

  // لون مُسعف الملكي
  Color musafRed = const Color(0xFFB7131A);

  // متغيرات التاريخ المرضي
  String _chronicDiseases = "";
  String _currentMedications = "";
  String _allergies = "";

  bool _isLoading = false;

  // دالة الحفظ النهائي (لم يتم المساس بها)
  void _saveHealthData() async {
    if (_selectedGender == null ||
        _selectedBloodType == null ||
        _ageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إكمال البيانات الأساسية')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'gender': _selectedGender,
        'age': _ageController.text,
        'bloodType': _selectedBloodType,
        'chronicDiseases': _chronicDiseases,
        'currentMedications': _currentMedications,
        'allergies': _allergies,
        'setupComplete': true, // علامة تدل على انتهاء إعداد الحساب
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/patient_home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), // لون خلفية هادئ مثل الصورة
      appBar: AppBar(
        title: const Text(
          'ادخال البيانات الحيوية',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.person_outline, color: musafRed),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.end, // لترتيب العناوين لغة عربية
          children: [
            // تنبيه علوي (تم تحويله للأحمر)
            _buildInfoAlert(musafRed),
            const SizedBox(height: 25),

            // قسم البيانات الأساسية
            _buildSectionHeader('البيانات الأساسية', Icons.person_outline),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_ageController, 'العمر', 'مثال: 25'),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildDropdown(
                    'الجنس',
                    ['ذكر', 'أنثى'],
                    _selectedGender,
                    (val) => setState(() => _selectedGender = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildDropdown(
              'فصيلة الدم',
              ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
              _selectedBloodType,
              (val) => setState(() => _selectedBloodType = val),
              isRed: true,
              brandedRed: musafRed,
            ),

            const SizedBox(height: 30),

            // قسم التاريخ المرضي
            _buildSectionHeader('التاريخ المرضي', Icons.history),
            const SizedBox(height: 15),
            _buildExpansionStep(
              'هل تعاني من أمراض مزمنة؟',
              Icons.monitor_heart_outlined,
              (val) => _chronicDiseases = val,
              musafRed,
            ),
            _buildExpansionStep(
              'هل تتناول أدوية حالياً؟',
              Icons.medication_outlined,
              (val) => _currentMedications = val,
              musafRed,
            ),
            _buildExpansionStep(
              'هل لديك أي حساسيات؟',
              Icons.warning_amber_rounded,
              (val) => _allergies = val,
              musafRed,
            ),

            const SizedBox(height: 40),

            // 🚀 التعديل هنا: استخدام الزر المخصص لحفظ الملف الطبي
            _isLoading
                ? Center(child: CircularProgressIndicator(color: musafRed))
                : CustomButton(
                    text: 'حفظ الملف الطبي',
                    isPrimary: true,
                    backgroundColor: musafRed,
                    onPressed: _saveHealthData,
                  ),
          ],
        ),
      ),
    );
  }

  // --- عناصر الواجهة المخصصة ---

  Widget _buildInfoAlert(Color alertColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: alertColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'هذه المعلومات ستكون متاحة للمسعفين فور طلبك للنجدة لضمان تقديم العلاج الأنسب لك في أسرع وقت.',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: alertColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 20, color: Colors.grey),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? currentVal,
    Function(String?) onChange, {
    bool isRed = false,
    Color brandedRed = Colors.red,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isRed && currentVal == null
                ? brandedRed.withOpacity(0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isRed && currentVal == null
                ? Border.all(color: brandedRed.withOpacity(0.2))
                : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentVal,
              isExpanded: true,
              hint: const Text('اختر'),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpansionStep(
    String title,
    IconData icon,
    Function(String) onTyped,
    Color tileRed,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(icon, color: tileRed),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: TextField(
              onChanged: onTyped,
              maxLines: 2,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: 'اكتب التفاصيل هنا...',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
