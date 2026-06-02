import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🚀 استدعاء الزر المخصص الموحد
import 'package:musaf_pro/widgets/custom_button.dart';

class HealthVitalsScreen extends StatefulWidget {
  const HealthVitalsScreen({super.key});

  @override
  State<HealthVitalsScreen> createState() => _HealthVitalsScreenState();
}

class _HealthVitalsScreenState extends State<HealthVitalsScreen> {
  final Color musafRed = const Color(0xFFB7131A);

  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _bpSystolicController = TextEditingController();
  final TextEditingController _bpDiastolicController = TextEditingController();
  final TextEditingController _heartRateController = TextEditingController();

  // متغيرات لمعرفة حالة المريض الطبية (سيتم جلبها من فايربيس)
  bool _isDiabetic = false;
  bool _isHypertensive = false;
  bool _isLoadingData = true;

  String? _sugarStatus;
  Color? _sugarColor;
  String? _bpStatus;
  Color? _bpColor;
  String? _hrStatus;
  Color? _hrColor;

  String _analysisResult = "أدخل بياناتك واضغط على تحليل";
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _fetchPatientHealthProfile();
  }

  // دالة جلب بيانات المريض مع حل مشكلة التعليق (Loading)
  Future<void> _fetchPatientHealthProfile() async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            // جلب البيانات مع التأكد من وجود الحقول لتجنب الأخطاء
            _isDiabetic = data.containsKey('hasDiabetes')
                ? data['hasDiabetes']
                : false;
            _isHypertensive = data.containsKey('hasHypertension')
                ? data['hasHypertension']
                : false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching health profile: $e");
    } finally {
      // نضمن إيقاف التحميل مهما حدث (سواء وُجدت بيانات أم لا)
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  void _analyzeData() {
    double? sugar = double.tryParse(_sugarController.text);
    int? sys = int.tryParse(_bpSystolicController.text);
    int? dia = int.tryParse(_bpDiastolicController.text);
    int? hr = int.tryParse(_heartRateController.text);

    if (sugar == null || sys == null || dia == null || hr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى إكمال جميع الحقول بدقة',
            textAlign: TextAlign.right,
          ),
        ),
      );
      return;
    }

    bool isDanger = false;

    setState(() {
      // --- 1. التحليل الذكي للسكر ---
      double maxNormalSugar = _isDiabetic ? 130.0 : 100.0;
      if (sugar > maxNormalSugar) {
        _sugarStatus = "مرتفع";
        _sugarColor = musafRed;
        isDanger = true;
      } else if (sugar < 70) {
        _sugarStatus = "منخفض";
        _sugarColor = Colors.orange;
        isDanger = true;
      } else {
        _sugarStatus = "طبيعي";
        _sugarColor = Colors.green;
      }

      // --- 2. التحليل الذكي للضغط ---
      int maxSys = _isHypertensive ? 140 : 120;
      int maxDia = _isHypertensive ? 90 : 80;
      if (sys > maxSys || dia > maxDia) {
        _bpStatus = "مرتفع";
        _bpColor = musafRed;
        isDanger = true;
      } else if (sys < 90 || dia < 60) {
        _bpStatus = "منخفض";
        _bpColor = Colors.orange;
        isDanger = true;
      } else {
        _bpStatus = "طبيعي";
        _bpColor = Colors.green;
      }

      // --- 3. تحليل نبضات القلب ---
      if (hr > 100) {
        _hrStatus = "مرتفع";
        _hrColor = musafRed;
        isDanger = true;
      } else if (hr < 60) {
        _hrStatus = "منخفض";
        _hrColor = Colors.orange;
        isDanger = true;
      } else {
        _hrStatus = "طبيعي";
        _hrColor = Colors.green;
      }

      // --- 4. تحديث الحالة العامة ---
      if (isDanger) {
        _analysisResult = "⚠️ تم رصد قياسات خارج النطاق الطبيعي لحالتك";
        _statusColor = musafRed;
        _showEmergencyAlert();
      } else {
        _analysisResult = "جميع قياساتك ممتازة وفي النطاق الطبيعي ✅";
        _statusColor = Colors.green;
      }
    });
  }

  void _showEmergencyAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تنبيه طارئ ⚠️',
          textAlign: TextAlign.right,
          style: TextStyle(color: musafRed),
        ),
        content: const Text(
          'بعض القياسات الحيوية خارج النطاق الطبيعي. هل تود إرسال طلب تدخل طارئ (SOS) للمرافقين؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تجاهل'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: musafRed),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إرسال SOS الآن',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'تحديث القياسات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoadingData
            ? Center(child: CircularProgressIndicator(color: musafRed))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _statusColor.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        _analysisResult,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildInputCard(
                      "معدل السكر (mg/dL)",
                      Icons.water_drop,
                      _sugarController,
                      Colors.blue,
                      status: _sugarStatus,
                      statusColor: _sugarColor,
                    ),
                    _buildInputCard(
                      "ضغط الدم (Sys / Dia)",
                      Icons.speed,
                      _bpSystolicController,
                      Colors.orange,
                      controller2: _bpDiastolicController,
                      status: _bpStatus,
                      statusColor: _bpColor,
                    ),
                    _buildInputCard(
                      "نبضات القلب (BPM)",
                      Icons.favorite,
                      _heartRateController,
                      Colors.red,
                      status: _hrStatus,
                      statusColor: _hrColor,
                    ),

                    const SizedBox(height: 40),

                    // 🚀 التعديل هنا: استخدام الزر المخصص الموحد
                    CustomButton(
                      text: 'تحليل القياسات',
                      isPrimary: true,
                      backgroundColor: musafRed,
                      onPressed: _analyzeData,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInputCard(
    String label,
    IconData icon,
    TextEditingController controller,
    Color iconColor, {
    TextEditingController? controller2,
    String? status,
    Color? statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: statusColor != null
              ? statusColor.withOpacity(0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (status != null && statusColor != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                const SizedBox(),
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(icon, color: iconColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (controller2 != null) ...[
                Expanded(
                  child: TextField(
                    controller: controller2,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "المنخفض",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    "/",
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                ),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: controller2 != null ? "العالي" : "أدخل القيمة",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
