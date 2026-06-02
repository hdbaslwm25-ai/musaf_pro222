import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: HomePage()));

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  Map<String, dynamic>? analysisResult;
  bool isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final List<Map<String, String>> _chatMessages = [];

  void resetAll() => setState(() { _image = null; analysisResult = null; isLoading = false;  _chatMessages.clear();});

  String cleanText(String text) {
    if (text.isEmpty) return text;
    String cleaned = text.trim();
    cleaned = cleaned.replaceFirst(RegExp(r'^[.\-\d\s]+'), '');
    if (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned.trim();
  }
Future<List<dynamic>> getDermatologyClinics() async {
  try {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    const String apiKey = "AIzaSyA-DZmQFpPpyf7WVVAl067ivyK4boChgYU";

    // 1. طلب البحث: وسعنا الكلمات ليشمل "مستوصف" و "مجمع" لزيادة النتائج
    final url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
        "?query=${Uri.encodeComponent('جلدية OR عيادة جلدية OR مستشفى جلدية OR مستوصف جلدية')}" 
        "&location=${position.latitude},${position.longitude}"
        "&radius=40000" // وسعنا الدائرة لـ 40كم لضمان صيد أكبر عدد من النتائج
        "&language=ar"
        "&key=$apiKey"; 

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List allResults = data['results'] ?? [];
      List filteredResults = [];

      for (var place in allResults) {
        String name = place['name'].toString().toLowerCase();
        var loc = place['geometry']['location'];
        
        double distanceInKm = Geolocator.distanceBetween(
          position.latitude, position.longitude, 
          loc['lat'], loc['lng']
        ) / 1000;

        // 2. قائمة الاستبعاد "الأكثر تسامحاً" على الإطلاق
        // أبقينا فقط التخصصات التي يستحيل وجود جلدية فيها (مثل العيون والأسنان)
        List<String> blackList = ['أسنان', 'اسنان', 'dental', 'عيون', 'optic', 'نظارات'];
        
        bool isForbidden = blackList.any((word) => name.contains(word));
        
        // 3. قاعدة ذهبية: إذا كان الاسم فيه (جلد، مستشفى، مستوصف، مركز) نقبله فوراً
        // حتى لو كان فيه كلمات أخرى، طالما لم يذكر "أسنان" أو "عيون" بشكل صريح كنشاط وحيد
        bool isMedicalHero = name.contains('جلد') || 
                             name.contains('مستشفى') || 
                             name.contains('مستوصف') || 
                             name.contains('مركز');

        if (distanceInKm < 50) {
          if (isMedicalHero && !isForbidden) {
            filteredResults.add(place);
          } else if (!isForbidden) {
            // إضافة احتياطية لأي نتيجة طبية عامة
            filteredResults.add(place);
          }
        }
      }

      // 4. الترتيب حسب الأقرب
      filteredResults.sort((a, b) {
        double distA = Geolocator.distanceBetween(position.latitude, position.longitude, a['geometry']['location']['lat'], a['geometry']['location']['lng']);
        double distB = Geolocator.distanceBetween(position.latitude, position.longitude, b['geometry']['location']['lat'], b['geometry']['location']['lng']);
        return distA.compareTo(distB);
      });

      // 5. الآن نأخذ الـ 6 الأوائل بكل ثقة
      return filteredResults.take(6).toList();
    }
  } catch (e) {
    debugPrint("Error: $e");
  }
  return [];
}
  Future<void> _openMapsForSpecificPlace(String placeName) async {
    final String query = Uri.encodeComponent(placeName);
    final String geoUrl = "geo:0,0?q=$query";
    if (await canLaunchUrl(Uri.parse(geoUrl))) { await launchUrl(Uri.parse(geoUrl)); }
  }

  Future<void> _openMapsGeneral() async {
    Position pos = await Geolocator.getCurrentPosition();
    final String geoUrl = "geo:${pos.latitude},${pos.longitude}?q=عيادة جلدية";
    await launchUrl(Uri.parse(geoUrl));
  }
  // --- دوال التقاط الصورة والرفع ---
  Future<void> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 50);
    if (picked != null) { setState(() { _image = File(picked.path); analysisResult = null; }); }
  }

  Future<void> uploadImage() async {
    if (_image == null) return;
    setState(() => isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse("https://server-api-wvb4.onrender.com/analyze-image"));
      request.files.add(await http.MultipartFile.fromPath('file', _image!.path));
      var response = await request.send().timeout(const Duration(seconds: 60));
      var resBody = await response.stream.bytesToString();
      var data = jsonDecode(resBody);
      if (response.statusCode == 200) {
        setState(() {
          var res = data['analysis'];
          analysisResult = res is String ? jsonDecode(res) : res;
          isLoading = false;
        });
      }
    } catch (e) { setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
       
        title: Text(analysisResult == null ? "" : "نتائج الفحص الذكي", style: const TextStyle(color: Color(0xFF135B6F), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: analysisResult == null ? _buildMainPickerUI() : _buildFinalResultsUI(),
    );
  }

  // واجهة اختيار الصورة
  Widget _buildMainPickerUI() {
    return Stack(
      children: [
        Container(color: const Color(0xFFF7F9FB)), 
        Positioned(
          top: 30, left: 20, right: 20,
          child: Container(
            height: 380,
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF135B6F).withOpacity(0.1), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
            ),
            child: _image == null 
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_a_photo_outlined, color: const Color(0xFF135B6F).withOpacity(0.5), size: 80),
                  const SizedBox(height: 20),
                  const Text("الرجاء التقاط صورة واضحة للجرح", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ])
              : ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.file(_image!, fit: BoxFit.cover, width: double.infinity)),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC1F1F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    onPressed: _image == null ? () => pickImage(ImageSource.camera) : uploadImage,
                    child: Text(_image == null ? "فتح الكاميرا" : "بدء التحليل الفوري", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 15),
                if (_image == null) 
                  TextButton(onPressed: () => pickImage(ImageSource.gallery), child: const Text("اختيار من الاستوديو", style: TextStyle(color: Color(0xFF135B6F), fontSize: 16))),
              ],
            ),
          ),
        ),
        if (isLoading) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
      ],
    );
  }

 Widget _buildFinalResultsUI() {
    String type = analysisResult!["نوع_الإصابة"] ?? "";

    String severity = (analysisResult!["مستوى_الخطورة"] ?? "غير محدد").toString();
    String recommendation = analysisResult!["التوصية"] ?? "";
    
    bool isInvalid = type.contains("غير واضح");
    bool isNotSkin = type.contains("ليست إصابة جلدية") || type.contains("جلد سليم");
    bool showFullDetails = !isInvalid && !isNotSkin;
    
    bool isUrgent = severity.contains("خطيرة");
    bool needsDoctor = recommendation.contains("طبيب") || isUrgent;

    return SingleChildScrollView(
      child: Column(
        children: [
          // 1. الصورة
          Stack(
            children: [
              Container(
                height: 250, width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(image: FileImage(_image!), fit: BoxFit.cover),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                ),
              ),
              Container(height: 250, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black26, Colors.transparent]), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)))),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2. كبسولات الحالة
                if (showFullDetails) 
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildStatusChip(severity, isUrgent ? Colors.red : Colors.green, isUrgent ? Icons.warning : Icons.check_circle),
                      const SizedBox(width: 8),
                      _buildStatusChip(type, const Color(0xFF135B6F), Icons.medical_services),
                    ],
                  )
                else
                  // ✅ التعديل الثاني: ضمان المحاذاة لليمين تماماً بدون فراغ
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildStatusChip(type, const Color(0xFF135B6F), Icons.medical_services),
                  ),

                // --- العناصر التي تظهر فقط للإصابات الجلدية ---
                if (showFullDetails) ...[
                  const SizedBox(height: 25),
                  const Text("التوصية الطبية", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(cleanText(recommendation), textAlign: TextAlign.right, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF135B6F))),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
                  Row(
                    children: [
                      Expanded(child: _buildActionButton(Icons.chat_bubble_outline, "استشارة ذكية", const Color(0xFF135B6F), () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(analysisResult: analysisResult! , messages: _chatMessages,)));
                      })),
                      const SizedBox(width: 12),
                      if (needsDoctor)
  Expanded(
    child: _buildActionButton(
      Icons.map_outlined, 
      "أقرب عيادة", 
      const Color(0xFFCC1F1F), 
      () async {
        // 1. طلب صلاحية الموقع قبل أي شيء
        LocationPermission permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          debugPrint("تم رفض صلاحية الموقع، لا يمكن المتابعة.");
          return;
        }

        // 2. التحقق من السياق قبل فتح النافذة
        if (!context.mounted) return;

        // 3. البحث عن العيادات
        List clinics = await getDermatologyClinics();
        
        // 4. التأكد مرة أخرى أن الصفحة لا تزال مفتوحة قبل عرض النتائج
        if (!context.mounted) return;

        if (clinics.isNotEmpty) { 
          _showClinicsModal(clinics); 
        } else { 
          _openMapsGeneral(); 
        }
      },
    ),
  ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text("خطوات العناية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8), Icon(Icons.list_alt, color: Color(0xFF135B6F)),
                  ]),
                  const SizedBox(height: 10),
                  ..._buildRecommendationsList(),
                  const SizedBox(height: 25),
                  
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber.shade200)),
                    child: const Text(
                      "إخلاء مسؤولية: هذه المعلومات للاسترشاد فقط ولا تغني عن استشارة الطبيب. في حالات الطوارئ توجه للمستشفى فوراً.",
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.brown, height: 1.5),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // تحديث الميثود لضبط المحاذاة لليمين تماماً (RTL)
  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.4), width: 1.5)),
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        textDirection: TextDirection.rtl, // ✅ يجبر العناصر على البدء من اليمين
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10), 
          Flexible(
            child: Text(
              label, 
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl, // ✅ يضمن محاذاة النص العربي لليمين
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
        child: Column(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  void _showClinicsModal(List clinics) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("العيادات الجلدية القريبة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 15),
            Flexible(child: ListView.builder(shrinkWrap: true, itemCount: clinics.length, itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: Text(clinics[index]['name']),
              onTap: () => _openMapsForSpecificPlace(clinics[index]['name']),
            ))),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecommendationsList() {
    List recs = analysisResult!["الإجراءات"] ?? [];
    return recs.map((text) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFF7F9FB), borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
          Expanded(child: Text(cleanText(text), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14))),
          const SizedBox(width: 12),
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
      ]),
    )).toList();
  }
}
// ✅ شاشة الشات بوت المحسنة مع التمرير التلقائي وتوسيع مربع النص
class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> analysisResult;
  final List<Map<String, String>> messages; // ✅ استقبال القائمة
  const ChatScreen({super.key, required this.analysisResult , required this.messages});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
