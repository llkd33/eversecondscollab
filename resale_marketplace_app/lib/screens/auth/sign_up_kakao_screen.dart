import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignUpKakaoScreen extends StatefulWidget {
  const SignUpKakaoScreen({super.key});

  @override
  State<SignUpKakaoScreen> createState() => _SignUpKakaoScreenState();
}

class _SignUpKakaoScreenState extends State<SignUpKakaoScreen> {
  bool _agreed = false;
  final _nicknameController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('약관에 동의해주세요')));
      return;
    }
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요')));
      return;
    }
    setState(() => _submitting = true);
    try {
      // TODO: 카카오 SDK 연동 후, 동의 및 토큰으로 Supabase 세션 연결
      // 닉네임 입력값을 users 테이블에 반영하도록 서버측 처리 필요
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('카카오 가입은 추후 연동 예정입니다.')));
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('카카오로 가입하기')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              title: const Text('필수 약관 전체 동의'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(labelText: '닉네임'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
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

