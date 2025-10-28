import 'package:flutter/material.dart';

class SignUpPhoneScreen extends StatelessWidget {
  const SignUpPhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('휴대폰 회원가입 (준비 중)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.build_circle_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                '휴대폰 기반 회원가입 기능을 준비 중입니다.\n현재는 카카오 로그인을 통해 가입 및 이용이 가능합니다.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('카카오 로그인으로 돌아가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
