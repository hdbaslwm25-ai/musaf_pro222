import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeleteAccountDialog extends StatefulWidget {
  // يمكنك تمرير الـ Repository إذا كنتِ تستخدمينه،
  // لكن للتبسيط والتحكم الدقيق في الأخطاء سنعالجها هنا مباشرة
  final dynamic authRepository;

  const DeleteAccountDialog({super.key, this.authRepository});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = ''; // 👈 هذا المتغير سيحمل السبب الحقيقي للخطأ
  bool _obscurePassword = true;

  final Color themeColor = const Color(0xFFB7131A);

  Future<void> _deleteAccount() async {
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال كلمة المرور أولاً.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = ''; // مسح الأخطاء السابقة
    });

    User? user = FirebaseAuth.instance.currentUser;

    if (user != null && user.email != null) {
      try {
        // 1. تجهيز بيانات المصادقة لإثبات هوية المستخدم
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );

        // 2. إعادة المصادقة (Re-authenticate)
        await user.reauthenticateWithCredential(credential);

        // 3. مسح بيانات المستخدم من قاعدة البيانات Firestore أولاً
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();

        // 4. حذف الحساب نهائياً من Firebase Auth
        await user.delete();

        // 5. توجيه المستخدم لصفحة تسجيل الدخول بعد النجاح
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/role_selection',
            (route) => false,
          );
        }
      } on FirebaseAuthException catch (e) {
        // 🚨 هنا السحر: ترجمة أكواد فايربيس المزعجة إلى رسائل واضحة للمستخدم
        setState(() {
          if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
            _errorMessage =
                'كلمة المرور غير صحيحة. يرجى التأكد والمحاولة مجدداً.';
          } else if (e.code == 'network-request-failed') {
            _errorMessage = 'لا يوجد اتصال بالإنترنت. تأكد من شبكتك.';
          } else if (e.code == 'requires-recent-login') {
            _errorMessage =
                'لدواعي أمنية، يرجى تسجيل الخروج ثم الدخول مجدداً قبل حذف الحساب.';
          } else if (e.code == 'too-many-requests') {
            _errorMessage =
                'محاولات كثيرة جداً. يرجى الانتظار قليلاً ثم المحاولة.';
          } else {
            // إذا ظهر خطأ غريب آخر، سيطبعه كما هو لنعرف ما هو
            _errorMessage = 'عذراً، لم نتمكن من حذف الحساب: ${e.code}';
          }
        });
      } catch (e) {
        setState(
          () => _errorMessage = 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.',
        );
      }
    } else {
      setState(
        () => _errorMessage = 'لا يمكن العثور على بيانات الحساب الحالي.',
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          SizedBox(width: 10),
          Text(
            "حذف الحساب نهائياً",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "هذا الإجراء لا يمكن التراجع عنه. سيتم مسح جميع بياناتك، سجلاتك، وارتباطاتك بشكل نهائي.\n\nيرجى إدخال كلمة المرور لتأكيد الحذف:",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 15),

          // حقل كلمة المرور
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: "كلمة المرور",
              labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: themeColor),
              ),
            ),
          ),

          // ⚠️ عرض رسالة الخطأ بوضوح إذا كانت موجودة
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text(
            "تراجع",
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          onPressed: _isLoading ? null : _deleteAccount,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  "تأكيد الحذف",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
