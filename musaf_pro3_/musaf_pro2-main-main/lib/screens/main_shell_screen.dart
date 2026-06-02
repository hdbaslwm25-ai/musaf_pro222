import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// تأكدي أن هذا هو اسم الكلاس الجديد
class PatientSettings extends StatefulWidget {
  final String? patientId;
  const PatientSettings({super.key, this.patientId});

  @override
  State<PatientSettings> createState() => _PatientSettingsState();
}

class _PatientSettingsState extends State<PatientSettings> {
  // 🔴 يجب إضافة دالة build هنا لكي يختفي الخطأ
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الإعدادات"),
        backgroundColor: const Color(0xFFB7131A),
      ),
      body: const Center(child: Text("صفحة إعدادات المريض")),
    );
  }
}
