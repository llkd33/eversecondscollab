import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignUpChoiceScreen extends StatelessWidget {
  const SignUpChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입 방법 선택')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/signup/kakao'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('카카오로 가입하기'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/signup/phone'),
              icon: const Icon(Icons.phone_android),
              label: const Text('일반 회원가입 (전화번호)'),
            ),
            const Spacer(),
            const Text(
              '카카오/일반 계정 중복 방지를 위해 본인인증(CI) 검증이 필요합니다.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

