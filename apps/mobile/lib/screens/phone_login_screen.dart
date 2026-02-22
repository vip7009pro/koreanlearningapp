import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  String? _verificationId;
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số điện thoại.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          try {
            final userCred =
                await FirebaseAuth.instance.signInWithCredential(credential);
            final token = await userCred.user?.getIdToken();
            if (token == null) throw Exception('No token');
            await ref.read(authProvider.notifier).loginWithPhone(
                  token,
                  displayName: _nameCtrl.text.trim().isEmpty
                      ? null
                      : _nameCtrl.text.trim(),
                );
            if (!mounted) return;
            Navigator.of(context).pop();
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đăng nhập thất bại.')),
            );
          }
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi OTP: ${e.message ?? e.code}')),
          );
        },
        codeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi OTP.')),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gửi OTP thất bại.')),
      );
    }
  }

  Future<void> _verify() async {
    final verificationId = _verificationId;
    final code = _codeCtrl.text.trim();
    if (verificationId == null || verificationId.isEmpty) return;
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã OTP.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final token = await userCred.user?.getIdToken();
      if (token == null) throw Exception('No token');

      await ref.read(authProvider.notifier).loginWithPhone(
            token,
            displayName:
                _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP không hợp lệ.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final palette = AppSettingsNotifier.themeById(settings.themeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng nhập bằng SĐT'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: palette.gradient),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị (tuỳ chọn)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+84971092454',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _sendCode,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Gửi OTP'),
            ),
            if (_verificationId != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mã OTP',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Xác nhận'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
