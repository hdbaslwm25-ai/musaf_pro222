import 'package:flutter/material.dart';
import 'package:musaf_pro/providers/location_provider.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/safe_zone.dart';
import '../widgets/zone_card.dart';

class AddZoneScreen extends StatefulWidget {
  final String patientId;
  const AddZoneScreen({super.key, required this.patientId});

  @override
  State<AddZoneScreen> createState() => _AddZoneScreenState();
}

class _AddZoneScreenState extends State<AddZoneScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isFetchingLocation = false;
  
  final Color themeColor = const Color(0xFF2E7D32);
  final Color backgroundColor = const Color(0xFFF8F9FD);
  
  final List<String> _nameOptions = ['منزل', 'مدرسة', 'حديقة', 'مسجد', 'عمل', 'مستشفى', 'منطقة مخصصة'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => 
      context.read<CaregiverPatientProvider>().loadSafeZones(widget.patientId)
    );
  }

  // --- Logic Layer ---

  Future<void> _fetchCurrentPosition(TextEditingController lat, TextEditingController lng, StateSetter setModalState) async {
    setModalState(() => _isFetchingLocation = true);
    try {
      // 🚀 التحقق من الصلاحيات أولاً
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showCustomSnackBar("يجب إعطاء صلاحية الموقع لاستخدام هذه الميزة", isError: true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showCustomSnackBar("الصلاحية مرفوضة نهائياً، يرجى تفعيلها من الإعدادات", isError: true);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      lat.text = position.latitude.toString();
      lng.text = position.longitude.toString();
    } catch (e) {
      _showCustomSnackBar("فشل في تحديد الموقع", isError: true);
    } finally {
      setModalState(() => _isFetchingLocation = false);
    }
  }

  void _onSavePressed({
    required bool isEdit,
    SafeZone? existingZone, // 👈 استلام المنطقة القديمة هنا
    int? index,
    required String name,
    required String lat,
    required String lng,

    required double radius,
  }) async {
    if (_formKey.currentState!.validate()) {
      final pro = context.read<CaregiverPatientProvider>();

      if (!isEdit) {
        // إضافة جديدة
        String resultMessage = await pro.addNewSafeZone(
          patientId: widget.patientId,
          name: name,
          latitude: double.parse(lat),
          longitude: double.parse(lng),
          radius: radius,
        );
if (mounted) {
          Navigator.pop(context); // ✅ الإغلاق هنا
          _showCustomSnackBar(resultMessage, isError: !resultMessage.contains('نجاح'));
        }      } else if (existingZone != null) {
        // 🚀 تحديث منطقة موجودة
        String resultMessage = await pro.updateExistingSafeZone(
          patientId: widget.patientId,
          oldZone: existingZone,
          newName: name,
          newLatitude: double.parse(lat),
          newLongitude: double.parse(lng),
          newRadius: radius,
        );
       if (mounted) {
          Navigator.pop(context); // ✅ الإغلاق هنا
          _showCustomSnackBar(resultMessage, isError: !resultMessage.contains('نجاح'));
        }
    }
    }

  }

  void _showCustomSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.redAccent : themeColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: _buildZonesList(),
      floatingActionButton: _buildAddButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: backgroundColor,
      title: const Text("إدارة المناطق الآمنة", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      centerTitle: true,
      actions: [
        Consumer<CaregiverPatientProvider>(
          builder: (context, loc, _) {
            if (loc.safeZones.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 28),
              onPressed: () => _confirmClearAll(loc),
            );
          },
        )
      ],
    );
  }

  Widget _buildZonesList() {
    return Consumer<CaregiverPatientProvider>(
      builder: (context, loc, _) {
        if (loc.safeZones.isEmpty) return _buildEmptyState();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          itemCount: loc.safeZones.length,
          itemBuilder: (context, index) {
            final zone = loc.safeZones[index];
            // داخل _buildZonesList
return Dismissible(
  key: Key(zone.id),
  direction: DismissDirection.endToStart,
  // 🚀 إضافة التأكيد قبل الحذف
  confirmDismiss: (direction) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("تأكيد الحذف", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text("هل أنت متأكد من حذف هذه المنطقة؟", style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("حذف", style: TextStyle(fontFamily: 'Cairo', color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  },
// 🚀 الملاحظة 5: استخدام الـ ID بدلاً من index
onDismissed: (_) => loc.deleteSafeZoneById(zone.id, widget.patientId),  child: ZoneCard(
    zone: zone, index: index, patientId: widget.patientId,
    locProvider: loc,
    onEdit: () => _openZoneModal(zone: zone, index: index),
    onDelete: () => _confirmDeletion(index),
  ),
);}
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          const Text("لا توجد مناطق آمنة مضافة", 
            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmClearAll(CaregiverPatientProvider loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تنبيه ⚠️"),
        content: const Text("حذف جميع المناطق الآمنة؟ لا يمكن التراجع!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
          TextButton(
            onPressed: () async {
              await loc.deleteAllZones(widget.patientId);
              if (context.mounted) Navigator.pop(context);
              _showCustomSnackBar("تم مسح جميع المناطق بنجاح 🧹", isError: false);
            }, 
            child: const Text("حذف الكل", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- Modal Logic ---

  void _openZoneModal({SafeZone? zone, int? index}) {
    final isEdit = zone != null;
    final latController = TextEditingController(text: isEdit ? zone.latitude.toString() : "");
    final lngController = TextEditingController(text: isEdit ? zone.longitude.toString() : "");
    String selectedName = (isEdit && _nameOptions.contains(zone.name)) ? zone.name : _nameOptions.first;
    double radius = isEdit ? zone.radius : 150.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 25, right: 25, top: 20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModalHandle(),
                  const SizedBox(height: 20),
                  _buildTypeDropdown(selectedName, (val) => setModalState(() => selectedName = val!)),
                  const SizedBox(height: 15),
                  _buildLocationPicker(latController, lngController, setModalState),
                  const SizedBox(height: 20),
                  _buildRadiusSlider(radius, (val) => setModalState(() => radius = val)),
                  const SizedBox(height: 25),
                  _buildSubmitAction(isEdit, index, selectedName, zone, latController, lngController, radius),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown(String value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration("نوع المكان", Icons.label_outline),
      items: _nameOptions.map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildRadiusSlider(double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("نطاق الأمان: ${value.toInt()} متر", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        Slider(value: value, min: 10, max: 1000, divisions: 99, activeColor: themeColor, onChanged: onChanged),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'Cairo'),
      prefixIcon: Icon(icon, color: themeColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: themeColor, width: 2)),
    );
  }

  Widget _buildLocationPicker(TextEditingController lat, TextEditingController lng, StateSetter setModalState) {
    return Column(
      children: [
        _buildAutoButton(lat, lng, setModalState),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildCoordsField(lat, "خط العرض")),
            const SizedBox(width: 10),
            Expanded(child: _buildCoordsField(lng, "خط الطول")),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoButton(TextEditingController lat, TextEditingController lng, StateSetter setModalState) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: themeColor.withValues(alpha: 0.1),  foregroundColor: themeColor, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: () => _fetchCurrentPosition(lat, lng, setModalState),
        icon: _isFetchingLocation ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: themeColor)) : const Icon(Icons.my_location),
        label: const Text("استخدام موقعي الحالي", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSubmitAction(bool isEdit, int? index, String name, SafeZone? zone, TextEditingController lat, TextEditingController lng, double radius) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: themeColor, padding: const EdgeInsets.all(15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: () => _onSavePressed(
  isEdit: isEdit, 
  existingZone: isEdit ? zone : null, // 👈 التمرير هنا مهم
  index: index, 
  name: name, 
  lat: lat.text, 
  lng: lng.text, 
  radius: radius
),

        child: Text(isEdit ? "تحديث" : "حفظ المنطقة", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16)),
      ),
    );
  }

  Widget _buildModalHandle() => Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)));

  Widget _buildCoordsField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _inputDecoration(label, Icons.location_on_outlined),
      style: const TextStyle(fontFamily: 'Cairo'),
      validator: (v) {
        // 🚀 التحقق من الفراغ ومن صحة الرقم لمنع الانهيار
        if (v == null || v.trim().isEmpty) return "مطلوب";
        if (double.tryParse(v.trim()) == null) return "رقم غير صالح";
        return null;
      },
    );
  }

  void _confirmDeletion(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("حذف المنطقة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد من حذف هذه المنطقة؟", style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
          TextButton(onPressed: () {
            context.read<CaregiverPatientProvider>().deleteSafeZone(index, widget.patientId);
            Navigator.pop(context);
            _showCustomSnackBar("تم الحذف بنجاح ✅", isError: false);
          }, child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return FloatingActionButton.extended(
      backgroundColor: themeColor,
      onPressed: () => _openZoneModal(),
      icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
      label: const Text("إضافة منطقة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}