void initState() {
  super.initState();
  _messages = widget.messages;
}
  final TextEditingController _controller = TextEditingController();
  
  // 1. إضافة الـ ScrollController للتحكم في النزول التلقائي
  final ScrollController _scrollController = ScrollController();
  
  late List<Map<String, String>> _messages ;
  bool _isTyping = false;

  // 2. دالة النزول لآخر المحادثة
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    String userMsg = _controller.text.trim();
    _controller.clear();
    
    setState(() { 
      _messages.add({"role": "user", "content": userMsg}); 
      _isTyping = true; 
    });
    
    // استدعاء النزول للأسفل بعد إرسال رسالتك
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse("https://server-api-wvb4.onrender.com/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "message": userMsg,
          "context": widget.analysisResult.toString(),
          "history": _messages.sublist(0, _messages.length - 1)
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() { 
          _messages.add({"role": "assistant", "content": data['reply']}); 
        });
        
        // استدعاء النزول للأسفل بعد استقبال رد الذكاء الاصطناعي
        _scrollToBottom();
      }
    } catch (e) { 
      debugPrint("خطأ شات: $e"); 
    } finally { 
      setState(() => _isTyping = false); 
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 1, 
        title: const Text("المسعف الذكي", style: TextStyle(color: Color(0xFF135B6F), fontWeight: FontWeight.bold)), 
        centerTitle: true, 
        iconTheme: const IconThemeData(color: Color(0xFF135B6F))
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // 3. ربط الكنترولر هنا
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUser = _messages[index]["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(15),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF135B6F) : Colors.white,
                      borderRadius: BorderRadius.circular(15).copyWith(
                        bottomRight: isUser ? Radius.zero : const Radius.circular(15), 
                        bottomLeft: isUser ? const Radius.circular(15) : Radius.zero
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                    ),
                          child: MarkdownBody(
                          // هذا التعديل سيبحث عن أي رقم (١- ، ٢- ، ٣-) ويضع قبله سطرين فارغين تلقائياً لضمان الفصل
                          data: '\u200f' + _messages[index]["content"]!
                          .replaceAll('إجباري:', '') 
                          // وضعنا \n واحدة فقط قبل الرقم لضمان بداية سطر جديد بدون فراغ ضخم
                          .replaceAllMapped(RegExp(r'(\d-|[١-٩]-)'), (match) => '\n${match.group(0)}')
                          .trim(),
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        textAlign: WrapAlignment.end,
                        p: TextStyle(
                          color: isUser ? Colors.white : Colors.black87, 
                          fontSize: 15,
                          height: 1.7,
                        ),
                        // الـ blockSpacing هو الذي يتحكم في الفراغ بين الفقرات بشكل أنيق
                        blockSpacing: 10.0,
                          ),
                        ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping) const Padding(
            padding: EdgeInsets.all(8.0), 
            child: LinearProgressIndicator(color: Color(0xFF135B6F), backgroundColor: Colors.transparent)
          ),
          Container(
            padding: const EdgeInsets.all(15), 
            color: Colors.white,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF135B6F)), onPressed: _sendMessage),
                Expanded(
                  child: TextField(
                    controller: _controller, 
                    textAlign: TextAlign.right,
                    // 4. التعديل لجعل المربع يتوسع تلقائياً حتى 5 أسطر
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: "...اكتب استفسارك هنا", 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), 
                      filled: true, 
                      fillColor: const Color(0xFFF1F5F9)
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}