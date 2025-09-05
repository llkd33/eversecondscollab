import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/sms_service.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';

class SignUpPhoneScreen extends StatefulWidget {
  const SignUpPhoneScreen({super.key});

  @override
  State<SignUpPhoneScreen> createState() => _SignUpPhoneScreenState();
}

class _SignUpPhoneScreenState extends State<SignUpPhoneScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _smsService = SMSService();
  final _authService = AuthService();

  bool _codeSent = false;
  String? _issuedCode; // For local verification
  bool _verifying = false;
  bool _verified = false;
  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('전화번호를 입력해주세요')));
      return;
    }
    final code = _generateCode();
    setState(() {
      _issuedCode = code;
      _codeSent = true;
    });
    try {
      await _smsService.sendVerificationCode(phoneNumber: phone, code: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('인증번호를 발송했습니다')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('인증번호 발송 실패: $e')));
    }
  }

  Future<void> _verifyCode() async {
    final input = _codeController.text.trim();
    if (input.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('6자리 인증번호를 입력해주세요')));
      return;
    }
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _verified = (input == _issuedCode);
      _verifying = false;
    });
    if (!_verified) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('인증번호가 올바르지 않습니다')));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('인증 완료')));
    }
  }

  Future<void> _submit() async {
    if (!_verified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('휴대폰 인증을 완료해주세요')));
      return;
    }
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final nickname = _nicknameController.text.trim();
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호는 6자 이상 입력해주세요')));
      return;
    }
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _authService.signUpWithPhonePassword(phone: phone, password: password, nickname: nickname);
      if (!mounted) return;
      // 로그인 상태로 전환
      await context.read<AuthProvider>().signInWithPhonePassword(phone: phone, password: password);
      if (mounted) context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _generateCode() => (Random().nextInt(900000) + 100000).toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('일반 회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '전화번호 (010-1234-5678)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '인증번호 6자리'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _codeSent ? _verifyCode : _sendCode,
                  child: _verifying
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_codeSent ? '인증' : '인증요청'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호 (6자 이상)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(labelText: '닉네임'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('가입하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

